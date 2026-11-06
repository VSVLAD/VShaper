#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0

# Очищаем кэш меню LuCI, чтобы пункт VShaper сразу исчез из веб-интерфейса
rm -f /tmp/luci-indexcache 2>/dev/null
/etc/init.d/rpcd reload 2>/dev/null

exit 0