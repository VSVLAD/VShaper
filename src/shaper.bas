#include once "logger.bas"
#Include once "utils.bas"
#Include once "system_tool.bas"

' Структура для информации о клиенте и его статистике трафика
Type ShaperClientInfo
    IP As String
    ClassId As String
    DownRate As String
    UpRate As String
    BytesTransferred As ULongInt
    PacketsTransferred As ULongInt
    IsActive As Boolean
End Type

' Класс-обертка для управления правилами tc/nft с возвратом детальных текстов ошибок
Type ShaperManager
    Private:
        Dim _lastError As String
        Declare Sub SetError(ByRef errStr As String)
    Public:
        Declare Constructor()
        Declare Property LastError() As String
        
        Declare Function Start(ByRef lanIf As String, ByRef wanIf As String) As Boolean
        Declare Function AddClient(ByRef lanIf As String, ByRef wanIf As String, ByRef ip As String, ByVal downKbps As ULong, ByVal upKbps As ULong) As Boolean
        
        ' Опциональный параметр onlyAction (по умолчанию False): если True, не сбрасывает и не затирает _lastError при откате
        Declare Function DelClient(ByRef lanIf As String, ByRef wanIf As String, ByRef ip As String, ByVal onlyAction As Boolean = False) As Boolean
        Declare Function Stop(ByRef lanIf As String, ByRef wanIf As String) As Boolean
        
        ' Метод получения списка активных клиентов, их лимитов и статистики из tc
        Declare Function GetClientsView(ByRef lanIf As String) As String
End Type

Constructor ShaperManager()
    This._lastError = ""
End Constructor

Property ShaperManager.LastError() As String
    Return This._lastError
End Property

Sub ShaperManager.SetError(ByRef errStr As String)
    This._lastError = errStr
End Sub

' 1. Инициализация инфраструктуры
Function ShaperManager.Start(ByRef lanIf As String, ByRef wanIf As String) As Boolean
    Dim tool As SystemTool

    logger.WriteFileNewLine()
    logger.WriteFileBlock("[CLI] vshaper start " & lanIf & " " & wanIf)
    logger.WriteFileNewLine()

    tool.Execute("tc qdisc del dev " & lanIf & " root")
    tool.Execute("tc qdisc del dev " & wanIf & " root")

    If Not tool.Execute("tc qdisc add dev " & lanIf & " root handle 1: htb default abcd") Then
        This.SetError("Не удалось установить HTB qdisc на LAN-интерфейсе " & lanIf & ": " & tool.Output)
        Return False
    End If

    If Not tool.Execute("tc qdisc add dev " & wanIf & " root handle 1: htb default abcd") Then
        This.SetError("Не удалось установить HTB qdisc на WAN-интерфейсе " & wanIf & ": " & tool.Output)
        Return False
    End If

    tool.Execute("tc class add dev " & lanIf & " parent 1: classid 1:abcd htb rate 1000mbit ceil 1000mbit")
    tool.Execute("tc class add dev " & wanIf & " parent 1: classid 1:abcd htb rate 1000mbit ceil 1000mbit")

    tool.Execute("nft delete chain inet fw4 vshaper_limiter_mangle")
    If Not tool.Execute("nft ""add chain inet fw4 vshaper_limiter_mangle { type filter hook forward priority mangle; }""") Then
        This.SetError("Не удалось создать цепочку nftables vshaper_limiter_mangle: " & tool.Output)
        Return False
    End If

    Return True
End Function

' 2. Точечное удаление клиента
Function ShaperManager.DelClient(ByRef lanIf As String, ByRef wanIf As String, ByRef ip As String, ByVal onlyAction As Boolean = False) As Boolean
    Dim octet As Integer
    Dim sClassId As String
    Dim sHexMark As String
    Dim nftList As String
    Dim handleVal As Integer
    Dim tool As SystemTool

    logger.WriteFileNewLine()
    logger.WriteFileBlock("[CLI] vshaper del " & ip & " " & lanIf & " " & wanIf)
    logger.WriteFileNewLine()

    If Not onlyAction Then
        This._lastError = ""
    End If

    octet = GetIpLastOctet(ip)
    
    If octet <= 0 Or octet > 254 Then
        If Not onlyAction Then
            This.SetError("Некорректный IP-адрес или недопустимый октет (" & ip & "). Диапазон: 1-254.")
        End If
        Return False
    End If

    sClassId = Str(octet)
    sHexMark = GetHexMark(octet)

    ' Удаляем фильтры и классы в строгом порядке по уникальному приоритету (prio = octet)
    tool.Execute("tc filter del dev " & lanIf & " protocol ip parent 1:0 prio " & sClassId)
    tool.Execute("tc class del dev " & lanIf & " classid 1:" & sClassId)

    tool.Execute("tc filter del dev " & wanIf & " protocol ip parent 1:0 prio " & sClassId)
    tool.Execute("tc class del dev " & wanIf & " classid 1:" & sClassId)

    ' Удаляем правило из nftables по совпадению IP адреса
    tool.Execute("nft delete rule inet fw4 vshaper_limiter_mangle ip saddr " & ip)

    Return True
