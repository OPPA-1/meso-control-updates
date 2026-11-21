#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#Include ..\Lib\Core.ahk
TestGui := Gui("+AlwaysOnTop -MaximizeBox", "Meso Visual Effects Test")
TestGui.BackColor := "3566AA"
TestGui.SetFont("s26 Bold cFFFFFF", "Segoe UI")
TestGui.AddText("x70 y125 w800 h80 Center", "MESO VISUAL EFFECTS TEST")
TestGui.SetFont("s17 cFFFFFF", "Segoe UI")
TestGui.AddText("x110 y260 w700 h160 Center", "Tests five visual effects. Keep this window focused. No Destiny input is sent.")
TestGui.SetFont("s24 Bold cFFE68F", "Segoe UI")
TestPulse := TestGui.AddText("x85 y440 w750 h64 Center", "LIVE MOTION 0  >>>")
SetTimer(UpdateMotionTest, 100)
TestGui.OnEvent("Close", (*) => ExitApp())
TestGui.Show("w920 h600 Center")
SetTimer(TestVisualEffects, -300)

UpdateMotionTest(*) {
    global TestPulse
    TestPulse.Text := "LIVE MOTION " A_TickCount "  >>>"
}

TestVisualEffects(*) {
    global TestGui
    results := []
    results.Push(RunVisualCheck("dark", 210))
    results.Push(RunVisualCheck("zoom", 2.0))
    results.Push(RunVisualCheck("puzzle", 1.0))
    results.Push(RunVisualCheck("mirror", 1.0))
    results.Push(RunVisualCheck("drunk", 1.0))
    detail := "Lights Out: " results[1] "`nTunnel Vision: " results[2] "`nScreen Shuffle: " results[3] "`nInvert Screen: " results[4] "`nDrunk Vision: " results[5]
    MsgBox(detail, "Meso Visual Effects Test")
}

RunVisualCheck(mode, amount) {
    global TestGui
    WinActivate("ahk_id " TestGui.Hwnd)
    root := A_ScriptDir "\.."
    state := A_Temp "\meso-visual-test-" A_TickCount "-" Random(1000, 9999) ".state"
    cmd := Chr(34) A_AhkPath Chr(34) " " Chr(34) root "\Meso_Visual_Effect.ahk" Chr(34) " " mode " " TestGui.Hwnd " 4500 " amount " " ProcessExist() " " Chr(34) state Chr(34)
    try Run(cmd, root, "", &pid)
    catch as err
        return "LAUNCH FAILED: " err.Message
    started := NowMs()
    outcome := "TIMED OUT waiting for visual worker"
    while NowMs() - started < 3200 {
        try {
            parts := Fields(Trim(FileRead(state, "UTF-8"), "`r`n"))
            if parts.Length >= 4 {
                if parts[3] = "ready" {
                    outcome := "VISIBLE (worker ready)"
                    break
                }
                if parts[3] = "error" {
                    outcome := "FAILED: " parts[4]
                    break
                }
            }
        }
        if !ProcessExist(pid) {
            outcome := "FAILED: worker exited before ready"
            break
        }
        Sleep(80)
    }
    if InStr(outcome, "VISIBLE")
        Sleep(1200)
    try FileAppend("cancel", state ".cancel", "UTF-8")
    Sleep(350)
    try FileDelete(state)
    try FileDelete(state ".cancel")
    return outcome
}
