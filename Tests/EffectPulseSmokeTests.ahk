#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\Effects.ahk
Effect := 0
EffectOwnedKeys := Map()
Clock := ActivityClock()
DestinyOnlyMode := true
AltTabActive := false
AppGui := 0
SettingsGui := 0
RecorderGui := 0
GameInputMethod := "Event"
RuntimeDir := A_ScriptDir "\smoke-runtime"
VisualWorkerPid := 0
VisualWorkerStatusFile := ""
VisualWorkerLaunchTick := 0
VisualWorkerLastCheck := 0
VisualWorkerReady := false
LastEffectMessage := ""
ReceivedDown := 0
ReceivedUp := 0
Checks := 0
InstallKeybdHook()
SetKeyDelay(-1, -1)
TestGui := Gui("+AlwaysOnTop", "Meso input smoke test - not the game")
TestGui.AddText("w460", "This test sends Ctrl only to this test window. Do not switch to another app during the test.")
TestEdit := TestGui.AddEdit("w460 h60")
OnMessage(0x100, ObserveKeyDown)
OnMessage(0x101, ObserveKeyUp)
OnExit(Cleanup)
try {
    TestGui.Show()
    WinActivate("ahk_id " TestGui.Hwnd)
    TestEdit.Focus()
    Sleep(150)
    p := {Name: "Crouch pulse test", Action: "Spam Crouch", Keys: "LControl", Duration: 1.4, Value: 0}
    now := NowMs()
    StartEffect(p, true, now)
    AdvanceEffect(now)
    Check(Effect.Preview && Effect.SentDown = 0, "Preview sends no key-downs")
    CancelEffects()
    StartEffect(p, false, NowMs())
    Check(Effect.Phase = "waiting" && !Effect.Preview, "An excluded foreground window waits rather than becoming a preview")
    AdvanceEffect(Effect.WaitUntil)
    Check(!IsObject(Effect), "Waiting expires instead of holding the queue forever")
    StartEffect(p, false, NowMs())
    Effect.Target := TestGui.Hwnd
    Effect.Phase := "running"
    Effect.Start := NowMs()
    Effect.Next := Effect.Start
    Effect.End := Effect.Start + 1400
    while IsObject(Effect) {
        if !WinActive("ahk_id " TestGui.Hwnd)
            throw Error("The test window lost focus. No further test inputs were sent.")
        AdvanceEffect(NowMs())
        Sleep(15)
    }
    Sleep(50)
    Check(ReceivedDown >= 3, "The test window received repeated Ctrl presses")
    Check(ReceivedUp >= 3, "The test window received Ctrl releases")
    Check(EffectOwnedKeys.Count = 0, "No injected keys remain held")
    Check(!GetKeyState("LControl"), "Logical Left Control is released")
    FileAppend("PASS " Checks " smoke checks; down=" ReceivedDown "; up=" ReceivedUp "`n", "*")
    TestGui.Destroy()
    MsgBox("Passed " Checks " input smoke checks.`nThis verifies this Windows test window only, not Destiny 2.", "Meso input tests")
    ExitApp(0)
} catch as err {
    CancelEffects("Smoke test ended")
    try TestGui.Destroy()
    FileAppend("FAIL " err.Message "`n", "*")
    MsgBox(err.Message, "Meso input test")
    ExitApp(1)
}
ActionNames() {
    return ["Spam Crouch"]
}
LoadMacro(*) {
    return []
}
ObserveKeyDown(wParam, lParam, msg, hwnd) {
    global ReceivedDown, TestGui
    if GuiHwndSafe(TestGui) && DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") = GuiHwndSafe(TestGui) && ((lParam >> 16) & 255) = 0x1D
        ReceivedDown += 1
}
ObserveKeyUp(wParam, lParam, msg, hwnd) {
    global ReceivedUp, TestGui
    if GuiHwndSafe(TestGui) && DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") = GuiHwndSafe(TestGui) && ((lParam >> 16) & 255) = 0x1D
        ReceivedUp += 1
}
Check(ok, description) {
    global Checks
    if !ok
        throw Error(description)
    Checks += 1
}
Cleanup(*) {
    CancelEffects("Test exit")
}
