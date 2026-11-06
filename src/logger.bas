#include once "vbcompat.bi"

Type MessageLogger
    Private:
        Const _lineSeparator As String = "----------------------------------------"
        Dim _filePath As String
    Public:
        Declare Constructor(ByRef FilePath As String)
        
        Declare Sub WriteConsole(ByRef message As String)

        Declare Sub WriteFile(ByRef message As String)
        Declare Sub WriteFileBlock(ByRef message As String)
        Declare Sub WriteFileSeparator()
        Declare Sub WriteFileNewLine()
End Type

' Объявляем глобальную переменную экстерном, чтобы она была видна во всем проекте
Extern logger As MessageLogger

Constructor MessageLogger(ByRef FilePath As String)
    This._filePath = FilePath
End Constructor

Sub MessageLogger.WriteFile(ByRef message As String)
    Dim fileNum As Integer = FreeFile()

    If Open(This._filePath For Append Encoding "UTF-8" As #fileNum) = 0 Then
        Dim logDateTime As String = Format(Now(), "yyyy-mm-dd hh:mm:ss")

        Print #fileNum, "[" & logDateTime & "] " & message
        Close #fileNum
    End If
End Sub

Sub MessageLogger.WriteFileNewLine()
    WriteFile("")
End Sub

Sub MessageLogger.WriteFileSeparator()
    WriteFile(_lineSeparator)
End Sub

Sub MessageLogger.WriteFileBlock(ByRef message As String)
    WriteFileSeparator()
    WriteFile(message)
    WriteFileSeparator()
End Sub

Sub MessageLogger.WriteConsole(ByRef message As String)
    Print message
End Sub
