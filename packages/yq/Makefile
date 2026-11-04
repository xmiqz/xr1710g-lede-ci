include $(TOPDIR)/rules.mk

PKG_NAME:=yq
PKG_VERSION:=4.33.1
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/yq
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Portable command-line YAML processor (prebuilt arm64)
  URL:=https://github.com/mikefarah/yq
  DEPENDS:=+libc
endef

define Build/Compile
endef

define Package/yq/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/yq $(1)/usr/bin/yq
endef

$(eval $(call BuildPackage,yq))
