#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\ActivityData.ahk
#Include ..\Lib\ActivityOptions.ahk
#Include ..\Lib\AltTab.ahk
#Include ..\Lib\Effects.ahk
#Include ..\Lib\GameplayInput.ahk
#Include ..\Lib\MacroCodec.ahk
#Include ..\Lib\Recorder.ahk
#Include ..\Lib\Editor.ahk
#Include ..\Lib\Scoreboard.ahk
#Include ..\Lib\RoundModel.ahk
#Include ..\Lib\Rounds.ahk
#Include ..\Lib\ChatPolicy.ahk
#Include ..\Lib\ChatControl.ahk
#Include ..\Lib\WheelRelay.ahk
#Include ..\Lib\DirectRewards.ahk
#Include ..\Lib\SharedKeys.ahk
#Include ..\Lib\PunishmentOptions.ahk
#Include ..\Lib\Updates.ahk
#Include ..\Lib\OutputState.ahk

checks := 0
RuntimeDir := A_Temp "\Meso600-" NewId()
DirCreate(RuntimeDir)
ConfigFile := RuntimeDir "\test.ini"
ProfilesDir := RuntimeDir "\Profiles"
CurrentPunishmentProfile := "Default"
ActiveEffects := []
Effect := 0
EffectOwnedKeys := Map()
GameKeyOwners := Map()
ChatEffect := 0
InputLockOwners := Map()
LastEffectMessage := ""
GameInputMethod := "Event"
Clock := ActivityClock()
Punishments := []
CurrentPunishmentProfile := "Default"
try {
    FileCopy(A_ScriptDir "\..\Defaults\Meso_Chaos.ini", ConfigFile)
    IniWrite("XButton2", ConfigFile, "ChatBindings", "grenade")
    IniWrite("Numpad1", ConfigFile, "P1", "Keys")
    IniWrite("240", ConfigFile, "P14", "Value")
    chat := LoadChatSettings()
    Chat := chat
    Punishments := LoadAndMigratePunishments()
    count := punishments.Length
    Check(LoadAndMigratePunishments().Length = count, "Migration adds the new punishments once")
    for name in ["Turn M&K Off", "Alt+Enter", "Wide View", "Change Mouse Sensitivity"] {
        matches := 0
        for p in punishments
            if p.Action = name
                matches += 1
        Check(matches = 1, name " migrates once")
    }
    Check(IniRead(ConfigFile, "P1", "Keys") = "Numpad1", "Legacy per-effect key survives migration")
    Check(Float(IniRead(ConfigFile, "P14", "Value")) = 240, "Legacy effect value survives migration")
    SharedKeys := LoadSharedKeys(ConfigFile, punishments, chat)
    Check(SharedKeys.Keys.Count = 21 && SharedKeys.Keys["grenade"] = "XButton2", "All shared fields and saved mouse bind")
    IniWrite("XButton1", ConfigFile, "SharedKeybinds", "grenade")
    SharedKeys := LoadSharedKeys(ConfigFile, punishments, chat)
    ApplySharedChatKeys()
    Check(chat.Bindings["grenade"] = "XButton1", "Shared key reaches chat")
    for i, key in ["Up", "Left", "Down", "Right"]
        Check(chat.Bindings["emote" i] = key, "Fixed emote " i)
    Check(chat.Bindings.Has("class") && ChatAlias("air-move") = "airmove", "New chat actions")
    Check(WheelRelayParse("mesowheel2|direct5|meso").Mode = "direct5", "Direct reward relay")
    Check(!IsObject(WheelRelayParse("mesowheel2|direct6|meso")), "Invalid direct slot")
    Check(WheelRelayParse("mesowheel2|double|meso").Mode = "double", "Double reward relay")
    queue := SpinQueue()
    Check(queue.Accept("double", false, 1000, "meso", true, 2) = 1 && queue.Count() = 1, "Double redeem is one queued job")
    Check(queue.Take(1000).Spins = 2, "Double job keeps its spin count")
    rounds := RoundCycle("batch", 1, 2)
    rounds.Tick(1000, true)
    rounds.Complete(1500)
    Check(!DirectRewardReady(rounds, false, 3499), "Direct reward waits during cooldown")
    Check(DirectRewardReady(rounds, true, 3499) && DirectRewardReady(rounds, false, 3500), "Direct bypass and end of cooldown")
    dark := {Name: "Lights Out", Action: "Lights Out", Keys: "", Duration: 0.5, Value: 240}
    wide := {Name: "Wide View", Action: "Wide View", Keys: "", Duration: 1, Value: 0.75}
    Check(VisualStrength(dark, 0) = 240 && VisualStrength(dark, 1) < VisualStrength(dark, 2), "Fixed and progressive darkness")
    Check(VisualStrength(wide, 1) > VisualStrength(wide, 2), "Progressive zoom-out")
    StartEffect(dark, true, 2000, "double")
    StartEffect(wide, true, 2000, "double")
    AdvanceEffect(2500)
    Check(ActiveEffects.Length = 1 && ActiveEffects[1].P.Name = "Wide View" && HasEffects("double"), "First effect can expire independently")
    CancelEffects()
    Check(!HasEffects() && !InputLockOwners.Count && !GameKeyOwners.Count, "Cancel leaves no owned inputs")
    job := {Id: "paired", Preview: true, Spins: 2, Pool: []}
    p1 := dark.Clone(), p1.Weight := 1
    p2 := wide.Clone(), p2.Weight := 1
    PrepareSpin(job, [p1, p2], 4000)
    first := job.P.Name
    LandSpin(job, 12000)
    Check(job.FirstResult.Name = first && job.DisplayId = "paired#second" && !HasEffects(), "First landing starts spin two without applying an effect")
    LandSpin(job, 20000)
    Check(ActiveEffects.Length = 2 && ActiveEffects[1].Start = ActiveEffects[2].Start && HasEffects("paired"), "Both effects start on the second landing")
    CancelEffects()
    TestVbsRewards()
    TestGameplayInput()
    Check(DirectArguments(5, 'C:\Meso Control\Meso_Wheel_Trigger.vbs') = '//B //NoLogo "C:\Meso Control\Meso_Wheel_Trigger.vbs" --direct 5 %userName%', "Copied Streamer.bot arguments preserve the quoted path")
    state := Line("meta", 1, 1, 2000) Line("status", 0, 0, 0) Line("wheel", "idle", "", 0, 0, "", 0, 0)
    state .= Line("slots", "idle", "", 0, 0, 0, 0, 0, "", "", "", "") Line("timer", "idle", 0, 0, 0)
    state .= Line("active", "Screen Shuffle", 3000, "Active", 2000) Line("active", "Lights Out", 4000, "Active", 2000)
    parsed := ParseOutputState(state)
    Check(parsed.ActiveItems.Length = 2, "Both effects reach the OBS state")
    Check(OutputPanelKeys(parsed, 3100)[3] != "idle", "Second OBS effect outlasts first")
    FileAppend("PASS " checks " Meso Control 6.0.0 checks`n", "*")
} catch as err {
    FileAppend("FAIL: " err.Message " (" err.File ":" err.Line ")`n", "*")
    ExitApp(1)
} finally {
    try DirDelete(RuntimeDir, true)
}
ExitApp(0)

