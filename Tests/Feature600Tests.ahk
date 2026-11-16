#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\ActivityData.ahk
#Include ..\Lib\ActivityOptions.ahk
#Include ..\Lib\AltTab.ahk
#Include ..\Lib\Effects.ahk
#Include ..\Lib\Sonion.ahk
#Include ..\Lib\SonionScream.ahk
#Include ..\Lib\SonionGlitch.ahk
#Include ..\Lib\Draw.ahk
#Include ..\Lib\GlitchWheel.ahk
#Include ..\Lib\HorrorFlash.ahk
#Include ..\Lib\GameplayInput.ahk
#Include ..\Lib\Sensitivity.ahk
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
    TestFeature603(p1, p2)
    TestSequencePicker()
    Check(DirectArguments(5, 'C:\Meso Control\Meso_Wheel_Trigger.vbs') = '//B //NoLogo "C:\Meso Control\Meso_Wheel_Trigger.vbs" --direct 5 %userName%', "Copied Streamer.bot arguments preserve the quoted path")
    state := Line("meta", 1, 1, 2000) Line("status", 0, 0, 0) Line("wheel", "idle", "", 0, 0, "", 0, 0)
    state .= Line("slots", "idle", "", 0, 0, 0, 0, 0, "", "", "", "") Line("timer", "idle", 0, 0, 0)
    state .= Line("active", "Screen Shuffle", 3000, "Active", 2000) Line("active", "Lights Out", 4000, "Active", 2000)
    state .= Line("bonus", "Tunnel Vision", 2000) Line("glitch", 2500, 9500)
    parsed := ParseOutputState(state)
    Check(parsed.Bonus = "Tunnel Vision" && parsed.GlitchEnd = 9500, "OBS receives the bonus and glitch animation")
    Check(OutputPanelKeys(parsed, 2600)[1] != OutputPanelKeys(parsed, 2650)[1], "Glitch animation refreshes the wheel panel")
    Check(parsed.ActiveItems.Length = 2, "Both effects reach the OBS state")
    Check(OutputPanelKeys(parsed, 3100)[3] != "idle", "Second OBS effect outlasts first")
    FileAppend("PASS " checks " Meso Control 6.0.5 checks`n", "*")
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
    random := {Action: "Change Mouse Sensitivity", Vary: true, Value: 1}
    Check(SensitivityMultiplier(random, true) = 3.0, "Random high is 3x")
    Check(SensitivityMultiplier(random, false) = 0.25, "Random low is 0.25x")
    Check(SensitivityMultiplier({Action: "Change Mouse Sensitivity", Vary: false, Value: 1.5}) = 1.5, "Fixed sensitivity preserves 1.5x")
    Check(SensitivityMultiplier({Action: "Change Mouse Sensitivity", Vary: false, Value: 0.5}) = 0.5, "Fixed sensitivity preserves 0.5x")
    Check(PunishmentValueRange("Lights Out").Max = 240 && PunishmentValueRange("Lights Out").Min = 100, "Lights Out shows its previous range")
    Check(PunishmentValueRange("Tunnel Vision").Min = 1.1 && PunishmentValueRange("Tunnel Vision").Max = 8, "Tunnel Vision supports zoom beyond 4x")
    Check(FixedPunishmentValue({Action: "Wide View", Value: 3}) = 0.25, "Wide View uses its supported upper limit")
    Check(FixedPunishmentValue({Action: "Change Mouse Sensitivity", Value: 10}) = 5, "Manual sensitivity uses its supported upper limit")
    visual := FileRead(A_ScriptDir "\..\Meso_Visual_Effect.ahk", "UTF-8")
    Check(InStr(visual, 'MagShowSystemCursor", "Int", false') && InStr(visual, 'MagShowSystemCursor", "Int", true'), "Wide View hides and restores the system cursor")
    TestInputHooks()
}

