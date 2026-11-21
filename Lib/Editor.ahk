

PunishmentProfileSafe(name) {
    name := Trim(String(name))
    if name = ""
        return "Default"
    name := SubStr(RTrim(RegExReplace(name, '[\\/:*?"<>|]', '_'), " ."), 1, 48)
    return name = "" ? "Default" : name
}

PunishmentProfilePath(profile := "") {
    global ConfigFile, ProfilesDir, CurrentPunishmentProfile
    if profile = ""
        profile := CurrentPunishmentProfile
    profile := PunishmentProfileSafe(profile)
    return profile = "Default" ? ConfigFile : ProfilesDir "\punishments_" profile ".ini"
}

LoadPunishmentProfileNames() {
    global ProfilesDir
    names := ["Default"]
    if DirExist(ProfilesDir) {
        loop files ProfilesDir "\punishments_*.ini" {
            name := RegExReplace(A_LoopFileName, '^punishments_(.*)\.ini$', '$1')
            if name != "" && name != "Default"
                names.Push(name)
        }
    }
    return names
}

RefreshPunishmentProfileDrop() {
    global PunishmentProfileDrop, CurrentPunishmentProfile
    if !IsSet(PunishmentProfileDrop) || !IsObject(PunishmentProfileDrop)
        return
    names := LoadPunishmentProfileNames()
    PunishmentProfileDrop.Delete()
    PunishmentProfileDrop.Add(names)
    idx := 1
    for i, n in names
        if n = CurrentPunishmentProfile
            idx := i
    PunishmentProfileDrop.Choose(idx)
}

SetPunishmentProfile(name) {
    global CurrentPunishmentProfile, Punishments
    name := PunishmentProfileSafe(name)
    CurrentPunishmentProfile := name
    Punishments := LoadAndMigratePunishments()
    SaveAppSettings()
    RefreshPunishmentProfileDrop()
    RefreshSettingsList()
    PublishState(true)
}

PunishmentProfileChanged(*) {
    global PunishmentProfileDrop
    SetPunishmentProfile(PunishmentProfileDrop.Text)
}

NewPunishmentProfile(*) {
    global Punishments
    ib := InputBox('Enter a profile name.', 'New punishment profile', 'w280 h120')
    if ib.Result != 'OK'
        return
    name := PunishmentProfileSafe(ib.Value)
    if name = ""
        return
    existing := Map()
    for item in LoadPunishmentProfileNames()
        existing[item] := true
    if existing.Has(name) {
        SetPunishmentProfile(name)
        return
    }
    SavePunishmentList(Punishments, name)
    SetPunishmentProfile(name)
}

DeletePunishmentProfile(*) {
    global CurrentPunishmentProfile
    if CurrentPunishmentProfile = 'Default' {
        MsgBox('The Default profile cannot be deleted.', 'Punishment profiles')
        return
    }
    if MsgBox('Delete profile "' CurrentPunishmentProfile '"?', 'Punishment profiles', 'YesNo Icon?') != 'Yes'
        return
    path := PunishmentProfilePath(CurrentPunishmentProfile)
    try FileDelete(path)
    SetPunishmentProfile('Default')
}

DefaultPunishments() {
    return [
        {Name: "Movement Jam", Enabled: true, Duration: 5, Weight: 5, Action: "Movement Jam", Keys: "w;s;a;d", Value: 0},
        {Name: "Crouch Frenzy", Enabled: true, Duration: 6, Weight: 5, Action: "Spam Crouch", Keys: "LControl", Value: 0},
        {Name: "Exit Game", Enabled: true, Duration: 3, Weight: 1, Action: "Exit Desktop", Keys: "+{Esc};{Enter}", Value: 0},
        {Name: "Trigger Happy", Enabled: true, Duration: 2, Weight: 5, Action: "Random Shoot", Keys: "LButton", Value: 0},
        {Name: "Weapon Shuffle", Enabled: true, Duration: 5, Weight: 5, Action: "Cycle Keys", Keys: "1;2;3", Value: 0},
        {Name: "Floor Shot", Enabled: true, Duration: 3, Weight: 5, Action: "Look Down + Shoot", Keys: "LButton", Value: 0},
        {Name: "Spin Cycle", Enabled: true, Duration: 3, Weight: 5, Action: "Spin 360", Keys: "", Value: 180},
        {Name: "Inventory Panic", Enabled: true, Duration: 2, Weight: 5, Action: "Inventory Spam", Keys: "i", Value: 0},
        {Name: "Super Burn", Enabled: true, Duration: 3, Weight: 2, Action: "Use Super", Keys: "f", Value: 0},
        {Name: "Bounce House", Enabled: true, Duration: 7, Weight: 5, Action: "Spam Jump", Keys: "Space", Value: 0},
        {Name: "Time Tax -2:00", Enabled: true, Duration: 3, Weight: 5, Action: "Time Tax", Keys: "", Value: 120},
        {Name: "Sliding Puzzle", Enabled: true, Duration: 1, Weight: 2, Action: "Sliding Puzzle", Keys: "", Value: 0, Grid: "3x3", Vary: false},
        {Name: "Jumpscare", Enabled: true, Duration: 1, Weight: 2, Action: "Jumpscare", Keys: "", Value: 0},
        {Name: "Send Chat", Enabled: true, Duration: 3, Weight: 5, Action: "Send Chat", Keys: "Enter", Value: 0},
        {Name: "Return to Orbit", Enabled: true, Duration: 5, Weight: 5, Action: "Return to Orbit", Keys: "Tab;o", Value: 0},
        {Name: "Lights Out", Enabled: true, Duration: 8, Weight: 2, Action: "Lights Out", Keys: "", Value: 210},
        {Name: "Tunnel Vision", Enabled: true, Duration: 8, Weight: 2, Action: "Tunnel Vision", Keys: "", Value: 2},
        {Name: "Screen Shuffle", Enabled: true, Duration: 8, Weight: 2, Action: "Screen Shuffle", Keys: "", Value: 0},
        {Name: "Invert Screen", Enabled: true, Duration: 8, Weight: 2, Action: "Invert Screen", Keys: "", Value: 0},
        {Name: "Drunk Vision", Enabled: true, Duration: 8, Weight: 2, Action: "Drunk Vision", Keys: "", Value: 3},
        {Name: "Loadout Roulette", Enabled: true, Duration: 4, Weight: 4, Action: "Random Loadout", Keys: "", Value: 12},
        {Name: "Turn Keyboard Off", Enabled: true, Duration: 5, Weight: 4, Action: "Turn Keyboard Off", Keys: "", Value: 0},
        {Name: "Alt+Enter", Enabled: true, Duration: 5, Weight: 3, Action: "Alt+Enter", Keys: "", Value: 1},
        {Name: "Wide View", Enabled: true, Duration: 8, Weight: 2, Action: "Wide View", Keys: "", Value: 0.25},
        {Name: "Change Mouse Sensitivity", Enabled: true, Duration: 8, Weight: 3, Action: "Change Mouse Sensitivity", Keys: "", Value: 0.5, Vary: true},
        {Name: "Chat Takes Control", Enabled: true, Duration: 30, Weight: 5, Action: "Chat Control", Keys: "", Value: 0}
    ]
}

