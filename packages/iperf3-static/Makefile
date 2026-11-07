include $(TOPDIR)/rules.mk

# Measurement-only iperf3. The feed's net/iperf3 depends on a variant
# libiperf3 that does not survive defconfig on this target (aarch64, musl),
# so build the same upstream tarball here as a single static binary with no
# runtime library dependency.
PKG_NAME:=xr1710g-iperf3
PKG_VERSION:=3.21
PKG_RELEASE:=1
PKG_LICENSE:=BSD-3-Clause
PKG_MAINTAINER:=XR1710G CI

PKG_SOURCE:=iperf-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://downloads.es.net/pub/iperf
PKG_HASH:=656e4405ebd620121de7ceca3eaf43a88f79ea1b857d041a6a0b1314801acdd8

PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1
PKG_FIXUP:=autoreconf

TARGET_CFLAGS += -D_GNU_SOURCE
TARGET_LDFLAGS += -latomic

include $(INCLUDE_DIR)/package.mk

define Package/xr1710g-iperf3
  SECTION:=net
  CATEGORY:=Network
  TITLE:=iperf3 (static build for offload/NAT benchmarking)
  URL:=https://github.com/esnet/iperf
endef

define Package/xr1710g-iperf3/description
 Static iperf3 used by the XR1710G metric matrix: wired and wireless
 throughput rows must be measured on the device itself.
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	touch $(PKG_BUILD_DIR)/README
endef

define Build/Configure
	$(call Build/Configure/Default, \
		--without-openssl \
		--without-sctp \
		--enable-static \
		--disable-shared \
	)
endef

define Build/Compile
	$(call Build/Compile/Default, noinst_PROGRAMS=)
endef

define Package/xr1710g-iperf3/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/iperf3 $(1)/usr/bin/iperf3
endef

$(eval $(call BuildPackage,xr1710g-iperf3))
