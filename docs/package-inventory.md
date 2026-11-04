# XR1710G 包盘点与取舍

本文记录 2026-11-04 对旧 ImmortalWrt 配置、LEDE feed 和 XR1710G 社区源码的盘点结果。目标是保留真正与 1710 硬件相关的观察/控制能力，不用旧 `.ipk` 或旧内核模块直接污染当前 LEDE。

## 结论

第一组直接加入默认镜像：

| 包 | 来源 | 作用 | 处理 |
| --- | --- | --- | --- |
| `xr1710g-status-core` | XR1710G `source-2.0` | 缓存、JSON 校验、共享状态采集 helper | 加入 |
| `luci-app-airoha-npu` | XR1710G `source-2.0` 1.1.0 | SoC/NPU、PPE、CPU 频率、温度、Wi-Fi token 状态 | 加入 |
| `luci-app-airoha-flowsense` | XR1710G `source-2.0` 1.1.3 | PPE/FlowSense、硬件转发和流表观察 | 加入 |
| `luci-app-airoha-fancontrol` | XR1710G `source-2.0` 1.0.0 | NCT7802 风扇曲线、手动/自动模式、温度保护 | 加入 |
| `luci-theme-argon` | LEDE `luci` feed 2.4.3 | Argon 主题 | 加入并设为首次启动默认主题 |
| `luci-app-nikki` + `luci-i18n-nikki-zh-cn` | LEDE `luci` feed / `packages` feed | Mihomo 透明代理及中文界面 | 加入 |

这些包都从源码在本次 LEDE 构建中重新编译，不直接安装旧 ImmortalWrt 的 `.ipk`。

## 上游源头与更新方式

设备包不是凭空出现的，当前仓库把 XR1710G 社区集成树的对应目录固定复制到 `packages/`，方便先在不改变上游 feed 的情况下复现构建。后续更新时按下面的来源对照：

当前 CI 的 LEDE 基线固定在 `98b3eed3ecb33da1be94d5084284b3644a864622`。这与 r6 真机验证使用的提交一致；当前后续 master 的 feed 曾出现 `dnsmasq/openvswitch` recursive dependency，不能在未验证前直接替换。

