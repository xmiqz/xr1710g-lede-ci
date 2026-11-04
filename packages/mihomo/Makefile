include $(TOPDIR)/rules.mk

PKG_NAME:=mihomo
PKG_VERSION:=1.19.33
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/mihomo
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Mihomo rule-based proxy (prebuilt arm64)
  URL:=https://github.com/MetaCubeX/mihomo
  DEPENDS:=+libc +ca-bundle
endef

define Build/Compile
endef

define Package/mihomo/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/usr/libexec
	$(INSTALL_BIN) ./files/mihomo $(1)/usr/bin/mihomo
	ln -sf /usr/bin/mihomo $(1)/usr/libexec/mihomo
endef

$(eval $(call BuildPackage,mihomo))
