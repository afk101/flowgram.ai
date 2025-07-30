### 这个文档用来介绍如何使用scriptsQ文件夹下的脚本，用于私有化、个性化定制@flowgram.ai/的包为@q/flowgram.ai.


#### 重要约定
个性化定制的分支统一为`feature/v数字.数字.数字`的格式，例如`feature/v0.2.26`，这样可以标记当前分支对应的是@flowgram.ai的哪个tag版本

#### 如何个性化定制当前版本代码并发布？
1.进行代码个性化修改
2.rush dev:demo-free-layout-simple(启用开发环境实时查看刚刚的代码修改，dev:后面可以换demo项目)
3.提交修改的代码（推荐），因为后面发布版本会强制推送，所以这里单独提交比较清晰
4.查看根目录是否有.env文件，如果没有，则按照.env.example创建.env文件
*如何获取两个token？*
```bash
 cat ~/.npmrc
```
结果：
```bash
home=https://www.npmjs.org
registry=https://registry.npmjs.org/
@q:registry=https://registry.qnpm.qihoo.net
//registry.qnpm.qihoo.net/:_authToken=xxx
//registry.npmjs.org/:_authToken=yyy
```
上面的xxx、yyy就是
如果没有Qnpm配置，查看[Qnpm](https://coding.qihoo.net/qnpm)
5.执行发布命令
```bash
./scriptsQ/publish.sh
```
如果没有权限，执行以下命令之后再重新执行发布命令
```bash
chmod +x scriptsQ/publish.sh
```

等待代码构建、发布、push到远程仓库
完成后终端会输出最新的版本号，例如：0.2.26-3
当前版本的所有修改，只会增加最后一位数字，例如：0.2.26-3=>0.2.26-4，目的是为了标志当前使用的包对应的是@flowgram.ai中是哪个tag版本的

*为什么执行发布脚本会强制提交代码并推送到远程仓库？*
考虑到每次升级版本，会统一修改所有的package.json文件以及common/config/rush/version-policies.json中的version字段并发布，如果当前代码忘记提交，那可能会导致远程仓库的代码版本低于线上实际版本，多人协作时，下次执行脚本会出错，因此这里强制提交


#### 如何大版本更新？（例如从v0.2.26=>v0.2.27）
1.确保当前在feature/v0.2.26分支(有个性化定制的commit修改)
```bash
# 按照规范，创建新的分支 feature/v0.2.27
git checkout -b feature/v0.2.27

# 回退Q化代码，防止后面合并新版本代码时大量冲突
chmod +x scriptsQ/omitQ.sh(一次性)
./scriptsQ/omitQ.sh

# 确保当前Fork仓库已经添加了上游仓库
git remote -v
# 查看是否有upstream对应的是https://github.com/bytedance/flowgram.ai.git
# 如果没有，执行以下命令
git remote add upstream https://github.com/bytedance/flowgram.ai.git

# 获取上游仓库的最新提交和标签
git fetch upstream

# 选择想要升级到的tag，这里以v0.2.27 tag为例
git merge v0.2.27 # 将最新版本的代码合并到当前分支，如果有冲突就解决，然后提交并push到远程仓库（非常推荐这么做！！！）

# 执行Q化脚本
chmod +x scriptsQ/initQ.sh(一次性)
./scriptsQ/initQ.sh

# 非常推荐将Q化代码单独提交，因为会改几千个文件
git add . && git commit -m 'feat: 升级大版本，执行initQ.sh' -n && git push

# 接着就可以基于最新版本v0.2.27愉快地开发了！
```

#### 如何更新maintainers维护者
1.修改scriptsQ/maintainers.json的文件
2.执行./scriptsQ/updateMaintainers.sh
3.提交代码
4.执行./scriptsQ/publish.sh发布代码
