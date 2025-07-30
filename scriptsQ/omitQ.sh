#!/bin/bash


# omitQ.sh - Q 项目初始化撤销脚本
# 用于撤销 initQ.sh 脚本的所有操作，恢复原始状态

set -e  # 遇到错误立即退出

echo "开始执行 Q 项目初始化撤销脚本..."

# ============================================================================
# 1. 恢复 .github 文件夹
# ============================================================================
echo "步骤 1: 恢复 .github 文件夹..."

if [ -d ".github.bak" ]; then
    echo "  - 删除当前 .github 文件夹（如果存在）"
    if [ -d ".github" ]; then
        rm -rf .github
    fi

    echo "  - 从 .github.bak 恢复 .github 文件夹"
    cp -r .github.bak .github

    echo "  - 删除备份文件夹 .github.bak"
    rm -rf .github.bak

    echo "  - .github 文件夹恢复完成"
else
    echo "  - .github.bak 文件夹不存在，跳过此步骤"
fi

# ============================================================================
# 2. 恢复 common/git-hooks 文件夹
# ============================================================================
echo "步骤 2: 恢复 common/git-hooks 文件夹..."

if [ -d ".git-hooks.bak" ]; then
    echo "  - 创建 common/git-hooks 文件夹"
    mkdir -p common/git-hooks

    echo "  - 从 .git-hooks.bak 恢复 common/git-hooks 文件夹内容"
    cp -r .git-hooks.bak/* common/git-hooks/

    echo "  - 删除备份文件夹 .git-hooks.bak"
    rm -rf .git-hooks.bak

    echo "  - common/git-hooks 文件夹恢复完成"
else
    echo "  - .git-hooks.bak 文件夹不存在，跳过此步骤"
fi

# ============================================================================
# 3. 恢复 rush.json 文件
# ============================================================================
echo "步骤 3: 恢复 rush.json 文件..."

if [ -f "rush.json.bak" ]; then
    echo "  - 从 rush.json.bak 恢复 rush.json 文件"
    cp rush.json.bak rush.json

    echo "  - 删除备份文件 rush.json.bak"
    rm -f rush.json.bak

    echo "  - rush.json 文件恢复完成"
else
    echo "  - rush.json.bak 文件不存在，跳过此步骤"
fi

# ============================================================================
# 4. 深度遍历所有文件夹，撤销包名替换和移除 maintainers 配置
# ============================================================================
echo "步骤 4: 深度遍历所有文件夹，撤销包名替换和移除 maintainers 配置..."

# 定义撤销包名替换的函数
revert_package_name_in_file() {
    local file="$1"
    if [ -f "$file" ]; then
        # 检查文件是否包含目标字符串，避免不必要的处理
        if grep -q "@q/flowgram\.ai\." "$file" 2>/dev/null; then
            # 使用 sed 进行替换，兼容 macOS 和 Linux
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' 's/@q\/flowgram\.ai\./@flowgram.ai\//g' "$file"
            else
                # Linux
                sed -i 's/@q\/flowgram\.ai\./@flowgram.ai\//g' "$file"
            fi
            echo "    - 已处理: $file"
        fi
    fi
}

# 定义移除 maintainers 配置和恢复 publishConfig 的函数
remove_maintainers_and_revert_registry() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "    - 正在处理 $file (移除 maintainers 配置和恢复 registry)..."

        # 使用 Node.js 脚本来处理 JSON 文件
        node -e "
        const fs = require('fs');

        try {
            // 读取 package.json
            const packageJsonPath = '$file';
            const packageData = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
            let modified = false;

            // 1. 移除 maintainers 字段
            if (packageData.maintainers) {
                delete packageData.maintainers;
                modified = true;
                console.log('    - ✅ 已移除 maintainers 配置');
            }

            // 2. 恢复 publishConfig 配置为原始的 npmjs.org
            if (packageData.publishConfig && packageData.publishConfig.registry === 'https://registry.qnpm.qihoo.net') {
                packageData.publishConfig.registry = 'https://registry.npmjs.org/';
                modified = true;
                console.log('    - ✅ 已恢复 publishConfig registry 为 npmjs.org');
            }

            // 3. 如果有修改，写回文件
            if (modified) {
                fs.writeFileSync(packageJsonPath, JSON.stringify(packageData, null, 2) + '\n', 'utf8');
                console.log('    - ✅ 已保存修改到 $file');
            } else {
                console.log('    - ⚠️  $file 无需修改');
            }
        } catch (error) {
            console.log('    - ❌ 处理 $file 时出错:', error.message);
        }
        "
    fi
}

# 定义要处理的文件夹列表
FOLDERS_TO_PROCESS=("packages" "apps" "e2e" "config")

for folder in "${FOLDERS_TO_PROCESS[@]}"; do
    if [ -d "$folder" ]; then
        echo "  - 处理 $folder 文件夹..."

        # 处理所有 package.json 文件
        find "$folder" -name "package.json" -type f | while read -r file; do
            # 先撤销包名替换
            revert_package_name_in_file "$file"
            # 再移除 maintainers 配置和恢复 registry
            remove_maintainers_and_revert_registry "$file"
        done

        # 处理所有其他类型的文件
        find "$folder" -type f \( \
            -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \
            -o -name "*.json" -o -name "*.md" -o -name "*.yml" -o -name "*.yaml" \
            -o -name "*.html" -o -name "*.css" -o -name "*.scss" -o -name "*.less" \
            -o -name "*.vue" -o -name "*.svelte" -o -name "*.txt" \
            -o -name "*.config.js" -o -name "*.config.ts" \
            -o -name "*.test.js" -o -name "*.test.ts" \
            -o -name "*.spec.js" -o -name "*.spec.ts" \
            -o -name "*.d.ts" -o -name "*.mjs" -o -name "*.cjs" \
            -o -name ".eslintrc.js" -o -name ".eslintrc.cjs" \
            -o -name "tsconfig.json" \
        \) ! -name "package.json" | while read -r file; do
            revert_package_name_in_file "$file"
        done

        echo "  - $folder 文件夹处理完成"
    else
        echo "  - $folder 文件夹不存在，跳过"
    fi
done

# ============================================================================
# 5. 恢复 apps/create-app/src/index.ts 中的 registry URL
# ============================================================================
echo "步骤 5: 恢复 apps/create-app/src/index.ts 中的 registry URL..."

if [ -f "apps/create-app/src/index.ts" ]; then
    echo "  - 将 https://registry.qnpm.qihoo.net 恢复为 https://registry.npmjs.org"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' 's|https://registry\.qnpm\.qihoo\.net|https://registry.npmjs.org|g' "apps/create-app/src/index.ts"
    else
        # Linux
        sed -i 's|https://registry\.qnpm\.qihoo\.net|https://registry.npmjs.org|g' "apps/create-app/src/index.ts"
    fi
    echo "  - apps/create-app/src/index.ts 文件恢复完成"
else
    echo "  - apps/create-app/src/index.ts 文件不存在，跳过此步骤"
fi

# ============================================================================
# 6. 恢复 .npmrc-publish 文件
# ============================================================================
echo "步骤 6: 恢复 .npmrc-publish 文件..."

if [ -f ".npmrc-publish.bak" ]; then
    echo "  - 从 .npmrc-publish.bak 恢复 common/config/rush/.npmrc-publish 文件"
    cp ".npmrc-publish.bak" "common/config/rush/.npmrc-publish"

    echo "  - 删除备份文件 .npmrc-publish.bak"
    rm -f ".npmrc-publish.bak"

    echo "  - .npmrc-publish 文件恢复完成"
else
    echo "  - .npmrc-publish.bak 文件不存在，跳过此步骤"
fi

# ============================================================================
# 7. 删除创建的 .env 和 .env.example 文件
# ============================================================================
echo "步骤 7: 删除创建的 .env 和 .env.example 文件..."

if [ -f ".env" ]; then
    echo "  - 删除 .env 文件"
    rm -f ".env"
    echo "  - .env 文件删除完成"
else
    echo "  - .env 文件不存在，跳过"
fi

if [ -f ".env.example" ]; then
    echo "  - 删除 .env.example 文件"
    rm -f ".env.example"
    echo "  - .env.example 文件删除完成"
else
    echo "  - .env.example 文件不存在，跳过"
fi

# ============================================================================
# 8. 删除创建的根目录 .npmrc 文件
# ============================================================================
echo "步骤 8: 删除创建的根目录 .npmrc 文件..."

if [ -f ".npmrc" ]; then
    echo "  - 删除 .npmrc 文件"
    rm -f ".npmrc"
    echo "  - .npmrc 文件删除完成"
else
    echo "  - .npmrc 文件不存在，跳过"
fi

# ============================================================================
# 9. 恢复 version-policies.json 文件
# ============================================================================
echo "步骤 9: 恢复 version-policies.json 文件..."

if [ -f "version-policies.json.bak" ]; then
    echo "  - 从 version-policies.json.bak 恢复 common/config/rush/version-policies.json 文件"
    cp "version-policies.json.bak" "common/config/rush/version-policies.json"

    echo "  - 删除备份文件 version-policies.json.bak"
    rm -f "version-policies.json.bak"

    echo "  - version-policies.json 文件恢复完成"
else
    echo "  - version-policies.json.bak 文件不存在，跳过此步骤"
fi

# ============================================================================
# 10. 特殊修改：处理特定文件的特殊要求
# ============================================================================
echo "步骤 10: 执行特殊修改..."

# 10.1 对于 apps/docs/package.json 和 apps/plugin-llms/package.json，确保没有 publishConfig 属性
echo "  - 处理 apps/docs/package.json 和 apps/plugin-llms/package.json 的 publishConfig..."

for special_file in "apps/docs/package.json" "apps/plugin-llms/package.json"; do
    if [ -f "$special_file" ]; then
        echo "    - 正在处理 $special_file (移除 publishConfig 属性)..."

        # 使用 Node.js 脚本确保这些文件没有 publishConfig 属性
        node -e "
        const fs = require('fs');

        try {
            const packageJsonPath = '$special_file';
            const packageData = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
            let modified = false;

            // 确保移除 publishConfig 属性
            if (packageData.publishConfig) {
                delete packageData.publishConfig;
                modified = true;
                console.log('    - ✅ 已移除 $special_file 的 publishConfig 属性');
            } else {
                console.log('    - ⚠️  $special_file 没有 publishConfig 属性，无需修改');
            }

            if (modified) {
                fs.writeFileSync(packageJsonPath, JSON.stringify(packageData, null, 2) + '\n', 'utf8');
                console.log('    - ✅ 已保存修改到 $special_file');
            }
        } catch (error) {
            console.log('    - ❌ 处理 $special_file 时出错:', error.message);
        }
        "
    else
        echo "    - $special_file 文件不存在，跳过"
    fi
done

# 10.2 对于 config/eslint-config/package.json，设置 maintainers: [] 在 author 属性下面
echo "  - 处理 config/eslint-config/package.json 的 maintainers 配置..."

if [ -f "config/eslint-config/package.json" ]; then
    echo "    - 正在处理 config/eslint-config/package.json (设置 maintainers: [])..."

    # 使用 Node.js 脚本来处理 JSON 文件
    node -e "
    const fs = require('fs');

    try {
        const packageJsonPath = 'config/eslint-config/package.json';
        const content = fs.readFileSync(packageJsonPath, 'utf8');
        const packageData = JSON.parse(content);
        let modified = false;

        // 确保 maintainers 字段存在且为空数组
        if (!packageData.maintainers || JSON.stringify(packageData.maintainers) !== '[]') {
            packageData.maintainers = [];
            modified = true;
            console.log('    - ✅ 已设置 maintainers 为空数组');
        } else {
            console.log('    - ⚠️  maintainers 已是空数组，无需修改');
        }

        if (modified) {
            // 重新构建 JSON，确保 maintainers 在 author 后面
            const orderedPackageData = {};

            // 按特定顺序添加字段
            if (packageData.name) orderedPackageData.name = packageData.name;
            if (packageData.version) orderedPackageData.version = packageData.version;
            if (packageData.author) orderedPackageData.author = packageData.author;
            if (packageData.maintainers !== undefined) orderedPackageData.maintainers = packageData.maintainers;

            // 添加其他所有字段
            for (const [key, value] of Object.entries(packageData)) {
                if (!['name', 'version', 'author', 'maintainers'].includes(key)) {
                    orderedPackageData[key] = value;
                }
            }

            fs.writeFileSync(packageJsonPath, JSON.stringify(orderedPackageData, null, 2) + '\n', 'utf8');
            console.log('    - ✅ 已保存修改到 config/eslint-config/package.json');
        }
    } catch (error) {
        console.log('    - ❌ 处理 config/eslint-config/package.json 时出错:', error.message);
    }
    "
else
    echo "    - config/eslint-config/package.json 文件不存在，跳过"
fi

echo "  - 特殊修改处理完成"

# ============================================================================
# 完成
# ============================================================================
echo ""
echo "🎉 Q 项目初始化撤销脚本执行完成！"
echo ""
echo "执行的撤销操作总结："
echo "1. ✅ 已从 .github.bak 恢复 .github 文件夹并删除备份"
echo "2. ✅ 已从 .git-hooks.bak 恢复 common/git-hooks 文件夹并删除备份"
echo "3. ✅ 已从 rush.json.bak 恢复 rush.json 文件并删除备份"
echo "4. ✅ 已撤销所有文件中的包名替换（@q/flowgram.ai. → @flowgram.ai/）并移除 maintainers 配置"
echo "5. ✅ 已恢复 apps/create-app/src/index.ts 中的 registry URL"
echo "6. ✅ 已从 .npmrc-publish.bak 恢复 .npmrc-publish 文件并删除备份"
echo "7. ✅ 已删除创建的 .env 和 .env.example 文件"
echo "8. ✅ 已删除创建的根目录 .npmrc 文件"
echo "9. ✅ 已从 version-policies.json.bak 恢复 version-policies.json 文件并删除备份"
echo "10. ✅ 已执行特殊修改："
echo "    - apps/docs/package.json 和 apps/plugin-llms/package.json 移除 publishConfig 属性"
echo "    - config/eslint-config/package.json 设置 maintainers: [] 在 author 属性下面"
echo ""
echo "项目已恢复到执行 initQ.sh 之前的原始状态！"
echo ""
