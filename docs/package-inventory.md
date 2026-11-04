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

这些包都从源码在本次 LEDE 构建中重新编译，不直接安装旧 ImmortalWrt 的 `.ipk`。

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
