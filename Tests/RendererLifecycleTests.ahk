#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\Draw.ahk
checks := 0
try {
    Check(ProcessExist() = DllCall("kernel32\GetCurrentProcessId", "UInt"), "Own process ID")
    Check(ProcessExist() > 0, "Process ID is valid")
    loop 30 {
        token := GdipStart()
        Check(token != 0, "Startup token")
        front := Surface(1920, 1080)
        back := Surface(1920, 1080)
        disk := Surface(800, 800, true)
        Check(front.G && front.DC && front.Bitmap, "Front allocation")
        Check(back.G && back.DC && back.Bitmap, "Back allocation")
        Check(disk.G && disk.Image, "Wheel allocation")
        disk.Clear(0x00000000)
        disk.Pie(58, 58, 684, 684, 0, 180, 0xFF682BB2)
        disk.Flush()
        loop 6 {
            back.Clear()
            back.RotateImage(disk.Image, A_Index * 35, 400, 400, 800, 800)
            back.RoundRect(823, 680, 1074, 318, 26, 0xFF160D21, 0xFF8151B4, 2)
            back.Text("PREP TIME", 860, 702, 1000, 53, 32, 0xFFE6CDFF, true)
            back.Text("00:59", 865, 764, 990, 139, 92, 0xFFF9F5FF, true)
            back.Flush()
            temporary := front
            front := back
            back := temporary
        }
        disk.Dispose()
        disk.Dispose()
        front.Dispose()
        front.Dispose()
        back.Dispose()
        back.Dispose()
        Check(!front.G && !front.DC && !front.Bitmap, "Front released")
        Check(!back.G && !back.DC && !back.Bitmap, "Back released")
        Check(!disk.G && !disk.Image, "Wheel released")
        Check(front.Fonts.Count = 0 && front.Pens.Count = 0 && front.Brushes.Count = 0, "Caches released")
        GdipStop(&token)
        GdipStop(&token)
        Check(token = 0, "Token cleared and shutdown idempotent")
    }
    FileAppend("PASS " checks " renderer lifecycle checks`n", "*")
    MsgBox("Passed " checks " renderer lifecycle checks. No game input was sent.", "Meso renderer tests")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message "`n", "*")
    MsgBox(err.Message, "Meso renderer test failed")
    ExitApp(1)
}
Check(ok, name) {
    global checks
    if !ok
        throw Error(name)
    checks += 1
}
