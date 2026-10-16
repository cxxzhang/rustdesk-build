# andesk-build

AnDesk 的构建流水线。这个仓库本身不含源码 —— 它把 [AnDesk 的几个源码仓库][repos]
拉下来、编译、把产物作为构件上传。

[repos]: https://gitcode.com/rustzhang

## 流水线

| Workflow | 产物 | 状态 |
|---|---|---|
| `server.yml` | hbbs / hbbr / rustdesk-utils（linux、windows、macOS） | ✅ 已验证的构建方式 |
| `web.yml` | 浏览器客户端 + TURN（linux、windows、macOS） | ✅ 已验证的构建方式 |
| `console.yml` | 控制台后端（4 个平台）+ 管理界面 | ✅ 已验证的构建方式 |
| `client-android.yml` | RustDesk 客户端 APK | ⚠️ 尽力而为，见下 |
| `client-windows.yml` | RustDesk 客户端 exe | ⚠️ 尽力而为，见下 |

手动触发：仓库页 → 流水线 → 选一个 workflow → 运行。

## 为什么没有 macOS 客户端 / iOS / OpenHarmony

这三条不是「还没做」，是**做不到**或**上游不支持**：

- **macOS 客户端 / iOS**：两者都必须用 Xcode 编译，而苹果的授权**只允许在苹果硬件上**
  运行 macOS。GitCode 的托管 runner 只有 Linux（`ubuntu-latest` / `euler-latest`），
  没有 macOS runner —— 所以这两个平台**在托管 runner 上无解**。
  要出包只能自建 macOS runner（`runs-on: [self-hosted, macos]`）。
  （服务端和 TURN 的 macOS 版**可以**交叉编译，已在 `server.yml` / `web.yml` 里做了。）
- **OpenHarmony**：上游 RustDesk **完全没有鸿蒙支持** —— 仓库里搜不到 `ohos` /
  `openharmony` / `harmony` 任何痕迹。这是个从零移植的工程（Rust 后端、Flutter 前端、
  屏幕采集、输入注入全都要新平台实现），不是加个 CI 就能出来的。

## 需要配置的密钥

仓库 → 设置 → 密钥，添加：

| 名称 | 用途 |
|---|---|
| `GITCODE_TOKEN` | 拉取那几个**私有**源码仓库。用你的 GitCode 访问令牌。 |

没有这个，所有流水线在第一步「拉取源码」就会失败。

## 平台支持的真实情况

| 组件 | Linux | Windows | macOS | Android | OpenHarmony |
|---|---|---|---|---|---|
| 服务端 (hbbs/hbbr) | ✅ | ✅ 交叉编译 | ✅ 交叉编译 | — | — |
| 浏览器客户端 | ✅ | ✅（静态文件） | ✅（静态文件） | ✅（就是网页） | — |
| TURN | ✅ | ✅ 交叉编译 | ✅ 交叉编译 | — | — |
| 控制台后端 | ✅ | ✅ 交叉编译 | ✅ 交叉编译 | — | — |
| RustDesk 客户端 | ✅ | ⚠️ 见下 | ❌ 需 macOS | ⚠️ 见下 | ❌ 上游不支持 |

「交叉编译」= 在 Linux runner 上产出目标平台的二进制，不需要那个平台的机器。
Go 用 `GOOS/GOARCH`，Rust 用 `--target`（服务端无 C 依赖，所以简单）。

## 客户端构建为什么标「尽力而为」

RustDesk 客户端是这套里最难自动化的，原因有三个，都跟 CI 无关：

1. **Rust ↔ Flutter 桥接代码**：`flutter_rust_bridge` 生成的 `bridge_generated.rs` 和
   `generated_bridge.dart` 必须成对，且 codegen 版本要跟 `Cargo.toml` 里的
   `flutter_rust_bridge` 版本**严格匹配**。上游是在另一台机器生成后**提交进仓库**的，
   所以 CI 里要么用它已有的，要么重新生成（版本不对就会编译失败）。
2. **Windows 需要 4 个 C 静态库**：libyuv / opus / libaom / libvpx，必须是
   **静态 CRT（`/MT`）且不带 `/GL`** —— 否则跟 Rust 那边链接不上。
   这是最容易崩的一环，`scripts/build-win-clibs.sh` 是尽力而为的复现。
3. **工具链版本敏感**：Flutter 版本、NDK 版本、codegen 版本三者互相牵制。

所以这两个 workflow 的**结构是对的**（依赖安装、缓存、桥接生成、打包、上传都齐了），
但**第一次跑很可能要调**。真跑的时候看日志改，比在这里猜准。

## 本地构建

同一套东西在本机也能跑（`E:\NetJobs\handoff\build.py`）。这个仓库是把那些步骤
搬进 CI，不是替代它。
