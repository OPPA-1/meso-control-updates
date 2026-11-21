#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\Draw.ahk
#Include ..\Lib\WheelLabels.ahk
checks := 0
token := 0
canvas := 0
try {
    token := GdipStart()
    canvas := Surface(800, 800, true)
    names := ["Movement Jam", "Crouch Frenzy", "Exit Game", "Trigger Happy", "Weapon Shuffle", "Floor Shot", "Spin Cycle", "Inventory Panic", "Super Burn", "Bounce House", "Time Tax -2:00", "Send Chat", "Return to Orbit", "Lights Out", "Tunnel Vision"]
    weights := [5, 5, 1, 5, 5, 5, 5, 5, 2, 5, 5, 5, 5, 2, 2]
    total := 0.0
    for weight in weights
        total += weight
    for i, name in names {
        sweep := 360 * weights[i] / total
        fitted := FitWheelLabel(canvas, name, sweep)
        Check(fitted.Lines.Length > 0, "Default label visible: " name)
        Check(fitted.Lines.Length <= (sweep < 24 ? 1 : 2), "Line count fits slice: " name)
        for line in fitted.Lines {
            bounds := canvas.MeasureText(line, fitted.Size, true)
            Check(bounds.W <= fitted.W - 6, "Measured line inside rectangle: " name)
        }
        Check(fitted.LineH * fitted.Lines.Length <= fitted.H - 2, "Measured height inside rectangle: " name)
        Check(ATan((fitted.H / 2) / (fitted.Radius - fitted.W / 2)) * 57.2957795130823 < sweep / 2, "Text rectangle inside wedge: " name)
        Check(Sqrt((fitted.Radius + fitted.W / 2) ** 2 + (fitted.H / 2) ** 2) < 342, "Text inside outer ring: " name)
        loop 24 {
            fitted.Center := A_Index * 15
            canvas.Clear(0x00000000)
            DrawWheelLabel(canvas, fitted, 17)
            canvas.Flush()
        }
    }
    Check(WheelLabelName("Chat Confession", 30) = "SEND CHAT", "Old name display migration")
    for sweep in [0.1, 1, 3, 5, 10, 12, 20, 24, 45, 90, 180, 360] {
        box := WheelLabelBox(sweep)
        Check(box.H >= 0 && box.W > 0, "Nonnegative label bounds")
        Check(box.Radius - box.W / 2 > 100, "Hub remains clear")
        if box.H > 0
            Check(ATan((box.H / 2) / (box.Radius - box.W / 2)) * 57.2957795130823 < sweep / 2, "Slice constraint")
    }
    canvas.Dispose()
    canvas := 0
    GdipStop(&token)
    FileAppend("PASS " checks " wheel label checks`n", "*")
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
