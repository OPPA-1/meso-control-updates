OpenRecorder(*) {
    global RecorderGui, RecordStateText, RecordEventsLV, RecordNameEdit, RecordWeightEdit, Recorder
    global RecordCaptureMode, RecordMouseCheck, RecordButtons
    if GuiHwndSafe(RecorderGui) {
        RecorderGui.Show()
        return
    }
    RecorderGui := Gui("-MaximizeBox", "Meso Input Recorder")
    RecorderGui.BackColor := "100B18"
    RecorderGui.SetFont("s16 Bold cF8F3FF", "Segoe UI")
    RecorderGui.AddText("x22 y18 w660 h31", "INPUT RECORDER")
    RecorderGui.SetFont("s10 Norm cC7B4E4", "Segoe UI")
    RecorderGui.AddText("x22 y62 w100 h26", "Record in")
    RecordCaptureMode := RecorderGui.AddDropDownList("x128 y57 w226 Choose1", ["Capture pad", "Game window"])
    RecordMouseCheck := RecorderGui.AddCheckbox("x380 y59 w285 h26", "Include mouse movement")
    RecordMouseCheck.Value := 1
    RecordStateText := RecorderGui.AddText("x22 y104 w660 h27 cC8A2FF", "Ready · F8 stops recording")
    RecordEventsLV := RecorderGui.AddListView("x22 y141 w660 h258 NoSortHdr -Multi Background1A1025 cF0E6FF", ["Time (ms)", "Event", "Input"])
    for i, width in [107, 105, 420]
        RecordEventsLV.ModifyCol(i, width)
    DarkTable(RecordEventsLV)
    RecordButtons := []
    for spec in [[22, 112, "Record", StartRecording], [145, 112, "Stop · F8", StopRecording], [268, 127, "Load selected", LoadSelectedRecording], [406, 127, "Delete event", DeleteRecordedEvent], [544, 137, "Edit time", EditRecordedTime]] {
        b := RecorderGui.AddButton("x" spec[1] " y416 w" spec[2] " h33", spec[3])
        b.OnEvent("Click", spec[4])
        if spec[3] != "Stop · F8"
            RecordButtons.Push(b)
    }
    RecorderGui.AddText("x22 y477 w95 h24", "Wheel name")
    RecordNameEdit := RecorderGui.AddEdit("x124 y470 w367 h33 Background21132F cFFFFFF", "Custom Chaos")
    RecorderGui.AddText("x512 y477 w62 h24", "Weight")
    RecordWeightEdit := RecorderGui.AddEdit("x579 y470 w102 h33 Background21132F cFFFFFF", "5")
    b := RecorderGui.AddButton("x22 y522 w318 h39", "Save new punishment")
    b.OnEvent("Click", (*) => SaveRecordedPunishment(false))
    RecordButtons.Push(b)
    b := RecorderGui.AddButton("x356 y522 w326 h39", "Update loaded punishment")
    b.OnEvent("Click", (*) => SaveRecordedPunishment(true))
    RecordButtons.Push(b)
    RecorderGui.OnEvent("Close", CloseRecorder)
    RecorderGui.OnEvent("Escape", CloseRecorder)
    ApplyGuiIcon(RecorderGui)
    RecorderGui.Show("w704 h584")
    Recorder.EditingFile := ""
    Recorder.EditingProfile := ""
    RefreshRecordedEvents()
}

RecorderStatus(message) {
    global RecorderGui, RecordStateText
    if GuiHwndSafe(RecorderGui) && IsSet(RecordStateText)
        try SetText(RecordStateText, message)
}

CloseRecorder(*) {
    global RecorderGui
    StopRecording()
    g := RecorderGui
    RecorderGui := 0
    if IsObject(g)
        try g.Destroy()
}

