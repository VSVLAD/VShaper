#include once "logger.bas"
#include once "file_config.bas"
#include once "shaper.bas"

' Логгер команд tc и nftables (в OpenWrt /tmp находится в RAM-диске tmpfs)
Dim logger As MessageLogger = MessageLogger("/tmp/vshaper.log")

' Для хранения имен WAN/LAN интерфейсов в отдельной конфигурации
' TODO: Доработки после
'Dim ifConfig As FileIfConfig = FileIfConfig("/etc/vshaper.conf")

' Управление устройствами
Dim shaper As ShaperManager

' Чтение аргументов командной строки
Dim action As String
action = LCase(Trim(Command(1)))

Select Case action
    Case "start"
        ' Аргументы: vshaper start <lanIf> <wanIf>
        Dim lanIf As String = Command(2)
        Dim wanIf As String = Command(3)
        
        If Len(lanIf) = 0 Or Len(wanIf) = 0 Then
            logger.WriteConsole("[!]: Не указаны обязательные сетевые интерфейсы (lanIf, wanIf)!")
            logger.WriteConsole("[?]: vshaper start br-lan eth0")
            End 1
        End If
        
        If shaper.Start(lanIf, wanIf) Then
            logger.WriteConsole("[+] Инициализация успешно выполнена")
        Else
            logger.WriteConsole("[x]: Ошибка инициализации: " & shaper.LastError)
            End 1
        End If

    Case "add"
        ' Аргументы: vshaper add <ip> <downKbps> <upKbps> <lanIf> <wanIf>
        Dim ip As String = Command(2)
        Dim downRateStr As String = Command(3)
        Dim upRateStr As String = Command(4)
        Dim lanIf As String = Command(5)
        Dim wanIf As String = Command(6)
        
        If Len(ip) = 0 Or Len(downRateStr) = 0 Or Len(upRateStr) = 0 Or Len(lanIf) = 0 Or Len(wanIf) = 0 Then
            logger.WriteConsole("[!]: Недостаточно параметров для добавления клиента (требуются ip, downKbps, upKbps, lanIf, wanIf)!")
            logger.WriteConsole("[?]: vshaper add 192.168.1.2 5000 2000 br-lan eth0")
            End 1
        End If
        
        If Not IsValidIp(ip) Then
            logger.WriteConsole("[!]: Указан некорректный IPv4-адрес (" & ip & ")!")
            End 1
        End If
        
        Dim downRate As ULong = ValLng(downRateStr)
        Dim upRate As ULong = ValLng(upRateStr)

        If shaper.AddClient(lanIf, wanIf, ip, downRate, upRate) Then
            logger.WriteConsole("[+] Лимит для IP " & ip & " успешно применен (Download: " & downRateStr & " Кбит/с, Upload: " & upRateStr & " Кбит/с).")
        Else
            logger.WriteConsole("[x]: Ошибка добавления лимита: " & shaper.LastError)
            End 1
        End If

    Case "del"
        ' Аргументы: vshaper del <ip> <lanIf> <wanIf>
        Dim ip As String = Command(2)
        Dim lanIf As String = Command(3)
        Dim wanIf As String = Command(4)
        
        If Len(ip) = 0 Or Len(lanIf) = 0 Or Len(wanIf) = 0 Then
            logger.WriteConsole("[!]: Недостаточно параметров для удаления (требуются ip, lanIf, wanIf)!")
            logger.WriteConsole("[?]: vshaper del 192.168.1.2 br-lan eth0")
            End 1
        End If
        
        If Not IsValidIp(ip) Then
            logger.WriteConsole("[!]: Указан некорректный IPv4-адрес (" & ip & ")!")
            End 1
        End If

        If shaper.DelClient(lanIf, wanIf, ip) Then
            logger.WriteConsole("[+] Правила ограничения для IP " & ip & " успешно удалены.")
        Else
            logger.WriteConsole("[x]: Ошибка удаления правила: " & shaper.LastError)
            End 1
        End If

    Case "stop"
        ' Аргументы: vshaper stop <lanIf> <wanIf>
        Dim lanIf As String = Command(2)
        Dim wanIf As String = Command(3)
        
        If Len(lanIf) = 0 Or Len(wanIf) = 0 Then
            logger.WriteConsole("[!]: Не указаны обязательные сетевые интерфейсы (lanIf, wanIf) для очистки!")
            logger.WriteConsole("[?]: vshaper stop br-lan eth0")
            End 1
        End If

        If shaper.Stop(lanIf, wanIf) Then
            logger.WriteConsole("[+] Все правила шейпера полностью сброшены.")
        Else
            logger.WriteConsole("[x]: Ошибка при очистке: " & shaper.LastError)
            End 1
        End If

    Case "view"
        ' Аргументы: vshaper view <lanIf>
        Dim lanIf As String = Command(2)
        If Len(lanIf) = 0 Then
            logger.WriteConsole("[!]: Не указан LAN интерфейс для просмотра статистики!")
            logger.WriteConsole("[?]: vshaper view br-lan")
            End 1
        End If
        
        Print shaper.GetClientsView(lanIf)

    Case Else
        Print "*********************************************"
        Print "**  VShaper Traffic Control by Vladilen    **"
        Print "*********************************************"
        Print ""
        Print "Использование:"
        Print "  vshaper <действие> [параметры...]"
        Print ""
        Print "Доступные действия:"
        Print "  start <lanIf> <wanIf>                      - Инициализация дисциплин HTB и цепочки nftables"
        Print "  add   <ip> <downKbps> <upKbps> <lan> <wan> - Установка лимитов скорости для клиента (в Кбит/с)"
        Print "  del   <ip> <lan> <wan>                     - Удаление лимитов для конкретного IP-адреса"
        Print "  stop  <lan> <wan>                          - Полный сброс всех правил и очистка интерфейсов"
        Print "  view  <lanIf>                              - Просмотр статистики и активных классов tc"
        Print ""
        Print "Примеры использования:"
        Print "  1. Инициализация (LAN=br-lan, WAN=eth0):"
        Print "     vshaper start br-lan eth0"
        Print ""
        Print "  2. Добавление ограничения (Скачивание 10 Мбит/с = 10000 Кбит/с, Отдача 5 Мбит/с = 5000 Кбит/с):"
        Print "     vshaper add 192.168.1.2 10000 5000 br-lan eth0"
        Print ""
        Print "  3. Удаление ограничения по IP:"
        Print "     vshaper del 192.168.1.2 br-lan eth0"
        Print ""
        Print "  4. Просмотр статистики:"
        Print "     vshaper view br-lan"
        Print ""
        Print "  5. Полный сброс всех правил:"
        Print "     vshaper stop br-lan eth0"
        Print ""
        Print "Информационные значки:"
        Print "  [!] - требуется исправление"
        Print "  [?] - подсказка для использования"
        Print "  [x] - ошибка выполнения"
        Print "  [+] - действие выполнено успешно"
End Select
