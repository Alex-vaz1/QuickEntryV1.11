#Requires AutoHotkey v2.0

global g_failures := 0
global g_total := 0

AssertEq(actual, expected, name)
{
    global g_failures, g_total
    g_total++
    if (actual == expected)
        FileAppend("PASS  " name "`n", "*")
    else
    {
        g_failures++
        FileAppend("FAIL  " name "`n      expected: [" expected "]`n      actual:   [" actual "]`n", "*")
    }
}

AssertContains(haystack, needle, name)
{
    global g_failures, g_total
    g_total++
    if (InStr(haystack, needle))
        FileAppend("PASS  " name "`n", "*")
    else
    {
        g_failures++
        FileAppend("FAIL  " name "`n      haystack: [" haystack "]`n      needle:   [" needle "]`n", "*")
    }
}

ReportarYSalir()
{
    global g_total, g_failures
    FileAppend("`n=== " g_total " tests, " g_failures " failures ===`n", "*")
    ExitApp(g_failures > 0 ? 1 : 0)
}
