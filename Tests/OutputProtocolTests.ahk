#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\OutputState.ahk
checks := 0
try {
    Check(StrSplit("", "|").Length = 0, "Empty fields are an empty array")
    data := Snapshot()
    Check(SubStr(data, -1) = "`n", "Publisher appends a newline")
    failed := false
    try {
        for row in StrSplit(data, "`n") {
            f := Fields(row)
            tag := f[1]
        }
    } catch IndexError {
        failed := true
    }
    Check(failed, "Previous blank-row indexing failure is reproduced")
    s := ParseOutputState(data)
    Check(s.Pid = ProcessExist(), "Controller PID retained")
    Check(s.Revision = 17 && s.PublishedAt = 1000, "Metadata parsed")
    Check(s.Wheel[2] = "spin" && s.Items.Length = 2, "Wheel parsed despite trailing newline")
    Check(s.Items[1].Name = "Movement | Jam%`nName", "Escaped labels retained")
    Check(s.Slots[2] = "spin" && s.Slots[9] = "PINNACLE OPS", "Slot state retained")
    Check(s.Pools[2][1] = "Exotic Mission", "Dependent reel pool retained")
    Check(s.Timer[2] = "prep" && s.Timer[3] + 0 = 61000, "Prep timer parsed")
    Check(s.Active[2] = "Crouch Spam", "Active punishment parsed")
    Check(s.Queue = 3 && s.Guides && !s.Paused, "Queue and guides parsed")
    Check(ParseOutputState(RTrim(data, "`n")).Wheel[2] = "spin", "No trailing newline")
    Check(ParseOutputState(data "`n`r`n`t `n").Revision = 17, "Trailing whitespace ignored")
    Check(ParseOutputState(StrReplace(data, "`n", "`r`n")).Revision = 17, "CRLF supported")
    Check(ParseOutputState(Chr(0xFEFF) data).Revision = 17, "UTF-8 BOM text supported")
    Check(ParseOutputState("`n`t `n" data).Revision = 17, "Leading blank records ignored")
    Check(ParseOutputState(StrReplace(data, "`n", "`n`n")).Revision = 17, "Blank lines between records ignored")
    Check(ParseOutputState(data Line("future", "value")).Revision = 17, "Unknown record does not corrupt known state")
    idle := Line("meta", 1, ProcessExist(), 1000)
    idle .= Line("status", 0, false, false)
    idle .= Line("wheel", "idle", "", 0, 0, "", 0, 0)
    idle .= Line("slots", "idle", "", 0, 0, 0, 0, 0, "", "", "", "")
    idle .= Line("timer", "idle", 0, 0, 0)
    idle .= Line("active", "", 0, "", 0)
    Check(ParseOutputState(idle).Wheel[2] = "idle", "Legitimate idle frame accepted")
    ExpectReject("", "Empty snapshot rejected")
    ExpectReject("`n`r`n", "Blank snapshot rejected")
    ExpectReject(Line("meta", 1), "Truncated metadata rejected")
    ExpectReject(StrReplace(data, Line("timer", "prep", 61000, 60000, 0), ""), "Missing record rejected")
    ExpectReject(StrReplace(data, "|prep|61000|", "|prep|bad|"), "Invalid timer rejected")
    ExpectReject(StrReplace(data, Line("item", "Exit Game", 1), Line("item", "Exit Game", 0)), "Zero wheel weight rejected")
    ExpectReject(StrReplace(data, "wheel|spin|", "wheel|unknown|"), "Unknown phase rejected")
    original := ParseOutputState(data)
    try original := ParseOutputState("broken")
    Check(original.Revision = 17, "Failed next parse preserves last good state")
    loop 100 {
        f := Fields(Line("pool", 2, "A|B", "C%25", "D`nE"))
        Check(f[1] = "pool" && f[3] = "A|B" && f[4] = "C%25", "Wire serialization unaffected by enclosing loop")
    }
    FileAppend("PASS " checks " output protocol checks`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " at line " err.Line "`n", "*")
    MsgBox(err.Message, "Meso output protocol test failed")
    ExitApp(1)
}

Snapshot() {
    data := Line("meta", 17, ProcessExist(), 1000)
    data .= Line("status", 3, false, true)
    data .= Line("wheel", "spin", "wheel-test", 1000, 2340, "Movement | Jam%`nName", 1, true)
    data .= Line("item", "Movement | Jam%`nName", 5)
    data .= Line("item", "Exit Game", 1)
    data .= Line("slots", "spin", "slots-test", 1000, false, 1, 0, 0, "PINNACLE OPS", "Exotic Mission", "The Whisper", "HUNTER")
    data .= Line("pool", 1, "STRIKE", "PINNACLE OPS")
    data .= Line("pool", 2, "Exotic Mission", "Onslaught", "Crawl")
    data .= Line("pool", 3, "The Whisper", "Zero Hour")
    data .= Line("pool", 4, "HUNTER", "WARLOCK", "TITAN")
    data .= Line("timer", "prep", 61000, 60000, 0)
    data .= Line("active", "Crouch Spam", 7000, "Preview only", 1000)
    return data
}

Check(ok, name) {
    global checks
    if !ok
        throw Error(name)
    checks += 1
}

ExpectReject(data, name) {
    rejected := false
    try ParseOutputState(data)
    catch {
        rejected := true
    }
    Check(rejected, name)
}
