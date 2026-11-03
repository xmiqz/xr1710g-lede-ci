# XR1710G LEDE 月度 CI 构建研究结论

研究日期：2026-11-03

## 1. 先给结论

这个方案可行，但必须把三件事分开：

| 目标 | 结论 | 原因 |
|---|---|---|
| 每月用 LEDE 最新源码构建 XR1710G | 可行 | 当前 master 已包含 XR1710G 设备配置 |
| CI 产物同时带 U-Boot 和 LEDE 固件 | 可行，但应打包成两个镜像，不是一个镜像 | U-Boot 写 `chainloader`，LEDE 写 UBI `fit` 卷 |
| 在 LuCI 里搜索/检查固件更新 | 原生不完整 | 原生有软件包搜索；固件在线检查需要 ASU 或自定义更新器 |
| 每月自动重编 U-Boot | 不建议 | 当前 http-uboot 仓库没有可直接复现 flash-slot 的 CI 打包脚本，且 bootloader 刷写风险高 |

最稳的方案：

1. LEDE 每月从 `coolsnowwolf/lede` 的 `master` 构建。
2. U-Boot 固定使用 YYH2913/http-uboot 的已验证 release，不在每次月更时重刷。
3. GitHub Actions 每次产出：
   - `openwrt-...-gemtek_xr1710g-...-sysupgrade.itb`
   - `xr1710g-chainloader-slot.bin`
   - `SHA256SUMS`
   - `BUILD_INFO.txt`
   - 可选：`recovery.itb`、`manifest`
4. 把以上文件放在同一个 GitHub Release/zip 中，但刷写时分别使用不同目标。

## 2. LEDE 提交和设备支持

关键提交：

- `98b3eed3ecb33da1be94d5084284b3644a864622`
- 标题：`airoha: add Gemtek XG2010G and XR1710G support`
- 提交日期：2026-10-31

截至研究时，`coolsnowwolf/lede` 的 master HEAD 已经包含该提交。设备配置位于：

- `target/linux/airoha/image/an7581.mk`
- `target/linux/airoha/dts/an7581-xr1710g.dts`
- `target/linux/airoha/an7581/base-files/lib/upgrade/platform.sh`
- `target/linux/airoha/an7581/base-files/etc/board.d/02_network`

构建目标：

```text
target: airoha/an7581
device: gemtek_xr1710g
kernel: 6.18
image: sysupgrade.itb
recovery image: KERNEL_INITRAMFS_SUFFIX = -recovery.itb
```

XR1710G 的设备包：

```text
kmod-gpio-button-hotplug kmod-leds-gpio
kmod-phy-realtek rtl826x-firmware
kmod-hwmon-nct7802 kmod-mt7996-firmware
wpad-openssl airoha-en7581-mt7996-npu-firmware
fitblk nand-utils ubi-utils
```

子目标还会带入：

```text
airoha-en7581-npu-firmware uboot-envtools
```

## 3. 为什么不能把 U-Boot 和 LEDE 合并成一个镜像

XR1710G 的分区边界是：

| 分区 | 起始 | 大小 | 作用 |
|---|---:|---:|---|
| `vendor` | `0x00000000` | `0x00600000` | 原厂保留区 |
| `chainloader` | `0x00600000` | `0x00100000` | 可刷写的 U-Boot chainloader 槽 |
| `ubi` | `0x00700000` | `0x1b700000` | LEDE 固件、factory、U-Boot 环境等 |
| `reserved_bmt` | `0x1be00000` | `0x04200000` | BMT/坏块表保留 |

LEDE 的升级脚本对 XR1710G 只检查并写入 UBI 卷：

```text
Required UBI volume: fit factory ubootenv ubootenv2
fit_do_upgrade "$1"
```

它不会写 `vendor` 和 `chainloader`，所以正常 `sysupgrade` 不会覆盖 U-Boot。反过来说，U-Boot 也不能通过 `sysupgrade.itb` 更新。

HTTP U-Boot 的 recovery 页面有两个不同目标：

- `firmware`：把 `*-sysupgrade.itb` 写到 `ubi:fit`
- `uboot`：把 `xr1710g-chainloader-slot.bin` 写到 raw `chainloader`

因此 CI 产物应是一个“发布包”，而不是一个单文件固件。

## 4. U-Boot 现状

研究时看到的最新 XR1710G release：

```text
tag:          xr1710g_261102
published:    2026-11-02
source commit:843312736f2ae03976ebbe1dd21d19561e2a7d4a
```

可刷写资产：

```text
xr1710g-chainloader-slot.bin
size:   922970
sha256: 96255513b47a0eeb74bde5e673a00ba725b81d17ad139e5068132e7d00afd25f
```

