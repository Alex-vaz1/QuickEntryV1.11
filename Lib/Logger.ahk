#Requires AutoHotkey v2.0

; Logger.ahk - file logging simple para diagnostico multi-operador.
;
; Output: %APPDATA%\QuickEntry\events.log
; Format: [YYYY-MM-DD HH:mm:ss] LEVEL EVENT=name kv1=val1 kv2=val2 ...
; Rotation: cuando events.log > 1 MB, rename a events.log.old (1 backup).

class Logger
{
    static MAX_BYTES := 1048576  ; 1 MB
    static _initialized := false
    static _logPath := ""

    static _Init()
    {
        if Logger._initialized
            return
        dir := A_AppData "\QuickEntry"
        if !DirExist(dir)
            DirCreate(dir)
        Logger._logPath := dir "\events.log"
        Logger._initialized := true
    }

    ; Path actual del log. Util para tests / soporte ("mandame events.log").
    static Path
    {
        get {
            Logger._Init()
            return Logger._logPath
        }
    }

    ; Escribe una linea estructurada. Rota si el archivo excede MAX_BYTES.
    ; level: "INFO" | "WARN" | "ERROR"
    ; event: nombre corto (ej "paste_batch")
    ; kvMap: Map de pares clave-valor opcionales
    static Log(level, event, kvMap := "")
    {
        Logger._Init()
        try {
            if FileExist(Logger._logPath) {
                size := FileGetSize(Logger._logPath)
                if (size > Logger.MAX_BYTES)
                    Logger._Rotate()
            }
            ts := FormatTime(, "yyyy-MM-dd HH:mm:ss")
            line := "[" ts "] " level " EVENT=" event
            if IsObject(kvMap) {
                for k, v in kvMap
                    line .= " " k "=" Logger._EscapeValue(v)
            }
            FileAppend(line "`n", Logger._logPath, "UTF-8")
        } catch {
            ; Log silencioso si falla escritura (disco lleno, permisos): no propagar.
            ; El operador ya tiene problemas mas grandes que un log roto.
        }
    }

    static Info(event, kvMap := "")  => Logger.Log("INFO", event, kvMap)
    static Warn(event, kvMap := "")  => Logger.Log("WARN", event, kvMap)
    static Error(event, kvMap := "") => Logger.Log("ERROR", event, kvMap)

    static _Rotate()
    {
        oldPath := Logger._logPath ".old"
        if FileExist(oldPath)
            FileDelete(oldPath)
        FileMove(Logger._logPath, oldPath)
    }

    ; Espacios y caracteres que rompen el grep: reemplazarlos.
    static _EscapeValue(v)
    {
        s := String(v)
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, " ", "_")
        return s
    }
}