| 包 | 可跟踪的上游/集成源 | 当前采用的版本/提交 | 更新建议 |
| --- | --- | --- | --- |
| `luci-app-airoha-npu` | [rchen14b/luci-app-airoha-npu](https://github.com/rchen14b/luci-app-airoha-npu) | 上游 README/Makefile 为 1.0.1；当前 XR 集成版为 1.1.0 | 以上游的 NPU/PPE 修复为主线，合并 XR 版的 `xr1710g-status-core` 缓存和安全读取改造 |
| `luci-app-airoha-flowsense` | [Gilly1970/Gemtek-W1700K](https://github.com/Gilly1970/Gemtek-W1700K) 的 `luci-apps/luci-app-airoha-flowsense`；XR 集成树继续维护 | Gilly `db3f1c8`，XR `source-2.0` 的 1.1.3 | 先看 Gilly 的 FlowSense 更新，再把 XR 的 XR1710G 状态缓存/ACL 改动合并回来 |
| `luci-app-airoha-fancontrol` | [naoki66/luci-app-airoha](https://github.com/naoki66/luci-app-airoha) 的 `luci-app-airoha-fancontrol`；XR 集成树为增强版 | naoki `0b1d8a0`，XR 为 1.0.0 | 保留 XR 的软件曲线和 fail-safe；对照 naoki 的温度/风量字段变化 |
| `xr1710g-status-core` | [orangeyoo/XR1710G-OpenWrt-iStoreOS-Community](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community) | `88276e8e8163b8bee1770aaa8973e8383d8a6333`（`source-2.0`） | 这是 XR 集成层自己的 helper，没有独立上游；随 XR 树的 NPU/FlowSense 更新同步 |
| `luci-theme-argon` | [jerrykuku/luci-theme-argon](https://github.com/jerrykuku/luci-theme-argon) | 从 LEDE feed 复制并固定为 2.4.3；上游最新为 3.1.2 | 当前优先跟随 LEDE 的 2.4.3；升级到 3.x 要单独处理同名包和新增依赖 |
| `luci-app-nikki` / `luci-i18n-nikki-zh-cn` | [nikkinikki-org/OpenWrt-nikki](https://github.com/nikkinikki-org/OpenWrt-nikki) | 从 LEDE feed 复制并固定为 LuCI 1.26.2 | 跟随上游 LuCI/po 变化更新；不要混用不同 feed 的旧 `.ipk` |
| `mihomo` | [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) | 固定的上游 arm64 release：`v1.19.33` | 通过本仓库的 `mihomo` 预编译包更新；它是 Nikki 的运行时依赖 |
| `yq` | [mikefarah/yq](https://github.com/mikefarah/yq) | 固定的上游 arm64 release：`v4.33.1` | 通过本仓库的 `yq` 预编译包更新；Nikki 的 YAML 配置依赖 |

更新设备包时的建议流程：

1. 在临时目录拉取 `orangeyoo/XR1710G-OpenWrt-iStoreOS-Community` 的 `source-2.0`，只比较 `package/luci-app-airoha-*` 和 `package/xr1710g-status-core`。
2. 对照 `rchen14b`、`Gilly1970`、`naoki66` 的上游，优先吸收 bug fix，不直接把旧 ImmortalWrt 的二进制包搬进来。
3. 更新后重新跑 CI，并至少验证 NPU/FlowSense 页面 RPC、风扇曲线写回、Argon 登录页、Nikki 启动和 `mihomo` 版本。
4. 更新完成后把新的源提交写回本文件，保证 `packages/` 内容可追溯。

Nikki 的 `mihomo` 和 `yq` 在 LEDE 的 Go 包 Kconfig 中未能被该 target 选中，因此本仓库把 `luci-app-nikki`、`nikki`、Argon 主题和两个运行时一起复制到 `packages/`，使用固定版本的上游 arm64 release，并在镜像构建时校验 SHA256 后放入 `xr1710g` 包。这样不依赖构建机的 Go 工具链，也能避免把旧 kernel/LuCI ABI 的 `.ipk` 直接混入。

## 暂不加入

| 包/方向 | 原因 |
| --- | --- |
| `luci-app-airoha-factory` | 会改 MAC、序列号、factory/DSD 和 U-Boot 环境；当前 `fw_printenv` 还有 Bad CRC，默认加入风险过高 |
| `luci-app-airoha-recovery` / `luci-app-xr1710g-recovery` | 依赖 U-Boot 环境触发，当前环境 CRC 不一致；可后续单独修复环境后再加 |
| `luci-app-mesh-conf` | 会拉入 `wpad-mesh-*`、`dawn`、`socat`，可能替换当前 `wpad-openssl`；单机使用没有必要 |
| `luci-app-netmode` | 属于网络模式切换工具，不是 1710 独有；会改 WAN/LAN 配置，后续按需要加 |
| `luci-app-clients` | 需要在 LEDE 外补充 feed，依赖 `ucode/rpcd-mod-iwinfo`；适合作为第二组 |
| `luci-app-wifihistory`、`timewol`、`watchcat`、`zerotier`、`ddns` 等 | 通用功能，不是 1710 硬件专属；按业务需要另行开启 |
| 旧 ImmortalWrt 的 `kmod-*`、`.ipk` | 内核 ABI 与本次 LEDE 6.18 构建不一致，必须从当前源码重编 |

## 与 LEDE 内置包的关系

LEDE 的 `luci` feed 里已经有一个较旧的 `luci-app-airoha-npu`（1.0.1）。它依赖 `devmem`，而当前 r6 系统没有 `/dev/mem`，Frame Engine 和超频部分会降级。为了让 NPU 页面在 r6 上可用，本仓库使用 XR1710G `source-2.0` 的 1.1.0 版本，并在 CI 中移除 feed 里的同名旧包，避免重复包名。

Argon 使用 LEDE feed 自带的 2.4.3，而不是上游最新的 3.1.2：两者包名相同，混用会形成重复 package；而 3.1.2 还引入 `ucode-mod-math`、`flock`、`coreutils-timeout` 等新依赖。当前选择优先保证月构建稳定，后续若要升级到 3.1.2，应单独替换 feed 并重新做完整 manifest 验证。

## 风扇与 U-Boot 安全边界

`luci-app-airoha-fancontrol` 会接管 NCT7802，并在镜像构建阶段移除 `airoha_fan` 的开机链接。为了确保烧录后的新镜像仍能启动风扇控制，本仓库在包安装阶段额外写入 `/etc/rc.d/S99fan`。包内控制器有写回校验和 88°C fail-safe 全速逻辑。

本次不修改 U-Boot、`ubootenv`、`ubootenv2` 或 `factory` 分区。`luci-app-airoha-recovery` 等工具即使以后加入，也必须先解决 `fw_printenv` 的 Bad CRC。

## 包源码锁定

设备包按以下提交复制到 `packages/`，构建不依赖第三方 feed 的实时变化：

```text
orangeyoo/XR1710G-OpenWrt-iStoreOS-Community
commit: 88276e8e8163b8bee1770aaa8973e8383d8a6333
branch: source-2.0
```

构建产物除固件外会额外包含：

```text
packages/xr1710g-status-core_*.ipk
packages/luci-app-airoha-npu_*.ipk
packages/luci-app-airoha-flowsense_*.ipk
packages/luci-app-airoha-fancontrol_*.ipk
packages/luci-i18n-airoha-*-zh-cn_*.ipk
packages/luci-theme-argon_*.ipk
```

安装顺序建议先装 `xr1710g-status-core`，再装 NPU/FlowSense，最后装风扇和主题；所有包仍应与同一轮构建的固件配套使用。
