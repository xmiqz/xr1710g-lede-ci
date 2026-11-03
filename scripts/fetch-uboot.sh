#!/usr/bin/env bash
set -euo pipefail

out_dir="${1:?usage: fetch-uboot.sh OUTPUT_DIR}"
repo="${UBOOT_REPO:-YYH2913/http-uboot}"
tag="${UBOOT_TAG:-xr1710g_261102}"

case "$tag" in
  xr1710g_*) ;;
  *)
    echo "Refusing non-XR1710G U-Boot release tag: $tag" >&2
    exit 1
    ;;
esac

mkdir -p "$out_dir"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

auth_args=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth_args=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

curl -fsSL \
  "${auth_args[@]}" \
  -H 'Accept: application/vnd.github+json' \
  "https://api.github.com/repos/${repo}/releases/tags/${tag}" \
  -o "$tmp_dir/release.json"

asset_url="$(jq -r '.assets[] | select(.name == "xr1710g-chainloader-slot.bin") | .browser_download_url' "$tmp_dir/release.json")"
sha_url="$(jq -r '.assets[] | select(.name == "SHA256SUMS") | .browser_download_url' "$tmp_dir/release.json")"
asset_digest="$(jq -r '.assets[] | select(.name == "xr1710g-chainloader-slot.bin") | .digest // empty' "$tmp_dir/release.json")"
commit="$(jq -r '.target_commitish' "$tmp_dir/release.json")"

if [ -z "$asset_url" ] || [ "$asset_url" = "null" ]; then
  echo "xr1710g-chainloader-slot.bin is missing from $repo release $tag" >&2
  exit 1
fi
curl -fL "$asset_url" -o "$out_dir/xr1710g-chainloader-slot.bin"
if [ -n "$sha_url" ] && [ "$sha_url" != "null" ]; then
  curl -fL "$sha_url" -o "$tmp_dir/SHA256SUMS"
  (
    cd "$out_dir"
    grep 'xr1710g-chainloader-slot.bin$' "$tmp_dir/SHA256SUMS" | sha256sum -c -
  )
  cp "$tmp_dir/SHA256SUMS" "$out_dir/UBOOT_SHA256SUMS"
else
  case "$asset_digest" in
    sha256:*)
      expected="${asset_digest#sha256:}"
      actual="$(sha256sum "$out_dir/xr1710g-chainloader-slot.bin" | awk '{print $1}')"
      if [ "$expected" != "$actual" ]; then
        echo "U-Boot asset digest mismatch" >&2
        exit 1
      fi
      echo "$actual  xr1710g-chainloader-slot.bin" > "$out_dir/UBOOT_SHA256SUMS"
      ;;
    *)
      echo "No SHA256SUMS asset and no sha256 digest for $tag" >&2
      exit 1
      ;;
  esac
fi
{
  echo "repo=$repo"
  echo "tag=$tag"
  echo "target_commitish=$commit"
  echo "asset=xr1710g-chainloader-slot.bin"
  echo "sha256=$(sha256sum "$out_dir/xr1710g-chainloader-slot.bin" | awk '{print $1}')"
} > "$out_dir/UBOOT_BUILD_INFO.txt"

echo "Fetched verified U-Boot slot image: $out_dir/xr1710g-chainloader-slot.bin"