StartRecording(*) {
    global Recorder, Queue, RecordCaptureMode, RecordMouseCheck, CapturePad, CapturePadLabel, CurrentPunishmentProfile, RecordButtons
    if IsObject(Queue.Active) || HasEffects() {
        RecorderStatus("Stop the current punishment first.")
        return
    }
    StopRecording()
    if Recorder.Events.Length && MsgBox("Replace the current unsaved recording?", "Input recorder", "YesNo") != "Yes"
        return
    if IsObject(Queue.Active) {
        RecorderStatus("Pause the wheel queue before recording")
        return
    }
    mode := RecordCaptureMode.Value = 2 ? "game" : "pad"
    oldFile := Recorder.HasOwnProp("EditingFile") ? Recorder.EditingFile : ""
    oldProfile := Recorder.HasOwnProp("EditingProfile") ? Recorder.EditingProfile : ""
    Recorder := {Phase: "countdown", Events: [], Target: 0, Hook: 0, Start: 0, Deadline: NowMs() + (mode = "game" ? 3000 : 1500), Down: Map(), LastMove: 0, Mode: mode, Mouse: RecordMouseCheck.Value = 1, AbsoluteMouse: Map(), LastUi: 0, EditingFile: oldFile, EditingProfile: oldProfile, StartedProfile: CurrentPunishmentProfile}
    if mode = "pad" {
        CapturePad := Gui("+AlwaysOnTop -MaximizeBox", "Meso Capture Pad")
        CapturePad.BackColor := "181020"
        CapturePad.SetFont("s19 Bold cEEE2FC", "Segoe UI")
        CapturePad.AddText("x25 y25 w670 h45 Center", "CAPTURE PAD")
        CapturePad.SetFont("s12 Norm cC4A9DF", "Segoe UI")
        CapturePadLabel := CapturePad.AddText("x25 y110 w670 h120 Center", "Get ready…")
        CapturePad.SetFont("s10 Norm cA08AAE", "Segoe UI")
        CapturePad.AddText("x25 y323 w670 h45 Center", "Press your keys and move/click the mouse here. F8 or Esc stops.")
        CapturePad.OnEvent("Close", StopRecording)
        ApplyGuiIcon(CapturePad)
        CapturePad.Show("w720 h390")
        Recorder.Target := CapturePad.Hwnd
    }
    for button in RecordButtons
        button.Enabled := false
    RefreshRecordedEvents()
    RecorderStatus(mode = "pad" ? "Capture pad opens in 1.5 seconds" : "Switch to the game · recording starts in 3 seconds")
}

RecorderTick(now) {
    global Recorder, AppGui, CapturePad, CapturePadLabel
    if Recorder.Phase = "countdown" {
        if now < Recorder.Deadline
            return
        target := Recorder.Mode = "game" ? ForegroundTarget() : GuiHwndSafe(CapturePad)
        if !target || !WinActive("ahk_id " target) {
            StopRecording()
            RecorderStatus("Nothing recorded · the capture target was not focused")
            return
        }
        Recorder.Target := target
        Recorder.Start := now
        Recorder.Clock := PerfNowMs()
        Recorder.Deadline := now + 60000
        ih := InputHook(Recorder.Mode = "pad" ? "L0 I1" : "V L0 I1")
        ih.KeyOpt("{All}", Recorder.Mode = "pad" ? "NS" : "N")
        ih.OnKeyDown := RecordKeyDown
        ih.OnKeyUp := RecordKeyUp
        Recorder.Hook := ih
        if !SetRawMouseSink(AppGui.Hwnd) {
            StopRecording()
            RecorderStatus("Mouse capture could not start · " A_LastError)
            return
        }
        Recorder.Phase := "recording"
        ih.Start()
        RecorderStatus("Recording · F8 to stop")
    } else if Recorder.Phase = "recording" {
        if now >= Recorder.Deadline || !WinActive("ahk_id " Recorder.Target) || Recorder.Events.Length >= 20000 {
            StopRecording()
            return
        }
        if now - Recorder.LastUi >= 100 {
            Recorder.LastUi := now
            caption := Format("{:.1f}s  ·  {} events", (now - Recorder.Start) / 1000, Recorder.Events.Length)
            RecorderStatus("Recording · " caption)
            if Recorder.Mode = "pad" && GuiHwndSafe(CapturePad)
                CapturePadLabel.Text := "RECORDING`n`n" caption
        }
    }
}

RecordKeyDown(ih, vk, sc) {
    global Recorder
    if Recorder.Phase != "recording" || !WinActive("ahk_id " Recorder.Target)
        return
    if vk = 0x77 || vk = 0x1B {
        StopRecording()
        return
    }
    if vk = 0x5B || vk = 0x5C
        return
    key := Format("vk{:02X}sc{:03X}", vk, sc)
    if Recorder.Down.Has(key)
        return
    Recorder.Down[key] := true
    AddRecordedEvent("down", key)
}

RecordKeyUp(ih, vk, sc) {
    global Recorder
    if Recorder.Phase != "recording"
        return
    key := Format("vk{:02X}sc{:03X}", vk, sc)
    if Recorder.Down.Has(key) {
        Recorder.Down.Delete(key)
        AddRecordedEvent("up", key)
    }
}