TestFeature603(p1, p2) {
    global RuntimeDir, Rounds, Sonion, SettingsGui, SettingsLV, DirectSlotControls, ConfigFile, ActiveEffects, EditorBindHook, SharedBindHook
    tunnel := {Action: "Tunnel Vision", Value: 9}
    Check(VisualStrength(tunnel, 1) = 3 && VisualStrength(tunnel, 3) > 4 && VisualStrength(tunnel, 20) = 8, "Tunnel Vision starts at 3x and progresses up to 8x")
    Check(VisualStrength({Action: "Wide View", Value: 1}, 1) = 0.25 && VisualStrength({Action: "Wide View", Value: 0.01}, 20) = 0.05, "Wide View starts at 0.25x and ends at 0.05x")
    Check(VisualStrength({Action: "Drunk Vision", Value: 0}, 0) = 3 && VisualStrength({Action: "Drunk Vision", Value: 9}, 0) = 5, "Drunk Vision sway defaults to 3 and caps at 5")
    alt := {Action: "Alt+Enter", Value: 0}
    Check(FixedPunishmentValue(alt) = 1, "Alt+Enter defaults to one second between presses")
    alt.Value := 0.8
    Check(FixedPunishmentValue(alt) = 0.8, "Alt+Enter accepts a custom interval")
    loop IniRead(ConfigFile, "Punishments", "Count", "0") + 0 {
        section := "P" A_Index
        if IniRead(ConfigFile, section, "Action", "") = "Alt+Enter" {
            Check(IniRead(ConfigFile, section, "Duration") = "5", "New Alt+Enter default is 5 seconds")
            IniWrite("3.0", ConfigFile, section, "Duration")
            IniWrite("0.0", ConfigFile, section, "Value")
            IniDelete(ConfigFile, "Meta", "Feature603")
            LoadAndMigratePunishments()
            Check(Float(IniRead(ConfigFile, section, "Duration")) = 5, "Old Alt+Enter default upgrades to 5 seconds")
            IniWrite("3", ConfigFile, section, "Duration")
            LoadAndMigratePunishments()
            Check(IniRead(ConfigFile, section, "Duration") = "3", "A later custom duration is preserved")
            break
        }
    }
    EditorBindHook := 0, SharedBindHook := 0
    SettingsGui := Gui()
    SettingsLV := 0
    DirectSlotControls := [SettingsGui.AddDropDownList("w150")]
    RefreshDirectSlots()
    CloseSettings()
    RefreshDirectSlots()
    Check(!DirectSlotControls.Length && !GuiHwndSafe(SettingsGui), "Profile refresh after Settings closes ignores destroyed dropdowns")
    Rounds := LoadRoundSettings()
    Check(!Rounds.BonusPunishment, "Bonus punishment defaults off")
    Rounds.BonusPunishment := true
    job := {Id: "bonus-test", Preview: true, Spins: 1}
    PrepareSpin(job, [p1, p2], 1000)
    LandSpin(job, 9000)
    Check(job.HasOwnProp("Bonus") && job.Bonus.Name != job.P.Name && ActiveEffects.Length = 2, "A bonus landing adds one distinct punishment")
    Check(ActiveEffects[1].Start = ActiveEffects[2].Start, "Both bonus effects start together")
    CancelEffects()
    ScheduleSonion(1, 2000)
    Check(Sonion.Next = 12000 && Sonion.Phase = "cue" && Sonion.Replies = 0
        && SonionQuestion() == "When the onion rings... Do You Answer?", "Sonion schedules the exact chat text and ten-second lead")
    neutral := ChatHorrorChoices("")
    afterTung := ChatHorrorChoices(TungChatPhrase())
    afterSonion := ChatHorrorChoices(SonionQuestion())
    Check(neutral[1].Weight = neutral[2].Weight && afterTung[1].Weight < afterTung[2].Weight
        && afterSonion[1].Weight > afterSonion[2].Weight, "Tung and Sonion share neutral odds and favor the other after a roll")
    ScheduleSonion(2, 3000)
    Check(Sonion.Target = 1, "A pending Sonion call cannot be replaced")
    StopSonion()
    Check(!IsObject(Sonion), "Sonion cleans up when cancelled")
    wave := FileOpen(SonionMediaFile(RuntimeDir, "321.wav"), "r")
    try Check(wave.Read(4) = "RIFF" && wave.Length > 90000, "The packaged 321.wav decodes as WAVE")
    finally wave.Close()
    Check(FileGetSize(SonionMediaFile(RuntimeDir, "glitch.mp3")) > 20000, "The packaged glitch track decodes")
    Check(FileExist(A_ScriptDir "\..\Ui\sonion_jeff.png") != "", "Jeff image is packaged")
    TestSonionWindows()
}