ActionNames() {
    return ["Sliding Puzzle", "Jumpscare", "Movement Jam", "Spam Crouch", "Spam Jump", "Exit Desktop", "Random Shoot", "Cycle Keys", "Look Down + Shoot", "Spin 360", "Inventory Spam", "Use Super", "Time Tax", "Send Chat", "Return to Orbit", "Lights Out", "Tunnel Vision", "Screen Shuffle", "Invert Screen", "Drunk Vision", "Random Loadout", "Recorded Sequence", "Custom Sequence", "Spam Key", "Chat Control", "Turn Keyboard Off", "Alt+Enter", "Wide View", "Change Mouse Sensitivity"]
}

LoadAndMigratePunishments() {
    global ConfigFile, CurrentPunishmentProfile
    defaults := DefaultPunishments()
    path := PunishmentProfilePath()
    migrating := IniRead(path, "Meta", "Schema", "0") != "3"
    legacyTiming := IniRead(path, "Meta", "Feature603", "0") != "1"
    needsSave := migrating || legacyTiming
    count := IniRead(path, "Punishments", "Count", "0") + 0
    result := []
    exists := Map()
    if path = ConfigFile && FileExist(path) && IniRead(path, "Meta", "Schema", "0") != "3" && !FileExist(path ".before-v3.bak")
        FileCopy(path, path ".before-v3.bak")
    loop Min(Max(0, count), 200) {
        section := "P" A_Index
        action := IniRead(path, section, "Action", "Custom Sequence")
        name := IniRead(path, section, "Name", "Custom " A_Index)
        keys := IniRead(path, section, "Keys", "")
        if action = "Turn M&K Off" {
            action := "Turn Keyboard Off"
            if name = "Turn M&K Off"
                name := "Turn Keyboard Off"
            needsSave := true
        }
        if action = "Chat Confession"
            action := "Send Chat"
        if name = "Chat Confession"
            name := "Send Chat"
        if action = "Swap Mouse Buttons" {
            action := "Movement Jam"
            name := "Movement Jam"
            keys := "w;s;a;d"
        }
        if action = "Spam Key" && (name = "Spam Crouch" || name = "Crouch Frenzy")
            action := "Spam Crouch"
        renames := Map("Spam Crouch", "Crouch Frenzy", "Exit to Desktop", "Exit Game", "Random Shooting", "Trigger Happy", "Loadout Shuffle", "Weapon Shuffle", "Look Down + Shoot", "Floor Shot", "Spin 360", "Spin Cycle", "Inventory Spam", "Inventory Panic", "Use Super", "Super Burn", "Spam Jump", "Bounce House")
        if renames.Has(name)
            name := renames[name]
        duration := IniRead(path, section, "Duration", "3")
        if action = "Return to Orbit" && (!IsNumber(duration) || Float(duration) < 5) {
            duration := "5"
            needsSave := true
        }
        if action = "Random Loadout" && (!IsNumber(duration) || Float(duration) < 4) {
            duration := "4"
            needsSave := true
        }
        weight := IniRead(path, section, "Weight", "5")
        value := IniRead(path, section, "Value", "0")
        if legacyTiming && action = "Alt+Enter" && name = "Alt+Enter" && IsNumber(duration) && Float(duration) = 3 && IsNumber(value) && Float(value) = 0
            duration := 5
        p := {Name: name, Enabled: IniRead(path, section, "Enabled", "1") = "1", Duration: IsNumber(duration) ? Max(0.1, Min(300, Float(duration))) : 3, Weight: IsNumber(weight) ? Max(0, Min(100, Float(weight))) : 5, Action: action, Keys: keys, Value: IsNumber(value) ? Float(value) : 0, Vary: IniRead(path, section, "Vary", action = "Change Mouse Sensitivity" ? "1" : "0") = "1", Grid: action = "Sliding Puzzle" ? SlidingPuzzleGrid(IniRead(path, section, "Grid", "3x3")) : PunishmentGrid(IniRead(path, section, "Grid", "2x3"))}
        result.Push(p)
        exists[action] := true
    }
    if migrating {
        for p in defaults
            if !exists.Has(p.Action) && result.Length < 200
                result.Push(p)
    }
    if IniRead(path, "Meta", "ChatControlAdded", "0") != "1" {
        found := false
        for p in result
            if p.Action = "Chat Control"
                found := true
        if !found
            result.Push({Name: "Chat Takes Control", Enabled: true, Duration: 30, Weight: 5, Action: "Chat Control", Keys: "", Value: 0})
        needsSave := true
    }
    if IniRead(path, "Meta", "Feature520", "0") != "1" {
        for candidate in defaults {
            if candidate.Action = "Screen Shuffle" || candidate.Action = "Random Loadout" {
                found := false
                for existing in result
                    if existing.Action = candidate.Action
                        found := true
                if !found
                    result.Push(candidate.Clone())
            }
        }
        needsSave := true
    }
    if IniRead(path, "Meta", "Feature522", "0") != "1" {
        for candidate in defaults {
            if candidate.Action != "Invert Screen" && candidate.Action != "Drunk Vision"
                continue
            found := false
            for existing in result {
                if existing.Action = candidate.Action {
                    found := true
                    break
                }
            }
            if !found
                result.Push(candidate.Clone())
        }
        needsSave := true
    }
    if IniRead(path, "Meta", "Feature600", "0") != "1" {
        for p in defaults
            if IsNew600Action(p.Action) && !exists.Has(p.Action) && !migrating && result.Length < 200
                result.Push(p.Clone())
        needsSave := true
    }
    if IniRead(path, "Meta", "Feature610", "0") != "1" {
        foundScare := false
        for p in result
            if p.Action = "Jumpscare"
                foundScare := true
        if !foundScare && result.Length < 200
            for p in defaults
                if p.Action = "Jumpscare"
                    result.Push(p.Clone())
        needsSave := true
    }
    if IniRead(path, "Meta", "Feature612", "0") != "1" {
        if !exists.Has("Sliding Puzzle") && result.Length < 200
            for p in defaults
                if p.Action = "Sliding Puzzle"
                    result.Push(p.Clone())
        needsSave := true
    }
    if needsSave {
        try SavePunishmentList(result)
        catch as err
            LogEvent("Punishment profile migration could not save: " err.Message)
    }
    return result
}

