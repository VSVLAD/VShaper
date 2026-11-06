#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0

# Выставляем владельца root:root и права 755 на исполняемый файл и init-скрипт
chown root:root /usr/bin/vshaper /etc/init.d/vshaper 2>/dev/null
chmod 755 /usr/bin/vshaper /etc/init.d/vshaper 2>/dev/null

# Корректно регистрируем и включаем автозапуск сервиса в procd / init.d
if [ -x /etc/init.d/vshaper ]; then
    /etc/init.d/vshaper enable 2>/dev/null
fi

# Оповещаем rpcd об обновлении ACL и меню LuCI
/etc/init.d/rpcd reload 2>/dev/null

exit 0