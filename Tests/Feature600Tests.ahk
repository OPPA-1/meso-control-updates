#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\ActivityData.ahk
#Include ..\Lib\ActivityOptions.ahk
#Include ..\Lib\AltTab.ahk
#Include ..\Lib\Effects.ahk
#Include ..\Lib\AltEnter.ahk
#Include ..\Lib\StreamScares.ahk
#Include ..\Lib\Sonion.ahk
#Include ..\Lib\SonionScream.ahk
#Include ..\Lib\SonionGlitch.ahk
#Include ..\Lib\SonionRingtone.ahk
#Include ..\Lib\ScareAssets.ahk
#Include ..\Lib\ScareMedia.ahk
#Include ..\Lib\ScareAudio1.ahk
#Include ..\Lib\ScareAudio2.ahk
#Include ..\Lib\Draw.ahk
#Include ..\Lib\GlitchWheel.ahk
#Include ..\Lib\HorrorFlash.ahk
#Include ..\Lib\GameplayInput.ahk
#Include ..\Lib\Sensitivity.ahk
#Include ..\Lib\SlidingPuzzle.ahk
#Include ..\Lib\PuzzleModel.ahk
#Include ..\Lib\InteractionPointer.ahk
#Include ..\Lib\ScareLocalAudio.ahk
#Include ..\Lib\EffectLabels.ahk
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
    for name in ["Sliding Puzzle", "Turn Keyboard Off", "Alt+Enter", "Wide View", "Change Mouse Sensitivity", "Jumpscare"] {
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
    TestSendChatPicker()
    TestScareQueue610()
    TestFeature611()
    TestFeature612()
    TestUpdateSession612()
    Check(DirectArguments(5, 'C:\Meso Control\Meso_Wheel_Trigger.vbs') = '//B //NoLogo "C:\Meso Control\Meso_Wheel_Trigger.vbs" --direct 5 %userName%', "Copied Streamer.bot arguments preserve the quoted path")
    state := Line("meta", 1, 1, 2000) Line("status", 0, 0, 0) Line("wheel", "idle", "", 0, 0, "", 0, 0)
    state .= Line("slots", "idle", "", 0, 0, 0, 0, 0, "", "", "", "") Line("timer", "idle", 0, 0, 0)
    state .= Line("active", "Screen Shuffle", 3000, "Active", 2000, 1) Line("active", "Lights Out", 4000, "Active", 2000)
    state .= Line("bonus", "Tunnel Vision", 2000) Line("glitch", 2500, 9500)
    state .= Line("sound", "test-call", "ringring.mp3", 1, 0) Line("scare", "scare1", 2600, 3160)
    parsed := ParseOutputState(state)
    Check(parsed.Bonus = "Tunnel Vision" && parsed.GlitchEnd = 9500, "OBS receives the bonus and glitch animation")
    Check(OutputPanelKeys(parsed, 2600)[1] != OutputPanelKeys(parsed, 2650)[1], "Glitch animation refreshes the wheel panel")
    Check(parsed.ActiveItems.Length = 2 && parsed.ActiveItems[1][6] = "1", "Both effects and the bonus badge reach the OBS state")
    Check(parsed.Sounds.Length = 1 && parsed.Sounds[1].Repeat && parsed.Scare[2] = "scare1", "Legacy scare metadata parses without changing the independent audio events")
    Check(OutputPanelKeys(parsed, 3100)[3] != "idle", "Second OBS effect outlasts first")
    FileAppend("PASS " checks " Meso Control feature checks`n", "*")
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
    Check(ActiveEffects[1].P.BonusPair && ActiveEffects[2].P.BonusPair, "Both bonus effects retain their active overlay badges")
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
    TestSonionRingtone()
    TestSonionWindows()
}

