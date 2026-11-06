include $(TOPDIR)/rules.mk

PKG_NAME:=xr1710g-npu-tuning
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=XR1710G CI

include $(INCLUDE_DIR)/package.mk

define Package/xr1710g-npu-tuning
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=XR1710G NPU/WED IRQ spreading and offload verification
  PKGARCH:=all
endef

define Package/xr1710g-npu-tuning/description
 Spreads the mt76-npu / mt7996 interrupts across CPUs at boot and ships
 xr1710g-offload-check, which proves (or disproves) that the Wi-Fi data
 path is really taken over by the Airoha NPU.
endef

define Build/Compile
endef

define Package/xr1710g-npu-tuning/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/xr1710g_npu $(1)/etc/config/xr1710g_npu
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/xr1710g-npu-tuning $(1)/etc/init.d/xr1710g-npu-tuning
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/95-xr1710g-npu-tuning $(1)/etc/uci-defaults/95-xr1710g-npu-tuning
	$(INSTALL_DIR) $(1)/etc/hotplug.d/net
	$(INSTALL_BIN) ./files/etc/hotplug.d/net/20-xr1710g-irq $(1)/etc/hotplug.d/net/20-xr1710g-irq
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/xr1710g-irq-balance $(1)/usr/bin/xr1710g-irq-balance
	$(INSTALL_BIN) ./files/usr/bin/xr1710g-offload-check $(1)/usr/bin/xr1710g-offload-check
endef

$(eval $(call BuildPackage,xr1710g-npu-tuning))