SavePunishmentList(list, profile := "") {
    path := PunishmentProfilePath(profile)
    Critical("On")
    staged := ""
    try {
        staged := StageIniFile(path)
        old := IniRead(staged, "Punishments", "Count", "0") + 0
        loop Max(0, Min(old, 200))
            try IniDelete(staged, "P" A_Index)
        IniWrite(list.Length, staged, "Punishments", "Count")
        for i, p in list {
            sec := "P" i
            IniWrite(p.Name, staged, sec, "Name")
            IniWrite(p.Enabled ? 1 : 0, staged, sec, "Enabled")
            IniWrite(p.Action = "Return to Orbit" ? Max(5, p.Duration) : p.Duration, staged, sec, "Duration")
            IniWrite(p.Weight, staged, sec, "Weight")
            IniWrite(p.Action, staged, sec, "Action")
            IniWrite(p.Keys, staged, sec, "Keys")
            IniWrite(p.Value, staged, sec, "Value")
            IniWrite(PunishmentVaries(p) ? 1 : 0, staged, sec, "Vary")
            IniWrite(p.HasOwnProp("Grid") ? p.Grid : "2x3", staged, sec, "Grid")
        }
        for p in list {
            if p.Action = "Turn Keyboard Off" && p.Name = "Turn Keyboard Off" {
                loop 5
                    if IniRead(staged, "DirectRedeems", "Slot" A_Index, "") = "Turn M&K Off"
                        IniWrite(p.Name, staged, "DirectRedeems", "Slot" A_Index)
                break
            }
        }
        IniWrite("3", staged, "Meta", "Schema")
        IniWrite("1", staged, "Meta", "ChatControlAdded")
        IniWrite("1", staged, "Meta", "Feature520")
        IniWrite("1", staged, "Meta", "Feature522")
        IniWrite("1", staged, "Meta", "Feature600")
        IniWrite("1", staged, "Meta", "Feature603")
        IniWrite("1", staged, "Meta", "Feature610")
        IniWrite("1", staged, "Meta", "Feature612")
        CommitIniFile(staged, path)
        return true
    } finally {
        Critical("Off")
        if staged != "" && FileExist(staged)
            try FileDelete(staged)
    }
}

SavePunishments() {
    global Punishments, CurrentPunishmentProfile
    try {
        SavePunishmentList(Punishments, CurrentPunishmentProfile)
        return true
    } catch as err {
        LogEvent("Punishments could not save: " err.Message)
        MsgBox("Could not save punishment settings. Check file permissions or close other programs using the INI file, then retry.", "Meso settings", "Iconx")
        return false
    }
}

DarkTable(lv) {
    h := lv.Hwnd
    DllCall("uxtheme\SetWindowTheme", "Ptr", h, "WStr", "", "WStr", "")
    SendHwnd(h, 0x1001, 0, 0x25101A)
    SendHwnd(h, 0x1026, 0, 0x25101A)
    SendHwnd(h, 0x1024, 0, 0xFFF0F0)
    SendHwnd(h, 0x1036, 0x10000, 0x10000)
    header := SendHwnd(h, 0x101F)
    if header {
        style := DllCall("user32\GetWindowLongPtrW", "Ptr", header, "Int", -16, "Ptr")
        DllCall("user32\SetWindowLongPtrW", "Ptr", header, "Int", -16, "Ptr", style | 0x0800, "Ptr")
    }
}

