# XR1710G LEDE 月构建起始模板

这是一套可直接放进 GitHub 仓库的起始模板，目标是每月构建：

- LEDE `coolsnowwolf/lede` 的 XR1710G FIT 固件
- 已验证的 YYH2913/http-uboot chainloader slot
- 统一 zip、SHA256SUMS、BUILD_INFO

## 文件

```text
.github/workflows/xr1710g-monthly.yml
configs/xr1710g.config
configs/xr1710g-trimmed.config
scripts/fetch-uboot.sh
scripts/package-artifacts.sh
scripts/verify-manifest.sh
```

## 使用

1. 新建一个 GitHub 仓库，把本目录内容放到仓库根目录。
2. 确认 Actions 的 `Workflow permissions` 允许写 Release。
3. 手动运行一次 `Build XR1710G LEDE + U-Boot bundle`，先选 `default` profile。
4. 下载 artifact，检查：
   - `dist/lede/*xr1710g*sysupgrade.itb`
   - `dist/uboot/xr1710g-chainloader-slot.bin`
   - `dist/SHA256SUMS`
   - `dist/BUILD_INFO.txt`
5. 确认 `BUILD_INFO.txt` 中的 LEDE commit 和 U-Boot release tag。
6. 首次真机刷写前，先按 http-uboot README 做完整 SPI-NAND 备份。

## 重要限制

- U-Boot 不是从 LEDE 源码生成的。它来自 `YYH2913/http-uboot` release，并由工作流校验 SHA256。
- 不要把 `xr1710g-chainloader-slot.bin` 和 `sysupgrade.itb` 合并成一个文件。
- `default` profile 保留 LEDE 的 Lean router 默认包，其中包含 `luci-app-ssr-plus` 等较大包。
- `trimmed` profile 只是候选裁剪配置。`make defconfig` 可能会重新选回 target 默认包，工作流会用最终 manifest 做硬校验。
- LEDE commit 说明里仍把物理 flash、PHY/PCIe、RF 校准、风扇/传感器列为硬件验收项。CI 成功不等于真机验收。

## 在线更新

这套模板发布的是 GitHub Release，不会让原生 LuCI 自动搜索到你的固件。

- LuCI 默认的软件包管理器可以搜索 opkg feed，但自编译固件的 ABI 与上游 feed 不一定一致。
- `luci-app-attendedsysupgrade` 需要兼容的 ASU 服务端；官方 ASU 不识别这个自定义 LEDE target。
- 若要在 LuCI 里检查月更固件，建议后续单独做一个轻量 LuCI app，读取 GitHub Release API，校验 SHA256 后再调用 `sysupgrade`。

## 设备专属包

默认镜像现在包含从 XR1710G `source-2.0` 固定提交复制的 NPU、FlowSense 和风扇控制页面，以及 LEDE feed 的 Argon 主题和 Nikki（含 `luci-i18n-nikki-zh-cn`）。源码副本位于 `packages/`，首次启动默认主题脚本位于 `files/etc/uci-defaults/`。详细取舍、上游来源和暂不加入的包见 `docs/package-inventory.md`。

Release 资产会额外包含本轮的 `packages/*.ipk`，方便在已运行的路由器上先做单包验证；不要把这些包与不同内核/LuCI ABI 的固件混装。