RecordRawMouse(wParam, lParam, msg, hwnd) {
    global Recorder
    if Recorder.Phase != "recording" || !WinActive("ahk_id " Recorder.Target)
        return
    try {
        header := 8 + A_PtrSize * 2
        size := 0
        DllCall("user32\GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", 0, "UInt*", &size, "UInt", header)
        if size < header + 24 || size > 4096
            return
        data := Buffer(size)
        if DllCall("user32\GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", data, "UInt*", &size, "UInt", header, "UInt") != size || NumGet(data, 0, "UInt") != 0
            return
        flags := NumGet(data, header + 4, "UShort")
        movementFlags := NumGet(data, header, "UShort")
        if Recorder.Mouse {
            dx := NumGet(data, header + 12, "Int")
            dy := NumGet(data, header + 16, "Int")
            if movementFlags & 1 {
                device := NumGet(data, 8, "Ptr")
                current := [dx, dy]
                if Recorder.AbsoluteMouse.Has(device) {
                    last := Recorder.AbsoluteMouse[device]
                    dx := Round((dx - last[1]) * (movementFlags & 2 ? SysGet(78) : A_ScreenWidth) / 65535)
                    dy := Round((dy - last[2]) * (movementFlags & 2 ? SysGet(79) : A_ScreenHeight) / 65535)
                } else
                    dx := dy := 0
                Recorder.AbsoluteMouse[device] := current
            }
            if dx || dy
                AddRecordedEvent("move", "", dx, dy)
        }
        for tuple in [[1, 2, "LButton"], [4, 8, "RButton"], [16, 32, "MButton"], [64, 128, "XButton1"], [256, 512, "XButton2"]] {
            key := tuple[3]
            if flags & tuple[1] {
                if !Recorder.Down.Has(key) {
                    Recorder.Down[key] := true
                    AddRecordedEvent("down", key)
                }
            }
            if flags & tuple[2] && Recorder.Down.Has(key) {
                Recorder.Down.Delete(key)
                AddRecordedEvent("up", key)
            }
        }
        delta := NumGet(data, header + 6, "Short")
        if flags & 0x400
            AddRecordedEvent("wheel", delta > 0 ? "WheelUp" : "WheelDown", delta)
        if flags & 0x800
            AddRecordedEvent("wheel", delta > 0 ? "WheelRight" : "WheelLeft", delta)
    } finally {
        if wParam = 0
            DllCall("user32\DefWindowProcW", "Ptr", hwnd, "UInt", msg, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }
    return 0
}

AddRecordedEvent(kind, key, x := 0, y := 0) {
    global Recorder
    if Recorder.Events.Length >= 20000 || Recorder.Phase != "recording"
        return
    at := Min(60000, Max(0, Round(PerfNowMs() - Recorder.Clock)))
    if kind = "move" && Recorder.Events.Length {
        last := Recorder.Events[Recorder.Events.Length]
        if last.Kind = "move" && Floor(at / 4) = Floor(last.At / 4) {
            last.X += x
            last.Y += y
            last.At := at
            return
        }
    }
    Recorder.Events.Push({At: at, Kind: kind, Key: key, X: x, Y: y})
}

StopRecording(*) {
    global Recorder, CapturePad, RecordButtons
    if Recorder.Phase = "idle"
        return
    oldPhase := Recorder.Phase
    Recorder.Phase := "idle"
    if IsObject(Recorder.Hook)
        try Recorder.Hook.Stop()
    Recorder.Hook := 0
    SetRawMouseSink()
    if oldPhase = "recording" {
        for key in Recorder.Down
            Recorder.Events.Push({At: Min(60000, Max(0, Round(PerfNowMs() - Recorder.Clock))), Kind: "up", Key: key, X: 0, Y: 0})
    }
    Recorder.Down := Map()
    if GuiHwndSafe(CapturePad)
        try CapturePad.Destroy()
    CapturePad := 0
    if IsSet(RecordButtons)
        for button in RecordButtons
            try button.Enabled := true
    RecorderStatus("Recorded " Recorder.Events.Length " events · review and save below")
    RefreshRecordedEvents()
}

RefreshRecordedEvents() {
    global Recorder, RecordEventsLV, RecorderGui
    if !GuiHwndSafe(RecorderGui) || !IsSet(RecordEventsLV)
        return
    RecordEventsLV.Opt("-Redraw")
    try {
        RecordEventsLV.Delete()
        for e in Recorder.Events {
            label := e.Kind = "move" ? "X " e.X "  Y " e.Y : GetKeyName(e.Key)
            RecordEventsLV.Add("", e.At, e.Kind, label)
        }
    } finally RecordEventsLV.Opt("+Redraw")
}

DeleteRecordedEvent(*) {
    global Recorder, RecordEventsLV
    if Recorder.Phase != "idle"
        return
    n := RecordEventsLV.GetNext()
    if n {
        Recorder.Events.RemoveAt(n)
        RefreshRecordedEvents()
    }
}

EditRecordedTime(*) {
    global Recorder, RecordEventsLV
    if Recorder.Phase != "idle"
        return
    n := RecordEventsLV.GetNext()
    if !n
        return
    r := InputBox("Event time in milliseconds", "Event timing", "w320 h130", Recorder.Events[n].At)
    if r.Result != "OK" || !RegExMatch(r.Value, "^\d+$")
        return
    at := Integer(r.Value)
    low := n > 1 ? Recorder.Events[n - 1].At : 0
    high := n < Recorder.Events.Length ? Recorder.Events[n + 1].At : 60000
    if at < low || at > high {
        RecorderStatus("Time must be between " low " and " high " ms")
        return
    }
    Recorder.Events[n].At := at
    RefreshRecordedEvents()
}


SaveRecordedPunishment(replace := false) {
    global Recorder, RecordNameEdit, RecordWeightEdit, Punishments, CurrentPunishmentProfile
    if Recorder.Phase != "idle" || !Recorder.Events.Length
        return
    name := SubStr(Trim(RecordNameEdit.Value), 1, 80)
    if name = "" || !IsNumber(RecordWeightEdit.Value) || RecordWeightEdit.Value + 0 <= 0 || RecordWeightEdit.Value + 0 > 100 {
        RecorderStatus("Enter a name and a weight from 0.1 to 100")
        return
    }
    index := 0
    if replace {
        if !Recorder.HasOwnProp("EditingFile") || Recorder.EditingFile = "" || Recorder.EditingProfile != CurrentPunishmentProfile {
            RecorderStatus("Load an existing recording from this profile first")
            return
        }
        for i, p in Punishments
            if p.Action = "Recorded Sequence" && p.Keys = Recorder.EditingFile {
                index := i
                break
            }
        if !index {
            RecorderStatus("The loaded punishment is no longer in this profile")
            return
        }
    }
    try {
        events := BalanceRecordedEvents(Recorder.Events)
        if !events.Length
            throw Error("No playable inputs")
        file := "Macros\" RegExReplace(name, "[^A-Za-z0-9_-]", "_") "_" StrReplace(StrReplace(NewId(), "{", ""), "}", "") ".msq"
        text := "MESOSEQ1`n"
        for e in events
            text .= Line(e.At, e.Kind, e.Key, e.X, e.Y)
        DirCreate(A_ScriptDir "\Macros")
        WriteAtomic(A_ScriptDir "\" file, text)
        verified := LoadMacro(file)
        if verified.Length != events.Length
            throw Error("Recording validation failed; no wheel entry added")
        duration := Max(0.1, (events[events.Length].At + 100) / 1000)
        p := {Name: name, Enabled: true, Duration: duration, Weight: Float(RecordWeightEdit.Value), Action: "Recorded Sequence", Keys: file, Value: 0}
        if replace
            Punishments[index] := p
        else
            Punishments.Push(p)
        SavePunishments()
        Recorder.Events := events
        Recorder.EditingFile := file
        Recorder.EditingProfile := CurrentPunishmentProfile
        RefreshSettingsList()
        RefreshRecordedEvents()
        RecorderStatus("Saved · " name)
    } catch as err {
        RecorderStatus(err.Message)
        LogEvent("Recorder save: " err.Message)
    }
}

LoadSelectedRecording(*) {
    global Recorder, Punishments, SelectedEditorIndex, CurrentPunishmentProfile, RecordNameEdit, RecordWeightEdit
    if Recorder.Phase != "idle"
        return
    if SelectedEditorIndex < 1 || SelectedEditorIndex > Punishments.Length || Punishments[SelectedEditorIndex].Action != "Recorded Sequence" {
        RecorderStatus("Select a recorded punishment in Settings first")
        return
    }
    p := Punishments[SelectedEditorIndex]
    events := LoadMacro(p.Keys)
    if !events.Length {
        RecorderStatus("The selected recording is missing or invalid")
        return
    }
    Recorder.Events := events
    Recorder.EditingFile := p.Keys
    Recorder.EditingProfile := CurrentPunishmentProfile
    RecordNameEdit.Value := p.Name
    RecordWeightEdit.Value := p.Weight
    RefreshRecordedEvents()
    RecorderStatus("Loaded · " p.Name)
}

LoadMacro(relativePath) {
    if InStr(relativePath, "..") || RegExMatch(relativePath, "[:/]") || SubStr(relativePath, 1, 7) != "Macros\"
        return []
    try return ParseMacroText(FileRead(A_ScriptDir "\" relativePath, "UTF-8"))
    return []
}
