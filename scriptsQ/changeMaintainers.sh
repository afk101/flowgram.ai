#!/bin/bash

# changeMaintainers.sh - 替换所有package.json中的maintainers属性值
# 深度遍历 packages 和 apps 文件夹，替换所有的package.json中的maintainers的属性值

set -e  # 遇到错误立即退出

echo "开始执行 maintainers 替换脚本..."

# ============================================================================
# 深度遍历 packages 和 apps 文件夹，替换所有的package.json中的maintainers属性值
# ============================================================================
echo "深度遍历并替换 package.json 中的 maintainers 配置..."

# 定义替换 maintainers 配置的函数
update_maintainers() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "  - 正在处理 $file (更新 maintainers 配置)..."

        # 使用 Node.js 脚本来处理 JSON 文件
        node -e "
        const fs = require('fs');
        const path = require('path');

        try {
            // 读取 maintainers.json
            const maintainersPath = 'scriptsQ/maintainers.json';
            if (!fs.existsSync(maintainersPath)) {
                console.log('  - ❌ 错误: scriptsQ/maintainers.json 文件不存在');
                process.exit(1);
            }

            const maintainersData = JSON.parse(fs.readFileSync(maintainersPath, 'utf8'));

            // 读取 package.json
            const packageJsonPath = '$file';
            const packageData = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
            let modified = false;

            // 添加或覆盖 maintainers 字段
            if (packageData.maintainers) {
                // 检查是否需要更新
                const currentMaintainers = JSON.stringify(packageData.maintainers);
                const newMaintainers = JSON.stringify(maintainersData);

                if (currentMaintainers !== newMaintainers) {
                    packageData.maintainers = maintainersData;
                    modified = true;
                    console.log('  - ✅ 已覆盖现有 maintainers 配置');
                } else {
                    console.log('  - ⚠️  maintainers 配置已是最新，跳过修改');
                }
            } else {
                packageData.maintainers = maintainersData;
                modified = true;
                console.log('  - ✅ 已添加 maintainers 配置');
            }

            // 如果有修改，写回文件
            if (modified) {
                fs.writeFileSync(packageJsonPath, JSON.stringify(packageData, null, 2) + '\n', 'utf8');
                console.log('  - ✅ 已保存修改到 $file');
            } else {
                console.log('  - ⚠️  $file 无需修改');
            }
        } catch (error) {
            console.log('  - ❌ 处理 $file 时出错:', error.message);
        }
        "
    fi
}

# 处理 packages 文件夹
if [ -d "packages" ]; then
    echo "- 处理 packages 文件夹..."

    # 查找所有 package.json 文件并处理
    find packages -name "package.json" -type f | while read -r file; do
        update_maintainers "$file"
    done

    echo "- packages 文件夹处理完成"
else
    echo "- packages 文件夹不存在，跳过"
fi

# 处理 apps 文件夹
if [ -d "apps" ]; then
    echo "- 处理 apps 文件夹..."

    # 查找所有 package.json 文件并处理
    find apps -name "package.json" -type f | while read -r file; do
        update_maintainers "$file"
    done

    echo "- apps 文件夹处理完成"
else
    echo "- apps 文件夹不存在，跳过"
fi

# ============================================================================
# 完成
# ============================================================================
echo ""
echo "🎉 maintainers 替换脚本执行完成！"
echo ""
echo "执行的操作总结："
echo "✅ 已深度遍历 packages 和 apps 文件夹"
echo "✅ 已替换所有 package.json 文件中的 maintainers 配置"
echo ""
echo "maintainers 配置来源: scriptsQ/maintainers.json"
echo ""
