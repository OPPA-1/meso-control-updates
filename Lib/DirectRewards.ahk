BuildDirectSettings(gui) {
    global DirectSlotControls, DirectBypassCooldown, DirectCooldownCheck, DirectSaveStatus
    DirectCooldownCheck := gui.AddCheckbox("x442 y301 w324 h28", "Direct redeems bypass cooldown")
    DirectCooldownCheck.Value := DirectBypassCooldown
    gui.SetFont("s10 Bold cF4EDF9", "Segoe UI")
    gui.AddText("x40 y349 w635 h23", "DIRECT REDEEMS")
    gui.SetFont("s10 Norm cD6C9E7", "Segoe UI")
    DirectSlotControls := []
    loop 5 {
        x := A_Index <= 3 ? 40 : 420
        y := 378 + (A_Index <= 3 ? A_Index - 1 : A_Index - 4) * 39
        gui.AddText("x" x " y" y + 4 " w59 h23", "Slot " A_Index)
        DirectSlotControls.Push(gui.AddDropDownList("x" x + 62 " y" y " w191"))
        copy := gui.AddButton("x" x + 259 " y" y " w78 h25", "Copy args")
        copy.OnEvent("Click", CopyDirectArguments.Bind(A_Index))
    }
    save := gui.AddButton("x420 y456 w140 h27", "Save redeems")
    save.OnEvent("Click", SaveDirectFromUi)
    DirectSaveStatus := gui.AddText("x572 y460 w198 h23 cD3B7F3", "")
}

DirectArguments(slot, script) {
    return "//B //NoLogo " Chr(34) script Chr(34) " --direct " slot " %userName%"
}

CopyDirectArguments(slot, *) {
    global DirectSaveStatus
    A_Clipboard := DirectArguments(slot, A_ScriptDir "\Meso_Wheel_Trigger.vbs")
    SetText(DirectSaveStatus, "Slot " slot " arguments copied")
}

SaveDirectFromUi(*) {
    global DirectSaveStatus
    try {
        SaveDirectSettings()
        SetText(DirectSaveStatus, "Saved")
    } catch as err {
        SetText(DirectSaveStatus, "Could not save redeems")
        LogEvent("Direct redeem save failed: " err.Message)
    }
}

DirectPunishment(slot, profile := "") {
    global Punishments, CurrentPunishmentProfile
    if profile != "" && profile != CurrentPunishmentProfile
        return 0
    name := IniRead(PunishmentProfilePath(), "DirectRedeems", "Slot" slot, "")
    if name != "" {
        for p in Punishments
            if p.Name = name
                return p
    }
    return 0
}

RefreshDirectSlots() {
    global DirectSlotControls, Punishments
    choices := ["None"], names := Map()
    names.CaseSense := "Off"
    for p in Punishments {
        if !names.Has(p.Name) {
            choices.Push(p.Name)
            names[p.Name] := choices.Length
        }
    }
    for i, drop in DirectSlotControls {
        p := DirectPunishment(i)
        drop.Delete()
        drop.Add(choices)
        drop.Choose(IsObject(p) ? names[p.Name] : 1)
    }
}

SaveDirectSettings() {
    global ConfigFile, DirectCooldownCheck, DirectBypassCooldown, DirectSlotControls
    path := PunishmentProfilePath()
    staged := StageIniFile(path)
    try {
        for slot, drop in DirectSlotControls
            IniWrite(drop.Value > 1 ? drop.Text : "", staged, "DirectRedeems", "Slot" slot)
        CommitIniFile(staged, path)
    } finally {
        if FileExist(staged)
            try FileDelete(staged)
    }
    MesoIniWrite(DirectCooldownCheck.Value, ConfigFile, "Rounds", "DirectBypassCooldown")
    DirectBypassCooldown := DirectCooldownCheck.Value = 1
}

AcceptDirectReward(slot, viewer, id) {
    global Queue, DirectPending, LastEffectMessage, CurrentPunishmentProfile
    if Queue.Seen.Has(id)
        return "DUPLICATE|Request already received"
    if DirectPending.Length >= Queue.Limit
        return "FULL|Direct queue is full"
    p := DirectPunishment(slot)
    if !IsObject(p)
        return "UNSET|Direct slot " slot " is empty"
    DirectPending.Push({P: p.Clone(), Id: id, Viewer: viewer, Slot: slot, Profile: CurrentPunishmentProfile})
    Queue.Seen[id] := NowMs()
    LastEffectMessage := "Direct queued: " p.Name
    LogEvent("Direct reward queued | slot=" slot " | effect=" p.Name " | viewer=" viewer)
    UpdateMainUi()
    return "QUEUED|Direct slot " slot
}

AdvanceDirectRewards(now) {
    global DirectPending, WheelControllerEnabled, Queue, Recorder, Rounds, DirectBypassCooldown, Clock, ChatEnabled
    if !DirectPending.Length || !WheelControllerEnabled || Queue.Paused || Recorder.Phase != "idle"
        return
    if !DirectRewardReady(Rounds, DirectBypassCooldown, now)
        return
    request := DirectPending.RemoveAt(1)
    if request.P.Action = "Chat Control" && !ChatEnabled
        return
    request.P.TimerGeneration := Clock.Generation
    StartEffect(request.P, false, now)
}

DirectRewardReady(rounds, bypass, now) {
    return bypass || !rounds.Cooling(now)
}