TestSonionRingtone() {
    global RuntimeDir
    ringtone := SonionUiAsset("ringring.mp3")
    if FileExist(ringtone) {
        Check(SonionMediaFile(RuntimeDir, "ringring.mp3") = ringtone, "The installed custom ringtone is used as-is")
        return
    }
    bundled := SonionMediaFile(RuntimeDir, "ringring.mp3")
    Check(FileExist(bundled) && FileGetSize(bundled) > 0, "The distributed ringtone decodes to an MP3")
    FileCopy(SonionMediaFile(RuntimeDir, "glitch.mp3"), ringtone)
    try Check(SonionMediaFile(RuntimeDir, "ringring.mp3") = ringtone, "Ringring loads from the installed Ui directory")
    finally FileDelete(ringtone)
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
        region := DllCall("gdi32\CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
        try Check(DllCall("user32\GetWindowRgn", "Ptr", Sonion.Panel.Hwnd, "Ptr", region) > 0
            && !DllCall("gdi32\PtInRegion", "Ptr", region, "Int", 0, "Int", 0)
            && DllCall("gdi32\PtInRegion", "Ptr", region, "Int", 153, "Int", 253), "The restored handset has rounded corners instead of a rectangular window")
        finally DllCall("gdi32\DeleteObject", "Ptr", region)
        Check(Sonion.Phase = "ringing" && GuiHwndSafe(Sonion.Dim) && GuiHwndSafe(Sonion.Panel), "Incoming call opens a dimmer and phone")
        Check(ControlGetText("Button1", "ahk_id " Sonion.Panel.Hwnd) = "Decline" && ControlGetText("Button2", "ahk_id " Sonion.Panel.Hwnd) = "Answer", "Both phone choices are clickable buttons")
        WinActivate("ahk_id " game.Hwnd)
        if WinWaitActive("ahk_id " game.Hwnd,, 1) {
            ShakeSonionPhone(Sonion, now + 100)
            AnswerSonion(false)
            Check(Sonion.Phase = "ringing" && Sonion.Phones.Length = 2, "Decline adds a second phone while the first stays ringing")
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

TestScareQueue610() {
    global ScareQueue, ActiveScare, SpecialSounds
    EnsureScareState()
    ScareQueue := []
    event := QueueRandomScare(1, 1000)
    Check(event.Due >= 2000 && event.Due <= 61000, "First random jumpscare is queued within a minute")
    previous := event.Due
    loop 40 {
        event := QueueRandomScare(1, 1000)
        Check(event.Due - previous >= 2000 && event.Due - previous <= 30000, "Queued scares are spaced two to thirty seconds apart")
        previous := event.Due
    }
    Check(!IsObject(ActiveScare), "Queued scares do not display or play audio early")
    CancelScares()
    Check(!ScareQueue.Length, "Cancellation clears delayed jumpscares")
    id := SpecialSound("ringring.mp3", true)
    Check(InStr(SpecialAudioState(NowMs()), "ringring.mp3") && SpecialSounds.Has(id), "Ring audio is published for stream output capture")
    StopSpecialSound(id)
    Check(!SpecialSounds.Has(id), "Ringing stops when its call closes")
    id := SpecialSound("scare1", false, 1)
    SpecialAudioState(NowMs() + 2)
    Check(!SpecialSounds.Has(id), "A finished scare cannot keep playing audio")
    for name in ["scare1", "scare2"] {
        Check(FileExist(SpecialAudioPath(name)) && ScareDefinition(name).Duration <= 1000, "Faster scare visuals have corresponding packaged audio")
    }
}

TestSendChatPicker() {
    window := Gui(, "Meso Send Chat picker test")
    try {
        controls := BuildChatTestPicker(window)
        picker := controls.Picker
        Check(picker.Value = 1 && picker.Text = "Random message", "Send Chat live tests default to a random line")
        expected := [TungChatPhrase(), SonionQuestion()]
        expected.Push(OrdinaryChatMessages()*)
        saved := {Name: "Send Chat", Action: "Send Chat", Weight: 0}
        for i, phrase in expected {
            picker.Choose(i + 1)
            Check(picker.Text == phrase, "The chat picker includes the exact message: " phrase)
            test := MakeTestPunishment(saved, false, picker.Text, 42)
            Check(SendChatMessage(test) == phrase, "The selected message reaches Send Chat verbatim: " phrase)
        }
        Check(test.Weight = 1 && test.TimerGeneration = 42 && saved.Weight = 0
            && !saved.HasOwnProp("ChatTestMessage"), "A specific test uses a one-off punishment copy")
        picker.Choose(1)
        randomTest := MakeTestPunishment(saved, false, "", 42)
        Check(!randomTest.HasOwnProp("ChatTestMessage"), "Random tests use the normal message selection")
        preview := MakeTestPunishment(saved, true, SonionQuestion(), 42)
        other := MakeTestPunishment({Action: "Lights Out", Weight: 1}, false, SonionQuestion(), 42)
        Check(!preview.HasOwnProp("ChatTestMessage") && !other.HasOwnProp("ChatTestMessage"),
            "A selected line applies only to live Send Chat tests")
    } finally window.Destroy()
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
        Check(call.Phase = "red" && GuiHwndSafe(call.Flash.Tint) && call.Flash.Word = "DO YOU ANSWER", "Sonion uses Tung's red overlay for DO YOU ANSWER")
        layerStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", call.Flash.TextGui.Hwnd, "Int", -20, "Ptr")
        blankPixel := DllCall("gdi32\GetPixel", "Ptr", call.Flash.TextSurface.DC, "Int", 0, "Int", 0, "UInt")
        Check((layerStyle & 0x80000) && blankPixel = 0x00010101, "The text sits on a color-keyed layer with transparent padding")
        flash := call.Flash
        AdvanceSonion(call.FlashStarted + 1800)
        Check(call.Phase = "reply" && !GuiHwndSafe(flash.Tint), "The red cue ends before chat replies")
        loop 3
            AdvanceSonion(call.Next)
        Check(call.Replies = 3 && call.Transcript.Text = SonionQuestion() "`nyes`nyes`nyes", "Preview shows all three replies")
        Check(!call.HasOwnProp("Clipboard") && DllCall("user32\GetClipboardSequenceNumber", "UInt") = clipboard, "Preview leaves the clipboard alone")
        AdvanceSonion(call.Next)
        acceptedAt := NowMs()
        ClickSequenceButton("Button2", call.Panel.Hwnd, (*) => call.Phase = "accepted")
        Check(call.Phase = "accepted" && !call.Phones.Length && !GuiHwndSafe(call.Panel)
            && call.Next >= acceptedAt + 5000 && call.Next <= NowMs() + 20000, "Answer clears every phone and schedules the scare five to twenty seconds later")
        AdvanceSonion(call.Next)
        Check(call.Phase = "answered" && IsObject(call.Scare), "The scare appears only when its delayed time arrives")
        ClickSequenceButton("Stop", call.Stage.Hwnd, (*) => !IsObject(Sonion))
        Check(!GuiHwndSafe(call.Stage) && !GuiHwndSafe(call.Scare.Gui), "Stop closes the delayed preview scare")
        ClickSequenceButton("Test sequence", settings.Hwnd, (*) => IsObject(Sonion))
        call := Sonion
        AdvanceSonion(call.Next)
        AdvanceSonion(call.FlashStarted + 1800)
        loop 4
            AdvanceSonion(call.Next)
        AdvanceSonion(call.Next + 31000)
        Check(call.Phase = "ringing" && GuiHwndSafe(call.Panel), "The phone keeps ringing beyond the old 30-second cutoff")
        firstPhone := call.Panel
        firstSound := call.Phones[1].Sound
        ClickSequenceButton("Button1", call.Panel.Hwnd, (*) => call.Phones.Length = 2)
        Check(GuiHwndSafe(firstPhone) && call.Phones.Length = 2 && firstSound != call.Phones[2].Sound,
            "Decline preserves the original phone and gives the new phone its own ringtone")
        capacity := SonionPhoneCapacity(SonionBounds(call))
        loop capacity
            AnswerSonion(false)
        Check(call.Phones.Length > capacity && call.Phones[1].Pager.Visible, "Overflow leaves every call ringing with page navigation")
        CycleSonionPhones()
        Check(call.Page < SonionPhonePages(call.Phones) && GuiHwndSafe(firstPhone), "Earlier calls remain available after the screen fills")
        StopSonion()
        Check(!GuiHwndSafe(firstPhone) && !GuiHwndSafe(call.Panel), "Stop clears all ringing phones")
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

TestFeature611() {
    global SharedKeys, Chat, ConfigFile, Punishments, State, OutputSpecialSounds, Test611AudioCalls, PendingAltEnterRestores
    for duration in [100, 1000, 3000, 5000, 11000] {
        for gap in [100, 500, 1000, 10000] {
            plan := AltEnterPlan(duration, gap)
            Check(plan.Count >= 2 && !Mod(plan.Count, 2), "Alt+Enter always plans an even number of presses")
            Check(plan.Duration >= (plan.Count - 1) * gap + 35, "The final Alt+Enter key-up fits in its lifetime")
        }
    }
    Check(AltEnterPlan(5000, 1000).Count = 6, "Default Alt+Enter finishes six presses at one-second intervals")
    PendingAltEnterRestores := Map()
    RestoreAltEnter({AltEnterCount: 2, Target: 0})
    Check(!PendingAltEnterRestores.Count, "An even Alt+Enter run sends no extra toggle")
    RestoreAltEnter({AltEnterCount: 1, Target: 0})
    Check(PendingAltEnterRestores.Has(0), "An interrupted odd pair waits for its original game instead of typing into another window")
    AdvanceAltEnterRestores()
    Check(!PendingAltEnterRestores.Count, "Closed targets release deferred Alt+Enter restoration state")
    Check(SendChatTabDelay(0) = 190 && SendChatTabDelay(1) = 90, "Only the final Tab gets an extra 100 ms to settle")
    shared := SharedKeys.Keys["prismatic"]
    SharedKeys.Keys["prismatic"] := "XButton2"
    ApplySharedChatKeys()
    Chat.Reset()
    now := NowMs()
    Check(Chat.Bindings["prismatic"] = "XButton2" && ChatRelayAction("!chat prismatic") = "prismatic", "Prismatic follows the saved shared key through the existing chat relay")
    Check(Chat.Accept("prismatic611", "viewer", "prismatic", now, now, now - 1) = 1
        && Chat.Take(now).Key = "XButton2", "Prismatic queues the bound mouse button")
    SharedKeys.Keys["prismatic"] := shared
    ApplySharedChatKeys()
    bounds := {X: 0, Y: 0, W: 1920, H: 1080}
    phones := []
    first := SonionPhonePlacement(bounds, phones)
    Check(first.X = 807 && first.Y = 287 && first.Page = 0, "First handset is centered")
    phones.Push(first)
    loop 18 {
        placement := SonionPhonePlacement(bounds, phones)
        Check(placement.X >= 0 && placement.X + 306 <= bounds.W && placement.Y >= 0 && placement.Y + 506 <= bounds.H, "Random phones stay inside gameplay")
        for other in phones
            if other.Page = placement.Page
                Check(SonionPhoneFits(placement.X, placement.Y, other), "Random phones keep both button rows accessible")
        phones.Push(placement)
    }
    spread := Map()
    loop 48 {
        placement := SonionPhonePlacement(bounds, [first])
        spread[placement.X "|" placement.Y] := true
    }
    Check(spread.Count > 20, "Extra handsets use random positions instead of fixed grid slots")
    State := EmptyState()
    Test611AudioCalls := []
    OutputSpecialSounds := Map()
    now := NowMs()
    State.Sounds := [{Id: "scare611", Name: "scare1", Repeat: false, Until: now + 1000}]
    SyncSpecialSounds(now)
    Check(OutputSpecialSounds.Count = 1 && Audio611Contains("volume to 1000") && Audio611Contains("play mesospecial"), "Loud scare audio plays without a Stream Output visual")
    State.Sounds := []
    SyncSpecialSounds(now + 1)
    Check(!OutputSpecialSounds.Count && Audio611Contains("close mesospecial"), "Scare audio closes when gameplay ends the visual")
    source := FileRead(A_ScriptDir "\..\Meso_Stream_Output.ahk", "UTF-8")
    Check(!InStr(source, "DrawOutputScare") && !InStr(source, "OutputScareFrame"), "Stream Output has no jumpscare drawing path")
    before := OutputPanelKeys(State, now)
    State.Scare := ["scare", "scare1", now, now + 1000]
    after := OutputPanelKeys(State, now + 1)
    Check(before[1] = after[1] && before[3] = after[3], "Legacy scare records cannot animate output panels")
    loop IniRead(ConfigFile, "Punishments", "Count", "0") + 0 {
        section := "P" A_Index
        if IniRead(ConfigFile, section, "Action", "") != "Turn Keyboard Off"
            continue
        IniWrite("Turn M&K Off", ConfigFile, section, "Action")
        IniWrite("Turn M&K Off", ConfigFile, section, "Name")
        IniWrite("6.25", ConfigFile, section, "Duration")
        IniWrite("3", ConfigFile, section, "Weight")
        IniWrite("Turn M&K Off", ConfigFile, "DirectRedeems", "Slot1")
        Punishments := LoadAndMigratePunishments()
        Check(IniRead(ConfigFile, section, "Name") = "Turn Keyboard Off" && IniRead(ConfigFile, section, "Action") = "Turn Keyboard Off", "Existing M&K punishment is renamed during upgrade")
        Check(Float(IniRead(ConfigFile, section, "Duration")) = 6.25 && Float(IniRead(ConfigFile, section, "Weight")) = 3, "Rename preserves punishment settings")
        Check(IsObject(DirectPunishment(1)) && DirectPunishment(1).Name = "Turn Keyboard Off", "Direct reward slots follow the renamed punishment")
        break
    }
}

Audio611Contains(value) {
    global Test611AudioCalls
    for command in Test611AudioCalls
        if InStr(command, value)
            return true
    return false
}

Mci(command) {
    global Test611AudioCalls
    Test611AudioCalls.Push(command)
    return 0
}

MciStatus(alias, field) {
    return "playing"
}

TestFeature612() {
    global RuntimeDir, ConfigFile, HorrorEvents, Sonion, ScareQueue, ActiveScare
    Check(SlidingPuzzleGrid("bad")="3x3" && SlidingPuzzleGrid("4x4")="4x4", "Puzzle defaults to fixed 3x3")
    for n in [3,4] {
        loop 30 {
            board := PuzzleShuffle(n), seen := Map(), inversions := 0, blank := 0
            for i,tile in board {
                seen[tile] := true
                if !tile
                    blank := i
                if tile
                    for j,other in board
                        if j>i && other && tile>other
                            inversions++
            }
            Check(seen.Count=n*n && seen.Has(0) && !PuzzleSolved(board), "Puzzle has every tile and one gap")
            solvable := Mod(n,2) ? !Mod(inversions,2) : Mod(inversions+n-(blank-1)//n,2)=1
            Check(solvable, "Every 3x3 and 4x4 layout is solvable")
            for neighbor in PuzzleNeighbors(blank,n)
                Check(PuzzleAdjacent(blank,neighbor,n), "Puzzle moves only adjacent tiles")
        }
    }
    Check(!PuzzleAdjacent(3,4,3) && !PuzzleAdjacent(4,5,4), "Puzzle cannot wrap across rows")
    Check(PuzzleSolved([1,2,3,4,5,6,7,8,0]), "Solved puzzle is recognized")
    Check(!SensitivityStatusFields("").Length && !SensitivityStatusFields("ready|1").Length && !SensitivityStatusFields("ready|x|2").Length, "Empty and partial sensitivity status is safe")
    path := RuntimeDir "\pending-raw.state"
    item := {Phase:"running", SensitivityPid:ProcessExist(), SensitivityFile:path, SensitivityCheck:0, SensitivityReady:false, SensitivityStartup:NowMs()+8000, End:NowMs()+8000, Sensitivity:3.0}
    loop 5 {
        item.SensitivityCheck := 0
        WriteAtomic(path,"")
        CheckSensitivityWorker(item,NowMs())
        Check(!item.SensitivityReady,"Sensitivity tolerates empty status while its worker starts")
    }
    start := NowMs()
    WriteAtomic(path,"ready|" start "|" (start+1000))
    item.SensitivityCheck := 0
    CheckSensitivityWorker(item,start)
    Check(item.SensitivityReady && item.End=start+1000 && InStr(item.Note,"High"),"Sensitivity starts only after worker acknowledgement")
    WriteAtomic(path,"restored")
    item.SensitivityCheck := 0
    CheckSensitivityWorker(item,start+100)
    Check(item.End=start+100,"Restoration ends the sensitivity effect")
    Check(ScareDefinition("scare1").Fps=50/3 && ScareDefinition("scare1").Duration=840,"FNAF 1 uses its original frame rate and duration")
    Check(ScareDefinition("scare2").Frames=1 && FileExist(A_ScriptDir "\..\Ui\omni.png"),"Omni replaces the second visual with its linked audio slot")
    Check(!FileExist(A_ScriptDir "\..\Ui\scare2.png"),"FNAF 2 visual is removed")
    IniWrite(26,ConfigFile,"Audio","ScareVolume")
    IniWrite(82,ConfigFile,"Audio","ScareOutputVolume")
    Check(ScareVolume()=26 && ScareVolume(true)=82,"Local and output audio sliders are independent")
    IniWrite(0,ConfigFile,"Audio","ScareVolume")
    Check(ScareVolume()=0 && ScareVolume(true)=82,"Local mute preserves output audio")
    Check(CompactEffectNote("Waiting for Destiny 2 - click back into the game")="Focus game","Waiting overlay has a short status")
    savedSonion := Sonion, savedHorror := HorrorEvents, savedQueue := ScareQueue, savedScare := ActiveScare
    try {
        Sonion := 0, HorrorEvents := [], ScareQueue := [], ActiveScare := 0
        Check(!SequenceBusy(1000),"Alt Enter is eligible without a sequence")
        HorrorEvents := [{Due:50000}]
        Check(SequenceBusy(1000),"Queued Tung excludes Alt Enter")
        HorrorEvents := [], Sonion := {Phase:"ringing"}
        Check(SequenceBusy(1000),"Sonion ringing excludes Alt Enter")
        Sonion := {Phase:"accepted"}
        Check(SequenceBusy(1000),"Delayed Jeff excludes Alt Enter")
        Sonion := 0, ScareQueue := [{Due:50000}]
        Check(SequenceBusy(1000),"Queued scares exclude Alt Enter")
    } finally {
        Sonion := savedSonion, HorrorEvents := savedHorror, ScareQueue := savedQueue, ActiveScare := savedScare
    }
    source := FileRead(A_ScriptDir "\..\Lib\Updates.ahk","UTF-8")
    Check(InStr(source,'"ForceAuto", "1"') && InStr(source,"600000") && InStr(source,"SaveUpdateSession()"),"Auto updates default on with ten minute checks and session persistence")
    source := FileRead(A_ScriptDir "\..\Lib\Sonion.ahk","UTF-8")
    Check(InStr(source,"UpdateInteractionPointer(call, firstPhone)") && InStr(source,"CloseInteractionPointer(call)"),"Sonion owns a visible software pointer")
}

TestUpdateSession612() {
    global Queue, AppGui, Slots, Clock, OutputEnabled, OutputPid, Guides, VisualHits, RuntimeDir, SettingsGui, Rounds, Recorder, DirectPending, HorrorEvents, Sonion, ScareQueue, ActiveScare
    AppGui := Gui("-DPIScale","Update session test")
    AppGui.Show("NA x25 y25 w320 h180")
    DirCreate(A_ScriptDir "\.updates")
    try {
        Queue := SpinQueue()
        Queue.Accept("pending-612",false,NowMs(),"meso",true,2)
        Queue.Paused := false
        Queue.Completed := 7
        Queue.Seen["already-redeemed-612"] := NowMs()
        Slots := {Phase:"idle",Locked:4,Id:"activity-612",Values:["RAID","LAST WISH","FULL CLEAR","TITAN"]}
        Clock := ActivityClock()
        Clock.Phase := "ready", Clock.Generation := 11
        OutputEnabled := false, OutputPid := 0, Guides := true
        VisualHits := Map("Lights Out",3,"Tunnel Vision",2,"Wide View",1)
        SaveUpdateSession()
        Queue.Paused := true, Queue.Completed := 0, Queue.Seen := Map()
        Clock.Phase := "idle", Clock.Generation := 0
        Slots.Values := ["","","",""], VisualHits := Map(), Guides := false
        Check(RestoreUpdateSession(),"Update session restores successfully")
        Check(!Queue.Paused && Queue.Count()=1 && Queue.Completed=7,"Update keeps queue state and completed count")
        Check(Queue.Seen.Has("already-redeemed-612"),"Update preserves redemption deduplication")
        Check(Clock.Phase="ready" && Clock.Generation=11 && Slots.Values[2]="LAST WISH" && Slots.Locked=4,"Update keeps activity results and ready timer")
        Check(Guides && VisualHits["Lights Out"]=3 && VisualHits["Tunnel Vision"]=2,"Update keeps overlays and progressive strength")
        Check(!FileExist(A_ScriptDir "\.updates\session.ini"),"Update session is consumed once")
        SettingsGui := 0, Rounds := RoundCycle(), Recorder := {Phase:"idle"}, DirectPending := []
        HorrorEvents := [], Sonion := 0, ScareQueue := [], ActiveScare := 0
        Check(UpdateCanInstall(NowMs()),"A quiet update can preserve pending spins")
        ScareQueue.Push({Due:NowMs()+5000})
        Check(!UpdateCanInstall(NowMs()),"An update waits for delayed scares")
        ScareQueue := []
    } finally {
        AppGui.Destroy()
    }
}
