#!/usr/bin/env bash
set -euo pipefail

dist_dir="${1:?usage: package-artifacts.sh DIST_DIR LEDE_DIR UBOOT_DIR}"
lede_dir="${2:?missing LEDE_DIR}"
uboot_dir="${3:?missing UBOOT_DIR}"
release_tag="${RELEASE_TAG:-xr1710g-$(date -u +%Y%m%d)}"
build_profile="${BUILD_PROFILE:-default}"
lede_commit="$(git -C "$lede_dir" rev-parse HEAD)"
uboot_tag="$(sed -n 's/^tag=//p' "$uboot_dir/UBOOT_BUILD_INFO.txt")"

mkdir -p "$dist_dir/lede" "$dist_dir/uboot"

target_dir="$lede_dir/bin/targets/airoha/an7581"
if [ ! -d "$target_dir" ]; then
  echo "LEDE target output directory is missing: $target_dir" >&2
  exit 1
fi

find "$target_dir" -maxdepth 1 -type f -exec cp -v {} "$dist_dir/lede/" \;

if ! compgen -G "$dist_dir/lede/*xr1710g*sysupgrade.itb" >/dev/null; then
  echo "No XR1710G sysupgrade.itb was produced" >&2
  exit 1
fi

if [ "$(cd "$uboot_dir" && pwd -P)" != "$(cd "$dist_dir/uboot" && pwd -P)" ]; then
  cp -v "$uboot_dir/xr1710g-chainloader-slot.bin" "$dist_dir/uboot/"
  cp -v "$uboot_dir/UBOOT_SHA256SUMS" "$dist_dir/uboot/"
  cp -v "$uboot_dir/UBOOT_BUILD_INFO.txt" "$dist_dir/uboot/"
fi

# The XR1710G FIT must describe the UBI 2.0 boundary expected by the pinned
# HTTP U-Boot. Fail closed if the image layout changes.
sysupgrade_image="$(compgen -G "$dist_dir/lede/*xr1710g*sysupgrade.itb" | head -n 1)"
dumpimage="$lede_dir/staging_dir/host/bin/dumpimage"
if [ ! -x "$dumpimage" ]; then
  echo "dumpimage not found at $dumpimage" >&2
  exit 1
fi
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
"$dumpimage" -T flat_dt -p 1 -o "$tmp_dir/xr1710g.dtb" "$sysupgrade_image" >/dev/null
dtc -I dtb -O dts -o "$tmp_dir/xr1710g.dts" "$tmp_dir/xr1710g.dtb" 2>/dev/null
if ! grep -q '0x1b700000' "$tmp_dir/xr1710g.dts"; then
  echo "The image does not carry the expected UBI 2.0 size (0x1b700000)" >&2
  exit 1
fi

cat > "$dist_dir/BUILD_INFO.txt" <<EOF
device=Gemtek XR1710G
target=airoha/an7581
profile=$build_profile
lede_commit=$lede_commit
uboot_release=$uboot_tag
release_tag=$release_tag
built_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ubi_layout=UBI 2.0 (0x00700000 + 0x1b700000)
EOF

cat > "$dist_dir/FLASH_README.txt" <<'EOF'
XR1710G release bundle
======================

This archive contains two different flash targets:

1. lede/*-sysupgrade.itb
   Upload this to the HTTP recovery "firmware" target, or use normal
   OpenWrt/LEDE sysupgrade. It writes the UBI "fit" volume.

2. uboot/xr1710g-chainloader-slot.bin
   Upload only to the HTTP recovery "uboot" target. It updates the raw
   chainloader slot. Do not use sysupgrade for this file.

The LEDE image is configured for UBI 2.0 and must be used with the matching
U-Boot layout. Keep a full SPI-NAND backup before changing U-Boot. A failed or
mismatched bootloader write can make the router unbootable.

The upstream U-Boot readme warns not to flash u-boot.bin, u-boot.img, or
xr1710g-ubi.img directly. Use the named chainloader slot image.
EOF

(
  cd "$dist_dir"
  find . -type f ! -name SHA256SUMS -print0 \
    | sort -z \
    | xargs -0 sha256sum > SHA256SUMS
)

archive="$dist_dir/${release_tag}.zip"
(
  cd "$dist_dir"
  zip -9 -r "$(basename "$archive")" lede uboot BUILD_INFO.txt FLASH_README.txt SHA256SUMS
)
(cd "$dist_dir" && sha256sum "$(basename "$archive")" >> SHA256SUMS)

echo "Prepared $archive"