OpenSettings(*) {
    global SettingsGui, SettingsLV, EditorName, EditorEnabled, EditorDuration, EditorWeight, EditorAction, EditorKeys, EditorValue, SelectedEditorIndex
    global TickPathEdit, LandPathEdit, TickSlider, LandSlider, TickSoundPath, LandSoundPath, TickVolume, LandVolume
    global SlotTickPathEdit, SlotLandPathEdit, SlotTickSlider, SlotLandSlider, SlotTickSoundPath, SlotLandSoundPath, SlotTickVolume, SlotLandVolume
    global EditorBindButton, InputMethodDrop, GameInputMethod, ModeDrop, WheelDisplayMode, AutoCheck, SlotAutoRoll, DestinyCheck, DestinyOnlyMode, SettingsGuideCheck, Guides, OutputEnabled
    global SequenceSlider, TtsSlider, SequenceVolumeLabel, TtsVolumeLabel, SpeakCheck, ViewerCheck, SequenceVolume, TtsVolume, TtsEnabled, ViewerVisible, SpinAnnouncementVolume, AnnouncementSlider, AnnouncementLabel
    global PunishmentProfileDrop, EditorVary, EditorGrid, EditorKeyLabel, EditorValueLabel, EditorRawKeys, EditorRange, RawAccelButton, EditorChatTest
    if GuiHwndSafe(SettingsGui) {
        SettingsGui.Show()
        return
    }
    SelectedEditorIndex := 0
    SettingsGui := Gui("-MaximizeBox", "Meso Control  |  Settings")
    SettingsGui.BackColor := "100D17"
    SettingsGui.MarginX := 0
    SettingsGui.MarginY := 0
    SettingsGui.SetFont("s17 Bold cF4EDF9", "Segoe UI")
    SettingsGui.AddText("x26 y20 w570 h35", "SETTINGS")
    SettingsGui.SetFont("s9 Norm cB5A5C9", "Segoe UI")
    SettingsGui.AddText("x27 y56 w240 h20", "MESO CONTROL")
    SettingsGui.SetFont("s10 Norm cEDE7F7", "Segoe UI")
    tab := SettingsGui.AddTab3("x20 y88 w784 h555", ["Punishments", "Activities", "Audio", "Stream", "Display", "Sequence", "Rounds", "Chat", "Updates", "Keybinds"])
    tab.UseTab(1)
    SettingsGui.SetFont("s9 cD3C5E4", "Segoe UI")
    SettingsGui.AddText("x35 y139 w70 h22", "PROFILE")
    PunishmentProfileDrop := SettingsGui.AddDropDownList("x111 y131 w315", LoadPunishmentProfileNames())
    PunishmentProfileDrop.OnEvent("Change", PunishmentProfileChanged)
    pnew := SettingsGui.AddButton("x440 y131 w93 h29", "New profile")
    pnew.OnEvent("Click", NewPunishmentProfile)
    pdel := SettingsGui.AddButton("x544 y131 w82 h29", "Delete")
    pdel.OnEvent("Click", DeletePunishmentProfile)
    SettingsLV := SettingsGui.AddListView("x35 y177 w754 h152 NoSortHdr -Multi Background181323 cF5EBFF", ["On", "Wheel name", "Seconds", "Weight", "Action", "Keys / recording"])
    for i, w in [42, 180, 60, 53, 143, 232]
        SettingsLV.ModifyCol(i, w)
    DarkTable(SettingsLV)
    SettingsLV.OnEvent("ItemSelect", EditorRowSelected)
    SettingsGui.AddText("x35 y348 w65 h22", "Name")
    EditorName := SettingsGui.AddEdit("x105 y343 w343 h29 Background241B30 cFFFFFF")
    EditorEnabled := SettingsGui.AddCheckbox("x470 y343 w132 h28", "Enabled")
    SettingsGui.AddText("x35 y390 w65 h22", "Seconds")
    EditorDuration := SettingsGui.AddEdit("x105 y385 w100 h29 Background241B30 cFFFFFF")
    SettingsGui.AddText("x223 y390 w59 h22", "Weight")
    EditorWeight := SettingsGui.AddEdit("x290 y385 w85 h29 Background241B30 cFFFFFF")
    SettingsGui.AddText("x387 y390 w49 h22", "Action")
    EditorAction := SettingsGui.AddDropDownList("x445 y385 w338", ActionNames())
    EditorAction.OnEvent("Change", UpdateEditorHint)
    EditorKeyLabel := SettingsGui.AddText("x35 y432 w70 h22", "Key / file")
    EditorKeys := SettingsGui.AddEdit("x105 y427 w329 h29 Background241B30 cFFFFFF")
    EditorBindButton := SettingsGui.AddButton("x444 y427 w109 h29", "Bind key")
    EditorBindButton.OnEvent("Click", BeginEditorKeyCapture)
    EditorValueLabel := SettingsGui.AddText("x553 y432 w65 h22", "Value")
    EditorValue := SettingsGui.AddEdit("x620 y427 w164 h29 Background241B30 cFFFFFF", "0")
    EditorVary := SettingsGui.AddCheckbox("x35 y467 w220 h27 Hidden", "Progressive")
    EditorVary.OnEvent("Click", UpdateEditorHint)
    EditorGrid := SettingsGui.AddDropDownList("x620 y427 w164 Hidden", PunishmentGridChoices())
    EditorGrid.Choose(1)
    EditorRange := SettingsGui.AddText("x553 y470 w230 h24 Hidden cAA95BF", "")
    RawAccelButton := SettingsGui.AddButton("x322 y461 w216 h30 Hidden", "Link Raw Accel")
    RawAccelButton.OnEvent("Click", OpenRawAccelSetup)
    EditorChatTest := BuildChatTestPicker(SettingsGui)
    EditorRawKeys := ""
    for spec in [[35, "New", EditorAdd, 75], [118, "Save", EditorSave, 78], [204, "Delete", EditorDelete, 78], [290, "Record inputs", OpenRecorder, 129], [427, "Preview", PreviewSelected, 108], [544, "Live test", LiveTestSelected, 125]] {
        b := SettingsGui.AddButton("x" spec[1] " y510 w" spec[4] " h33", spec[2])
        b.OnEvent("Click", spec[3])
    }
    SettingsGui.AddText("x35 y565 w100 h22", "Input mode")
    InputMethodDrop := SettingsGui.AddDropDownList("x144 y561 w240", ["Scan-code Event", "Scan-code Input"])
    InputMethodDrop.Choose(GameInputMethod = "Input" ? 2 : 1)
    InputMethodDrop.OnEvent("Change", SetGameInputMethod)
    b := SettingsGui.AddButton("x401 y561 w125 h27", "Input log")
    b.OnEvent("Click", OpenInputLog)
    tab.UseTab(2)
    BuildActivitySettings(SettingsGui)
    global ScareLocalVolume, ScareStreamVolume, ScareLocalSlider, ScareStreamSlider, ScareLocalLabel, ScareStreamLabel
    tab.UseTab(3)
    SettingsGui.SetFont("s11 Bold cF1E7F8", "Segoe UI")
    SettingsGui.AddText("x40 y126 w550 h25", "WHEEL")
    SettingsGui.SetFont("s9 Norm cD6C9E7", "Segoe UI")
    SettingsGui.AddText("x40 y165 w98 h23", "Spin tick")
    TickPathEdit := SettingsGui.AddEdit("x144 y158 w395 h29 Background241B30 cFFFFFF", TickSoundPath)
    b := SettingsGui.AddButton("x545 y158 w72 h29", "Browse")
    b.OnEvent("Click", (*) => PickSound("tick"))
    TickSlider := SettingsGui.AddSlider("x635 y158 w143 h29 Range0-100 ToolTip", TickVolume)
    SettingsGui.AddText("x40 y207 w98 h23", "Landing")
    LandPathEdit := SettingsGui.AddEdit("x144 y200 w395 h29 Background241B30 cFFFFFF", LandSoundPath)
    b := SettingsGui.AddButton("x545 y200 w72 h29", "Browse")
    b.OnEvent("Click", (*) => PickSound("land"))
    LandSlider := SettingsGui.AddSlider("x635 y200 w143 h29 Range0-100 ToolTip", LandVolume)
    SettingsGui.AddText("x40 y248 w190 h23", "Spin announcement")
    AnnouncementLabel := SettingsGui.AddText("x548 y248 w57 h23 Right", SpinAnnouncementVolume "%")
    AnnouncementSlider := SettingsGui.AddSlider("x635 y242 w143 h29 Range0-100 ToolTip", SpinAnnouncementVolume)
    SettingsGui.AddText("x40 y287 w155 h23", "General TTS")
    TtsVolumeLabel := SettingsGui.AddText("x548 y287 w57 h23 Right", TtsVolume "%")
    TtsSlider := SettingsGui.AddSlider("x635 y281 w143 h29 Range0-100 ToolTip", TtsVolume)
    SpeakCheck := SettingsGui.AddCheckbox("x40 y306 w370 h25", "Voice announcement")
    SpeakCheck.Value := TtsEnabled
    SettingsGui.SetFont("s10 Bold cEDE4F8", "Segoe UI")
    SettingsGui.AddText("x40 y342 w570 h23", "ACTIVITY")
    SettingsGui.SetFont("s9 Norm cD6C9E7", "Segoe UI")
    SettingsGui.AddText("x40 y370 w98 h22", "Spin tick")
    SlotTickPathEdit := SettingsGui.AddEdit("x144 y364 w395 h29 Background241B30 cFFFFFF", SlotTickSoundPath)
    b := SettingsGui.AddButton("x545 y364 w72 h29", "Browse")
    b.OnEvent("Click", (*) => PickSound("slottick"))
    SlotTickSlider := SettingsGui.AddSlider("x635 y364 w143 h29 Range0-100 ToolTip", SlotTickVolume)
    SettingsGui.AddText("x40 y406 w98 h22", "Landing")
    SlotLandPathEdit := SettingsGui.AddEdit("x144 y400 w395 h29 Background241B30 cFFFFFF", SlotLandSoundPath)
    b := SettingsGui.AddButton("x545 y400 w72 h29", "Browse")
    b.OnEvent("Click", (*) => PickSound("slotland"))
    SlotLandSlider := SettingsGui.AddSlider("x635 y400 w143 h29 Range0-100 ToolTip", SlotLandVolume)
    SettingsGui.SetFont("s10 Bold cEDE4F8", "Segoe UI")
    SettingsGui.AddText("x40 y448 w550 h23", "SEQUENCE")
    SettingsGui.SetFont("s9 Norm cD6C9E7", "Segoe UI")
    SettingsGui.AddText("x40 y478 w230 h24", "Sequence volume")
    SequenceVolumeLabel := SettingsGui.AddText("x548 y478 w57 h24 Right", SequenceVolume "%")
    SequenceSlider := SettingsGui.AddSlider("x635 y472 w143 h29 Range0-100 ToolTip", SequenceVolume)
    SettingsGui.AddText("x40 y517 w230 h23", "Jumpscares · Meso")
    ScareLocalLabel := SettingsGui.AddText("x548 y517 w57 h23 Right", ScareLocalVolume "%")
    ScareLocalSlider := SettingsGui.AddSlider("x635 y511 w143 h29 Range0-100 ToolTip", ScareLocalVolume)
    SettingsGui.AddText("x40 y554 w230 h23", "Jumpscares · Output")
    ScareStreamLabel := SettingsGui.AddText("x548 y554 w57 h23 Right", ScareStreamVolume "%")
    ScareStreamSlider := SettingsGui.AddSlider("x635 y548 w143 h29 Range0-100 ToolTip", ScareStreamVolume)
    for slider in [AnnouncementSlider, TtsSlider, SequenceSlider, ScareLocalSlider, ScareStreamSlider]
        slider.OnEvent("Change", UpdateAudioLabels)
    b := SettingsGui.AddButton("x543 y589 w236 h36", "Save audio")
    b.OnEvent("Click", SaveAudioClick)
    tab.UseTab(4)
    SettingsGui.SetFont("s11 Bold cF1E7F8", "Segoe UI")
    SettingsGui.AddText("x40 y135 w660 h28", "STREAM")
    SettingsGui.SetFont("s10 Norm cD6C9E7", "Segoe UI")
    ViewerCheck := SettingsGui.AddCheckbox("x40 y179 w660 h32", "Show viewer names")
    ViewerCheck.Value := ViewerVisible
    b := SettingsGui.AddButton("x543 y554 w236 h36", "Save stream options")
    b.OnEvent("Click", SaveStreamClick)
    tab.UseTab(5)
    SettingsGui.SetFont("s11 Bold cF1E7F8", "Segoe UI")
    SettingsGui.AddText("x40 y135 w680 h28", "DISPLAY")
    SettingsGui.SetFont("s10 Norm cD6C9E7", "Segoe UI")
    SettingsGui.AddText("x40 y189 w180 h25", "Chaos mode")
    ModeDrop := SettingsGui.AddDropDownList("x245 y184 w284", ["Wheel", "Single reel"])
    ModeDrop.Choose(WheelDisplayMode = "reel" ? 2 : 1)
    ModeDrop.OnEvent("Change", ChangeWheelDisplayMode)
    AutoCheck := SettingsGui.AddCheckbox("x40 y247 w650 h30", "Auto-roll activity reels")
    AutoCheck.Value := SlotAutoRoll
    AutoCheck.OnEvent("Click", ToggleAutoRoll)
    DestinyCheck := SettingsGui.AddCheckbox("x40 y307 w650 h30", "Destiny 2 only")
    DestinyCheck.Value := DestinyOnlyMode
    DestinyCheck.OnEvent("Click", ToggleDestinyOnly)
    SettingsGuideCheck := SettingsGui.AddCheckbox("x40 y367 w650 h30", "OBS crop guides")
    SettingsGuideCheck.Value := Guides
    SettingsGuideCheck.Enabled := OutputEnabled
    SettingsGuideCheck.OnEvent("Click", ToggleSettingsGuides)
    tab.UseTab(6)
    BuildSequenceSettings(SettingsGui)
    tab.UseTab(7)
    BuildRoundSettings(SettingsGui)
    tab.UseTab(8)
    BuildChatSettings(SettingsGui)
    tab.UseTab(9)
    BuildUpdateSettings(SettingsGui)
    tab.UseTab(10)
    BuildSharedKeySettings(SettingsGui)
    tab.UseTab()
    UpdateEditorHint()
    SettingsGui.OnEvent("Close", CloseSettings)
    SettingsGui.OnEvent("Escape", CloseSettings)
    ApplyGuiIcon(SettingsGui)
    RefreshPunishmentProfileDrop()
    RefreshSettingsList()
    SettingsGui.Show("w824 h674")
    FitLastColumn(SettingsLV, 6)
}

