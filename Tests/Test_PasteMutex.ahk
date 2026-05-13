#Requires AutoHotkey v2.0
#SingleInstance Off

#Include "..\Lib\PasteMutex.ahk"
#Include "_AssertHelpers.ahk"

; Estado inicial limpio
PasteMutex.Release()

; --- 1. Estado inicial: no locked
AssertEq(PasteMutex.IsLocked, false, "estado inicial: IsLocked=false")

; --- 2. Acquire toma el lock
ok := PasteMutex.Acquire()
AssertEq(ok, true, "primer Acquire retorna true")
AssertEq(PasteMutex.IsLocked, true, "tras Acquire: IsLocked=true")

; --- 3. Acquire mientras lockeado retorna false (no-recursive)
ok2 := PasteMutex.Acquire()
AssertEq(ok2, false, "segundo Acquire retorna false")
AssertEq(PasteMutex.IsLocked, true, "sigue locked despues del segundo Acquire fallido")

; --- 4. Release libera
PasteMutex.Release()
AssertEq(PasteMutex.IsLocked, false, "tras Release: IsLocked=false")

; --- 5. Release idempotente
PasteMutex.Release()
AssertEq(PasteMutex.IsLocked, false, "Release doble no rompe nada")

; --- 6. Acquire post-Release funciona
ok3 := PasteMutex.Acquire()
AssertEq(ok3, true, "Acquire despues de Release funciona")
PasteMutex.Release()

ReportarYSalir()
