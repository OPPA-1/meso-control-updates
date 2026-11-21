#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
base := A_ScriptDir "\.."
visual := FileRead(base "\Meso_Visual_Effect.ahk", "UTF-8")
Assert(InStr(visual, "DCompositionCreateDevice2"), "DirectComposition device")
Assert(InStr(visual, "DCompInvoke(MirrorDevice, 11"), "Live layered magnifier source")
Assert(InStr(visual, "DCompInvoke(MirrorVisual, 15"), "Live visual source")
Assert(InStr(visual, "DCompInvoke(MirrorTarget, 3"), "Composed target")
Assert(InStr(visual, "NumPut(""Float"", -1.0"), "Horizontal reflection matrix")
Assert(InStr(visual, "DwmSetWindowAttribute"), "Source cloak")
Assert(InStr(visual, "MagSetWindowSource"), "Continuous magnifier capture")
Assert(InStr(visual, "InvalidateRect"), "Continuous repaint")
Assert(!InStr(visual, "DrawMirror(") && !InStr(visual, "PrintWindow") && !InStr(visual, "SetWindowDisplayAffinity"), "No stale captures or OBS exclusion")
FileAppend("PASS Meso live flip source checks`n", "*")
ExitApp(0)
Assert(valid, name) {
    if !valid
        throw Error(name)
}