TestSonionWindows() {
    global Sonion, InputLockOwners, WheelDisplayMode
    game := Gui(, "Meso Sonion test")
    game.Show("w800 h600")
    try {
        now := NowMs()
        ScheduleSonion(game.Hwnd, now)
        ShowSonionPhone(Sonion, now)
        Check(Sonion.CallerImage.Hwnd && DllCall("user32\GetWindowLongPtrW", "Ptr", Sonion.CallerImage.Hwnd, "Int", -16, "Ptr"), "The phone loads its bundled caller image")
        Check(Sonion.Phase = "ringing" && GuiHwndSafe(Sonion.Dim) && GuiHwndSafe(Sonion.Panel), "Incoming call opens a dimmer and phone")
        Check(ControlGetText("Button1", "ahk_id " Sonion.Panel.Hwnd) = "Decline" && ControlGetText("Button2", "ahk_id " Sonion.Panel.Hwnd) = "Answer", "Both phone choices are clickable buttons")
        WinActivate("ahk_id " game.Hwnd)
        if WinWaitActive("ahk_id " game.Hwnd,, 1) {
            ShakeSonionPhone(Sonion, now + 100)
            AnswerSonion(false)
            Check(Sonion.Phase = "declined" && Sonion.Next >= now + 5000 && !GuiHwndSafe(Sonion.Panel), "Decline closes the phone and defers the glitch for five seconds")
        }
        StopSonion()
        ScheduleSonion(game.Hwnd, now)
        Sonion.Start := now
        WheelDisplayMode := "reel"
        ShowSonionGlitch(Sonion, now)
        Check(GuiHwndSafe(Sonion.Panel) && Sonion.GlitchMode = "reel" && Sonion.Next = now + 33, "The glitch overlay renders a reel frame in reel mode")
        WheelDisplayMode := "wheel"
        CloseSonionWindows(Sonion)
        ShowSonionScare(Sonion, A_ScriptDir "\..\Ui\sonion_jeff.png")
        Check(GuiHwndSafe(Sonion.Panel), "Jeff overlay opens with the packaged image")
    } finally {
        StopSonion()
        game.Destroy()
    }
}

