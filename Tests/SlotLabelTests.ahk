#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\Draw.ahk
#Include ..\Lib\WheelLabels.ahk
#Include ..\Lib\SlotLabels.ahk
#Include ..\Lib\ActivityData.ahk
checks := 0
token := 0
canvas := 0
try {
    token := GdipStart()
    canvas := Surface(1120, 480, true)
    names := Map()
    db := BuildActivityDatabase()
    for category, groups in db {
        names[category] := true
        for group, activities in groups {
            names[group] := true
            for name in activities
                names[name] := true
        }
    }
    for name in ["HUNTER", "WARLOCK", "TITAN"]
        names[name] := true
    for name in names {
        layout := FitSlotLabel(canvas, name)
        Check(layout.Lines.Length >= 1 && layout.Lines.Length <= 2, "One or two full lines: " name)
        joined := ""
        for line in layout.Lines {
            joined .= (joined = "" ? "" : " ") line
            measured := canvas.MeasureText(line, layout.Size, true)
            Check(measured.W <= 203, "Width fits: " name)
        }
        Check(joined = name, "No split word, truncation, or lost character: " name)
        Check(layout.LineH * layout.Lines.Length <= 102, "Height fits: " name)
        canvas.Clear()
        DrawSlotLabel(canvas, name, 18, 192)
        canvas.Flush()
    }
    for name in ["MORPHOLOGY", "TRANSMIGRATION", "METAMORPHOSIS"] {
        layout := FitSlotLabel(canvas, name)
        Check(layout.Lines.Length = 1 && layout.Lines[1] = name, "Long single word stays whole: " name)
    }
    exitLayout := FitWheelLabel(canvas, "Exit Game", 360 / 62)
    Check(exitLayout.Lines.Length = 1 && exitLayout.Lines[1] = "EXIT", "EXIT shown in full")
    Check(exitLayout.Size >= 16, "EXIT readable at default weight")
    Check(exitLayout.LineH <= exitLayout.H - 2, "EXIT not clipped vertically")
    canvas.Dispose()
    canvas := 0
    GdipStop(&token)
    FileAppend("PASS " checks " slot / exit typography checks`n", "*")
    ExitApp(0)
} catch as err {
    if IsObject(canvas)
        canvas.Dispose()
    GdipStop(&token)
    FileAppend("FAIL " err.Message " at line " err.Line "`n", "*")
    ExitApp(1)
}
Check(ok, name) {
    global checks
    if !ok
        throw Error(name)
    checks += 1
}