UpdateAudioLabels(*) {
    global SequenceSlider, TtsSlider, SequenceVolumeLabel, TtsVolumeLabel, AnnouncementSlider, AnnouncementLabel
    global ScareLocalSlider, ScareStreamSlider, ScareLocalLabel, ScareStreamLabel
    ScareLocalLabel.Text := ScareLocalSlider.Value "%"
    ScareStreamLabel.Text := ScareStreamSlider.Value "%"
    SequenceVolumeLabel.Text := SequenceSlider.Value "%"
    TtsVolumeLabel.Text := TtsSlider.Value "%"
    AnnouncementLabel.Text := AnnouncementSlider.Value "%"
}

SaveAudioClick(control, info) {
    SaveSoundSettings(false)
}

SaveStreamClick(control, info) {
    global ViewerVisible, ViewerCheck
    ViewerVisible := ViewerCheck.Value = 1
    SaveAppSettings()
    PublishState(true)
}

ToggleSettingsGuides(*) {
    global GuideCheck, SettingsGuideCheck
    GuideCheck.Value := SettingsGuideCheck.Value
    ToggleGuides()
}

BuildSequenceSettings(gui) {
    gui.SetFont("s13 Bold cF4EDF9", "Segoe UI")
    gui.AddText("x40 y137 w640 h35", "SEQUENCE")
    gui.SetFont("s10 Norm cEDE7F7", "Segoe UI")
    choice := gui.AddDropDownList("x40 y177 w314 Choose1 vSequenceChoice", ["He Is Coming", "Sonion Call"])
    notice := gui.AddText("x40 y278 w640 h27 cCDB6E3 vSequenceNotice", "")
    gui.AddButton("x40 y222 w184 h43", "Test sequence").OnEvent("Click", TestSequence.Bind(choice, notice))
    gui.AddButton("x236 y222 w118 h43", "Stop").OnEvent("Click", (*) => (StopSequence(), SetText(notice, "")))
}

