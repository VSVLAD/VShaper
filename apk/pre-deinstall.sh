#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0

LAN_IF=$(uci -q get vshaper.settings.lan_if)
WAN_IF=$(uci -q get vshaper.settings.wan_if)

if [ -x /usr/bin/vshaper ] && [ -n "$LAN_IF" ] && [ -n "$WAN_IF" ]; then
    /usr/bin/vshaper stop "$LAN_IF" "$WAN_IF" 2>/dev/null
fi

if [ -x /usr/bin/vshaper ]; then
    /etc/init.d/vshaper disable 2>/dev/null
fi

exit 0