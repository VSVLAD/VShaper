'use strict';
'require view';
'require dom';
'require poll';
'require uci';

return view.extend({
    currentInterval: 2,

    load: function() {
        return uci.load('vshaper');
    },

    // Опрос данных для таблицы мониторинга
    updateData: function() {
        var table = document.getElementById('vshaper_monitor_table');
        if (!table) return Promise.resolve();

        var clients = uci.sections('vshaper', 'client');
        var tbody = table.querySelector('tbody');
        dom.content(tbody, null);

        if (!clients || clients.length === 0) {
            tbody.appendChild(E('tr', { 'class': 'tr' }, [
                E('td', { 'class': 'td', 'colspan': 6, 'style': 'text-align: center; font-style: italic;' },
                    _('Правила ограничения клиентов не настроены'))
            ]));
            return Promise.resolve();
        }

        for (var i = 0; i < clients.length; i++) {
            var c = clients[i];
            var row = E('tr', { 'class': 'tr' }, [
                E('td', { 'class': 'td' }, c.name || _('Без имени')),
                E('td', { 'class': 'td' }, E('strong', {}, c.ip || '-')),
                E('td', { 'class': 'td' }, (c.down_limit || '0') + ' Кбит/с'),
                E('td', { 'class': 'td' }, (c.up_limit || '0') + ' Кбит/с'),
                E('td', { 'class': 'td' }, E('em', {}, _('Ожидание данных бинарника...'))),
                E('td', { 'class': 'td' }, E('span', { 'class': 'badge' }, _('Активен')))
            ]);
            tbody.appendChild(row);
        }

        return Promise.resolve();
    },

    render: function() {
        var self = this;

        // Панель управления интервалом обновления
        var intervalSelect = E('select', {
            'class': 'cbi-input-select',
            'change': function(ev) {
                var val = parseInt(ev.target.value, 10);
                self.currentInterval = val;
                poll.stop();
                if (val > 0) {
                    poll.add(self.updateData.bind(self), val);
                    poll.start();
                }
            }
        }, [
            E('option', { 'value': '1' }, _('1 сек.')),
            E('option', { 'value': '2', 'selected': 'selected' }, _('2 сек.')),
            E('option', { 'value': '5' }, _('5 сек.')),
            E('option', { 'value': '10' }, _('10 сек.')),
            E('option', { 'value': '30' }, _('30 сек.')),
            E('option', { 'value': '0' }, _('Отключено'))
        ]);

        var controlBar = E('div', {
            'style': 'display: flex; justify-content: space-between; align-items: center; margin-bottom: 1em;'
        }, [
            E('div', {}, [
                E('span', { 'style': 'margin-right: 8px;' }, _('Период обновления:')),
                intervalSelect
            ]),
            E('button', {
                'class': 'cbi-button cbi-button-action',
                'click': function() { self.updateData(); }
            }, _('Обновить сейчас'))
        ]);

        // Таблица мониторинга активности
        var table = E('table', { 'class': 'table', 'id': 'vshaper_monitor_table' }, [
            E('thead', {}, [
                E('tr', { 'class': 'tr table-titles' }, [
                    E('th', { 'class': 'th' }, _('Имя устройства')),
                    E('th', { 'class': 'th' }, _('IP-адрес')),
                    E('th', { 'class': 'th' }, _('Лимит Down')),
                    E('th', { 'class': 'th' }, _('Лимит Up')),
                    E('th', { 'class': 'th' }, _('Текущий трафик')),
                    E('th', { 'class': 'th' }, _('Статус'))
                ])
            ]),
            E('tbody', {}, [
                E('tr', { 'class': 'tr' }, [
                    E('td', { 'class': 'td', 'colspan': 6, 'style': 'text-align: center;' },
                        _('Загрузка данных...'))
                ])
            ])
        ]);

        // Регистрируем автоопрос через стандартный poll LuCI
        poll.add(self.updateData.bind(self), self.currentInterval);

        return E('div', { 'class': 'cbi-map' }, [
            E('h2', {}, _('Мониторинг активности')),
            E('div', { 'class': 'cbi-map-descr' }, _('Текущая пропускная способность и статус правил шейпера в реальном времени.')),
            controlBar,
            table
        ]);
    },

    handleSaveApply: null,
    handleSave: null,
    handleReset: null
});