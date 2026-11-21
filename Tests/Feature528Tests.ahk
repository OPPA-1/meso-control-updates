#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
source := FileRead(A_ScriptDir "\..\Meso_Visual_Effect.ahk", "UTF-8")
Check(!InStr(source, "MirrorSourceGui"), "No separate black mirror window")
Check(InStr(source, 'mode = "mirror" ? "+AlwaysOnTop -Caption +ToolWindow +E0x08000020'), "Composition host is not layered")
Check(InStr(source, 'mode = "mirror" ? 0x00080020 : 0x00000020'), "Magnifier source is layered")
Check(InStr(source, 'DCompInvoke(MirrorDevice, 11, "Ptr", mag'), "Composition captures magnifier child")
Check(InStr(source, "DwmSetWindowAttribute"), "Magnifier child is cloaked")
Check(InStr(source, 'return DllCall(callArgs*)'), "COM invoker is correctly expanded")
Check(InStr(source, 'visual-errors.log'), "Persistent visual failures")
Check(InStr(source, 'DllCall("user32\InvalidateRect"'), "Continuous refresh remains enabled")
Check(InStr(source, 'Mode = "mirror"') || InStr(source, 'mode = "mirror"'), "Invert screen mode remains")
FileAppend("PASS 5.2.8 flip architecture`n", "*")
ExitApp(0)
Check(pass, title) {
    if !pass
        throw Error(title)
}
