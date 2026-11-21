#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
checks := 0
g := 0
try {
    g := Gui(, "Meso icon test")
    Check(!ApplyGuiIcon(0), "Invalid window is handled")
    Check(!ApplyGuiIcon(g, A_ScriptDir "\missing.ico"), "Missing icon is handled")
    Check(ApplyGuiIcon(g, A_ScriptDir "\..\Meso_Icon.ico"), "Icon loads without any controller globals")
    Check(ApplyGuiIcon(g, A_ScriptDir "\..\Meso_Icon.ico"), "Icon handles are reused")
    g.Destroy()
    Check(!ApplyGuiIcon(g, A_ScriptDir "\..\Meso_Icon.ico"), "Destroyed window is handled")
    FileAppend("PASS " checks " icon-startup checks`n", "*")
    MsgBox("Passed " checks " checks. No game input was sent.", "Meso icon tests")
    ExitApp(0)
} catch as err {
    if GuiHwndSafe(g)
        g.Destroy()
    FileAppend("FAIL " err.Message "`n", "*")
    MsgBox(err.Message, "Meso icon test failed")
    ExitApp(1)
}
Check(ok, message) {
    global checks
    if !ok
        throw Error(message)
    checks += 1
}
