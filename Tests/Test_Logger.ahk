#Requires AutoHotkey v2.0
#SingleInstance Off

#Include "..\Lib\Logger.ahk"
#Include "_AssertHelpers.ahk"

; Setup: redirigir log a un path temp para no contaminar APPDATA del operador.
testDir := A_Temp "\QuickEntry_Test_Logger"
if DirExist(testDir)
    DirDelete(testDir, true)
DirCreate(testDir)
Logger._logPath := testDir "\events.log"
Logger._initialized := true

; --- 1. Log.Info crea el archivo y escribe una linea bien formada
Logger.Info("test_event", Map("slot", 3, "value", "ok"))
AssertEq(FileExist(Logger._logPath) ? 1 : 0, 1, "Info crea el archivo")
content := FileRead(Logger._logPath)
AssertContains(content, "INFO EVENT=test_event", "linea contiene INFO + event name")
AssertContains(content, "slot=3", "kv slot serializado")
AssertContains(content, "value=ok", "kv value serializado")

; --- 2. Niveles distintos
Logger.Warn("test_warn")
Logger.Error("test_error", Map("err", "x"))
content := FileRead(Logger._logPath)
AssertContains(content, "WARN EVENT=test_warn", "Warn escribe WARN")
AssertContains(content, "ERROR EVENT=test_error", "Error escribe ERROR")

; --- 3. Escape de valores con espacios
Logger.Info("escape_test", Map("msg", "hello world"))
content := FileRead(Logger._logPath)
AssertContains(content, "msg=hello_world", "espacios reemplazados por _")

; --- 4. Rotacion cuando supera MAX_BYTES
; Forzamos MAX_BYTES bajo para no escribir 1MB en el test.
Logger.MAX_BYTES := 200
loop 20 {
    Logger.Info("fill", Map("i", A_Index, "data", "aaaaaaaaaaaaaaaaaaaa"))
}
oldPath := Logger._logPath ".old"
AssertEq(FileExist(oldPath) ? 1 : 0, 1, "rotacion crea .old")

; Cleanup
DirDelete(testDir, true)

ReportarYSalir()
