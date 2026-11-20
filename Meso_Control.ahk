#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#MaxThreadsPerHotkey 1
#Include Lib\Core.ahk
#Include Lib\ActivityData.ahk
#Include Lib\ActivityOptions.ahk
#Include Lib\AltTab.ahk
#Include Lib\Effects.ahk
#Include Lib\Sonion.ahk
#Include Lib\SonionScream.ahk
#Include Lib\SonionGlitch.ahk
#Include Lib\SonionRingtone.ahk
#Include Lib\ScareAssets.ahk
#Include Lib\ScareMedia.ahk
#Include Lib\ScareAudio1.ahk
#Include Lib\ScareAudio2.ahk
#Include Lib\Draw.ahk
#Include Lib\GlitchWheel.ahk
#Include Lib\HorrorFlash.ahk
#Include Lib\GameplayInput.ahk
#Include Lib\Sensitivity.ahk
#Include Lib\MacroCodec.ahk
#Include Lib\Recorder.ahk
#Include Lib\Editor.ahk
#Include Lib\Scoreboard.ahk
#Include Lib\RoundModel.ahk
#Include Lib\Rounds.ahk
#Include Lib\ChatPolicy.ahk
#Include Lib\ChatControl.ahk
#Include Lib\WheelRelay.ahk
#Include Lib\DirectRewards.ahk
#Include Lib\SharedKeys.ahk
#Include Lib\PunishmentOptions.ahk
#Include Lib\Updates.ahk

AppName := "Meso Control"
RestartInTray := false
RestoreOutputAfterUpdate := false
for argument in A_Args {
    if argument = "--background"
        RestartInTray := true
    if argument = "--restore-output"
        RestoreOutputAfterUpdate := true
}
IconPath := A_ScriptDir "\Meso_Icon.ico"
LogoPath := A_ScriptDir "\Meso_Icon.png"
ConfigFile := A_ScriptDir "\Meso_Chaos.ini"
RuntimeDir := A_ScriptDir "\runtime"
WheelRelayInbox := WheelRelayBasePath() "\Inbox"
WheelRelayReplies := WheelRelayBasePath() "\Replies"
ProfilesDir := A_ScriptDir "\Profiles"
ChatRelayInbox := ChatBridgeInboxPath()
ChatRelayReplies := ChatBridgeRepliesPath()
ChatBridgeInitialize()
DirCreate(RuntimeDir)
DirCreate(ProfilesDir)
DirCreate(A_ScriptDir "\Macros")
SharedLargeIcon := 0
SharedSmallIcon := 0
Closing := false
Refreshing := false
EngineBusy := false
PublisherRevision := 0
LastPublished := ""
LastPublishTick := 0
LastUiTick := 0
LastPruneTick := 0
OutputPid := 0
OutputEnabled := false
OutputStopping := false
OutputManagementBusy := false
Guides := false
Queue := SpinQueue()
Rounds := LoadRoundSettings()
Sonion := 0
Chat := LoadChatSettings()
ChatBridgeStatus := "Waiting for Twitch chat"
CapturePad := 0
Clock := ActivityClock()
SettingsGui := 0
StreamSettingsGui := 0
RecorderGui := 0
SettingsLV := 0
SelectedEditorIndex := 0
Effect := 0
EffectOwnedKeys := Map()
EffectOwnedKeys.CaseSense := "Off"
GameKeyOwners := Map()
GameKeyOwners.CaseSense := "Off"
ActiveEffects := []
InputLockOwners := Map()
GameplayLock := 0
VisualHits := Map()
ChatEffect := 0
DirectPending := []
DirectSlotControls := []
DirectBypassCooldown := IniRead(ConfigFile, "Rounds", "DirectBypassCooldown", "0") = "1"
SharedBindHook := 0
SharedBindId := ""
EditorBindHook := 0
EditorBindIndex := 0
LastEffectMessage := "No punishment active"
Recorder := {Phase: "idle", Events: [], Target: 0, Hook: 0, Start: 0, Deadline: 0, Down: Map(), LastMove: 0}
CaptureExclusions := Map()
CustomAltTabFeatureEnabled := false
AltTabActive := false
AltTabBuilding := false
AltTabWindows := []
AltTabGroups := []
AltTabIndex := 0
AltTabGui := 0

AltTabGroupGui := 0
AltTabGroupIndex := 0
AltTabGroupThumbnails := []
AltTabGroupCells := []
AltTabGroupHoverIndex := 0
AltTabGroupBorders := []

AltTabGroupGap := 14
AltTabGroupPadding := 10
AltTabGroupBorder := 2
AltTabGroupRadius := 16
AltTabGroupCardWidth := 190
AltTabGroupCardHeight := 88
AltTabGroupIconSize := 38
AltTabGroupCloseSize := 18
AltTabGroupCardGap := 8

RecentWindows := []
LastActiveHwnd := 0
HighlightBorders := []
AltTabCellPositions := []
HighlightCurrentX := 0
HighlightCurrentY := 0
HighlightTargetX := 0
HighlightTargetY := 0
HighlightSize := 54
BorderThickness := 3
HighlightEase := 0.34
LastAltTabMouseX := -99999
LastAltTabMouseY := -99999

AltTabPreviewThumbnail := 0
AltTabPreviewIndex := 0
AltTabPreviewHwnd := 0
AltTabPreviewGui := 0
AltTabPreviewCloseGui := 0
AltTabPreviewCloseRect := 0
AltTabBaseGuiWidth := 0
AltTabBaseGuiHeight := 0
AltTabGuiX := 0
AltTabGuiY := 0
AltTabPreviewGap := 14
AltTabPreviewPadding := 9
AltTabPreviewBorder := 2
AltTabPreviewRadius := 16
AltTabPreviewMaxWidth := 620
AltTabPreviewMaxHeight := 300


CoordMode("Mouse", "Screen")
SetKeyDelay(-1, -1)
SetMouseDelay(-1)
InstallKeybdHook()
InstallMouseHook()
WheelControllerEnabled := IniRead(ConfigFile, "Wheel", "ControllerEnabled", "0") = "1"
DestinyOnlyMode := IniRead(ConfigFile, "Wheel", "DestinyOnly", "1") = "1"
GameInputMethod := IniRead(ConfigFile, "Wheel", "InputMethod", "Event")
if GameInputMethod != "Input"
    GameInputMethod := "Event"
SlotAutoRoll := IniRead(ConfigFile, "Slots", "AutoRoll", "0") = "1"
PrepTimeValue := IniRead(ConfigFile, "ActivityTimer", "PrepTime", "01:00")
ActivityTimeValue := IniRead(ConfigFile, "ActivityTimer", "ActivityTime", "30:00")
TickSoundPath := IniRead(ConfigFile, "Wheel", "TickSound", "")
LandSoundPath := IniRead(ConfigFile, "Wheel", "LandSound", "")
TickVolume := IniRead(ConfigFile, "Wheel", "TickVolume", "55") + 0
LandVolume := IniRead(ConfigFile, "Wheel", "LandVolume", "80") + 0
SlotTickSoundPath := IniRead(ConfigFile, "Slots", "TickSound", "")
SlotLandSoundPath := IniRead(ConfigFile, "Slots", "LandSound", "")
SlotTickVolume := IniRead(ConfigFile, "Slots", "TickVolume", "55") + 0
SlotLandVolume := IniRead(ConfigFile, "Slots", "LandVolume", "80") + 0
SequenceVolume := Max(0, Min(100, Integer(IniRead(ConfigFile, "Audio", "SequenceVolume", IniRead(ConfigFile, "Audio", "HorrorVolume", "75")))))
HorrorVolume := SequenceVolume
FigureVolume := SequenceVolume
TtsVolume := Max(0, Min(100, Integer(IniRead(ConfigFile, "Audio", "TtsVolume", "80"))))
SpinAnnouncementVolume := Max(0, Min(100, Integer(IniRead(ConfigFile, "Audio", "SpinAnnouncementVolume", "85"))))
TtsEnabled := IniRead(ConfigFile, "Audio", "TtsEnabled", "1") = "1"
ViewerVisible := IniRead(ConfigFile, "Wheel", "ViewerVisible", "1") = "1"
WheelDisplayMode := StrLower(IniRead(ConfigFile, "Wheel", "DisplayMode", "wheel"))
if WheelDisplayMode != "reel"
    WheelDisplayMode := "wheel"
