#!/usr/bin/env bash
set -euo pipefail

target_dir="${1:?usage: verify-manifest.sh TARGET_DIR MODE}"
mode="${2:-default}"

manifest="$(find "$target_dir" -maxdepth 1 -type f -name '*xr1710g*.manifest' | head -n 1)"
if [ -z "$manifest" ]; then
  echo "No XR1710G manifest found in $target_dir" >&2
  exit 1
fi

echo "Checking $manifest"

required=(
  airoha-en7581-npu-firmware
  airoha-en7581-mt7996-npu-firmware
  fitblk
  kmod-hwmon-nct7802
  kmod-mt7996-firmware
  kmod-phy-realtek
  kmod-leds-gpio
  kmod-gpio-button-hotplug
  luci
  luci-app-package-manager
  nand-utils
  rtl826x-firmware
  ubi-utils
  uboot-envtools
  wpad-openssl
)

for pkg in "${required[@]}"; do
  grep -q " - $pkg$" "$manifest" || {
    echo "Required hardware package is missing: $pkg" >&2
    exit 1
  }
done

if [ "$mode" = "trimmed" ]; then
  forbidden=(
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
    luci-app-ddns
    luci-app-autoreboot
    ddns-scripts_aliyun
    ddns-scripts_dnspod
    coremark
  )
  for pkg in "${forbidden[@]}"; do
    if grep -q " - $pkg$" "$manifest"; then
      echo "Trimmed profile still contains: $pkg" >&2
      exit 1
    fi
  done
fi

echo "Manifest checks passed ($mode)"