TestSequence(choice, notice, *) {
    try {
        if !GuiHwndSafe(choice.Gui)
            return
        SetText(notice, "")
        if choice.Value = 2 {
            if !StartSonionPreview(choice.Gui.Hwnd, NowMs())
                SetText(notice, "A Sonion call is already running.")
        } else {
            StopSonionPreview()
            SaveSoundSettings(false)
            OpenStreamOutput(false)
            ScheduleHorror(NowMs() + 1600)
        }
    } catch as err {
        SetText(notice, "The sequence could not start. See Meso.log.")
        LogEvent("Sequence test failed: " err.Message)
    }
}

StopSequence(*) {
    global HorrorEvents, OutputPid
    StopSonionPreview()
    HorrorEvents := []
    PublishState(true)
    h := StreamOutputWindow(OutputPid)
    if h
        try PostMessage(0x8003, 0, 0,, "ahk_id " h)
}

CloseSettings(*) {
    global SettingsGui, SettingsLV, SelectedEditorIndex, DirectSlotControls
    previousCritical := A_IsCritical
    Critical("On")
    try {
        StopEditorKeyCapture()
        StopSharedKeyCapture()
        g := SettingsGui
        SettingsGui := 0
        SettingsLV := 0
        SelectedEditorIndex := 0
        DirectSlotControls := []
        if IsObject(g)
            try g.Destroy()
    } finally Critical(previousCritical)
}

RefreshSettingsList() {
    global SettingsGui, SettingsLV, Punishments
    if !GuiHwndSafe(SettingsGui) || !IsObject(SettingsLV)
        return
    list := SettingsLV
    previousCritical := A_IsCritical
    Critical("On")
    try {
        if !GuiHwndSafe(SettingsGui) || list != SettingsLV
            return
        list.Opt("-Redraw")
        list.Delete()
        for p in Punishments {
            keys := SharedKeysForAction(p.Action, KeyTokens(p.Keys))
            list.Add("", p.Enabled ? "Yes" : "No", p.Name, p.Duration, p.Weight, p.Action, keys.Length ? JoinKeys(keys) : p.Keys)
        }
    } finally {
        try list.Opt("+Redraw")
        Critical(previousCritical)
    }
    RefreshDirectSlots()
}

EditorRowSelected(control, index, selected) {
    global SettingsLV, SelectedEditorIndex, Punishments, EditorName, EditorEnabled, EditorDuration, EditorWeight, EditorAction, EditorKeys, EditorValue, EditorVary, EditorGrid, EditorRawKeys
    if !IsObject(SettingsLV) || SettingsLV != control || !selected || index < 1 || index > Punishments.Length
        return
    SelectedEditorIndex := index
    p := Punishments[index]
    EditorName.Value := p.Name
    EditorEnabled.Value := p.Enabled
    EditorDuration.Value := p.Duration
    EditorWeight.Value := p.Weight
    for i, name in ActionNames()
        if name = p.Action
            EditorAction.Choose(i)
    EditorRawKeys := p.Keys
    EditorKeys.Value := p.Keys
    EditorValue.Value := FixedPunishmentValue(p)
    EditorVary.Value := PunishmentVaries(p)
    grid := p.HasOwnProp("Grid") ? p.Grid : "2x3"
    EditorGrid.Choose(1)
    EditorGrid.Delete()
    EditorGrid.Add(p.Action = "Sliding Puzzle" ? ["3x3", "4x4"] : PunishmentGridChoices())
    for i, size in (p.Action = "Sliding Puzzle" ? ["3x3", "4x4"] : PunishmentGridChoices())
        if size = grid
            EditorGrid.Choose(i)
    UpdateEditorHint()
}

UpdateEditorHint(*) {
    global EditorAction, EditorKeys, EditorKeyLabel, EditorBindButton, EditorValue, EditorValueLabel, EditorVary, EditorGrid, EditorRange, RawAccelButton, SettingsGui, EditorChatTest
    if !GuiHwndSafe(SettingsGui)
        return
    action := EditorAction.Text
    global EditorRawKeys
    shared := SharedKeysForAction(action, KeyTokens(EditorRawKeys))
    hasKeys := shared.Length || InStr("|Spam Key|Exit Desktop|Return to Orbit|Send Chat|Custom Sequence|Recorded Sequence|", "|" action "|")
    valueLabels := Map("Spam Crouch", "Pulse ms", "Exit Desktop", "Delay ms", "Spin 360", "Step", "Lights Out", "Darkness", "Tunnel Vision", "Zoom", "Wide View", "Scale", "Screen Shuffle", "Grid", "Sliding Puzzle", "Grid", "Random Loadout", "Slots", "Change Mouse Sensitivity", "Multiplier", "Alt+Enter", "Gap (sec)", "Drunk Vision", "Sway")
    variable := InStr("|Lights Out|Tunnel Vision|Wide View|Screen Shuffle|Sliding Puzzle|Change Mouse Sensitivity|", "|" action "|") > 0
    EditorVary.Visible := variable
    EditorVary.Text := action = "Screen Shuffle" || action = "Sliding Puzzle" || action = "Change Mouse Sensitivity" ? "Random" : "Progressive"
    EditorKeyLabel.Visible := hasKeys
    EditorKeys.Visible := hasKeys
    EditorKeys.Enabled := !shared.Length
    EditorKeyLabel.Text := shared.Length ? "Shared keys" : "Key / file"
    if shared.Length
        EditorKeys.Value := JoinKeys(shared)
    EditorBindButton.Visible := action = "Spam Key" || action = "Send Chat"
    EditorChatTest.Label.Visible := action = "Send Chat"
    EditorChatTest.Picker.Visible := action = "Send Chat"
    EditorValueLabel.Visible := valueLabels.Has(action)
    EditorValueLabel.Text := valueLabels.Get(action, "Value")
    EditorGrid.Visible := action = "Screen Shuffle" || action = "Sliding Puzzle"
    choices := action = "Sliding Puzzle" ? ["3x3", "4x4"] : PunishmentGridChoices()
    if EditorGrid.Visible && EditorGrid.Text != "" && !(action = "Sliding Puzzle" ? RegExMatch(EditorGrid.Text, "^[34]x[34]$") : RegExMatch(EditorGrid.Text, "^[2-5]x[2-6]$")) {
        EditorGrid.Delete()
        EditorGrid.Add(choices)
        EditorGrid.Choose(1)
    }
    EditorGrid.Enabled := !EditorVary.Value
    EditorValue.Visible := valueLabels.Has(action) && action != "Screen Shuffle" && action != "Sliding Puzzle"
    EditorValue.Enabled := !variable || !EditorVary.Value
    limits := PunishmentValueRange(action)
    EditorRange.Visible := IsObject(limits) && EditorValue.Enabled
    EditorRange.Text := IsObject(limits) ? limits.Label : ""
    RawAccelButton.Visible := action = "Change Mouse Sensitivity"
    if RawAccelButton.Visible
        RawAccelButton.Text := "Raw Accel setup"
}