End Function

' 3. Добавление лимита клиенту с атомарным откатом при ошибках (безопасное добавление)
Function ShaperManager.AddClient(ByRef lanIf As String, ByRef wanIf As String, ByRef ip As String, ByVal downKbps As ULong, ByVal upKbps As ULong) As Boolean
    Dim octet As Integer
    Dim sClassId As String
    Dim sDownRate As String
    Dim sUpRate As String
    Dim sHexMark As String
    Dim tool As SystemTool

    logger.WriteFileNewLine()
    logger.WriteFileBlock("[CLI] vshaper add " & ip & " " & downKbps & " " & upKbps & " " & lanIf & " " & wanIf)
    logger.WriteFileNewLine()

    octet = GetIpLastOctet(ip)
    
    If octet <= 0 Or octet > 254 Then
        This.SetError("Недопустимый IP-адрес (" & ip & "). Последний октет должен быть от 1 до 254.")
        Return False
    End If

    sClassId = Str(octet)
    sHexMark = GetHexMark(octet)
    sDownRate = FormatRate(downKbps)
    sUpRate = FormatRate(upKbps)

    ' 1. Предварительно очищаем старые правила перед добавлением новых
    This.DelClient(lanIf, wanIf, ip, False)

    ' 2. Последовательно применяем новые правила
    If Not tool.Execute("tc class add dev " & lanIf & " parent 1: classid 1:" & sClassId & " htb rate " & sDownRate & " ceil " & sDownRate) Then
        This.SetError("Не удалось добавить входящий класс tc на интерфейсе " & lanIf & ": " & tool.Output)
        This.DelClient(lanIf, wanIf, ip, True)
        Return False
    End If

    If Not tool.Execute("tc filter add dev " & lanIf & " protocol ip parent 1:0 prio " & sClassId & " handle ::" & sClassId & " u32 match ip dst " & ip & " flowid 1:" & sClassId) Then
        This.SetError("Не удалось добавить входящий фильтр tc на интерфейсе " & lanIf & ": " & tool.Output)
        This.DelClient(lanIf, wanIf, ip, True)
        Return False
    End If

    If Not tool.Execute("tc class add dev " & wanIf & " parent 1: classid 1:" & sClassId & " htb rate " & sUpRate & " ceil " & sUpRate) Then
        This.SetError("Не удалось добавить исходящий класс tc на интерфейсе " & wanIf & ": " & tool.Output)
        This.DelClient(lanIf, wanIf, ip, True)
        Return False
    End If

    If Not tool.Execute("tc filter add dev " & wanIf & " protocol ip parent 1:0 prio " & sClassId & " handle " & sHexMark & "/0xff00 fw flowid 1:" & sClassId) Then
        This.SetError("Не удалось добавить исходящий фильтр tc на интерфейсе " & wanIf & ": " & tool.Output)
        This.DelClient(lanIf, wanIf, ip, True)
        Return False
    End If

    If Not tool.Execute("nft ""add rule inet fw4 vshaper_limiter_mangle ip saddr " & ip & " meta mark set mark and 0xffff00ff or " & sHexMark & """") Then
        This.SetError("Не удалось добавить правило маркировки в nftables: " & tool.Output)
        This.DelClient(lanIf, wanIf, ip, True)
        Return False
    End If

    Return True
End Function

' 4. Полный сброс
Function ShaperManager.Stop(ByRef lanIf As String, ByRef wanIf As String) As Boolean
    Dim tool As SystemTool

    logger.WriteFileNewLine()
    logger.WriteFileBlock("[CLI] vshaper stop " & lanIf & " " & wanIf)
    logger.WriteFileNewLine()

    tool.Execute("tc qdisc del dev " & lanIf & " root")
    tool.Execute("tc qdisc del dev " & wanIf & " root")
    tool.Execute("nft flush chain inet fw4 vshaper_limiter_mangle")
    tool.Execute("nft delete chain inet fw4 vshaper_limiter_mangle")

    Return True
End Function

' 5. Получение информации об активных классах и статистике из tc
Function ShaperManager.GetClientsView(ByRef lanIf As String) As String
    Dim tool As SystemTool

    logger.WriteFileNewLine()
    logger.WriteFileBlock("[CLI] vshaper view " & lanIf)
    logger.WriteFileNewLine()

    If tool.Execute("tc -s class show dev " & lanIf) Then
        Return tool.Output
    End If
    Return "Ошибка получения статистики tc: " & tool.Output
End Function