TestSequencePicker() {
    global Sonion, ActiveEffects, SequenceTestHorrorDue, SequenceTestOutputOpened, HorrorEvents, OutputPid
    global TickPathEdit, LandPathEdit, TickSlider, LandSlider, SlotTickPathEdit, SlotLandPathEdit, SlotTickSlider, SlotLandSlider
    global SequenceSlider, TtsSlider, AnnouncementSlider, SpeakCheck, ViewerCheck
    settings := Gui(, "Meso sequence picker test")
    BuildSequenceSettings(settings)
    settings.Show("w824 h362")
    selector := settings["SequenceChoice"], notice := settings["SequenceNotice"]
    try {
        TickPathEdit := LandPathEdit := SlotTickPathEdit := SlotLandPathEdit := {Value: ""}
        TickSlider := LandSlider := SlotTickSlider := SlotLandSlider := SequenceSlider := TtsSlider := AnnouncementSlider := {Value: 75}
        SpeakCheck := ViewerCheck := {Value: 0}
        SequenceTestHorrorDue := 0, SequenceTestOutputOpened := false
        HorrorEvents := [], OutputPid := 0
        Check(selector.Text = "He Is Coming", "The Sequence tab selects the original sequence by default")
        ClickSequenceButton("Test sequence", settings.Hwnd, (*) => SequenceTestHorrorDue > 0)
        Check(SequenceTestOutputOpened && SequenceTestHorrorDue > NowMs(), "The original sequence test enables output and schedules playback. Status: " notice.Text)
        selector.Choose(2)
        Check(selector.Text = "Sonion Call", "The Sequence tab offers Sonion Call")
        ClickSequenceButton("Test sequence", settings.Hwnd, (*) => IsObject(Sonion))
        Check(IsObject(Sonion) && Sonion.Preview && GuiHwndSafe(Sonion.Stage), "Testing Sonion opens the stand-alone preview. Status: " notice.Text)
        call := Sonion
        Check(call.Transcript.Text = SonionQuestion() && call.Replies = 0, "Preview starts with the Sonion chat prompt")
        clipboard := DllCall("user32\GetClipboardSequenceNumber", "UInt")
        AdvanceSonion(call.Next - 1)
        Check(call.Phase = "cue" && !IsObject(call.Flash), "Preview waits before flashing")
        AdvanceSonion(call.Next)
        Check(call.Phase = "red" && GuiHwndSafe(call.Flash.Tint) && call.Flash.Main.Text = "DO YOU ANSWER", "Sonion uses Tung's red overlay for DO YOU ANSWER")
        flash := call.Flash
        AdvanceSonion(call.FlashStarted + 1800)
        Check(call.Phase = "reply" && !GuiHwndSafe(flash.Tint), "The red cue ends before chat replies")
        loop 3
            AdvanceSonion(call.Next)
        Check(call.Replies = 3 && call.Transcript.Text = SonionQuestion() "`nyes`nyes`nyes", "Preview shows all three replies")
        Check(!call.HasOwnProp("Clipboard") && DllCall("user32\GetClipboardSequenceNumber", "UInt") = clipboard, "Preview leaves the clipboard alone")
        AdvanceSonion(call.Next)
        ClickSequenceButton("Button2", call.Panel.Hwnd, (*) => call.Phase = "answered")
        Check(call.Phase = "answered" && GuiHwndSafe(call.Panel), "Answering the test call shows the Jeff overlay")
        ClickSequenceButton("Stop", call.Stage.Hwnd, (*) => !IsObject(Sonion))
        Check(!GuiHwndSafe(call.Stage) && !GuiHwndSafe(call.Panel), "Stop closes preview windows during the scare")
        ClickSequenceButton("Test sequence", settings.Hwnd, (*) => IsObject(Sonion))
        call := Sonion
        AdvanceSonion(call.Next)
        AdvanceSonion(call.FlashStarted + 1800)
        loop 4
            AdvanceSonion(call.Next)
        ClickSequenceButton("Button1", call.Panel.Hwnd, (*) => call.Phase = "declined")
        Check(call.Phase = "declined" && !GuiHwndSafe(call.Panel), "Declining closes the ringing preview")
        count := ActiveEffects.Length
        AdvanceSonion(call.Next - 1)
        Check(call.Phase = "declined", "The preview respects the five-second delay after decline")
        AdvanceSonion(call.Next)
        Check(call.Phase = "glitch" && GuiHwndSafe(call.Panel) && call.GlitchMode = "wheel"
            && ActiveEffects.Length = count, "Decline runs the selected wheel preview without live punishments")
        AdvanceSonion(call.Deadline)
        Check(!IsObject(Sonion) && !GuiHwndSafe(call.Stage), "The finished preview cleans up its windows")
        TestSequence(selector, notice)
        preview := Sonion.Stage
        ScheduleSonion(1, NowMs())
        Check(!Sonion.Preview && !GuiHwndSafe(preview), "A live call takes priority over the stand-alone preview")
        TestSequence(selector, notice)
        Check(!Sonion.Preview && notice.Text != "", "Testing cannot replace a live Sonion call")
    } finally {
        StopSonion()
        settings.Destroy()
        log := A_ScriptDir "\runtime\Meso.log"
        if FileExist(log) {
            for row in StrSplit(FileRead(log, "UTF-8"), "`n")
                if RegExMatch(row, "Sequence test failed|Sonion (audio|response)")
                    FileAppend(row "`n", "*")
        }
    }
}

ClickSequenceButton(control, hwnd, done) {
    button := ControlGetHwnd(control, "ahk_id " hwnd)
    id := DllCall("user32\GetDlgCtrlID", "Ptr", button, "Int")
    ; Send the button's standard click notification without requiring a focused desktop.
    DllCall("user32\PostMessageW", "Ptr", hwnd, "UInt", 0x111, "UPtr", id, "Ptr", button)
    deadline := NowMs() + 1250
    while !done() && NowMs() < deadline
        Sleep(15)
}

OpenStreamOutput(focus := true) {
    global SequenceTestOutputOpened
    SequenceTestOutputOpened := true
}

ScheduleHorror(due) {
    global SequenceTestHorrorDue
    SequenceTestHorrorDue := due
}

SaveAppSettings() {
}

EligiblePunishments() {
    return [{Name: "Tunnel Vision", Weight: 1}, {Name: "Lights Out", Weight: 1}]
}

SetText(control, value) {
    control.Text := value
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
