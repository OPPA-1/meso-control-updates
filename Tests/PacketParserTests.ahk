#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#Include ..\Lib\Core.ahk
Checked := 0
try {
    request := ParseMesoPacket("chat|sample123|viewer_name|123456|!chat jump")
    Check(IsObject(request), "Chat packet parsed")
    Check(request.Mode = "chat" && request.Id = "sample123", "Mode and ID parsed")
    Check(request.Viewer = "viewer_name" && request.Message = "!chat jump", "Viewer and payload parsed")
    Check(request.Sent = 123456, "Timestamp parsed")
    skip := ParseMesoPacket("skip|id-1|viewer_name")
    Check(IsObject(skip) && skip.Mode = "skip", "Skip packet parsed")
    spin := ParseMesoPacket("spin|id-2|viewer_name")
    Check(IsObject(spin) && spin.Mode = "spin", "Spin packet parsed")
    Check(!IsObject(ParseMesoPacket("bad|id-2|viewer_name")), "Unknown mode rejected")
    Check(!IsObject(ParseMesoPacket("chat|id-1|viewer|nonsense|!play jump")), "Invalid timestamp rejected")
    Check(!IsObject(ParseMesoPacket("chat|id-1|viewer|1234")), "Missing command rejected")
    Check(!IsObject(ParseMesoPacket("spin|id-1|viewer|extra")), "Trailing packet fields rejected")
    Check(!IsObject(ParseMesoPacket("chat|id!|viewer|1234|!play jump")), "Invalid ID rejected")
    Check(!IsObject(ParseMesoPacket("chat|id-1|viewer|1234|" . Format("{:160}", "x") . "x")), "Oversized text rejected")
    MsgBox(Checked " packet parser tests passed. No game inputs were sent.", "Meso packet tests")
    ExitApp(0)
} catch as err {
    MsgBox(err.Message "`n" err.File ":" err.Line, "Meso packet tests failed", "Iconx")
    ExitApp(1)
}
Check(condition, message) {
    global Checked
    Checked += 1
    if !condition
        throw Error(message)
}