HorrorEvents := []
ScoreVisible := IniRead(ConfigFile, "Scoreboard", "Visible", "0") = "1"
MesoScore := ScoreNumber(IniRead(ConfigFile, "Scoreboard", "Meso", "0"))
ChatScore := ScoreNumber(IniRead(ConfigFile, "Scoreboard", "Chat", "0"))
ScoreUiBusy := false
CurrentPunishmentProfile := IniRead(ConfigFile, "Profiles", "Punishments", "Default")
CurrentActivityProfile := IniRead(ConfigFile, "Profiles", "Activities", "Default")
if CurrentPunishmentProfile != "Default" && !FileExist(PunishmentProfilePath(CurrentPunishmentProfile))
    CurrentPunishmentProfile := "Default"
if CurrentActivityProfile != "Default" && !FileExist(SlotOptionsPath(CurrentActivityProfile))
    CurrentActivityProfile := "Default"
Punishments := LoadAndMigratePunishments()
SharedKeys := LoadSharedKeys(ConfigFile, Punishments, Chat)
ApplySharedChatKeys()
ActivityData := BuildActivityDatabase()
ActivityClasses := ["HUNTER", "WARLOCK", "TITAN"]
SlotOptionRecords := LoadSlotOptionRecords()
Slots := {Phase: "idle", Start: 0, Locked: 0, Reel: 0, Mode: false, Values: ["", "", "", ""], Pools: [], HoldUntil: 0, Id: ""}
RestorePending()
BuildMainWindow()
InitUpdates()
SetTimer(RefreshUpdateStatus, 350)
OnMessage(0x4A, ReceiveMesoCommand)
OnMessage(0xFF, RecordRawMouse)
WheelRelayInitialize()
SetTimer(ReadWheelRelay, 75)
SetTimer(ReadChatRelay, 65)
OnExit(Shutdown)
WriteAtomic(RuntimeDir "\controller.info", A_AhkPath "`n" AppGui.Hwnd "`n" ProcessExist())
try DllCall("user32\ChangeWindowMessageFilterEx", "Ptr", AppGui.Hwnd, "UInt", 0x4A, "UInt", 1, "Ptr", 0)
SetTimer(EngineTick, 15)
SetTimer(TrackActiveWindow, 150)
SetTimer(AltTabFailsafe, 25)
SetTimer(HighlightAnimationTick, 16)
SetTimer(AltTabMouseTick, 20)
PublishState(true)
SetTimer(CheckStreamOutput, 200)
UpdateMainUi()
if RestoreOutputAfterUpdate
    SetTimer((*) => OpenStreamOutput(false), -400)
return

#HotIf Recorder.Phase = "idle"
^!m::ShowApp()
#HotIf
^!F12::EmergencyStop()

#HotIf IsMesoFocused()
^r::RefreshApp()
#HotIf

#HotIf CustomAltTabFeatureEnabled && Recorder.Phase = "idle" && (GetKeyState("LAlt", "P") || GetKeyState("RAlt", "P"))
$*Tab::AltTabCycle(GetKeyState("Shift", "P") ? -1 : 1)
#HotIf CustomAltTabFeatureEnabled && Recorder.Phase = "idle"
~*LAlt Up::AltTabRelease()
~*RAlt Up::AltTabRelease()
#HotIf CustomAltTabFeatureEnabled && AltTabActive
Esc::CloseAltTabGui()
$*LButton::AltTabMouseClick()
$*RButton::AltTabMousePreview()
#HotIf Recorder.Phase = "recording" || Recorder.Phase = "countdown"
F8::StopRecording()
#HotIf IsEditorKeyCaptureActive()
~*LButton::EditorMouseCaptured("LButton")
~*RButton::EditorMouseCaptured("RButton")
~*MButton::EditorMouseCaptured("MButton")
~*XButton1::EditorMouseCaptured("XButton1")
~*XButton2::EditorMouseCaptured("XButton2")
~*WheelUp::EditorMouseCaptured("WheelUp")
~*WheelDown::EditorMouseCaptured("WheelDown")
~*WheelLeft::EditorMouseCaptured("WheelLeft")
~*WheelRight::EditorMouseCaptured("WheelRight")
#HotIf

