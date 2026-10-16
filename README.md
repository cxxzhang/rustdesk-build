# rustdesk-build

构建流水线。这个仓库**不含源码** —— 它把源码拉下来、打补丁、编译，产物作为
Actions artifact 上传。

用 GitHub Actions，因为它是唯一同时提供 **Linux / Windows / macOS** 托管 runner
的免费 CI：客户端要在 Windows 和 macOS 上原生编译，别的平台给不了。

## 仓库结构

**只有一个自建源码仓库**：[`rustdesk-webclient`](https://github.com/cxxzhang/rustdesk-webclient)。

其余三个组件都是「**上游 + 补丁**」，不另建仓库 —— 构建时按补丁对应的上游 commit
clone，再 `git apply` 打补丁：

| 组件 | 上游 | 固定 commit |
|---|---|---|
| `rustdesk-server` | `rustdesk/rustdesk-server` | `873230e` (1.1.17) |
| `rustdesk` 客户端 | `rustdesk/rustdesk` | `9997b7a3b` (1.5.1) |
| `rustdesk-api-server-pro` | `liyan-lucky/rustdesk-api-server-pro` | `1ab27a4` (1.3.20) |

补丁在 `patches/`。上游升级 = 改 `scripts/fetch.sh` 里的 commit 常量 + 可能调整补丁。

> ⚠️ `rustdesk-server` 的补丁会改到 `libs/hbb_common`，而上游把它作为**子模块**。
> git 不允许透过子模块边界写索引，所以脚本用 `git apply`（直接改工作区）而不是
> `git am`。构建只需要文件内容，不需要 git 索引。

## 流水线

| Workflow | 产物 |
|---|---|
| `server.yml` | hbbs / hbbr / rustdesk-utils —— linux(x64/arm64)、windows、macOS(arm64/x64) |
| `web.yml` | 浏览器客户端 + TURN（linux/win/macOS × amd64/arm64） |
| `console.yml` | 控制台后端（5 平台）+ 管理界面 |
| `client.yml` | RustDesk 客户端 —— **linux / windows / macos / android 各用原生 runner** |

手动触发：仓库 → Actions → 选 workflow → Run workflow。

## 平台支持

| 组件 | Linux | Windows | macOS | Android | OpenHarmony |
|---|---|---|---|---|---|
| 服务端 | ✅ | ✅ | ✅ | — | — |
| 浏览器客户端 | ✅ | ✅ | ✅ | ✅（就是网页） | — |
| TURN | ✅ | ✅ | ✅ | — | — |
| 控制台后端 | ✅ | ✅ | ✅ | — | — |
| RustDesk 客户端 | ✅ | ✅ | ✅ | ✅ | ❌ |

**OpenHarmony 没有**：上游 RustDesk 完全没有鸿蒙支持（仓库里搜不到 `ohos` /
`openharmony` / `harmony`）。那是从零移植（Rust 后端、Flutter 前端、屏幕采集、
输入注入全都要新平台实现），不是加个 CI 能解决的。

**iOS 也没有**：需要 Xcode + 苹果签名证书，且本仓库没做 iOS 的 provisioning 配置。

## 客户端构建的已知难点

1. **Rust ↔ Dart 桥接**：`flutter_rust_bridge` 生成的 `bridge_generated.rs` 和
   `generated_bridge.dart` 必须成对，codegen 版本要跟 `Cargo.toml` 里的
   `flutter_rust_bridge` **严格匹配**。上游是在另一台机器生成后提交的；如果 checkout
   里没有，workflow 会用 `FRB_CODEGEN_VERSION` 重新生成 —— 版本不对就会编译失败。
2. **Windows 需要 4 个 C 静态库**（libyuv / opus / libaom / libvpx），必须
   **静态 CRT `/MT` 且不带 `/GL`**。`scripts/build-win-clibs.sh` 是尽力而为的复现，
   实际可能由 `build.py` 的 features 机制处理。
3. **工具链版本敏感**：Flutter / NDK / codegen 三者互相牵制。

所以 `client.yml` 的四个 job 标了 `if-no-files-found: warn` —— 一个平台失败不该
掩盖另一个平台成功。**第一次跑大概率要按日志调**。

## 本地

同一套步骤在本机也能跑：`E:\NetJobs\handoff\build.py`。这个仓库是把它们搬进 CI。
