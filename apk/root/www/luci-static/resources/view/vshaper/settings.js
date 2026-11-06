'use strict';
'require view';
'require form';
'require rpc';
'require tools.widgets as widgets';

var callHostHints = rpc.declare({
    object: 'luci-rpc',
    method: 'getHostHints',
    expect: { '': {} }
});

return view.extend({
    load: function() {
        return callHostHints();
    },

    render: function(hosts) {
        var m, s, o;

        m = new form.Map('vshaper', _('Ограничение скорости'), _('Управление ограничением скорости для локальных устройств сети'));

        // ==========================================
        // СЕКЦИЯ 1: Общие настройки
        // ==========================================
        s = m.section(form.NamedSection, 'settings', 'global', _('Общие настройки'));
        s.anonymous = false;

        o = s.option(form.Flag, 'enabled', _('Включить'));
        o.rmempty = false;
        o.default = '0';
        o.validate = function(section_id, value) {
            if (value === '1') {
                var lan = m.uci.get('vshaper', 'settings', 'lan_if');
                var wan = m.uci.get('vshaper', 'settings', 'wan_if');
                if (!lan || !wan) {
                    return _('Невозможно включить шейпер: необходимо обязательно выбрать LAN и WAN интерфейсы');
                }
            }
            return true;
        };

        o = s.option(widgets.DeviceSelect, 'lan_if', _('LAN интерфейс (Download)'));
        o.noaliases = true;
        o.rmempty = false;
        o.validate = function(section_id, value) {
            var wan = m.uci.get('vshaper', 'settings', 'wan_if');
            if (wan && value === wan) {
                return _('LAN и WAN интерфейсы не могут совпадать');
            }
            return true;
        };

        o = s.option(widgets.DeviceSelect, 'wan_if', _('WAN интерфейс (Upload)'));
        o.noaliases = true;
        o.rmempty = false;
        o.validate = function(section_id, value) {
            var lan = m.uci.get('vshaper', 'settings', 'lan_if');
            if (lan && value === lan) {
                return _('WAN и LAN интерфейсы не могут совпадать');
            }
            return true;
        };

        // ==========================================
        // СЕКЦИЯ 2: Список лимитов для клиентов
        // ==========================================
        s = m.section(form.GridSection, 'client', _('Правила ограничения устройств'));
        s.anonymous = true;
        s.addremove = true;

        o = s.option(form.Value, 'name', _('Описание'));
        o.placeholder = 'ПК / Smart TV';

        o = s.option(form.Value, 'ip', _('IP-адрес устройства'));
        o.datatype = 'ip4addr';
        o.rmempty = false;
        o.validate = function(section_id, value) {
            if (!value) return _('IP-адрес обязателен для заполнения');
            
            // Проверяем дубликаты IP среди других клиентов в конфигурации
            var sections = m.uci.sections('vshaper', 'client');
            for (var i = 0; i < sections.length; i++) {
                var sId = sections[i]['.name'];
                
                // Пропускаем текущую редактируемую секцию
                if (sId === section_id) continue;
                
                var existingIp = m.uci.get('vshaper', sId, 'ip');
                if (existingIp && existingIp === value) {
                    var errMsg = _('Клиент с IP-адресом ' + value + ' уже добавлен в список ограничений');
                    return errMsg;
                }
            }
            return true;
        };

        if (hosts) {
            for (var mac in hosts) {
                var host = hosts[mac];
                if (host.ipaddrs && host.ipaddrs.length > 0) {
                    for (var i = 0; i < host.ipaddrs.length; i++) {
                        var ip = host.ipaddrs[i];
                        if (ip !== '192.168.1.1' && ip.indexOf('100.121.') === -1) {
                            var label = ip;
                            if (host.name) {
                                label += ' (' + host.name.replace('.lan', '') + ')';
                            }
                            o.value(ip, label);
                        }
                    }
                }
            }
        }

        o = s.option(form.Value, 'down_limit', _('Download (Кбит/с)'));
        o.datatype = 'uinteger';
        o.placeholder = '15000 (15 Мбит/с)';
        o.rmempty = false;

        o = s.option(form.Value, 'up_limit', _('Upload (Кбит/с)'));
        o.datatype = 'uinteger';
        o.placeholder = '5000 (5 Мбит/с)';
        o.rmempty = false;

        return m.render();
    }
});