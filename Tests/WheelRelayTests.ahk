#Requires AutoHotkey v2.0 64-bit
#Include ..\Lib\Core.ahk
#Include ..\Lib\WheelRelay.ahk

Check(condition, msg) {
    if !condition
        throw Error(msg)
}
Check(!IsObject(WheelRelayParse("")), "Empty requests rejected")
Check(!IsObject(WheelRelayParse("mesowheel2|unknown|user")), "Unknown modes rejected")
Check(!IsObject(WheelRelayParse("mesowheel2|spin|a|extra")), "Extra fields rejected")
Check(!IsObject(WheelRelayParse("mesowheel2|spin|bad name")), "Invalid viewer rejected")
Check(IsObject(WheelRelayParse("mesowheel2|spin|-")), "Manual spins supported")
Check(IsObject(WheelRelayParse("mesowheel2|spin|viewer_1")), "Viewer spins supported")
Check(IsObject(WheelRelayParse("mesowheel2|skip|viewer_1")), "Skip cooldown supported")
Check(IsObject(WheelRelayParse("mesowheel2|preview|-")), "Preview supported")
FileAppend("Wheel relay parser tests OK`n", "*", "UTF-8")
