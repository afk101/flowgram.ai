#!/bin/bash

# 获取当前分支
CURRENT_BRANCH=$(git branch --show-current)
echo "  - 当前分支: $CURRENT_BRANCH"

# 校验分支名格式是否为 feature/v数字.数字.数字
if [[ $CURRENT_BRANCH =~ ^feature/v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "  - ✅ 分支名格式正确"
else
    echo -e "\033[31m❌ 分支名不符合规范，停止脚本\033[0m"
    echo -e "\033[31m   要求格式: feature/v数字.数字.数字 (例如: feature/v0.2.27)\033[0m"
    echo -e "\033[31m   当前分支: $CURRENT_BRANCH\033[0m"
    exit 1
fi

# 加载环境变量
export $(cat .env | xargs)

# 更新依赖
rush update

# 构建
rush build

# 升级版本
rush version --bump --version-policy MyProject-prerelease

# 统一发布
rush publish --force --apply --publish --target-branch $CURRENT_BRANCH --include-all

# 校验版本策略配置
if ! grep -q '"policyName": "MyProject-prerelease"' common/config/rush/version-policies.json; then
    echo -e "\033[31m❌ version-policies.json配置错误，没有检测到MyProject-prerelease\033[0m"
    exit 1
fi

# 获取版本号
VERSION=$(cat common/config/rush/version-policies.json | grep -A 3 '"policyName": "MyProject-prerelease"' | grep '"version"' | sed 's/.*"version": "\([^"]*\)".*/\1/')

# 提交代码
git add .
git commit -m "release: publish $VERSION"
git push