README 明确要求：

- 只能把 `xr1710g-chainloader-slot.bin` 刷到 U-Boot 槽
- 不要直接刷 `u-boot.bin`
- 不要直接刷 `u-boot.img`
- 不要把 `xr1710g-ubi.img` 当作普通固件
- 更新前先做完整 SPI-NAND 备份

U-Boot 默认环境使用：

```text
bootconf=config-1
bootcmd=run boot_ubi || http_recovery
ubi_read_production=ubi read ${loadaddr} fit
recovery page: http://192.168.255.1
```

LEDE 的 `Build/fit` 在未设置 `DEVICE_DTS_CONFIG` 时默认使用 `config-1`，与 U-Boot 的 `bootconf=config-1` 对齐。

注意：README 里有一段“latest verified multi-layout recovery build”的旧说明，里面的文件名和 SHA256 与 release 资产并不完全一致。CI 应以 release 的 `SHA256SUMS`/API digest 为准，不要照抄 README 里的旧 hash。

### U-Boot 自编译的限制

当前 `YYH2913/http-uboot` 的 master 有 `xr1710g_defconfig`，但没有可直接调用的 GitHub Actions 发布流水线，也没有把以下打包件完整提交到仓库：

- chainloader prefix shim
- chainloader shim
- chainloader control DTB
- FIT ITS 模板
- 参考 vendor slot

README 里给出的是简化打包逻辑，不是可复现的完整构建脚本。单独执行：

```sh
make xr1710g_defconfig
make
```

得到的是 U-Boot 原始构建产物，不等于 final 可刷写的 `xr1710g-chainloader-slot.bin`。

所以第一版 CI 应固定使用上游已验证 release 资产，并校验 SHA256。若以后确实要在 CI 中自编 U-Boot，需要先补齐打包脚本并做真机回归，不能只凭 `make` 成功就发布。

## 5. 推荐 CI 结构

仓库中建议放：

```text
.github/workflows/xr1710g-monthly.yml
configs/xr1710g.config
scripts/fetch-uboot.sh
scripts/package-artifacts.sh
scripts/verify-manifest.sh
```

工作流步骤：

1. `schedule` 每月触发，同时保留 `workflow_dispatch` 手动触发。
2. 检出 `coolsnowwolf/lede` 的 `master`，记录 commit SHA。
3. 使用 `configs/xr1710g.config` 生成配置。
4. `feeds update/install`，`make defconfig`。
5. 校验设备选择，执行 `make download` 和 `make`。
6. 从固定 U-Boot release 下载并校验 `xr1710g-chainloader-slot.bin`。
7. 用 FIT 里的 DTB 校验 UBI 边界必须是 `0x00700000 + 0x1b700000`，不匹配直接失败。
8. 用最终 `.manifest` 校验硬件必需包仍然存在。
9. 打包 zip、SHA256SUMS、BUILD_INFO。
10. 上传 GitHub Actions artifact，并创建 GitHub Release。

建议的 cron：

```yaml
schedule:
  - cron: "0 18 1 * *"
```

这是 UTC 18:00，即北京时间次月 2 日 02:00。若你希望固定在北京时间每月 1 日，可在工作流里用 `date` 做日期判断，或接受每月 2 日凌晨构建。

### 5.1 CI 资源和稳定性

- 使用 `ubuntu-22.04`，先释放 runner 磁盘空间。
- LEDE 完整编译单设备通常也要较长时间；工作流应设置至少 6 小时超时。
- 先 `make download -j$(nproc)`，再 `make -j$(nproc)`；失败时只对错误重跑 `make -j1 V=s` 获取可读日志。
- 不建议把 `build_dir` 全量做 Actions cache，体积太大；可以后续只缓存 `dl/` 和 ccache。
- 构建失败时不要覆盖上一版 Release；工作流只在成功时创建新 tag。
- `master` 可能随时引入回归，`workflow_dispatch` 应保留 `lede_ref` 输入，必要时固定到已验证 commit。

## 6. 默认内置包

LEDE 的 `include/target.mk` 对 router 目标默认加入很多 Lean 定制包，不是“精简 OpenWrt”。XR1710G 的直接默认包共 77 个，分层如下。

### 6.1 基础包

```text
base-files ca-bundle dropbear fstools libc libgcc libustream-openssl
logd mtd netifd opkg uci uclient-fetch urandom-seed urngd
busybox procd procd-ujail procd-seccomp
```

### 6.2 Lean router 默认包

