#include once "crt/stdio.bi"
#include once "logger.bas"

Type SystemTool
    Private:
        Dim _lastOutput As String
        Dim _exitCode As Integer
    Public:
        ' Главный метод: запускает команду, собирает вывод и код возврата
        Declare Function Execute(ByVal command As String) As Boolean
        
        ' Свойства для получения результатов
        Declare Property Output() As String
        Declare Property ExitCode() As Integer
End Type

Function SystemTool.Execute(ByVal command As String) As Boolean
    This._lastOutput = ""
    This._exitCode = -1

    Dim fullCmd As String = command & " 2>&1"
    
    logger.WriteFile("[COMMAND]  " & command)

    Dim pipe As FILE Ptr = popen(fullCmd, "r")
    If pipe = NULL Then
        This._exitCode = -1
        logger.WriteFile("[RETURN] -1")
        logger.WriteFile("[STDOUT]  <error: popen failed>")
        logger.WriteFileSeparator()
        Return False
    End If
    
    Dim buffer As ZString * 512

    While fgets(buffer, SizeOf(buffer), pipe) <> NULL
        This._lastOutput &= buffer
    Wend
    
    Dim status As Integer = pclose(pipe)
    This._exitCode = (status Shr 8) And &hFF
    
    This._lastOutput = Trim(This._lastOutput, Any !"\r\n ")

    logger.WriteFile("[RETURN] " & Str(This._exitCode))
    If Len(This._lastOutput) > 0 Then
        logger.WriteFile("[STDOUT]  " & This._lastOutput)
    Else
        logger.WriteFile("[STDOUT]  <empty>")
    End If
    logger.WriteFileSeparator()

    Return This._exitCode = 0
End Function

Property SystemTool.Output() As String
    Return This._lastOutput
End Property

Property SystemTool.ExitCode() As Integer
    Return This._exitCode
End Property
