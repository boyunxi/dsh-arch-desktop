# dsh-arch-desktop

DeepSeek Harness 桌面端及其相关软件包的 Arch Linux 个人软件仓库。

## 仓库结构

```
x86_64/            仓库数据库（进 git）
packages/          软件包本体（作为 Release 附件发布，不进 git）
scripts/           构建与维护脚本
pacman.conf.d/     客户端配置片段
```

**为什么要拆成两处存放：**

GitHub 对普通仓库里的单个文件有 **100 MB 硬限制**，而本仓库的软件包约 350 MB，根本无法 push。Release 附件则允许到 2 GB。因此数据库（几 KB）放进 git 随源码版本化，软件包本体走 Release 附件。

pacman 需要这两者在**同一个 `Server` 路径下**：它会先取 `<仓库名>.db`，再按数据库里记录的 `%FILENAME%` 到同一路径取包体。所以 Release 里同时放了数据库和包体，`Server` 直接指向 Release 的下载路径。

## 客户端配置

把 `pacman.conf.d/` 里的片段加到 `/etc/pacman.conf`：

```ini
[dsh-arch-desktop]
Server = https://github.com/boyunxi/dsh-arch-desktop/releases/download/arch
SigLevel = Optional TrustAll
```

然后：

```sh
sudo pacman -Syu
sudo pacman -S deepseek-harness-desktop
```

> ⚠️ `Server` 里的 `arch` 是本仓库 Release 的 **tag 名**，不是包架构（架构是 `x86_64`）。这个 tag 一旦改动，所有客户端的 `Server` 都要跟着改，所以**发布后不要再动它**。

## 发布新包

1. 构建出软件包（见项目自身的 PKGBUILD）。

2. 把包加入仓库。这一步会拷贝产物到 `packages/`、重写数据库，并把 `.db`/`.files` 的便捷名实体化（`repo-add` 生成的是软链，GitHub 不提供软链）：

   ```sh
   ./scripts/repo-add-pkg.sh /path/to/foo-1.0-1-x86_64.pkg.tar.zst
   ```

3. 确认数据库里记录的每个包体都存在且校验和匹配：

   ```sh
   ./scripts/repo-verify.sh
   ```

4. 提交数据库：

   ```sh
   git add x86_64/
   git commit -m "添加 foo 1.0-1"
   git push
   ```

5. 把包体**连同数据库**传成 Release 附件（沿用同一个 tag）：

   ```sh
   gh release upload arch \
     packages/foo-1.0-1-x86_64.pkg.tar.zst \
     x86_64/dsh-arch-desktop.db \
     x86_64/dsh-arch-desktop.files \
     --clobber
   ```

   **每次发布都要连数据库一起传**，否则客户端拿到的是旧数据库。

## 为什么不用 GitHub Pages

最初的设计是数据库走 Pages、包体走 Release。实测**行不通**：

pacman 按 `Server` 拼接包体路径，拿到的是 Pages 域名，而 Pages 上没有包体（353 MB 放不进去），必然 404。两者必须同源，所以最终让 `Server` 指向 Release 下载路径，数据库也作为附件上传。

## 关于附件命名

GitHub 会对 Release 附件名做规范化：`dsh-arch-desktop.db.tar.zst` 上传后**无法通过原路径访问**（返回 404），而 `dsh-arch-desktop.db` 正常。

好在 pacman 实际请求的是不带 `.tar.zst` 的 `<仓库名>.db`，所以不受影响。**上传时带上 `.db` 和 `.files` 两个无后缀版本即可**。

## 关于签名

本仓库**未签名**。签名要求每台客户端先导入并信任一个密钥，而本仓库只存放自建包、使用环境也都在同一控制之下，因此选了 `SigLevel = Optional TrustAll`。如果将来要服务自己不管理的机器，应当改用签名仓库。

## 添加第二个包

流程与包本身无关。对新产物跑一遍 `repo-add-pkg.sh`，验证，提交数据库，再把包体连同数据库一起传成附件。所有包共用同一个 `dsh-arch-desktop` 数据库。
