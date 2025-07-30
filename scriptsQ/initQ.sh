#!/bin/bash

# initQ.sh - 项目初始化脚本
# 用于将 flowgram.ai 项目转换为 Q 项目的配置

set -e  # 遇到错误立即退出

echo "开始执行 Q 项目初始化脚本..."

# ============================================================================
# 0. 校验分支名格式
# ============================================================================
echo "步骤 0: 校验分支名格式..."

# 获取当前分支名
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

# ============================================================================
# 1. 备份并移除 .github 文件夹
# ============================================================================
echo "步骤 1: 处理 .github 文件夹..."

if [ -d ".github" ]; then
    echo "  - 创建 .github.bak 文件夹"
    mkdir -p .github.bak

    echo "  - 将 .github 中的所有文件移动到 .github.bak"
    cp -r .github/* .github.bak/

    echo "  - 删除 .github 文件夹"
    rm -rf .github

    echo "  - .github 文件夹处理完成"
else
    echo "  - .github 文件夹不存在，跳过此步骤"
fi

# ============================================================================
# 2. 备份并移除 common/git-hooks 文件夹
# ============================================================================
echo "步骤 2: 处理 common/git-hooks 文件夹..."

if [ -d "common/git-hooks" ]; then
    echo "  - 创建 .git-hooks.bak 文件夹"
    mkdir -p .git-hooks.bak

    echo "  - 将 common/git-hooks 中的所有文件移动到 .git-hooks.bak"
    cp -r common/git-hooks/* .git-hooks.bak/

    echo "  - 删除 common/git-hooks 文件夹"
    rm -rf common/git-hooks

    echo "  - common/git-hooks 文件夹处理完成"
else
    echo "  - common/git-hooks 文件夹不存在，跳过此步骤"
fi

# ============================================================================
# 3. 修改 rush.json 中的 projects 配置
# ============================================================================
echo "步骤 3: 修改 rush.json 文件..."

if [ -f "rush.json" ]; then
    echo "  - 备份原始 rush.json 文件"
    cp rush.json rush.json.bak

    echo "  - 使用 Node.js 脚本修改 rush.json"
    node -e "
    const fs = require('fs');
    const path = 'rush.json';

    console.log('读取 rush.json 文件...');
    let content = fs.readFileSync(path, 'utf8');

    // 统计修改前的状态
    const beforeVersionPolicy = (content.match(/\"versionPolicyName\":\s*\"[^\"]*\"/g) || []).length;
    const beforePackageName = (content.match(/\"packageName\":\s*\"@flowgram\.ai\//g) || []).length;
    console.log('修改前: versionPolicyName 项目数量: ' + beforeVersionPolicy + ', @flowgram.ai/ 包名数量: ' + beforePackageName);

    // 1. 修改所有 versionPolicyName 为 'MyProject-prerelease'
    console.log('步骤1: 修改 versionPolicyName...');
    content = content.replace(
        /\"versionPolicyName\":\s*\"[^\"]*\"/g,
        '\"versionPolicyName\": \"MyProject-prerelease\"'
    );

    // 2. 在有 versionPolicyName 的对象中添加 shouldPublish: true
    console.log('步骤2: 添加 shouldPublish 属性...');
    // 使用更精确的方法：在项目对象开始后立即添加 shouldPublish
    const lines = content.split('\n');
    let modifiedLines = [];
    let i = 0;

    while (i < lines.length) {
        const line = lines[i];
        modifiedLines.push(line);

        // 检测项目对象开始（非注释的大括号）
        if (line.trim().startsWith('{') && !line.includes('//')) {
            // 收集这个项目对象的所有内容来检查是否包含 versionPolicyName
            let projectContent = '';
            let braceCount = 1;
            let j = i + 1;

            while (j < lines.length && braceCount > 0) {
                const tempLine = lines[j];
                projectContent += tempLine + '\n';
                const openBraces = (tempLine.match(/{/g) || []).length;
                const closeBraces = (tempLine.match(/}/g) || []).length;
                braceCount += openBraces - closeBraces;
                j++;
            }

            // 如果这个项目包含 versionPolicyName 但不包含 shouldPublish
            if (projectContent.includes('versionPolicyName') && !projectContent.includes('shouldPublish')) {
                // 在项目对象开始后立即添加 shouldPublish（作为第一个属性）
                modifiedLines.push('            \"shouldPublish\": true,');
            }
        }

        i++;
    }

    content = modifiedLines.join('\n');

    // 3. 修改 packageName 中的 @flowgram.ai/ 为 @q/flowgram.ai.
    console.log('步骤3: 修改 packageName...');
    content = content.replace(
        /\"packageName\":\s*\"@flowgram\.ai\//g,
        '\"packageName\": \"@q/flowgram.ai.'
    );

    // 统计修改后的状态
    const afterVersionPolicy = (content.match(/\"versionPolicyName\":\s*\"MyProject-prerelease\"/g) || []).length;
    const afterShouldPublish = (content.match(/\"shouldPublish\":\s*true/g) || []).length;
    const afterPackageName = (content.match(/\"packageName\":\s*\"@q\/flowgram\.ai\./g) || []).length;
    console.log('修改后: MyProject-prerelease 数量: ' + afterVersionPolicy + ', shouldPublish 数量: ' + afterShouldPublish + ', @q/flowgram.ai. 包名数量: ' + afterPackageName);

    // 写回文件
    fs.writeFileSync(path, content, 'utf8');
    console.log('✅ rush.json 修改完成');

    // 输出修改统计
    console.log('');
    console.log('📊 修改统计:');
    console.log('- 修改了 ' + afterVersionPolicy + ' 个项目的 versionPolicyName');
    console.log('- 添加了 ' + afterShouldPublish + ' 个 shouldPublish 属性');
    console.log('- 修改了 ' + afterPackageName + ' 个包名前缀');
    "

    echo "  - rush.json 文件修改完成"
else
    echo "  - rush.json 文件不存在，跳过此步骤"
fi

# ============================================================================
# 4. 深度遍历 packages 和 apps 文件夹，替换文件内容、添加 maintainers 配置并更新 registry 地址
# ============================================================================
echo "步骤 4: 深度遍历并替换文件内容、添加 maintainers 配置并更新 registry 地址..."

# 定义替换函数
replace_in_file() {
    local file="$1"
    if [ -f "$file" ]; then
        # 使用 sed 进行替换，兼容 macOS 和 Linux
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' 's/@flowgram\.ai\//@q\/flowgram.ai./g' "$file"
        else
            # Linux
            sed -i 's/@flowgram\.ai\//@q\/flowgram.ai./g' "$file"
        fi
        echo "    - 已处理: $file"
    fi
}

# 定义添加 maintainers 配置和修改 publishConfig 的函数
# 替换
# "publishConfig": {
#    "access": "public",
#    "registry": "https://registry.npmjs.org/"
# }
# 的registry为"https://registry.qnpm.qihoo.net"
add_maintainers_and_update_registry() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "    - 正在处理 $file (添加 maintainers 配置和更新 registry)..."

        # 使用 Node.js 脚本来处理 JSON 文件
        node -e "
        const fs = require('fs');
        const path = require('path');

        try {
            // 读取 maintainers.json
            const maintainersPath = 'scriptsQ/maintainers.json';
            if (!fs.existsSync(maintainersPath)) {
                console.log('    - 警告: scriptsQ/maintainers.json 文件不存在，跳过添加 maintainers');
            }

            let maintainersData = null;
            if (fs.existsSync(maintainersPath)) {
                maintainersData = JSON.parse(fs.readFileSync(maintainersPath, 'utf8'));
            }

            // 读取 package.json
            const packageJsonPath = '$file';
            const packageData = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
            let modified = false;

            // 1. 添加或覆盖 maintainers 字段
            if (maintainersData) {
                if (packageData.maintainers) {
                    console.log('    - ✅ 已覆盖现有 maintainers 配置');
                } else {
                    console.log('    - ✅ 已添加 maintainers 配置');
                }
                packageData.maintainers = maintainersData;
                modified = true;
            }

            // 2. 设置或替换 publishConfig 配置
            const targetPublishConfig = {
                access: 'public',
                registry: 'https://registry.qnpm.qihoo.net'
            };

            if (packageData.publishConfig) {
                // 如果已有 publishConfig，检查是否需要更新
                const currentConfig = JSON.stringify(packageData.publishConfig);
                const targetConfig = JSON.stringify(targetPublishConfig);

                if (currentConfig !== targetConfig) {
                    packageData.publishConfig = targetPublishConfig;
                    modified = true;
                    console.log('    - ✅ 已替换 publishConfig 配置');
                } else {
                    console.log('    - ⚠️  publishConfig 配置已是目标配置，跳过修改');
                }
            } else {
                // 如果没有 publishConfig，创建新的配置
                packageData.publishConfig = targetPublishConfig;
                modified = true;
                console.log('    - ✅ 已创建 publishConfig 配置');
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

# 处理 packages 文件夹
if [ -d "packages" ]; then
    echo "  - 处理 packages 文件夹..."

    # 查找所有 package.json 文件并处理
    find packages -name "package.json" -type f | while read -r file; do
        # 先替换包名
        replace_in_file "$file"
        # 再添加 maintainers 配置和更新 registry
        add_maintainers_and_update_registry "$file"
    done

    # 查找所有 src 文件夹下的文件
    find packages -path "*/src/*" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" -o -name "*.json" -o -name "*.md" \) | while read -r file; do
        replace_in_file "$file"
    done

    echo "  - packages 文件夹处理完成"
else
    echo "  - packages 文件夹不存在，跳过"
fi

# 处理 apps 文件夹
if [ -d "apps" ]; then
    echo "  - 处理 apps 文件夹..."

    # 查找所有 package.json 文件并处理
    find apps -name "package.json" -type f | while read -r file; do
        # 先替换包名
        replace_in_file "$file"
        # 再添加 maintainers 配置和更新 registry
        add_maintainers_and_update_registry "$file"
    done

    # 查找所有 src 文件夹下的文件
    find apps -path "*/src/*" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" -o -name "*.json" -o -name "*.md" \) | while read -r file; do
        replace_in_file "$file"
    done

    echo "  - apps 文件夹处理完成"
else
    echo "  - apps 文件夹不存在，跳过"
fi

# ============================================================================
# 5. 替换 apps/create-app/src/index.ts 中的 registry URL
# ============================================================================
echo "步骤 5: 替换 apps/create-app/src/index.ts 中的 registry URL..."

if [ -f "apps/create-app/src/index.ts" ]; then
    echo "  - 将 https://registry.npmjs.org 替换为 https://registry.qnpm.qihoo.net"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' 's|https://registry\.npmjs\.org|https://registry.qnpm.qihoo.net|g' "apps/create-app/src/index.ts"
    else
        # Linux
        sed -i 's|https://registry\.npmjs\.org|https://registry.qnpm.qihoo.net|g' "apps/create-app/src/index.ts"
    fi
    echo "  - apps/create-app/src/index.ts 文件修改完成"
else
    echo "  - apps/create-app/src/index.ts 文件不存在，跳过此步骤"
fi

# ============================================================================
# 6. 处理 .npmrc-publish 文件
# ============================================================================
echo "步骤 6: 处理 .npmrc-publish 文件..."

if [ -f "common/config/rush/.npmrc-publish" ]; then
    echo "  - 创建 .npmrc-publish.bak 文件并复制内容"
    cp "common/config/rush/.npmrc-publish" ".npmrc-publish.bak"

    echo "  - 替换 common/config/rush/.npmrc-publish 文件内容"
    cat > "common/config/rush/.npmrc-publish" << 'EOF'
registry=https://registry.qnpm.qihoo.net
//registry.qnpm.qihoo.net/:_authToken=${QNPM_AUTH_TOKEN}
EOF

    echo "  - .npmrc-publish 文件处理完成"
else
    echo "  - common/config/rush/.npmrc-publish 文件不存在，跳过此步骤"
fi

# ============================================================================
# 7. 创建 .env 和 .env.example 文件
# ============================================================================
echo "步骤 7: 创建 .env 和 .env.example 文件..."

echo "  - 创建 .env 文件"
cat > ".env" << 'EOF'
QNPM_AUTH_TOKEN=your-qnpm-token
EOF

echo "  - 创建 .env.example 文件"
cat > ".env.example" << 'EOF'
QNPM_AUTH_TOKEN=your-qnpm-token
EOF

echo "  - .env 和 .env.example 文件创建完成"

# ============================================================================
# 8. 创建根目录 .npmrc 文件
# ============================================================================
echo "步骤 8: 创建根目录 .npmrc 文件..."

echo "  - 创建 .npmrc 文件"
cat > ".npmrc" << 'EOF'
@q:registry=https://registry.qnpm.qihoo.net
registry=https://registry.npmjs.org
legacy-peer-deps=true
EOF

echo "  - .npmrc 文件创建完成"

# ============================================================================
# 9. 处理 version-policies.json 文件
# ============================================================================
echo "步骤 9: 处理 version-policies.json 文件..."

if [ -f "common/config/rush/version-policies.json" ]; then
    echo "  - 创建 version-policies.json.bak 文件并复制内容"
    cp "common/config/rush/version-policies.json" "version-policies.json.bak"

    echo "  - 获取当前分支名"
    CURRENT_BRANCH=$(git branch --show-current)
    echo "    当前分支: $CURRENT_BRANCH"

    # 提取版本号（匹配 feature/v 后面的内容）
    if [[ $CURRENT_BRANCH =~ feature/v(.+)$ ]]; then
        VERSION_NUMBER="${BASH_REMATCH[1]}"
        echo "    提取的版本号: $VERSION_NUMBER"

        echo "  - 替换 common/config/rush/version-policies.json 文件内容"
        cat > "common/config/rush/version-policies.json" << EOF
[
  {
    "definitionName": "lockStepVersion",
    "policyName": "MyProject-prerelease",
    "version": "${VERSION_NUMBER}-0",
    "nextBump": "prerelease"
  }
]
EOF

        echo "  - version-policies.json 文件处理完成，版本设置为: ${VERSION_NUMBER}-0"
    else
        echo "  - 警告: 当前分支名不符合 feature/v* 格式，跳过版本号替换"
        echo "  - 使用默认版本号 0.0.0-0"
        cat > "common/config/rush/version-policies.json" << 'EOF'
[
  {
    "definitionName": "lockStepVersion",
    "policyName": "MyProject-prerelease",
    "version": "0.0.0-0",
    "nextBump": "prerelease"
  }
]
EOF
    fi
else
    echo "  - common/config/rush/version-policies.json 文件不存在，跳过此步骤"
fi

# ============================================================================
# 10. 深度遍历 e2e 和 config 文件夹下的所有 package.json 文件，修改包名引用
# ============================================================================
echo "步骤 10: 深度遍历 e2e 和 config 文件夹下的所有 package.json 文件，修改包名引用..."

# 定义要处理的文件夹列表
FOLDERS_TO_PROCESS_PACKAGE=("e2e" "config")

for folder in "${FOLDERS_TO_PROCESS_PACKAGE[@]}"; do
    if [ -d "$folder" ]; then
        echo "  - 处理 $folder 文件夹..."

        # 查找所有 package.json 文件并处理
        find "$folder" -name "package.json" -type f | while read -r file; do
            echo "    - 正在处理: $file"
            # 使用 sed 进行替换，兼容 macOS 和 Linux
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' 's/@flowgram\.ai\//@q\/flowgram.ai./g' "$file"
            else
                # Linux
                sed -i 's/@flowgram\.ai\//@q\/flowgram.ai./g' "$file"
            fi
            echo "    - 已处理: $file"
        done

        echo "  - $folder 文件夹处理完成"
    else
        echo "  - $folder 文件夹不存在，跳过"
    fi
done

# ============================================================================
# 11. 深度遍历 e2e、apps、packages、config 文件夹，替换 .eslintrc.js 和 .eslintrc.cjs 文件中的包名引用
# ============================================================================
echo "步骤 11: 深度遍历 e2e、apps、packages、config 文件夹，替换 .eslintrc.js 和 .eslintrc.cjs 文件中的包名引用..."

# 定义要处理的文件夹列表
FOLDERS_TO_PROCESS_ESLINT=("e2e" "apps" "packages" "config")

for folder in "${FOLDERS_TO_PROCESS_ESLINT[@]}"; do
    if [ -d "$folder" ]; then
        echo "  - 处理 $folder 文件夹..."

        # 查找所有 .eslintrc.js 文件并处理
        find "$folder" -name ".eslintrc.js" -type f | while read -r file; do
            echo "    - 正在处理: $file"
            # 使用 sed 进行替换，兼容 macOS 和 Linux
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' 's/@flowgram\.ai\//@q\/flowgram.ai./g' "$file"
            else
                # Linux
                sed -i 's/@flowgram\.ai\//@q\/flowgram.ai./g' "$file"
            fi
            echo "    - 已处理: $file"
        done

        # 查找所有 .eslintrc.cjs 文件并处理
        find "$folder" -name ".eslintrc.cjs" -type f | while read -r file; do
            echo "    - 正在处理: $file"
            # 使用 sed 进行替换，兼容 macOS 和 Linux
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' 's/@flowgram\.ai\//@q\/flowgram.ai./g' "$file"
            else
                # Linux
                sed -i 's/@flowgram\.ai\//@q\/flowgram.ai./g' "$file"
            fi
            echo "    - 已处理: $file"
        done

        echo "  - $folder 文件夹中的 .eslintrc.js 和 .eslintrc.cjs 文件处理完成"
    else
        echo "  - $folder 文件夹不存在，跳过"
    fi
done

echo "  - 所有 .eslintrc.js 和 .eslintrc.cjs 文件处理完成"

# ============================================================================
# 12. 处理 config/eslint-config/tsconfig.json 文件中的extends引用
# ============================================================================
echo "步骤 12: 处理 config/eslint-config/tsconfig.json 文件中的extends引用..."

if [ -f "config/eslint-config/tsconfig.json" ]; then
    echo "  - 正在处理 config/eslint-config/tsconfig.json"
    # 使用 sed 进行替换，兼容 macOS 和 Linux
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' 's/@flowgram\.ai\//@q\/flowgram.ai./g' "config/eslint-config/tsconfig.json"
    else
        # Linux
        sed -i 's/@flowgram\.ai\//@q\/flowgram.ai./g' "config/eslint-config/tsconfig.json"
    fi
    echo "  - 已处理: config/eslint-config/tsconfig.json"
else
    echo "  - config/eslint-config/tsconfig.json 文件不存在，跳过此步骤"
fi

echo "  - config/eslint-config/tsconfig.json 文件处理完成"

# ============================================================================
# 完成
# ============================================================================
echo ""
echo "🎉 Q 项目初始化脚本执行完成！"
echo ""
echo "执行的操作总结："
echo "0. ✅ 已校验分支名格式符合规范"
echo "1. ✅ 已将 .github 文件夹备份到 .github.bak 并删除原文件夹"
echo "2. ✅ 已将 common/git-hooks 文件夹备份到 .git-hooks.bak 并删除原文件夹"
echo "3. ✅ 已修改 rush.json 中的 projects 配置"
echo "4. ✅ 已替换 packages 和 apps 文件夹中的包名引用，添加 maintainers 配置并更新 publishConfig registry 地址"
echo "5. ✅ 已替换 apps/create-app/src/index.ts 中的 registry URL"
echo "6. ✅ 已处理 .npmrc-publish 文件配置"
echo "7. ✅ 已创建 .env 和 .env.example 文件"
echo "8. ✅ 已创建根目录 .npmrc 文件"
echo "9. ✅ 已处理 version-policies.json 文件配置"
echo "10. ✅ 已深度遍历 e2e 和 config 文件夹下的所有 package.json 文件，修改包名引用"
echo "11. ✅ 已深度遍历 e2e、apps、packages、config 文件夹下的所有 .eslintrc.js 和 .eslintrc.cjs 文件，修改包名引用"
echo "12. ✅ 已处理 config/eslint-config/tsconfig.json 文件中的extends引用"
echo ""
echo "备份文件位置："
echo "- .github.bak/ (原 .github 文件夹内容)"
echo "- .git-hooks.bak/ (原 common/git-hooks 文件夹内容)"
echo "- rush.json.bak (原 rush.json 文件)"
echo "- .npmrc-publish.bak (原 .npmrc-publish 文件)"
echo "- version-policies.json.bak (原 version-policies.json 文件)"
echo ""
echo "新创建的文件："
echo "- .env (包含 QNPM_AUTH_TOKEN 配置)"
echo "- .env.example (包含 QNPM_AUTH_TOKEN 示例)"
echo "- .npmrc (包含 registry 配置)"
echo ""