BuildMainWindow() {
    global
    AppGui := Gui("-MaximizeBox", AppName)
    AppGui.BackColor := "0E0B15"
    AppGui.MarginX := 0
    AppGui.MarginY := 0
    AppGui.SetFont("s10 cEDE7F7", "Segoe UI")
    AppGui.AddPicture("x0 y0 w1000 h750", A_ScriptDir "\Ui\Meso_Dashboard.png")
    ActionButton(AppGui, 739, 28, 101, 40, "Refresh", RefreshApp, "272032", "btn_refresh.png")
    ActionButton(AppGui, 851, 28, 121, 40, "Settings", OpenSettings, "683C91", "btn_settings.png")
    AltChip := AddStatusChip(AppGui, 38, 118, 200, "ALT+TAB", ToggleAltVisual, "ring")
    WheelTile := AddStatusChip(AppGui, 265, 118, 191, "WHEEL", ToggleWheelVisual)
    StreamTile := AddStatusChip(AppGui, 486, 118, 191, "OBS OUTPUT", ToggleOutputVisual)
    AltCheck := AppGui.AddCheckbox("Hidden x0 y0 w1 h1", "")
    WheelEnableCheck := AppGui.AddCheckbox("Hidden x0 y0 w1 h1", "")
    WheelEnableCheck.Value := WheelControllerEnabled
    OutputCheck := AppGui.AddCheckbox("Hidden x0 y0 w1 h1", "")
    GuideCheck := AppGui.AddCheckbox("Hidden x0 y0 w1 h1", "")
    GuideCheck.Enabled := false
    ScoreVisibleCheck := AppGui.AddCheckbox("Hidden x0 y0 w1 h1", "")
    ScoreVisibleCheck.Value := ScoreVisible
    ModeWheelChip := AddSegmentChip(AppGui, 303, 211, 80, "Wheel", (*) => SelectWheelMode("wheel"))
    ModeReelChip := AddSegmentChip(AppGui, 391, 211, 80, "Reel", (*) => SelectWheelMode("reel"))
    QueueLabel := UiLabel(AppGui, 42, 261, 241, 22, "Queued spins: 0", 9, "BBADCE", "1C1628")
    WheelStateLabel := UiLabel(AppGui, 320, 261, 141, 22, "Ready", 9, "C6B7D7", "1C1628", "Norm", "Right")
    NowLabel := UiLabel(AppGui, 42, 294, 413, 40, "No punishment active", 12, "E6DCEF", "1C1628", "Bold")
    LiveWheelButton := ActionButton(AppGui, 43, 345, 146, 40, "Live spin", (*) => EnqueueLocal(false), "6B3E94", "btn_live.png")
    TestWheelButton := ActionButton(AppGui, 198, 345, 111, 40, "Preview", (*) => EnqueueLocal(true), "30263D", "btn_preview.png")
    QueueMenuButton := ActionButton(AppGui, 320, 345, 144, 40, "Queue  ···", OpenQueueMenu, "30263D", "btn_queue.png")
    PauseButton := AppGui.AddButton("Hidden x0 y0 w1 h1", "Pause queue")
    StopButton := AppGui.AddButton("Hidden x0 y0 w1 h1", "Stop current")
    ClearButton := AppGui.AddButton("Hidden x0 y0 w1 h1", "Clear queue")
    EditButton := AppGui.AddButton("Hidden x0 y0 w1 h1", "Settings")
    SlotLabel := UiLabel(AppGui, 522, 288, 436, 48, "Awaiting roll", 12, "E7DAF4", "1C1628")
    RollSprites := Map()
    for row in [["ROLL REEL 1", "btn_roll_1.png"], ["ROLL REEL 2", "btn_roll_2.png"], ["ROLL REEL 3", "btn_roll_3.png"], ["ROLL REEL 4", "btn_roll_4.png"], ["NEW ROLL", "btn_roll_new.png"], ["ROLL ALL REELS", "btn_roll_all.png"]] {
        sprite := AppGui.AddPicture("x521 y345 w437 h40 +0x100 +Hidden", A_ScriptDir "\Ui\" row[2])
        sprite.OnEvent("Click", RollActivity)
        RollSprites[row[1]] := sprite
    }
    RollButton := RollSprites["ROLL REEL 1"]
    PrepEdit := AppGui.AddEdit("x58 y515 w160 h37 Center -Border Background292135 cF8F0FF", PrepTimeValue)
    PrepEdit.SetFont("s18 Bold", "Segoe UI")
    ActivityEdit := AppGui.AddEdit("x287 y515 w160 h37 Center -Border Background292135 cF8F0FF", ActivityTimeValue)
    ActivityEdit.SetFont("s18 Bold", "Segoe UI")
    SkipButton := ActionButton(AppGui, 43, 557, 186, 37, "Skip prep", SkipPrep, "30253E", "btn_skip.png")
    StartButton := ActionButton(AppGui, 242, 557, 221, 37, "Start activity", StartActivity, "553473", "btn_start.png")
    TimerLabel := UiLabel(AppGui, 43, 611, 419, 20, "Timer idle", 10, "DBCBEB", "21192E")
    ScoreBadge := AddStatusChip(AppGui, 798, 438, 160, "IN OBS", ToggleTallyVisual)
    ScoreMesoEdit := AppGui.AddEdit("x528 y515 w160 h37 Center -Multi Number Limit4 -Border Background292135 cFFFFFF", MesoScore)
    ScoreMesoEdit.SetFont("s18 Bold", "Segoe UI")
    ScoreChatEdit := AppGui.AddEdit("x748 y515 w160 h37 Center -Multi Number Limit4 -Border Background292135 cFFFFFF", ChatScore)
    ScoreChatEdit.SetFont("s18 Bold", "Segoe UI")
    ScoreMesoEdit.OnEvent("Change", ScoreChanged)
    ScoreChatEdit.OnEvent("Change", ScoreChanged)
    ScoreMesoEdit.OnEvent("LoseFocus", NormalizeScoreInputs)
    ScoreChatEdit.OnEvent("LoseFocus", NormalizeScoreInputs)
    MesoMinusButton := ActionButton(AppGui, 526, 564, 76, 30, "-1", (*) => AdjustTally("meso", -1), "30253E", "btn_score_minus.png")
    MesoPlusButton := ActionButton(AppGui, 610, 564, 76, 30, "+1", (*) => AdjustTally("meso", 1), "553473", "btn_score_plus.png")
    ChatMinusButton := ActionButton(AppGui, 746, 564, 76, 30, "-1", (*) => AdjustTally("chat", -1), "30253E", "btn_score_minus.png")
    ChatPlusButton := ActionButton(AppGui, 830, 564, 76, 30, "+1", (*) => AdjustTally("chat", 1), "553473", "btn_score_plus.png")
    ScoreResetButton := ActionButton(AppGui, 672, 603, 132, 31, "Reset scores", ResetScores, "30253E", "btn_reset.png")
    ActionButton(AppGui, 35, 660, 277, 49, "Interact Delay", OpenInteractDelay, "292039", "btn_interact.png")
    ActionButton(AppGui, 733, 663, 115, 45, "Minimize", HideApp, "292039", "btn_minimize.png")
    ActionButton(AppGui, 858, 663, 110, 45, "Exit", (*) => ExitApp(), "292039", "btn_exit.png")
    OutputStatusLabel := UiLabel(AppGui, 80, 731, 865, 14, "Output: off", 8, "9F92B4", "0D0817")
    FocusSink := AppGui.AddButton("x981 y734 w1 h1 -Tabstop", "")
    TrayButton := AppGui.AddButton("Hidden x0 y0 w1 h1", "Minimize to tray")
    QuitButton := AppGui.AddButton("Hidden x0 y0 w1 h1", "Exit")
    ModeDrop := 0
    AutoCheck := 0
    DestinyCheck := 0
    AppGui.OnEvent("Close", HideApp)
    AppGui.OnEvent("Escape", HideApp)
    ApplyGuiIcon(AppGui)
    try TraySetIcon(IconPath)
    A_IconTip := "Meso Control"
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Open Meso Control", ShowApp)
    A_TrayMenu.Add("Stream output", (*) => OpenStreamOutput(true))
    A_TrayMenu.Add("Emergency stop", EmergencyStop)
    if !A_IsAdmin
        A_TrayMenu.Add("Run as administrator", RestartElevated)
    A_TrayMenu.Add("Refresh", RefreshApp)
    A_TrayMenu.Add("Exit", (*) => ExitApp())
    A_TrayMenu.Default := "Open Meso Control"
    AppGui.Show((RestartInTray ? "Hide " : "") "w1000 h750")
    try FocusSink.Focus()
    SetTimer(FocusMainAfterShow, -100)
    UpdateChrome()
}

UiCard(gui, x, y, w, h, bg := "1C1628", border := "35273F") {
    if FileExist(A_ScriptDir "\Ui\Meso_Dashboard.png")
        return
    gui.AddText("x" x " y" y " w" w " h" h " Background" border, "")
    gui.AddText("x" (x + 1) " y" (y + 1) " w" (w - 2) " h" (h - 2) " Background" bg, "")
}

UiLabel(gui, x, y, w, h, label, size := 10, color := "EDE7F7", bg := "1C1628", weight := "Norm", opts := "") {
    control := gui.AddText("x" x " y" y " w" w " h" h " Background" bg " c" color " +0x100 " opts, label)
    control.SetFont("s" size " " weight, "Segoe UI")
    return control
}

ActionButton(gui, x, y, w, h, label, callback, color := "30243F", asset := "") {
    path := A_ScriptDir "\Ui\" asset
    if asset != "" && FileExist(path)
        control := gui.AddPicture("x" x " y" y " w" w " h" h " +0x100", path)
    else
        control := UiLabel(gui, x, y, w, h, label, 10, "FFFFFF", color, "Bold", "Center +0x200 +0x100")
    control.OnEvent("Click", callback)
    return control
}

UpdateRollButton(label, available) {
    global RollSprites
    if !IsSet(RollSprites) || !IsObject(RollSprites)
        return
    for name, sprite in RollSprites {
        sprite.Opt(name = label ? "-Hidden" : "+Hidden")
        sprite.Enabled := available
    }
}

AddStatusChip(gui, x, y, w, label, callback, form := "pill") {
    path := A_ScriptDir "\Ui\" form "_" w "_" RegExReplace(StrLower(label), "[^a-z0-9]+", "_") "_"
    if !FileExist(path "on.png") {
        on := UiLabel(gui, x, y, w, 36, "●  " label "  ON", 10, "A7F3D2", "1A483B", "Bold", "Center +0x200 +Hidden")
        off := UiLabel(gui, x, y, w, 36, "○  " label "  OFF", 10, "F1BBC5", "48242F", "Bold", "Center +0x200")
        on.OnEvent("Click", callback)
        off.OnEvent("Click", callback)
        return {On: on, Off: off, Last: -1}
    }
    on := gui.AddPicture("x" x " y" y " w" w " h36 +0x100 +Hidden", path "on.png")
    off := gui.AddPicture("x" x " y" y " w" w " h36 +0x100", path "off.png")
    on.OnEvent("Click", callback)
    off.OnEvent("Click", callback)
    return {On: on, Off: off, Last: -1}
}

AddSegmentChip(gui, x, y, w, label, callback) {
    path := A_ScriptDir "\Ui\segment_" StrLower(label) "_"
    if FileExist(path "on.png") {
        on := gui.AddPicture("x" x " y" y " w" w " h31 +0x100 +Hidden", path "on.png")
        off := gui.AddPicture("x" x " y" y " w" w " h31 +0x100", path "off.png")
    } else {
        on := UiLabel(gui, x, y, w, 31, label, 9, "FFFFFF", "70469A", "Bold", "Center +0x200 +Hidden")
        off := UiLabel(gui, x, y, w, 31, label, 9, "BBAACB", "30263D", "Bold", "Center +0x200")
    }
    on.OnEvent("Click", callback)
    off.OnEvent("Click", callback)
    return {On: on, Off: off, Last: -1}
}

UpdateStatusChip(tile, active) {
    if tile.Last == active
        return
    tile.Last := active
    tile.On.Opt(active ? "-Hidden" : "+Hidden")
    tile.Off.Opt(active ? "+Hidden" : "-Hidden")
}

UpdateChrome() {
    global WheelTile, StreamTile, ScoreBadge, AltChip, ModeWheelChip, ModeReelChip
    global WheelControllerEnabled, OutputEnabled, ScoreVisible, CustomAltTabFeatureEnabled, WheelDisplayMode
    if IsSet(WheelTile) && IsObject(WheelTile)
        UpdateStatusChip(WheelTile, WheelControllerEnabled)
    if IsSet(StreamTile) && IsObject(StreamTile)
        UpdateStatusChip(StreamTile, OutputEnabled)
    if IsSet(ScoreBadge) && IsObject(ScoreBadge)
        UpdateStatusChip(ScoreBadge, ScoreVisible)
    if IsSet(AltChip) && IsObject(AltChip)
        UpdateStatusChip(AltChip, CustomAltTabFeatureEnabled)
    if IsSet(ModeWheelChip) && IsObject(ModeWheelChip)
        UpdateStatusChip(ModeWheelChip, WheelDisplayMode = "wheel")
    if IsSet(ModeReelChip) && IsObject(ModeReelChip)
        UpdateStatusChip(ModeReelChip, WheelDisplayMode = "reel")
}

ToggleAltVisual(*) {
    global AltCheck
    AltCheck.Value := !AltCheck.Value
    ToggleAltTab()
    UpdateChrome()
}

ToggleWheelVisual(*) {
    global WheelEnableCheck
    WheelEnableCheck.Value := !WheelEnableCheck.Value
    ToggleWheelController()
    UpdateChrome()
}

ToggleOutputVisual(*) {
    global OutputCheck
    OutputCheck.Value := !OutputCheck.Value
    ToggleStreamOutput()
    UpdateChrome()
}

ToggleTallyVisual(*) {
    global ScoreVisibleCheck
    ScoreVisibleCheck.Value := !ScoreVisibleCheck.Value
    ToggleScoreboard()
    UpdateChrome()
}

OpenQueueMenu(*) {
    global Queue
    m := Menu()
    m.Add(Queue.Paused ? "Resume queue" : "Pause queue", ToggleQueuePause)
    m.Add("Clear pending spins", ClearQueue)
    m.Add("Stop current", StopCurrent)
    m.Show()
}

SetText(control, value) {
    try {
        if IsObject(control) && control.Text != value
            control.Text := value
    }
}

IsMesoFocused() {
    global AppGui, SettingsGui, RecorderGui, StreamSettingsGui
    h := WinExist("A")
    return h && (h = GuiHwndSafe(AppGui) || h = GuiHwndSafe(SettingsGui) || h = GuiHwndSafe(RecorderGui) || h = GuiHwndSafe(StreamSettingsGui))
}

ShowApp(*) {
    global AppGui
    AppGui.Show()
    WinActivate("ahk_id " AppGui.Hwnd)
    SetTimer(FocusMainAfterShow, -100)
}

FocusMainAfterShow(*) {
    global AppGui, FocusSink, PrepEdit, ActivityEdit, ScoreMesoEdit, ScoreChatEdit
    if !WinActive("ahk_id " AppGui.Hwnd)
        return
    try FocusSink.Focus()
    try DllCall("user32\SetFocus", "Ptr", FocusSink.Hwnd, "Ptr")
    for input in [PrepEdit, ActivityEdit, ScoreMesoEdit, ScoreChatEdit]
        try DllCall("user32\SendMessageW", "Ptr", input.Hwnd, "UInt", 0xB1, "Ptr", 0, "Ptr", 0, "Ptr")
}

HideApp(*) {
    global AppGui
    SaveAppSettings()
    AppGui.Hide()
}

ToggleAltTab(*) {
    global AltCheck, CustomAltTabFeatureEnabled
    CustomAltTabFeatureEnabled := AltCheck.Value = 1
    if !CustomAltTabFeatureEnabled
        CloseAltTabGui()
}

ChangeWheelDisplayMode(*) {
    global ModeDrop
    SelectWheelMode(ModeDrop.Value = 2 ? "reel" : "wheel")
}

SelectWheelMode(mode) {
    global WheelDisplayMode, SettingsGui, ModeDrop
    if mode != "wheel" && mode != "reel"
        return
    if WheelDisplayMode = mode {
        UpdateChrome()
        return
    }
    WheelDisplayMode := mode
    UpdateChrome()
    if GuiHwndSafe(SettingsGui) && IsObject(ModeDrop)
        try ModeDrop.Choose(mode = "reel" ? 2 : 1)
    SaveAppSettings()
    PublishState(true)
}

NormalizeViewer(value) {
    name := Trim(String(value))
    if !RegExMatch(name, "^[A-Za-z0-9_]{1,25}$")
        return ""
    return name
}

ToggleWheelController(*) {
    global WheelControllerEnabled, WheelEnableCheck, Queue, Rounds
    WheelControllerEnabled := WheelEnableCheck.Value = 1
    if !WheelControllerEnabled {
        Rounds.Reset()
        CancelEffects("Controller disabled")
        Queue.Finish()
        Queue.Paused := true
    } else
        Queue.Paused := false
    SaveAppSettings()
    PublishState(true)
}

ToggleDestinyOnly(*) {
    global DestinyOnlyMode, DestinyCheck
    DestinyOnlyMode := DestinyCheck.Value = 1
    CancelEffects("Game scope changed")
    SaveAppSettings()
}

ToggleQueuePause(*) {
    global Queue
    Queue.Paused := !Queue.Paused
    UpdateMainUi()
}

ClearQueue(*) {
    global Queue, DirectPending
    Queue.Clear()
    DirectPending := []
    UpdateMainUi()
}

StopCurrent(*) {
    global Queue
    Queue.Paused := true
    CancelEffects("Stopped")
    Queue.Finish()
    PublishState(true)
    UpdateMainUi()
}

EmergencyStop(*) {
    global Queue, WheelControllerEnabled, WheelEnableCheck, Rounds, DirectPending
    DirectPending := []
    Rounds.Reset()
    StopSequence()
    Queue.Paused := true
    Queue.Clear()
    CancelEffects("Emergency stop")
    Queue.Finish()
    StopRecording()
    CloseAltTabGui()
    WheelControllerEnabled := false
    WheelEnableCheck.Value := 0
    PublishState(true)
    UpdateMainUi()
}

EnqueueLocal(preview := true) {
    global Queue, WheelControllerEnabled, LastEffectMessage
    if !preview && !WheelControllerEnabled {
        LastEffectMessage := "Enable Wheel Controller before using LIVE SPIN"
        UpdateMainUi()
        return
    }
    AcceptSpinRequest(NewId(), preview, "", false)
    Queue.Paused := false
    LogEvent("Local spin queued | preview=" preview)
    LastEffectMessage := preview ? "PREVIEW ONLY - no game inputs" : "Live spin queued - return to your game"
    UpdateMainUi()
}

ReceiveMesoCommand(wParam, lParam, msg, hwnd) {
    global Queue, WheelControllerEnabled, Closing
    Critical(20)
    if Closing || !lParam || NumGet(lParam, 0, "UPtr") != 0x4D45534F
        return 0
    size := NumGet(lParam, A_PtrSize, "UInt")
    ptr := NumGet(lParam, A_PtrSize * 2, "Ptr")
    if !ptr || size < 2 || size > 4096 || Mod(size, 2)
        return 0
    try {
        text := StrGet(ptr, size // 2 - 1, "UTF-16")
        packet := ParseMesoPacket(text)
        if !IsObject(packet)
            return 0
        if !WheelControllerEnabled && packet.Mode != "preview" && packet.Mode != "chat"
            return -1
        viewer := NormalizeViewer(packet.Viewer)
        if packet.Mode = "chat" {
            if viewer = ""
                return 0
            return ReceiveChatInput(packet.Id, viewer, packet.Message, packet.Sent)
        }
        if packet.Mode = "skip"
            return AcceptCooldownSkip(packet.Id, viewer)
        return AcceptSpinRequest(packet.Id, packet.Mode = "preview", viewer, true)
    } catch as err {
        LogEvent("Command packet rejected: " err.Message)
        return 0
    }
}

EligiblePunishments() {
    global Punishments, Clock, ChatEnabled
    list := []
    for p in Punishments {
        if !p.Enabled || p.Weight <= 0
            continue
        if p.Action = "Chat Control" && !ChatEnabled
            continue
        if p.Action = "Time Tax" && (Clock.Phase != "activity" || Clock.Remaining(NowMs()) <= 0)
            continue
        list.Push(p.Clone())
    }
    return list
}

EngineTick() {
    global Closing, EngineBusy, Queue, Clock, WheelControllerEnabled, Recorder, LastPruneTick, LastUiTick, HorrorEvents, RuntimeDir, TtsEnabled, OutputEnabled, Rounds
    if Closing || EngineBusy
        return
    EngineBusy := true
    try {
        now := NowMs()
        if UpdatesTick(now)
            return
        Clock.Tick(now)
        AdvanceSlots(now)
        RecorderTick(now)
        if IsObject(Queue.Active) {
            job := Queue.Active
            if job.Phase = "announce" {
                confirmed := false
                try {
                    receipt := Fields(Trim(FileRead(RuntimeDir "\tts.done", "UTF-8"), "`r`n"))
                    confirmed := receipt.Length >= 2 && receipt[1] = job.Id
                }
                if confirmed || !TtsEnabled || !OutputEnabled || now - job.Start >= 3200 {
                    if !confirmed
                        LogEvent("Voice announcement timed out; beginning spin " job.Id)
                    job.Phase := "spin"
                    job.Start := now
                    PublishState(true)
                }
            }
            elapsed := now - job.Start
            if elapsed >= 5000 && job.Phase = "spin"
                job.Phase := "hold"
            if elapsed >= 8000 && job.Phase = "hold" && SonionGlitchRoom(SpinEffectCount(job))
                LandSpin(job, now)
        }
        AdvanceEffect(now)
        AdvanceScares(now)
        try AdvanceSonion(now)
        catch as err {
            LogEvent("Sonion sequence: " err.Message)
            StopSonion()
        }
        if IsObject(Queue.Active) && Queue.Active.Phase = "result" && now >= Queue.Active.VisualUntil && !HasEffects(Queue.Active.Id) {
            if !Queue.Active.Preview
                Rounds.Complete(now)
            Queue.Finish()
        }
        AdvanceDirectRewards(now)
        if WheelControllerEnabled && !Queue.Paused && Recorder.Phase = "idle"
            Rounds.Tick(now, Queue.Count() > 0)
        if !IsObject(Queue.Active) && WheelControllerEnabled && !Queue.Paused && Recorder.Phase = "idle" && Rounds.Mode = "auto" && !Rounds.Cooling(now) && Queue.Count() = 0
            Queue.Accept(NewId(), false, now, "", false)
        if !IsObject(Queue.Active) && !Queue.Paused && Recorder.Phase = "idle" && Queue.Count() > 0 {
            next := Queue.Pending[Queue.Head]
            if (WheelControllerEnabled || next.Preview) && (next.Preview || !Rounds.Cooling(now)) {
                pool := EligiblePunishments()
                if !pool.Length {
                    Queue.Paused := true
                    LogEvent("Queue paused: no eligible punishments")
                }
                if pool.Length {
                    job := Queue.Take(now)
                    PrepareSpin(job, pool, now)
                    if TtsEnabled && job.Remote && !job.Preview && OutputEnabled {
                        job.Phase := "announce"
                        job.Start := now
                    }
                }
            }
        }
        if now - LastPruneTick >= 60000 {
            Queue.Prune(now)
            loop HorrorEvents.Length {
                index := HorrorEvents.Length - A_Index + 1
                if now > HorrorEvents[index].Due + 120000
                    HorrorEvents.RemoveAt(index)
            }
            LastPruneTick := now
        }
        if now - LastUiTick >= 100 {
            LastUiTick := now
            UpdateMainUi()
            PublishState()
        }
    } catch as err {
        LogEvent("Engine error: " err.Message)
        try StopRecording()
        Queue.Paused := true
        CancelEffects("Input error: " err.Message)
        Queue.Finish()
        UpdateMainUi()
    } finally {
        EngineBusy := false
    }
}

UpdateMainUi() {
    global Queue, Clock, Slots, SlotAutoRoll, Recorder, LastEffectMessage, Rounds, DirectPending
    global QueueLabel, PauseButton, WheelStateLabel, NowLabel, RollButton, SlotLabel, TimerLabel, SkipButton, StartButton, WheelControllerEnabled
    SetText(QueueLabel, "Queued spins: " Queue.Count() (DirectPending.Length ? "  |  Direct: " DirectPending.Length : ""))
    SetText(PauseButton, Queue.Paused ? "Resume queue" : "Pause queue")
    status := IsObject(Queue.Active) ? (Queue.Active.Phase = "announce" ? "Announcing" : Queue.Active.Phase = "spin" ? "Spinning" : Queue.Active.Phase = "hold" ? "Landed" : "Punishment") : (Queue.Paused ? "Queue paused" : WheelControllerEnabled ? "Ready" : "Controller off")
    if !IsObject(Queue.Active) && Rounds.Cooling(NowMs()) && WheelControllerEnabled
        status := "Cooldown " TimeText(Max(0, Rounds.CooldownUntil - NowMs()))
    if IsObject(Queue.Active) && Queue.Active.HasOwnProp("Bonus") && NowMs() < Queue.Active.VisualUntil
        status := "2×  + " Queue.Active.Bonus.Name
    SetText(WheelStateLabel, status)
    SetText(NowLabel, !HasEffects() && Rounds.Cooling(NowMs()) && WheelControllerEnabled ? "Next round in " TimeText(Max(0, Rounds.CooldownUntil - NowMs())) : EffectUiText())
    spinning := Slots.Phase = "spin"
    label := Slots.Locked >= 4 ? "NEW ROLL" : "ROLL REEL " (Slots.Locked + 1)
    UpdateRollButton(SlotAutoRoll ? "ROLL ALL REELS" : label, !spinning)
    if Slots.Locked > 0 {
        s := ""
        loop Slots.Locked
            s .= (A_Index > 1 ? "  /  " : "") Slots.Values[A_Index]
        SetText(SlotLabel, s)
    } else
        SetText(SlotLabel, "Awaiting roll")
    SkipButton.Enabled := Clock.Phase = "prep"
    StartButton.Enabled := Clock.Phase = "ready"
    SetText(TimerLabel, Clock.Phase = "idle" ? "Timer idle" : Clock.Phase = "ready" ? "READY - press Start activity" : Clock.Phase = "time" ? "TIME!" : (Clock.Phase = "prep" ? "PREP TIME  " : "ACTIVITY TIME  ") TimeText(Clock.Remaining(NowMs())))
    UpdateChrome()
}

ToggleAutoRoll(*) {
    global SlotAutoRoll, AutoCheck, Slots
    SlotAutoRoll := AutoCheck.Value = 1
    SaveAppSettings()
    UpdateMainUi()
}

ReadTimerInputs() {
    global PrepEdit, ActivityEdit, PrepTimeValue, ActivityTimeValue
    prep := ParseTime(PrepEdit.Value), activity := ParseTime(ActivityEdit.Value)
    if prep < 0 || activity <= 0 {
        MsgBox("Enter seconds, MM:SS, or HH:MM:SS. Activity time must be above zero.", "Check timer values")
        return false
    }
    PrepTimeValue := Trim(PrepEdit.Value)
    ActivityTimeValue := Trim(ActivityEdit.Value)
    return true
}

RollActivity(*) {
    global Slots, SlotAutoRoll
    if Slots.Phase = "spin"
        return
    if !ReadTimerInputs()
        return
    if Slots.Locked >= 4 || Slots.Id = "" || SlotAutoRoll {
        cats := GetSlotChoices(1)
        classes := GetSlotChoices(4)
        if !cats.Length || !classes.Length {
            MsgBox("Enable at least one complete activity and one class in Settings > Activities.", "Activity Roulette")
            return
        }
        cat := SlotWeightedChoice(cats)
        groups := GetSlotChoices(2, cat)
        second := SlotWeightedChoice(groups)
        activities := GetSlotChoices(3, cat, second)
        third := SlotWeightedChoice(activities)
        cls := SlotWeightedChoice(classes)
        Slots := {Phase: "idle", Start: 0, Locked: 0, Reel: 0, Mode: SlotAutoRoll, Values: [cat, second, third, cls], Pools: [SlotOptionsToNames(cats), SlotOptionsToNames(groups), SlotOptionsToNames(activities), SlotOptionsToNames(classes)], HoldUntil: 0, Id: NewId()}
    }
    Slots.Mode := SlotAutoRoll
    Slots.Phase := "spin"
    Slots.Reel := Slots.Locked + 1
    Slots.Start := NowMs()
    SaveAppSettings()
    PublishState(true)
    UpdateMainUi()
}

AdvanceSlots(now) {
    global Slots, Clock, PrepTimeValue
    if Slots.Phase = "spin" {
        elapsed := now - Slots.Start
        if Slots.Mode {
            locked := 0
            for t in [2400, 3100, 3800, 4500]
                if elapsed >= t
                    locked += 1
            Slots.Locked := locked
        } else if elapsed >= 1450
            Slots.Locked := Slots.Reel
        if (Slots.Mode && Slots.Locked = 4) || (!Slots.Mode && elapsed >= 1450) {
            Slots.Phase := Slots.Locked = 4 ? "hold" : "wait"
            if Slots.Locked = 4 {
                Slots.HoldUntil := now + 6000
                Clock.Prep(ParseTime(PrepTimeValue), now)
            }
        }
    } else if Slots.Phase = "hold" && now >= Slots.HoldUntil
        Slots.Phase := "idle"
}

SkipPrep(*) {
    global Clock
    Clock.Skip()
    PublishState(true)
    UpdateMainUi()
}

StartActivity(*) {
    global Clock, ActivityTimeValue
    if !ReadTimerInputs()
        return
    Clock.Start(ParseTime(ActivityTimeValue), NowMs())
    SaveAppSettings()
    PublishState(true)
    UpdateMainUi()
}

ToggleScoreboard(*) {
    global ScoreVisible, ScoreVisibleCheck
    ScoreVisible := ScoreVisibleCheck.Value = 1
    PublishState(true)
    ScheduleScoreSave()
}

ScoreChanged(*) {
    global MesoScore, ChatScore, ScoreMesoEdit, ScoreChatEdit, ScoreUiBusy
    if ScoreUiBusy
        return
    meso := ScoreNumber(ScoreMesoEdit.Value, -1)
    chat := ScoreNumber(ScoreChatEdit.Value, -1)
    changed := false
    if meso >= 0 && meso != MesoScore {
        MesoScore := meso
        changed := true
    }
    if chat >= 0 && chat != ChatScore {
        ChatScore := chat
        changed := true
    }
    if changed {
        PublishState(true)
        ScheduleScoreSave()
    }
}

NormalizeScoreInputs(*) {
    global MesoScore, ChatScore, ScoreMesoEdit, ScoreChatEdit, ScoreUiBusy
    ScoreChanged()
    ScoreUiBusy := true
    try {
        ScoreMesoEdit.Value := MesoScore
        ScoreChatEdit.Value := ChatScore
    } finally ScoreUiBusy := false
}

AdjustTally(team, amount) {
    global MesoScore, ChatScore, ScoreMesoEdit, ScoreChatEdit, ScoreUiBusy
    ScoreChanged()
    ScoreUiBusy := true
    try {
        if team = "meso" {
            MesoScore := Max(0, Min(9999, MesoScore + amount))
            ScoreMesoEdit.Value := MesoScore
        } else if team = "chat" {
            ChatScore := Max(0, Min(9999, ChatScore + amount))
            ScoreChatEdit.Value := ChatScore
        } else
            return
    } finally ScoreUiBusy := false
    PublishState(true)
    ScheduleScoreSave()
}

ResetScores(*) {
    global MesoScore, ChatScore, ScoreMesoEdit, ScoreChatEdit, ScoreUiBusy
    ScoreUiBusy := true
    try {
        MesoScore := 0
        ChatScore := 0
        ScoreMesoEdit.Value := 0
        ScoreChatEdit.Value := 0
    } finally ScoreUiBusy := false
    PublishState(true)
    ScheduleScoreSave()
}

ScheduleScoreSave() {
    SetTimer(SaveScoreSettings, -300)
}

SaveScoreSettings(*) {
    global ConfigFile, ScoreVisible, MesoScore, ChatScore
    try {
        MesoIniWrite(ScoreVisible ? 1 : 0, ConfigFile, "Scoreboard", "Visible")
        MesoIniWrite(MesoScore, ConfigFile, "Scoreboard", "Meso")
        MesoIniWrite(ChatScore, ConfigFile, "Scoreboard", "Chat")
    } catch as err {
        LogEvent("Scoreboard settings write: " err.Message)
    }
}

ToggleGuides(*) {
    global Guides, GuideCheck
    Guides := GuideCheck.Value = 1
    PublishState(true)
}

ToggleStreamOutput(*) {
    global OutputCheck
    if OutputCheck.Value
        OpenStreamOutput(false)
    else
        CloseStreamOutput()
}

OpenStreamOutput(focus := true) {
    global OutputEnabled, OutputCheck, GuideCheck, OutputPid, OutputStopping, Closing
    if Closing
        return
    OutputEnabled := true
    OutputCheck.Value := 1
    GuideCheck.Enabled := true
    PublishState(true)
    CheckStreamOutput()
    if focus && !OutputStopping {
        h := StreamOutputWindow(OutputPid)
        if h {
            try WinRestore("ahk_id " h)
            try WinActivate("ahk_id " h)
        }
    }
}

CloseStreamOutput() {
    global OutputEnabled, OutputCheck, GuideCheck, OutputPid, OutputStopping
    OutputEnabled := false
    if IsSet(OutputCheck)
        try OutputCheck.Value := 0
    if IsSet(GuideCheck)
        try GuideCheck.Enabled := false
    if !OutputPid
        OutputPid := ExistingStreamOutputPid()
    if OutputPid && ProcessExist(OutputPid) {
        OutputStopping := true
        h := StreamOutputWindow(OutputPid)
        if h
            try PostMessage(0x8002, 0, 0,, "ahk_id " h)
    } else {
        OutputPid := 0
        OutputStopping := false
    }
}

CheckStreamOutput() {
    global OutputEnabled, OutputCheck, GuideCheck, OutputPid, OutputStopping, OutputManagementBusy, Closing
    if Closing || OutputManagementBusy
        return
    OutputManagementBusy := true
    try {
        if !OutputPid
            OutputPid := ExistingStreamOutputPid()
        if OutputPid {
            if ProcessExist(OutputPid) {
                if OutputStopping || !OutputEnabled {
                    OutputStopping := true
                    h := StreamOutputWindow(OutputPid)
                    if h
                        try PostMessage(0x8002, 0, 0,, "ahk_id " h)
                }
                return
            }
            requestedStop := OutputStopping
            OutputPid := 0
            OutputStopping := false
            if !requestedStop {
                OutputEnabled := false
                OutputCheck.Value := 0
                GuideCheck.Enabled := false
                return
            }
        }
        if OutputEnabled {
            args := Chr(34) A_AhkPath Chr(34) " " Chr(34) A_ScriptDir "\Meso_Stream_Output.ahk" Chr(34)
            Run(args, A_ScriptDir, "", &OutputPid)
        }
    } catch as err {
        OutputEnabled := false
        OutputCheck.Value := 0
        GuideCheck.Enabled := false
        OutputPid := 0
        OutputStopping := false
        LogEvent("Stream output could not open: " err.Message)
        MsgBox("The stream output could not open.`n`n" err.Message, "Meso Stream Output")
    } finally {
        OutputManagementBusy := false
        UpdateOutputHealth()
    }
}

UpdateOutputHealth() {
    global OutputStatusLabel, OutputEnabled, OutputStopping, OutputPid, RuntimeDir
    UpdateChrome()
    if !IsSet(OutputStatusLabel) || !IsObject(OutputStatusLabel)
        return
    if !OutputEnabled {
        SetText(OutputStatusLabel, OutputStopping ? "Output: closing" : "Output: off")
        return
    }
    text := "Output: connecting..."
    try {
        row := Trim(FileRead(RuntimeDir "\output-health.info", "UTF-8"), "`r`n")
        f := Fields(row)
        if f.Length >= 4 && Integer(f[1]) = OutputPid {
            if NowMs() - (f[2] + 0) > 5000
                text := "Output: waiting for renderer"
            else if f[3] = "error"
                text := "Output error: " f[4]
            else if f[3] = "connected"
                text := "Output: connected - " f[4]
            else
                text := "Output: " f[4]
        }
    }
    SetText(OutputStatusLabel, SubStr(text, 1, 98))
}

StreamOutputWindow(pid) {
    if !pid
        return 0
    previous := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
        for h in WinGetList("ahk_pid " pid) {
            try {
                if WinGetTitle("ahk_id " h) = "Meso Stream Output" && WinGetClass("ahk_id " h) = "AutoHotkeyGUI"
                    return h
            }
        }
    } finally DetectHiddenWindows(previous)
    return 0
}

ExistingStreamOutputPid() {
    global RuntimeDir
    if !FileExist(RuntimeDir "\output.info")
        return 0
    try {
        info := StrSplit(FileRead(RuntimeDir "\output.info", "UTF-8"), "`n")
        if info.Length < 3
            return 0
        if StrLower(Trim(info[3], "`r`n ")) != StrLower(A_ScriptDir "\Meso_Stream_Output.ahk")
            return 0
        pid := Integer(Trim(info[1], "`r "))
        h := Integer(Trim(info[2], "`r "))
        if pid && ProcessExist(pid) && StreamOutputWindow(pid) = h
            return pid
    }
    return 0
}

PublishState(force := false) {
    global ActiveScare
    EnsureScareState()
    global Queue, Clock, Slots, ActiveEffects, Guides, LastPublished, LastPublishTick, PublisherRevision, RuntimeDir, ScoreVisible, MesoScore, ChatScore, HorrorEvents, ViewerVisible, WheelDisplayMode, TtsEnabled, Sonion
    now := NowMs()
    body := Line("status", Queue.Count(), Queue.Paused, Guides)
    body .= SpecialAudioState(now)
    visibleScare := IsObject(ActiveScare) ? ActiveScare : IsObject(Sonion) && IsObject(Sonion.Scare) ? Sonion.Scare : 0
    if IsObject(visibleScare)
        body .= Line("scare", visibleScare.Name, visibleScare.Start, visibleScare.End)
    body .= Line("score", ScoreVisible ? 1 : 0, MesoScore, ChatScore)
    glitch := IsObject(Sonion) && !Sonion.Preview && Sonion.Phase = "glitch"
    if IsObject(Queue.Active) && Queue.Active.HasOwnProp("Pool") {
        j := Queue.Active
        phase := j.Phase = "result" && now >= j.VisualUntil ? "idle" : j.Phase
        body .= Line("wheel", phase, j.HasOwnProp("DisplayId") ? j.DisplayId : j.Id, j.Start, j.Angle, j.P.Name, j.Index, j.Preview, ViewerVisible ? j.Viewer : "", ViewerVisible ? 1 : 0, WheelDisplayMode, TtsEnabled ? 1 : 0)
        for p in j.Pool
            body .= Line("item", p.Name, p.Weight)
        if j.HasOwnProp("FirstResult") && phase != "idle"
            body .= Line("first", j.FirstResult.Name)
        if j.HasOwnProp("Bonus") && phase = "result"
            body .= Line("bonus", j.Bonus.Name, j.BonusStart)
    } else {
        displayId := glitch ? "sonion-" Sonion.Start : ""
        body .= Line("wheel", "idle", displayId, 0, 0, "", 0, 0, "", ViewerVisible ? 1 : 0, WheelDisplayMode, TtsEnabled ? 1 : 0)
        if glitch {
            for p in Sonion.GlitchDisplay
                body .= Line("item", p.Name, p.Weight)
        }
    }
    if glitch
        body .= Line("glitch", Sonion.Start, Sonion.Deadline)
    body .= Line("slots", Slots.Phase, Slots.Id, Slots.Start, Slots.Mode, Slots.Reel, Slots.Locked, Slots.HoldUntil, Slots.Values*)
    for i, pool in Slots.Pools
        body .= Line("pool", i, pool*)
    body .= Line("timer", Clock.Phase, Clock.Deadline, Clock.Total, Clock.ClearAt)
    for event in HorrorEvents
        body .= Line("horror", event.Id, event.Due)
    if ActiveEffects.Length {
        for item in ActiveEffects
            body .= Line("active", item.P.Name, item.End, item.Preview ? "" : item.Note, item.Start, item.P.HasOwnProp("BonusPair") ? 1 : 0)
    } else
        body .= PublishCooldown(now)
    if body = LastPublished && !force && now - LastPublishTick < 1000
        return
    PublisherRevision += 1
    snapshot := Line("meta", PublisherRevision, ProcessExist(), now) body
    try {
        WriteAtomic(RuntimeDir "\output.state", snapshot)
        LastPublished := body
        LastPublishTick := now
    } catch as err {
        LogEvent("Output state write: " err.Message)
    }
}

ScheduleHorror(due) {
    global HorrorEvents
    HorrorEvents.Push({Id: NewId(), Due: due})
    PublishState(true)
    LogEvent("Sequence scheduled")
}

SaveAppSettings() {
    global ConfigFile, WheelControllerEnabled, DestinyOnlyMode, GameInputMethod, PrepTimeValue, ActivityTimeValue, TickSoundPath, LandSoundPath, TickVolume, LandVolume
    global SlotTickSoundPath, SlotLandSoundPath, SlotTickVolume, SlotLandVolume, HorrorVolume, FigureVolume, SequenceVolume, TtsVolume, TtsEnabled, ViewerVisible, WheelDisplayMode, SlotAutoRoll, SpinAnnouncementVolume
    global CurrentPunishmentProfile, CurrentActivityProfile
    MesoIniWrite(WheelControllerEnabled ? 1 : 0, ConfigFile, "Wheel", "ControllerEnabled")
    MesoIniWrite(DestinyOnlyMode ? 1 : 0, ConfigFile, "Wheel", "DestinyOnly")
    MesoIniWrite(GameInputMethod, ConfigFile, "Wheel", "InputMethod")
    MesoIniWrite(PrepTimeValue, ConfigFile, "ActivityTimer", "PrepTime")
    MesoIniWrite(ActivityTimeValue, ConfigFile, "ActivityTimer", "ActivityTime")
    MesoIniWrite(TickSoundPath, ConfigFile, "Wheel", "TickSound")
    MesoIniWrite(LandSoundPath, ConfigFile, "Wheel", "LandSound")
    MesoIniWrite(TickVolume, ConfigFile, "Wheel", "TickVolume")
    MesoIniWrite(LandVolume, ConfigFile, "Wheel", "LandVolume")
    MesoIniWrite(ViewerVisible ? 1 : 0, ConfigFile, "Wheel", "ViewerVisible")
    MesoIniWrite(WheelDisplayMode, ConfigFile, "Wheel", "DisplayMode")
    MesoIniWrite(SequenceVolume, ConfigFile, "Audio", "SequenceVolume")
    MesoIniWrite(SequenceVolume, ConfigFile, "Audio", "HorrorVolume")
    MesoIniWrite(SequenceVolume, ConfigFile, "Audio", "FigureVolume")
    MesoIniWrite(TtsVolume, ConfigFile, "Audio", "TtsVolume")
    MesoIniWrite(SpinAnnouncementVolume, ConfigFile, "Audio", "SpinAnnouncementVolume")
    MesoIniWrite(TtsEnabled ? 1 : 0, ConfigFile, "Audio", "TtsEnabled")
    MesoIniWrite(SlotTickSoundPath, ConfigFile, "Slots", "TickSound")
    MesoIniWrite(SlotLandSoundPath, ConfigFile, "Slots", "LandSound")
    MesoIniWrite(SlotAutoRoll ? 1 : 0, ConfigFile, "Slots", "AutoRoll")
    MesoIniWrite(SlotTickVolume, ConfigFile, "Slots", "TickVolume")
    MesoIniWrite(SlotLandVolume, ConfigFile, "Slots", "LandVolume")
    MesoIniWrite(CurrentPunishmentProfile, ConfigFile, "Profiles", "Punishments")
    MesoIniWrite(CurrentActivityProfile, ConfigFile, "Profiles", "Activities")
    SaveScoreSettings()
}

SavePending() {
    global Queue, RuntimeDir, DirectPending
    text := ""
    loop Queue.Count() {
        p := Queue.Pending[Queue.Head + A_Index - 1]
        text .= Line(p.Id, p.Preview, p.Viewer, p.Remote, p.HasOwnProp("Spins") ? p.Spins : 1)
    }
    WriteAtomic(RuntimeDir "\pending.state", text)
    direct := ""
    for item in DirectPending
        direct .= Line(item.Id, item.Viewer, item.Slot, item.Profile)
    WriteAtomic(RuntimeDir "\pending-direct.state", direct)
}

RestorePending() {
    global Queue, RuntimeDir, DirectPending
    try {
        text := FileRead(RuntimeDir "\pending.state", "UTF-8")
        for row in StrSplit(text, "`n") {
            f := Fields(row)
            if f.Length >= 2 && f[1] != ""
                Queue.Accept(f[1], f[2] = "1", NowMs(), f.Length >= 3 ? NormalizeViewer(f[3]) : "", f.Length >= 4 ? f[4] = "1" : false, f.Length >= 5 && f[5] = "2" ? 2 : 1)
        }
        FileDelete(RuntimeDir "\pending.state")
        if Queue.Count()
            Queue.Paused := true
    }
    try {
        text := FileRead(RuntimeDir "\pending-direct.state", "UTF-8")
        for row in StrSplit(text, "`n") {
            f := Fields(row)
            if f.Length != 4 || !RegExMatch(f[3], "^[1-5]$")
                continue
            p := DirectPunishment(Integer(f[3]), f[4])
            if IsObject(p) && !Queue.Seen.Has(f[1]) {
                DirectPending.Push({P: p.Clone(), Id: f[1], Viewer: f[2], Slot: Integer(f[3]), Profile: f[4]})
                Queue.Seen[f[1]] := NowMs()
            }
        }
        FileDelete(RuntimeDir "\pending-direct.state")
        if DirectPending.Length
            Queue.Paused := true
    }
}

RefreshApp(*) {
    global Refreshing
    SaveAppSettings()
    SavePending()
    CancelEffects("Refresh")
    StopRecording()
    Refreshing := true
    Reload()
}

OpenInteractDelay(*) {
    DetectHiddenWindows(true)
    h := WinExist("Interact Delay ahk_class AutoHotkeyGUI")
    if h {
        WinShow("ahk_id " h)
        WinActivate("ahk_id " h)
        return
    }
    path := A_ScriptDir "\InteractDelay\Interact_Delay.ahk"
    if FileExist(path)
        Run(Chr(34) A_AhkPath Chr(34) " " Chr(34) path Chr(34), A_ScriptDir "\InteractDelay")
    else
        MsgBox("Interact Delay was not found in the InteractDelay folder.", "Meso Control")
}

Shutdown(reason, code) {
    global Closing, Refreshing, Queue, RuntimeDir, SharedLargeIcon, SharedSmallIcon
    if Closing
        return
    Closing := true
    SetTimer(SaveScoreSettings, 0)
    SetTimer(ReadWheelRelay, 0)
    SetTimer(ReadChatRelay, 0)
    SetTimer(EngineTick, 0)
    SetTimer(CheckStreamOutput, 0)
    SetTimer(TrackActiveWindow, 0)
    SetTimer(AltTabFailsafe, 0)
    SetTimer(HighlightAnimationTick, 0)
    SetTimer(AltTabMouseTick, 0)
    StopEditorKeyCapture()
    StopSharedKeyCapture()
    CloseStreamSettings()
    CancelEffects("Exit")
    StopRecording()
    CloseAltTabGui()
    try SaveAppSettings()
    if !Refreshing
        try SavePending()
    CloseStreamOutput()
    try FileDelete(RuntimeDir "\controller.info")
}

RestartElevated(*) {
    global Queue, OutputEnabled
    if HasEffects() || IsObject(Queue.Active) {
        MsgBox("Finish the active punishment first.", "Meso Control")
        return
    }
    try {
        Run("*RunAs " UpdateQuote(A_AhkPath) " " UpdateQuote(A_ScriptFullPath) (OutputEnabled ? " --restore-output" : ""), A_ScriptDir)
    } catch as err {
        LogEvent("Administrator restart did not start: " err.Message)
    }
}