EditorAdd(*) {
    global Punishments, SelectedEditorIndex, SettingsLV
    if Punishments.Length >= 200
        return
    Punishments.Push({Name: "New punishment", Enabled: false, Duration: 3, Weight: 5, Action: "Custom Sequence", Keys: "", Value: 0})
    RefreshSettingsList()
    SettingsLV.Modify(Punishments.Length, "Select Focus Vis")
}

EditorSave(*) {
    global Punishments, SelectedEditorIndex, SettingsLV, EditorName, EditorEnabled, EditorDuration, EditorWeight, EditorAction, EditorKeys, EditorValue, EditorVary, EditorGrid, EditorRawKeys
    i := SelectedEditorIndex
    if i < 1 || i > Punishments.Length
        return false
    if Trim(EditorName.Value) = "" || !IsNumber(EditorDuration.Value) || !IsNumber(EditorWeight.Value) || !IsNumber(EditorValue.Value) {
        MsgBox("Enter a name and valid numeric duration, weight, and value.")
        return false
    }
    d := Float(EditorDuration.Value), w := Float(EditorWeight.Value)
    if d < 0.1 || d > 300 || w < 0 || w > 100 {
        MsgBox("Duration: 0.1 to 300 seconds. Weight: 0 to 100.")
        return false
    }
    action := EditorAction.Text
    if action = ""
        return false
    value := Float(EditorValue.Value)
    limits := PunishmentValueRange(action)
    if IsObject(limits) && EditorValue.Enabled && (value < limits.Min || value > limits.Max) {
        MsgBox("Enter a value from " limits.Label ".", "Meso Control")
        return false
    }
    for a in ["Spam Key", "Send Chat"] {
        if action = a {
            tokens := KeyTokens(EditorKeys.Value)
            if tokens.Length != 1 || SimpleKey(tokens[1]) = "" {
                MsgBox("Set one valid game key, such as LControl, c, Space, or LButton. Bind key can capture a keyboard key.", "Check the binding")
                return false
            }
            break
        }
    }
    if action = "Random Loadout" && d < 4 {
        d := 4
        EditorDuration.Value := d
    }
    if action = "Return to Orbit" {
        d := Max(5, d)
        EditorDuration.Value := d
    }
    savedKeys := SharedKeysForAction(action).Length ? EditorRawKeys : Trim(EditorKeys.Value)
    original := Punishments[i]
    Punishments[i] := {Name: SubStr(Trim(EditorName.Value), 1, 80), Enabled: EditorEnabled.Value = 1, Duration: d, Weight: w, Action: action, Keys: savedKeys, Value: value, Vary: EditorVary.Visible && EditorVary.Value, Grid: action = "Sliding Puzzle" ? SlidingPuzzleGrid(EditorGrid.Text) : PunishmentGrid(EditorGrid.Text)}
    if !SavePunishments() {
        Punishments[i] := original
        return false
    }
    RefreshSettingsList()
    SettingsLV.Modify(i, "Select Focus Vis")
    return true
}

EditorDelete(*) {
    global Punishments, SelectedEditorIndex
    if SelectedEditorIndex < 1 || SelectedEditorIndex > Punishments.Length
        return
    Punishments.RemoveAt(SelectedEditorIndex)
    SelectedEditorIndex := 0
    SavePunishments()
    RefreshSettingsList()
}

BuildChatTestPicker(gui) {
    messages := ["Random message", TungChatPhrase(), SonionQuestion()]
    messages.Push(OrdinaryChatMessages()*)
    label := gui.AddText("x35 y471 w78 h22 Hidden", "Test message")
    picker := gui.AddDropDownList("x115 y465 w668 Choose1 Hidden", messages)
    return {Label: label, Picker: picker}
}

PreviewSelected(*) {
    StartSelectedTest(true)
}

LiveTestSelected(*) {
    StartSelectedTest(false)
}

StartSelectedTest(preview) {
    global Queue, Punishments, SelectedEditorIndex, WheelControllerEnabled, Recorder, Clock, LastEffectMessage, EditorChatTest
    if IsObject(Queue.Active) || Queue.Count() || HasEffects() || Recorder.Phase != "idle" {
        MsgBox("Finish or stop the current spin and clear the queue before testing an item.", "Meso Control")
        return
    }
    if !preview && !WheelControllerEnabled {
        MsgBox("Enable Wheel Controller first. A live test sends real game inputs.", "Meso Control")
        return
    }
    if SelectedEditorIndex < 1 || SelectedEditorIndex > Punishments.Length
        return
    if !EditorSave()
        return
    picker := EditorChatTest.Picker
    chatMessage := picker.Value > 1 ? picker.Text : ""
    p := MakeTestPunishment(Punishments[SelectedEditorIndex], preview, chatMessage, Clock.Generation)
    Queue.Accept(NewId(), preview, NowMs())
    Queue.Paused := false
    j := Queue.Take(NowMs())
    j.Pool := [p]
    j.Index := 1
    j.P := p
    j.Angle := 2160 + NormAngle(-90 - SliceCenter(j.Pool, 1))
    j.VisualUntil := 0
    LastEffectMessage := preview ? "Visual preview only - no game input" : "LIVE TEST: return to the game - the effect waits for focus"
    if !preview
        CloseSettings()
    PublishState(true)
    UpdateMainUi()
}

