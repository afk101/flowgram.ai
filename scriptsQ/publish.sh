#!/bin/bash

# 将所有输出重定向到 publish.txt 文件
exec > >(tee -a publish.txt) 2>&1

# 清空之前的日志文件
> publish.txt

echo "📅 发布开始时间: $(date)"
echo "================================"

# 检验是否在项目根目录执行脚本
if [[ ! -f "rush.json" ]] || [[ ! -d "common/config/rush" ]]; then
    echo -e "\033[31m❌ 请在项目根目录执行此脚本！\033[0m"
    echo -e "\033[31m   当前目录: $(pwd)\033[0m"
    echo -e "\033[31m   需要包含: rush.json 和 common/config/rush/ 目录\033[0m"
    exit 1
fi

echo "🚀 开始执行发布脚本..."
echo "================================"

# 获取当前分支
echo "📋 步骤 1/9: 获取当前分支信息"
CURRENT_BRANCH=$(git branch --show-current)
echo "  - 当前分支: $CURRENT_BRANCH"

# 校验分支名格式是否为 feature/v数字.数字.数字
echo "📋 步骤 2/9: 校验分支名格式"
if [[ $CURRENT_BRANCH =~ ^feature/v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "  - ✅ 分支名格式正确"
else
    echo -e "\033[31m❌ 分支名不符合规范，停止脚本\033[0m"
    echo -e "\033[31m   要求格式: feature/v数字.数字.数字 (例如: feature/v0.2.27)\033[0m"
    echo -e "\033[31m   当前分支: $CURRENT_BRANCH\033[0m"
    exit 1
fi

# 加载环境变量
echo "📋 步骤 3/9: 加载环境变量"
export $(cat .env | xargs)
echo "  - ✅ 环境变量加载完成"

# 校验版本策略配置
echo "📋 步骤 4/9: 校验版本策略配置"
if ! grep -q '"policyName": "MyProject-prerelease"' common/config/rush/version-policies.json; then
    echo -e "\033[31m❌ version-policies.json配置错误，没有检测到MyProject-prerelease\033[0m"
    exit 1
fi
echo "  - ✅ 版本策略配置正确"

# 更新依赖
echo "📋 步骤 5/9: 更新项目依赖"
if rush update; then
    echo "  - ✅ 依赖更新完成"
else
    echo -e "\033[31m❌ 依赖更新失败！请检查网络连接和依赖配置\033[0m"
    echo -e "\033[31m   错误信息: rush update 命令执行失败\033[0m"
    exit 1
fi

# 构建
echo "📋 步骤 6/9: 构建项目"
if rush build; then
    echo "  - ✅ 项目构建完成"
else
    echo -e "\033[31m❌ 项目构建失败！请检查代码编译错误\033[0m"
    echo -e "\033[31m   错误信息: rush build 命令执行失败\033[0m"
    exit 1
fi

# 升级版本
echo "📋 步骤 7/9: 升级版本号"
rush version --bump --version-policy MyProject-prerelease
echo "  - ✅ 版本号升级完成"

# 获取版本号
VERSION=$(cat common/config/rush/version-policies.json | grep -A 3 '"policyName": "MyProject-prerelease"' | grep '"version"' | sed 's/.*"version": "\([^"]*\)".*/\1/')
echo "  - 当前版本: $VERSION"

# 统一发布
echo "📋 步骤 8/9: 发布包到仓库"
rush publish --force --apply --publish --target-branch $CURRENT_BRANCH --include-all
echo "  - ✅ 包发布完成"


# 提交代码
echo "📋 步骤 9/9: 提交代码到Git仓库"
git add .
git commit -m "release: publish $VERSION" -n

# 检查远程分支是否存在，如果不存在则设置上游分支
if ! git ls-remote --exit-code --heads origin $CURRENT_BRANCH > /dev/null 2>&1; then
    echo "  - 检测到新分支，设置上游分支..."
    git push --set-upstream origin $CURRENT_BRANCH
else
    echo "  - 推送到现有分支..."
    git push
fi
echo "  - ✅ 代码提交完成"

echo "================================"
echo "🎉 发布脚本执行完成！"
echo "📅 发布结束时间: $(date)"
echo ""
echo "📊 执行总结:"
echo "  - 分支: $CURRENT_BRANCH"
echo "  - 版本: $VERSION"
echo "  - 操作: 依赖更新 → 项目构建 → 版本升级 → 包发布 → 代码提交"
echo "  - 状态: ✅ 全部完成"
echo ""
echo "📄 完整日志已保存到: publish.txt"
