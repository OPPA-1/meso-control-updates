#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#Include ..\Lib\Core.ahk
count := 0
try {
    app := FileRead(A_ScriptDir "\..\Meso_Control.ahk", "UTF-8")
    Check(InStr(app, "body .= PublishCooldown(now)"), "Cooldown fallback retained")
    Check(!InStr(app, "Line(""visual"""), "Inversion removed from stream output state")
    Check(InStr(app, "} else {") && InStr(app, "body .= PublishCooldown(now)"), "Active effect conditional has valid braces")
    visual := FileRead(A_ScriptDir "\..\Meso_Visual_Effect.ahk", "UTF-8")
    Check(!InStr(visual, "SetWindowDisplayAffinity"), "Display Capture can see visual overlay")
    Check(InStr(visual, "+0x02000000"), "Original magnifier host clipping restored")
    Check(InStr(visual, "count := mode = ""puzzle"" ? 6 : 1"), "Mirror receives a live magnifier control")
    Check(InStr(visual, "MagSetWindowFilterList"), "Magnifier excludes its own window")
    Check(!InStr(visual, "user32\GetDC") && !InStr(visual, "PrintWindow") && !InStr(visual, "DrawMirror("), "Unreliable mirror fallback is removed")
    Check(InStr(visual, "1000.0 / 60.0"), "Frame scheduling targets 60 Hz")
    output := FileRead(A_ScriptDir "\..\Meso_Stream_Output.ahk", "UTF-8")
    Check(!InStr(output, "PaintStreamMirror"), "OBS output window has no gameplay mirror")
    Check(InStr(output, "sourceWidth * 2.5"), "Large Tung chunks retained")
    Check(InStr(output, "Until: now + 60000"), "Per-chunk duration retained")
    FileAppend("PASS " count " Meso 5.2.4 checks`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message "`n", "*")
    ExitApp(1)
}
Check(ok, label) {
    global count
    count += 1
    if !ok
        throw Error(label)
}
