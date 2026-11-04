# XR1710G LEDE 实机测试报告

测试时间：2026-11-04

## 1. 测试对象

- 设备：Gemtek XR1710G
- 地址：`192.168.2.3`
- CI 仓库：https://github.com/xmiqz/xr1710g-lede-ci
- Release：`xr1710g-lede-default-2026-11-r6`
- LEDE commit：`98b3eed3ecb33da1be94d5084284b3644a864622`
- U-Boot release：`xr1710g_261102`
- 固件：`openwrt-airoha-an7581-gemtek_xr1710g-squashfs-sysupgrade.itb`
- 固件 SHA256：`7f4c75033dadc1e370f928a844736a35e2c35968a61a2af4328f0c4489399715`

## 2. 刷写前检查

- 当前系统：ImmortalWrt naoki66 XR1710G，kernel `6.18.55`
- 当前 MTD/UBI 布局为新布局：`vendor + chainloader + ubi(0x1b700000) + reserved_bmt`
- `sysupgrade -T`：通过
- `sysupgrade -T -f`（带最小迁移配置）：通过
- 已备份：
  - 当前配置：`router-backup-before-r6.tar.gz`
  - `bootloader.bin`
  - `chainloader.bin`
  - `fit-volume.bin`
  - `ubootenv.bin` / `ubootenv2.bin`
  - `factory.bin`

## 3. 刷写方式

没有沿用 ImmortalWrt 的全部配置。使用 `-n` 清空系统配置，再通过 `-f` 恢复最小兼容配置，只保留：

- 网络：`br-lan` 桥接、LAN DHCP 客户端（维持 `192.168.2.3`）
- 无线：现有 2.4/5/6 GHz SSID、密码和信道
- DHCP：关闭 LAN DHCP 服务，避免与上游网关冲突
- Dropbear：保留 root 密码登录和 SSH host key
- root 密码：升级后由最小配置中的 uci-defaults 恢复
- 不保留：`dawn`、`lucky`、`pushbot`、`radius`、`ubihealthd` 等 ImmortalWrt 定制服务配置

实际命令：

```sh
sysupgrade -n -f /tmp/xr1710g-minimal-config.tar.gz /tmp/xr1710g-r6.itb
```

## 4. 刷写后结果

设备在约 1 分钟内恢复 SSH，仍使用原 root 密码登录。

### 4.1 系统

```text
DISTRIB_ID='OpenWrt'
DISTRIB_RELEASE='24.10.5'
DISTRIB_TARGET='airoha/an7581'
DISTRIB_ARCH='aarch64_generic'
DISTRIB_REVISION='R26.11.4'
DISTRIB_DESCRIPTION='LEDE '
Linux XR1710G 6.18.60
board_name=gemtek,xr1710g
```

### 4.2 网络

```text
br-lan  UP  192.168.2.3/24
default via 192.168.2.1 dev br-lan
ping 192.168.2.1: 3/3, 0% loss
ping 1.1.1.1:     3/3, 0% loss
DNS openwrt.org -> 198.18.54.169 via 192.168.2.1
```

### 4.3 无线

三个 MT7996E radio 全部起来：

```text
2.4 GHz: HE20, channel 4
5 GHz:   EHT160, channel 64
6 GHz:   EHT320, channel 65
```

SSID 保持为 `Xiaomi_xqzwl`，2.4/5 GHz 为 WPA2/WPA3 mixed，6 GHz 为 WPA3 SAE。

### 4.4 风扇和温度

```text
thermal_zone0/temp = 44800  (44.8 C)
nct7802/pwm1 = 55
nct7802/pwm1_enable = 2
```

### 4.5 LuCI

```text
http://192.168.2.3/ -> HTTP 200
```

### 4.6 包状态

```text
opkg installed: 279
luci-app-package-manager: present
wpad-openssl: present
kmod-mt7996-firmware: present
rtl826x-firmware: present
fitblk: present
nand-utils: present
ubi-utils: present
uboot-envtools: present
airoha-en7581-npu-firmware: present
airoha-en7581-mt7996-npu-firmware: present
```

### 4.7 NPU 状态

NPU 驱动和固件已经启动：

```text
airoha-npu 1e900000.npu: NPU fw version: 0.1111
mt7996e 0000:01:00.0: NPU version: 0.1111
```

MT76 NPU 中断有计数，说明 MT7996 侧 NPU 中断路径在工作：

```text
mt76-npu.0: 10728
mt76-npu.1: 3014
```

但以太网 PPE 的 debugfs 显示：

```text
npu_attached: 0
/sys/kernel/debug/ppe/entries: 空
```

当前路由器是 AP/桥接模式（`br-lan` 统一承载 LAN/WAN 端口，LAN 为 DHCP 客户端），没有 WAN 路由转发流量，因此不能把 `npu_attached: 0` 直接理解为 NPU 驱动失败。更准确的说法是：

- MT7996 NPU 固件和中断路径已经起来
- 以太网 PPE 的硬件转发当前没有挂载
- 如果要验证 WAN 路由下的硬件加速，需要先把 WAN/LAN 分离，并启用 flow offload，再观察 `npu_attached` 和 PPE entries 是否变化

## 5. 发现的问题

### 5.1 `opkg update` 的 core feed 404

```text
https://mirrors.tencent.com/lede/releases/24.10.5/targets/airoha/an7581/packages/Packages.gz
-> HTTP 404
```

base/luci/packages/routing/telephony 五个通用 feed 可以下载，只有 target 专属的 `openwrt_core` 不存在。因此目前 LuCI 软件包页面能搜索通用包，但 `opkg update` 会报告 core feed 失败。

后续可选修复：

- 把本次 raw target 产物中的 `bin/targets/airoha/an7581/packages` 发布为独立 feed。
- 或者去掉 `openwrt_core` 这一行，只保留可用通用 feed。

### 5.2 `fw_printenv` 仍报 Bad CRC

```text
Warning: Bad CRC, using default environment
```

这来自当前 U-Boot 环境和 `uboot-envtools` 配置不一致，不影响本次 LEDE 启动和 `sysupgrade`。在没有确认 U-Boot env 存储格式前，不建议修改 `ubootenv/ubootenv2` 或刷 U-Boot。

### 5.3 原 ImmortalWrt 配置不能完整保留

原系统有大量当前 LEDE 镜像未包含的定制服务（`dawn`、`lucky`、`pushbot`、`radius`、`ubihealthd`、Argon 主题配置等）。如果使用 `-c` 或完整保留配置，可能产生无意义配置残留、LuCI 主题缺失或服务异常。本次使用最小迁移配置，结果正常。

## 6. 结论

本次实机测试通过：

- 新 LEDE 固件可正常启动
- SSH 可恢复，原 root 密码有效
- 原有网络地址 `192.168.2.3` 保持
- 上游网关、DNS、外网连通
- 三频 WiFi 全部起来
- 风扇、温度、MT7996、RTL8261 链路正常
- LuCI 可访问
- 核心硬件包和 LuCI 包管理器已安装

未执行任何 U-Boot 写入。当前保留的 U-Boot、chainloader 和升级前固件备份可用于后续回滚分析。
