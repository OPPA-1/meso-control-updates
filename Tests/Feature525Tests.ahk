#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
root := A_ScriptDir "\.."
visual := FileRead(root "\Meso_Visual_Effect.ahk", "UTF-8")
output := FileRead(root "\Meso_Stream_Output.ahk", "UTF-8")
control := FileRead(root "\Meso_Control.ahk", "UTF-8")
Check(InStr(visual, "InitializeLiveMirror(w, h)"), "Live DirectComposition mirror initialized")
Check(InStr(visual, "DCompositionCreateDevice2") && InStr(visual, "DCompInvoke(MirrorDevice, 11"), "Mirror composition device and live surface")
Check(InStr(visual, "for control in PuzzleMags") && InStr(visual, "InvalidateRect"), "Continuous puzzle redraw")
Check(InStr(visual, "if mag") && InStr(visual, "InvalidateRect"), "Continuous single view redraw")
Check(!InStr(visual, "DrawMirror(") && !InStr(visual, "GetDC") && !InStr(visual, "PrintWindow"), "No stale GDI game frames")
Check(!InStr(visual, "SetWindowDisplayAffinity"), "Overlay visible to Display Capture")
Check(InStr(visual, "+E0x08080020") && InStr(visual, "+E0x08000020"), "Normal effect and mirror hosts use separate capture-compatible styles")
Check(InStr(visual, "NumPut(""Float"", -1.0"), "Reflection uses negative horizontal scaling")
Check(!InStr(output, "PaintStreamMirror"), "Stream output unchanged")
Check(InStr(control, "body .= PublishCooldown(now)"), "Existing stream state kept")
MsgBox("PASS Meso 5.2.5 visual regression checks", "Meso Control")
ExitApp(0)
Check(condition, label) {
    if !condition
        throw Error(label)
}
