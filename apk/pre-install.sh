#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0

if [ -x /etc/init.d/vshaper ]; then
    /etc/init.d/vshaper stop 2>/dev/null
fi

exit 0