```text
dnsmasq-full firewall4 nftables-json iptables ppp ppp-mod-pppoe
odhcp6c odhcpd-ipv6only ip6tables libip6tc kmod-ipt-nat6
block-mount coremark kmod-nf-nathelper kmod-nf-nathelper-extra
kmod-ipt-raw kmod-tun iptables-mod-tproxy iptables-mod-extra
ipset ip-full default-settings luci luci-proto-ipv6
ddns-scripts_aliyun ddns-scripts_dnspod luci-app-ddns
luci-app-upnp luci-app-autoreboot luci-app-arpbind
luci-app-filetransfer luci-app-vsftpd luci-app-ssr-plus
luci-app-vlmcsd luci-app-accesscontrol luci-app-nlbwmon
luci-app-turboacc luci-app-wol curl ca-certificates
kmod-sched-core kmod-sched-bpf kmod-xdp-sockets-diag kmod-veth
```

### 6.3 Airoha/XR1710G 必须保留的包

```text
kmod-leds-gpio kmod-gpio-button-hotplug
airoha-en7581-npu-firmware
airoha-en7581-mt7996-npu-firmware
kmod-phy-realtek rtl826x-firmware
kmod-hwmon-nct7802 kmod-mt7996-firmware
wpad-openssl
fitblk nand-utils ubi-utils uboot-envtools
iwinfo
```

说明：

- `wpad-openssl` 会被额外带入 `iwinfo`
- `fitblk`、`nand-utils`、`ubi-utils` 不建议删除
- `rtl826x-firmware` 对应 RTL8261/8264 PHY
- `kmod-hwmon-nct7802` 对应风扇/温度传感器
- `airoha-en7581-*-npu-firmware` 对应 NPU/MT7996 数据路径

完整的直接默认包清单见：

```text
outputs/xr1710g-default-packages.txt
```

实际镜像还包含依赖闭包。构建后 LEDE 会生成 `.manifest`，那才是最终安装列表；CI 应把它一起上传。

这里的 77 个包是“target 源码声明的直接默认包”，不是对某个 feed 分支实际编译结果的承诺。若某个 feed 分支缺包或包名变更，应以 `make defconfig` 和最终 `.manifest` 为准。

### 6.4 可获取的包数量

本次盘点得到的仓库包目录数量（目录不等于最终二进制包数量）：

| 来源 | 包目录数（约） |
|---|---:|
| `coolsnowwolf/packages` | 1231 |
| `coolsnowwolf/luci` | 246 |
| LEDE 仓库内 `package/` | 242 |
| `fw876/helloworld` | 29 |

可筛选的完整清单见：

```text
outputs/xr1710g-available-packages.csv
```

### 6.5 是否需要定制

建议保留硬件和升级链相关包，不要为了减小体积删除它们。

如果不需要 Lean 默认的“全家桶”，可以考虑从默认列表移除：

```text
luci-app-ssr-plus
luci-app-vlmcsd
luci-app-accesscontrol
luci-app-arpbind
luci-app-filetransfer
luci-app-vsftpd
luci-app-nlbwmon
luci-app-turboacc
luci-app-wol
luci-app-upnp
ddns-scripts_aliyun
ddns-scripts_dnspod
luci-app-ddns
luci-app-autoreboot
coremark
```

但要注意：

1. 这些包来自 `include/target.mk` 的 `DEFAULT_PACKAGES.router`，不是普通的“可选包”。直接在 `.config` 里关掉可能被 target 默认值重新选中。
2. 如果要真正裁剪，建议在 CI 仓库维护一个小 patch，或者在 `TARGET_PER_DEVICE_ROOTFS` 场景下用 `CONFIG_TARGET_DEVICE_PACKAGES_...` 的负包名，并通过构建后的 `.manifest` 验证确实被移除。

如果只是“想要一个稳定能用的 XR1710G”，建议第一版保留默认包，先验证硬件，再裁剪。

## 7. LuCI 搜索更新怎么理解

### 7.1 软件包搜索

LEDE 的 `luci` collection 默认依赖：

```text
luci-app-package-manager
```

所以默认镜像里通常有 LuCI 的“软件包”页面，可以搜索 opkg feed 中的软件包。默认 `default-settings` 还会：

- 把 `downloads.openwrt.org` 改成 `mirrors.tencent.com/lede`
- 删除 `helloworld` feed
- 去掉 `check_signature`

这意味着：

- 默认软件包搜索可用，但依赖 Tencent 镜像的 LEDE 包索引是否和你当前构建 ABI 匹配。
- 自编译固件的内核 ABI、包 ABI 可能和镜像上的 feed 不完全一致，不能保证任意在线安装都成功。
- 若要自己托管 feed，可把本次构建的 `.ipk` 和 `Packages`/`Packages.gz` 发布到稳定地址，再在 `/etc/opkg/customfeeds.conf` 添加。
- 只构建单设备固件时，默认只会有本次选中的包，不是完整 1231 个包的索引；想让 LuCI 搜索完整 feed，需要额外构建全部包或使用同 ABI 的完整 feed。
- `default-settings` 还会写入固定的 root 密码哈希并移除 `check_signature`。首次启动后应立即修改 root 密码；如果要对外网开放管理界面，建议恢复包签名校验并启用 HTTPS。

