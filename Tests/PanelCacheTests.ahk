#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\OutputState.ahk
checks := 0
try {
    state := EmptyState()
    state.Wheel := ["wheel", "spin", "test", "0", "2160", "Crouch Frenzy", "1", "1"]
    state.Items := [{Name: "Crouch Frenzy", Weight: 5}]
    a := OutputPanelKeys(state, 1000)
    b := OutputPanelKeys(state, 1016)
    Check(a[1] != b[1], "Spinning wheel changes its own panel")
    loop 4
        Check(a[A_Index + 1] = b[A_Index + 1], "Stationary panels stay cached")
    state.Revision := 999
    c := OutputPanelKeys(state, 1016)
    loop 5
        Check(b[A_Index] = c[A_Index], "Heartbeat does not invalidate the canvas")
    state.Timer := ["timer", "activity", "61000", "60000", "0"]
    a := OutputPanelKeys(state, 1016)
    b := OutputPanelKeys(state, 1032)
    Check(a[4] = b[4], "Timer is not redrawn at wheel speed")
    b := OutputPanelKeys(state, 2100)
    Check(a[4] != b[4], "Timer continues advancing independently")
    state.Score := ["score", "1", "0", "0"]
    a := OutputPanelKeys(state, 2200)
    state.Score[3] := "9"
    b := OutputPanelKeys(state, 2200)
    Check(a[5] != b[5], "Score change redraws the tally")
    loop 4
        Check(a[A_Index] = b[A_Index], "Tally update leaves other panels unchanged")
    state.Guides := true
    c := OutputPanelKeys(state, 2200)
    loop 5
        Check(b[A_Index] != c[A_Index], "Guide toggle refreshes every panel")
    state.Active := ["active", "Crouch Frenzy", "3000", "Active", "1000"]
    a := OutputPanelKeys(state, 2500)
    b := OutputPanelKeys(state, 3100)
    Check(a[3] != b[3], "Expired active card clears independently")
    FileAppend("PASS " checks " panel-cache checks`n", "*")
    MsgBox("Passed " checks " checks. No game input was sent.", "Meso cache tests")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message "`n", "*")
    MsgBox(err.Message, "Meso cache test failed")
    ExitApp(1)
}
Check(ok, message) {
    global checks
    if !ok
        throw Error(message)
    checks += 1
}
