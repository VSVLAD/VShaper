
' Конвертер скорости: из Кбит/с в строковый формат ("Xmbit" или "Ykbit")
Function FormatRate(ByVal kbps As ULong) As String
    If kbps >= 1000 And (kbps Mod 1000 = 0) Then
        Return Str(kbps \ 1000) & "mbit"
    End If
    Return Str(kbps) & "kbit"
End Function

' Простейшая проверка валидности IPv4-адреса
Function IsValidIp(ByRef ip As String) As Boolean
    Dim parts(1 To 4) As Integer
    Dim cnt As Integer = 0
    Dim p As Integer = 1
    Dim nextP As Integer
    
    While p <= Len(ip)
        nextP = InStr(p, ip, ".")
        cnt += 1
        If cnt > 4 Then Return False
        
        Dim partStr As String
        If nextP > 0 Then
            partStr = Mid(ip, p, nextP - p)
            p = nextP + 1
        Else
            partStr = Mid(ip, p)
            p = Len(ip) + 1
        End If
        
        If Len(partStr) = 0 Or Len(partStr) > 3 Then Return False
        Dim valPart As Integer = Val(partStr)
        If valPart < 0 Or valPart > 255 Then Return False
    Wend
    
    Return (cnt = 4)
End Function

' Извлечение последнего октета IPv4 адреса
Function GetIpLastOctet(ByRef ip As String) As Integer
    Dim lastDot As Integer
    lastDot = InStrRev(ip, ".")
    If lastDot > 0 Then
        Return Val(Mid(ip, lastDot + 1))
    End If
    Return 0
End Function

' Получение HEX-строки метки со сдвигом во 2-й байт (octet Shl 8)
Function GetHexMark(ByVal octet As Integer) As String
    Dim shifted As Integer
    shifted = (octet And &hFF) Shl 8
    Return "0x" & Hex(shifted, 4)
End Function
