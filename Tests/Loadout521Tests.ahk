#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#Include ..\Lib\Effects.ahk
count := 0
try {
    CheckPos(1920, 1080, 1, 117, 386)
    CheckPos(1920, 1080, 4, 405, 386)
    CheckPos(1920, 1080, 5, 117, 482)
    CheckPos(1920, 1080, 20, 405, 770)
    CheckPos(2560, 1440, 1, 157, 515)
    CheckPos(2560, 1440, 20, 541, 1027)
    CheckPos(3440, 1440, 1, 597, 515)
    p := D2LoadoutCoordsForScreen(1920, 0, 1920, 1080, 1)
    Check(p.X = 2037 && p.Y = 386, "Second-monitor offsets")
    MsgBox(count " loadout position checks passed.", "Meso 5.2.1")
    ExitApp(0)
} catch as err {
    MsgBox(err.Message, "Meso 5.2.1 checks", "Iconx")
    ExitApp(1)
}
CheckPos(width, height, slot, x, y) {
    p := D2LoadoutCoordsForScreen(0, 0, width, height, slot)
    Check(p.X = x && p.Y = y, "Incorrect slot " slot " at " width "x" height ": " p.X "," p.Y)
}
Check(result, message) {
    global count
    count += 1
    if !result
        throw Error(message)
}
