#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
base := A_ScriptDir "\.."
visual := FileRead(base "\Meso_Visual_Effect.ahk", "UTF-8")
updater := FileRead(base "\Lib\GitHubUpdateTools.ps1", "UTF-8")
settings := FileRead(base "\Lib\Updates.ahk", "UTF-8")
source := FileRead(A_ScriptDir "\..\Tests\Feature522Tests.ahk", "UTF-8")
Assert(InStr(visual, "+E0x08080020 +0x02000000 -DPIScale"), "5.2.2 overlay host restored")
Assert(InStr(visual, "mode = ""puzzle"" ? 6 : 1"), "3x2 mosaic preserved")
Assert(InStr(visual, "MagSetWindowSource"), "Live magnifier capture remains")
Assert(InStr(visual, "InvalidateRect"), "Live repaint requests restored")
Assert(InStr(visual, "DCompositionCreateDevice2"), "Mirror uses GPU-backed composition")
Assert(!InStr(visual, "DrawMirror(") && !InStr(visual, "SetWindowDisplayAffinity"), "No GDI or capture hiding")
Assert(InStr(updater, "-PassThru -ErrorAction Stop") && InStr(updater, "HasExited"), "Updater confirms relaunch")
Assert(!InStr(updater, "--background"), "Updater no longer restarts hidden")
Assert(InStr(settings, "restart automatically"), "Update UI describes automatic restart")
Assert(InStr(source, "RunVisualCheck(""mirror"""), "Visual smoke test retained")
FileAppend("PASS Meso 5.2.5 flip checks`n", "*")
ExitApp(0)
Assert(valid, message) {
    if !valid
        throw Error(message)
}
