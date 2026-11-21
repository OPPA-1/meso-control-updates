#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\Scoreboard.ahk
#Include ..\Lib\OutputState.ahk
checks := 0
try {
    Check(ScoreNumber("0") = 0, "Zero accepted")
    Check(ScoreNumber("42") = 42, "Whole score accepted")
    Check(ScoreNumber("9999") = 9999, "Highest score accepted")
    Check(ScoreNumber("0007") = 7, "Leading zeros normalized")
    Check(ScoreNumber(" 12 ") = 12, "Whitespace normalized")
    for input in ["", "-1", "10000", "1.2", "one", "2:00", "1,000"]
        Check(ScoreNumber(input, 9) = 9, "Invalid edit preserves last value")
    data := Snapshot()
    initial := ParseOutputState(data)
    Check(initial.Score[2] = "0", "Previous output snapshots remain supported")
    parsed := ParseOutputState(data Line("score", 1, 12, 5))
    Check(parsed.Score[2] = "1", "Tally enabled independently")
    Check(parsed.Score[3] + 0 = 12 && parsed.Score[4] + 0 = 5, "Scores survive publisher encoding")
    Check(parsed.Timer[2] = "prep" && parsed.Timer[3] + 0 = 61000, "Tally does not change timer")
    Check(ParseOutputState(data Line("score", 0, 12, 5)).Score[2] = "0", "Tally can be hidden without changing scores")
    Check(ParseOutputState(data Line("score", 1, 0, 0)).Score[3] + 0 = 0, "Reset propagated")
    for record in [Line("score", 1, -1, 0), Line("score", 1, 1.5, 0), Line("score", 1, "x", 0), Line("score", 1, 10000, 0), Line("score", 2, 0, 0)] {
        rejected := false
        try ParseOutputState(data record)
        catch {
            rejected := true
        }
        Check(rejected, "Bad tally record rejected")
    }
    FileAppend("PASS " checks " scoreboard checks`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message " at line " err.Line "`n", "*")
    ExitApp(1)
}
Snapshot() {
    data := Line("meta", 1, ProcessExist(), 1000)
    data .= Line("status", 0, false, false)
    data .= Line("wheel", "idle", "", 0, 0, "", 0, 0)
    data .= Line("slots", "idle", "", 0, 0, 0, 0, 0, "", "", "", "")
    data .= Line("timer", "prep", 61000, 60000, 0)
    data .= Line("active", "", 0, "", 0)
    return data
}
Check(ok, name) {
    global checks
    if !ok
        throw Error(name)
    checks += 1
}