Check(result, description) {
    global checks
    if !result
        throw Error(description)
    checks += 1
}

PublishState(*) {
}

TestVbsRewards() {
    global RuntimeDir
    previousData := EnvGet("LOCALAPPDATA")
    EnvSet("LOCALAPPDATA", RuntimeDir)
    inbox := WheelRelayBasePath() "\Inbox"
    replies := WheelRelayBasePath() "\Replies"
    DirCreate(inbox)
    DirCreate(replies)
    try {
        for test in [["--direct 5 meso", "direct5"], ["--double meso", "double"]] {
            host := A_WinDir "\System32\cscript.exe"
            trigger := A_ScriptDir "\..\Meso_Wheel_Trigger.vbs"
            process := ComObject("WScript.Shell").Exec('"' host '" //nologo "' trigger '" ' test[1])
            packet := ""
            deadline := NowMs() + 2500
            while NowMs() < deadline && packet = "" {
                loop files inbox "\*.req", "F" {
                    path := A_LoopFileFullPath
                    packet := FileRead(path, "UTF-8")
                    FileDelete(path)
                    id := RegExReplace(A_LoopFileName, "\.req$", "")
                    WriteAtomic(replies "\" id ".ack", "QUEUED|Test")
                    break
                }
                if packet = ""
                    Sleep(15)
            }
            while process.Status = 0 && NowMs() < deadline
                Sleep(15)
            request := WheelRelayParse(packet)
            Check(IsObject(request) && request.Mode = test[2] && request.Viewer = "meso", "VBS sends " test[2])
            Check(process.Status != 0 && process.ExitCode = 0, "VBS reads acknowledgement for " test[2])
        }
    } finally EnvSet("LOCALAPPDATA", previousData)
}

TestGameplayInput() {
    high := 0.0, low := 0.0, reverse := 0.0
    Check(RawMouseCorrection(5, 3.0, &high) = 10, "3x adds two times the raw delta")
    sum := 0
    loop 4
        sum += RawMouseCorrection(1, 0.25, &low)
    Check(sum = -3 && low = 0, "0.25x keeps fractional motion")
    Check(RawMouseCorrection(-8, 0.5, &reverse) = 4, "Low sensitivity corrects negative motion")
    Check(SensitivityMultiplier({Action: "Change Mouse Sensitivity", Vary: false, Value: 1.5}) = 1.5, "Fixed sensitivity preserves 1.5x")
    Check(SensitivityMultiplier({Action: "Change Mouse Sensitivity", Vary: false, Value: 0.5}) = 0.5, "Fixed sensitivity preserves 0.5x")
    TestInputHooks()
}

TestInputHooks() {
    global GameplayLock
    target := DllCall("user32\GetForegroundWindow", "Ptr")
    if !target
        return
    GameplayLock := {Target: target, Modifiers: Map(0xA2, false, 0xA3, false, 0xA4, false, 0xA5, false)}
    try {
        kb := Buffer(24, 0), mouse := Buffer(32, 0)
        NumPut("UInt", 0x57, kb)
        Check(GameplayKeyboardHook(0, 0x100, kb) = 1, "Focused lock swallows physical keyboard input")
        Check(GameplayMouseHook(0, 0x200, mouse) = 1, "Focused lock swallows physical mouse input")
        NumPut("UInt", 0x10, kb, 8)
        NumPut("UInt", 1, mouse, 12)
        Check(GameplayKeyboardHook(0, 0x100, kb) != 1, "Loadout keyboard injection is allowed")
        Check(GameplayMouseHook(0, 0x201, mouse) != 1, "Loadout mouse injection is allowed")
    } finally GameplayLock := 0
}
