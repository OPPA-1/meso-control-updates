#Requires AutoHotkey v2.0 64-bit
; The validation job copies this harness beside Meso_Control.ahk.
OnError((err, mode) => (FileAppend(err.Message " (" err.File ":" err.Line ")" Chr(10), A_ScriptDir "\session-test-error.txt"), ExitApp(1)))
IniWrite(0,A_ScriptDir "\Meso_Chaos.ini","Updates","ForceAuto")
FileAppend("Harness started" Chr(10),A_ScriptDir "\session-test-progress.txt")
SetTimer(PrepareSessionTest614,-1000)
#Include Meso_Control.ahk

PrepareSessionTest614() {
    global Updates, WheelControllerEnabled, ConfigFile, RuntimeDir, Queue, Clock, Slots, Guides, VisualHits, AppGui, OutputPid
    global UpdateInstallButton, RoundBonusChance, RoundBonusCheck, EditorRange, EditorValue
    global ScareLocalSlider, ScareStreamSlider, EditorAction, EditorGrid, EditorVary, EditorDuration, ScareLocalVolume, ScareStreamVolume
    try {
        Updates.AutoCheck := false
        WheelControllerEnabled := false
        FileAppend("Opening Settings" Chr(10),A_ScriptDir "\session-test-progress.txt")
        OpenSettings()
        ScareLocalSlider.Value := 0
        ScareStreamSlider.Value := 82
        SaveSoundSettings()
        if ScareVolume()!=0 || ScareVolume(true)!=82
            throw Error("Audio controls did not save independent volume values")
        for index, action in ActionNames()
            if action="Sliding Puzzle"
                EditorAction.Choose(index)
        UpdateEditorHint()
        if EditorGrid.Text!="3x3" || EditorDuration.Visible
            throw Error("Puzzle controls did not default to fixed 3x3 without a duration")
        EditorVary.Value := 1
        UpdateEditorHint()
        if EditorGrid.Enabled
            throw Error("Random puzzle mode must disable the fixed grid")
        EditorVary.Value := 0
        UpdateEditorHint()
        EditorGrid.Choose(2)
        if EditorGrid.Text!="4x4"
            throw Error("Puzzle grid list must offer 4x4")
        for index, action in ActionNames()
            if action="Invert Screen"
                EditorAction.Choose(index)
        UpdateEditorHint()
        EditorVary.Value := 0
        UpdateEditorHint()
        for index, choice in FlipChoices() {
            EditorGrid.Choose(index)
            if EditorGrid.Text!=choice || !EditorGrid.Enabled
                throw Error("Screen flip choices were not usable")
        }
        EditorVary.Value := 1
        UpdateEditorHint()
        if EditorGrid.Enabled || EditorVary.Text!="Random"
            throw Error("Random screen flip controls did not update")
        for index, action in ActionNames()
            if action="Hazy Vision"
                EditorAction.Choose(index)
        EditorVary.Value := 0
        UpdateEditorHint()
        if EditorVary.Text!="Random" || !EditorValue.Enabled || EditorRange.Text!="1 to 40"
            throw Error("Hazy Vision settings do not show their fixed strength range")
        RoundBonusChance.Value := 27.5
        RoundBonusCheck.Value := 1
        SaveRoundSettings()
        if IniRead(ConfigFile,"Rounds","BonusChance")!="27.5"
            throw Error("The bonus chance control did not persist its value")
        FileAppend("Settings verified" Chr(10),A_ScriptDir "\session-test-progress.txt")
        CloseSettings()
        AppGui.Hide()
        WheelControllerEnabled := true
        Queue.Accept("emergency-hidden-window",false,NowMs(),"meso",true,1)
        RequestInteractionEmergency()
        deadline := NowMs()+1500
        while WheelControllerEnabled && NowMs()<deadline
            Sleep(20)
        if WheelControllerEnabled || Queue.Count()
            throw Error("Emergency stop did not reach the hidden controller")
        Queue.Accept("pending-session-612",false,NowMs(),"meso",true,2)
        Queue.Paused := false
        Queue.Completed := 7
        Queue.Seen["already-redeemed-session-612"] := NowMs()
        Clock.Phase := "ready"
        Clock.Generation := 11
        Slots.Phase := "idle", Slots.Locked := 4, Slots.Id := "activity-session-612"
        Slots.Values := ["RAID","LAST WISH","FULL CLEAR","TITAN"]
        Guides := true
        VisualHits := Map("Lights Out",3,"Tunnel Vision",2,"Wide View",1)
        AppGui.Hide()
        OpenStreamOutput(false)
        deadline := NowMs()+7000
        while (!OutputPid || !StreamOutputWindow(OutputPid)) && NowMs()<deadline
            Sleep(50)
        if !OutputPid || !StreamOutputWindow(OutputPid)
            throw Error("Stream output did not open")
        WriteAtomic(RuntimeDir "\session-test-original.state",Line(ProcessExist(),OutputPid))
        FileAppend("Requesting quiet update" Chr(10),A_ScriptDir "\session-test-progress.txt")
        SetTimer(DumpSessionTest614,500)
        DumpSessionTest614()
        OpenSettings()
        Updates.Requested := true
        RefreshUpdateStatus()
        if !UpdateInstallButton.Enabled
            throw Error("A staged update must remain installable while Settings is open")
        Updates.Requested := false
        Updates.AutoCheck := true
        Updates.ReadyAt := NowMs()-2000
        WriteAtomic(RuntimeDir "\session-test-ready.state","ready")
    } catch as err {
        FileAppend(err.Message " (" err.File ":" err.Line ")" Chr(10),A_ScriptDir "\session-test-error.txt")
        ExitApp(1)
    }
}

DumpSessionTest614() {
    global Updates, RuntimeDir, Queue, Rounds, Recorder, DirectPending, Clock, Slots, SettingsGui, OutputPid
    body := "can=" UpdateCanInstall(NowMs()) " sequence=" SequenceBusy() " ready=" Updates.Ready " requested=" Updates.Requested " pid=" Updates.Pid " output=" OutputPid " prepare=" Updates.OutputPrepareAt
    body .= Chr(10) "active=" IsObject(Queue.Active) " effects=" HasEffects() " direct=" DirectPending.Length " recorder=" Recorder.Phase " round=" Rounds.Phase " clock=" Clock.Phase " slots=" Slots.Phase " settings=" GuiHwndSafe(SettingsGui)
    body .= Chr(10) Updates.Message
    WriteAtomic(RuntimeDir "\session-test-engine.state",body)
}
