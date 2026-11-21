#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#Include ..\Lib\Core.ahk
#Include ..\Lib\ChatPolicy.ahk
#Include ..\Lib\ChatControl.ahk
p := MesoChatPacket("mesochat3|testid1|tester|jump")
if !IsObject(p) || p.Id != "testid1" || p.Viewer != "tester" || p.Token != "jump" || !p.IsCommand
    throw Error("Command relay packet failed")
if IsObject(MesoChatPacket("mesochat3|testid2|tester|{Win}"))
    throw Error("Unsafe relay packet accepted")
if IsObject(MesoChatPacket("mesochat3|testid3|tester|jump|other"))
    throw Error("Malformed relay packet accepted")
if !IsObject(MesoChatPacket("mesochat2|testid4|tester|!chat jump")) || !IsObject(MesoChatPacket("chat|testid5|tester|12345|!chat jump"))
    throw Error("Existing relay packet failed")
if ChatRelayAction("!chat jump") != "jump" || ChatRelayAction("jump") != "jump"
    throw Error("Legacy chat command normalization failed")
if ChatRelayAction("!chat jump shoot") != "" || ChatRelayAction("!chat {Win}") != ""
    throw Error("Unsafe legacy command accepted")
if ChatRelayResult(-2) != "WAIT|Chat Takes Control not active"
    throw Error("Relay acknowledgement mapping failed")
MsgBox("Relay packet tests passed")
ExitApp(0)
