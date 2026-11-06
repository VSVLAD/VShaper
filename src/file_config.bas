Type FileIfConfig
    Private:
        Dim _filePath As String
        Const lanConfig As String = "lan="
        Const wanConfig As String = "wan="
    Public:
        Declare Constructor(ByRef FilePath As String)
        Declare Function SaveConfig(ByRef lanIf As String, ByRef wanIf As String) As Boolean
        Declare Function LoadConfig(ByRef lanIf As String, ByRef wanIf As String) As Boolean
        Declare Function RemoveConfig() As Boolean
End Type

Constructor FileIfConfig(ByRef FilePath As String)
    This._filePath = FilePath
End Constructor

Function FileIfConfig.SaveConfig(ByRef lanIf As String, ByRef wanIf As String) As Boolean
    Dim fileNum As Integer = FreeFile()
    If Open(This._filePath For Output As #fileNum) = 0 Then
        Print #fileNum, lanConfig & lanIf
        Print #fileNum, wanConfig & wanIf
        Close #fileNum
        Return True
    End If
    Return False
End Function

Function FileIfConfig.RemoveConfig() As Boolean
    If Kill(This._filePath) = 0 Then
        Print "Err() = " & Err()
        Return True
    Else
        Print "Err() = " & Err()
        Return False
    End If
End Function

Function FileIfConfig.LoadConfig(ByRef lanIf As String, ByRef wanIf As String) As Boolean
    Dim fileNum As Integer = FreeFile()
    lanIf = ""
    wanIf = ""

    If Open(This._filePath For Input As #fileNum) = 0 Then
        While Not EOF(fileNum)
            Dim lineStr As String

            Line Input #fileNum, lineStr
            lineStr = Trim(lineStr)
            
            If LCase(Left(lineStr, 4)) = lanConfig Then
                lanIf = Trim(Mid(lineStr, 5))
            ElseIf LCase(Left(lineStr, 4)) = wanConfig Then
                wanIf = Trim(Mid(lineStr, 4))
            End If
        Wend
        Close #fileNum
        
        If Len(lanIf) > 0 And Len(wanIf) > 0 Then
            Return True
        End If
    End If
    
    Return False
End Function