MakeTestPunishment(punishment, preview, chatMessage, timerGeneration) {
    test := punishment.Clone()
    if test.Weight <= 0
        test.Weight := 1
    test.TimerGeneration := timerGeneration
    if !preview && test.Action = "Send Chat" && chatMessage != ""
        test.ChatTestMessage := chatMessage
    return test
}

PickSound(which) {
    global TickPathEdit, LandPathEdit, SlotTickPathEdit, SlotLandPathEdit
    path := FileSelect(1, , "Choose a sound", "Audio (*.wav;*.mp3)")
    if path = ""
        return
    switch which {
        case "tick": TickPathEdit.Value := path
        case "land": LandPathEdit.Value := path
        case "slottick": SlotTickPathEdit.Value := path
        case "slotland": SlotLandPathEdit.Value := path
    }
}

SaveSoundSettings(notify := true) {
    global TickSoundPath, LandSoundPath, TickVolume, LandVolume, TickPathEdit, LandPathEdit, TickSlider, LandSlider, HorrorVolume, FigureVolume, SequenceVolume, TtsVolume, TtsEnabled, ViewerVisible, SequenceSlider, TtsSlider, SpeakCheck, ViewerCheck, SpinAnnouncementVolume, AnnouncementSlider
    global SlotTickSoundPath, SlotLandSoundPath, SlotTickVolume, SlotLandVolume, SlotTickPathEdit, SlotLandPathEdit, SlotTickSlider, SlotLandSlider
    TickSoundPath := Trim(TickPathEdit.Value)
    LandSoundPath := Trim(LandPathEdit.Value)
    global ScareLocalVolume, ScareStreamVolume, ScareLocalSlider, ScareStreamSlider
    ScareLocalVolume := ScareLocalSlider.Value
    ScareStreamVolume := ScareStreamSlider.Value
    TickVolume := TickSlider.Value
    LandVolume := LandSlider.Value
    SlotTickSoundPath := Trim(SlotTickPathEdit.Value)
    SlotLandSoundPath := Trim(SlotLandPathEdit.Value)
    SlotTickVolume := SlotTickSlider.Value
    SlotLandVolume := SlotLandSlider.Value
    SequenceVolume := SequenceSlider.Value
    HorrorVolume := SequenceVolume
    FigureVolume := SequenceVolume
    TtsVolume := TtsSlider.Value
    SpinAnnouncementVolume := AnnouncementSlider.Value
    TtsEnabled := SpeakCheck.Value = 1
    ViewerVisible := ViewerCheck.Value = 1
    SaveAppSettings()
    PublishState(true)
    if notify
        return true
}

FitLastColumn(lv, count) {
    r := Buffer(16, 0)
    DllCall("user32\GetClientRect", "Ptr", lv.Hwnd, "Ptr", r)
    width := NumGet(r, 8, "Int")
    used := 0
    loop count - 1
        used += SendHwnd(lv.Hwnd, 0x101D, A_Index - 1)
    SendHwnd(lv.Hwnd, 0x101E, count - 1, Max(60, width - used))
}


SetGameInputMethod(*) {
    global InputMethodDrop, GameInputMethod, Queue
    CancelEffects("Input method changed")
    GameInputMethod := InputMethodDrop.Value = 2 ? "Input" : "Event"
    SaveAppSettings()
    LogEvent("Input method set to " GameInputMethod)
    UpdateMainUi()
}

OpenInputLog(*) {
    global RuntimeDir
    path := RuntimeDir "\Meso.log"
    if !FileExist(path)
        LogEvent("Input diagnostics opened")
    Run("notepad.exe " Chr(34) path Chr(34))
}

BeginEditorKeyCapture(*) {
    global EditorBindHook, EditorBindIndex, SelectedEditorIndex, EditorAction, EditorBindButton
    if SelectedEditorIndex < 1
        return
    action := EditorAction.Text
    allowed := false
    for a in ["Spam Key", "Send Chat"]
        if action = a
            allowed := true
    if !allowed {
        return
    }
    StopSharedKeyCapture()
    StopEditorKeyCapture()
    EditorBindIndex := SelectedEditorIndex
    EditorBindHook := InputHook("L0 T8 I1")
    EditorBindHook.KeyOpt("{All}", "NS")
    EditorBindHook.OnKeyDown := EditorKeyCaptured
    EditorBindHook.OnEnd := EditorCaptureEnded
    EditorBindButton.Text := "Press a key…"
    EditorBindHook.Start()
}

EditorKeyCaptured(hook, vk, sc) {
    global EditorBindIndex, SelectedEditorIndex, EditorKeys, SettingsGui
    if vk != 0x1B && EditorBindIndex = SelectedEditorIndex && GuiHwndSafe(SettingsGui) {
        key := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
        if key = "" && sc
            key := Format("sc{:03X}", sc)
        if key != ""
            EditorKeys.Value := SimpleKey(key, key)
    }
    hook.Stop()
}

EditorCaptureEnded(hook) {
    global EditorBindHook, EditorBindIndex, EditorBindButton, SettingsGui
    if EditorBindHook != hook
        return
    EditorBindHook := 0
    EditorBindIndex := 0
    if GuiHwndSafe(SettingsGui) {
        EditorBindButton.Text := "Bind key"
        UpdateEditorHint()
    }
}

StopEditorKeyCapture() {
    global EditorBindHook, EditorBindIndex, EditorBindButton, SettingsGui
    hook := EditorBindHook
    EditorBindHook := 0
    EditorBindIndex := 0
    if IsObject(hook)
        hook.Stop()
    if GuiHwndSafe(SettingsGui) && IsSet(EditorBindButton)
        try EditorBindButton.Text := "Bind key"
}

OpenStreamSettings(*) {
    OpenSettings()
}

CloseStreamSettings(*) {
}

IsEditorKeyCaptureActive() {
    global EditorBindHook, SettingsGui
    global SharedBindHook
    return (IsObject(EditorBindHook) || IsObject(SharedBindHook)) && GuiHwndSafe(SettingsGui)
}

EditorMouseCaptured(name) {
    global EditorBindHook, EditorKeys, EditorBindIndex, SelectedEditorIndex, SettingsGui
    if CaptureSharedKey(name)
        return
    if !IsObject(EditorBindHook) || EditorBindIndex != SelectedEditorIndex || !GuiHwndSafe(SettingsGui)
        return
    EditorKeys.Value := name
    StopEditorKeyCapture()
    UpdateEditorHint()
}