### 7.2 固件在线更新

LEDE feed 中存在：

```text
luci-app-attendedsysupgrade
attendedsysupgrade-common
```

它的工作方式是请求一个 ASU（Attended Sysupgrade）服务器，由服务器按当前包集合重新构建镜像。问题是：

- OpenWrt 官方 ASU 服务器只面向官方 OpenWrt 镜像/ImageBuilder。
- 这个 XR1710G 是自定义 LEDE target，当前不在官方 ASU 的 profile/ImageBuilder 里。
- 因此不能把 `luci-app-attendedsysupgrade` 简单打开后就指望它搜索到你的月构建。

可行的替代方案：

1. **推荐、简单**：CI 发 GitHub Release，路由器通过 LuCI 手动上传 `sysupgrade.itb`，或脚本从 GitHub API 检查 release 并提示。
2. **要原生“搜索固件更新”**：自建 ASU/ImageBuilder 服务，维护 LEDE target 和包仓库；复杂度远高于 GitHub Actions 月构建。
3. **要轻量自研**：做一个小的 LuCI app，读取 GitHub Release 的 `latest`，显示版本/日期，下载并校验 SHA256 后调用 `sysupgrade`。这不依赖 ASU，但需要自己写前端和 rpcd 权限。

结论：第一版不要为了“在线搜索固件”引入 ASU；先做 GitHub Release + 手动升级，后续再加轻量更新器。

## 8. 刷写流程和安全边界

### 8.1 首次从原厂/旧布局迁移

http-uboot README 给的是通用流程，实际操作前必须先确认当前 `/proc/mtd` 是否还是旧 `tclinux` 布局：

- 仍是旧 `tclinux`：按 README 的 `nandwrite` 流程，只覆盖主 `tclinux` 槽前 1 MiB，不要用 `sysupgrade` 写 U-Boot。
- 已经是 `vendor + chainloader + ubi`：进入 HTTP recovery，先备份，再用 `uboot` 目标刷 `chainloader-slot.bin`。

首次切换到 UBI 2.0 后，HTTP recovery 的 full rebuild 会重建 `ubootenv`、`ubootenv2`、`fit`、`rootfs_data`。factory EEPROM/MAC 从 vendor DSD 恢复，保存的 U-Boot 环境会重置。

### 8.2 每月升级

只需要：

1. 下载本月 `*-sysupgrade.itb`。
2. 在 LuCI 系统升级页上传，或 HTTP recovery 选 `firmware`。
3. 确认 WebUI 的 UBI 布局选择为 `UBI 2.0`。
4. 不要动 `uboot` 目标。

### 8.3 必须做的验收

LEDE 提交说明明确写着：物理 flash boot、PHY/PCIe link、RF 校准、sensor/fan 仍是 hardware acceptance 项。CI 编译通过不等于真机通过。

首次测试至少检查：

- 能正常进入 LEDE
- WAN/LAN2/LAN3/LAN4 端口映射正确
- 2.4/5/6 GHz Wi-Fi 能起
- 风扇/温度传感器正常
- `sysupgrade` 后配置保留/重置符合预期
- 断电重启后能再次启动

## 9. 建议的下一步

1. 先使用 `default` profile 构建一次，确认 CI 能产出 `sysupgrade.itb` + `chainloader-slot.bin`。
2. 真机只做“只读备份 + 启动验证”，不要先批量刷机。
3. 根据 `manifest` 决定是否启用 `trimmed` profile。
4. 如果确实需要 LuCI 在线检查，再单独实现轻量 GitHub Release 更新器；不要直接上 ASU。
5. U-Boot 在真机验证前保持固定 release tag，不要让它跟随 LEDE 月更。

## 10. 参考

- LEDE 提交：https://github.com/coolsnowwolf/lede/commit/98b3eed3ecb33da1be94d5084284b3644a864622
- http-uboot：https://github.com/YYH2913/http-uboot
- http-uboot release：https://github.com/YYH2913/http-uboot/releases/tag/xr1710g_261102
- LEDE 默认包定义：`include/target.mk`
- XR1710G 设备定义：`target/linux/airoha/image/an7581.mk`
- XR1710G 升级逻辑：`target/linux/airoha/an7581/base-files/lib/upgrade/platform.sh`
