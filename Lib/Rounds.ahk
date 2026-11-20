LoadRoundSettings() {
    global ConfigFile
    mode := IniRead(ConfigFile, "Rounds", "Mode", "normal")
    batch := IniRead(ConfigFile, "Rounds", "Spins", "5")
    seconds := IniRead(ConfigFile, "Rounds", "CooldownSeconds", "15")
    rounds := RoundCycle(mode, IsNumber(batch) ? batch : 5, IsNumber(seconds) ? seconds : 15)
    rounds.BonusPunishment := IniRead(ConfigFile, "Rounds", "BonusPunishment", "0") = "1"
    return rounds
}

BuildRoundSettings(gui) {
    global Rounds, RoundModeDrop, RoundCountEdit, RoundCooldownEdit, RoundNotice, RoundBonusCheck
    gui.SetFont("s12 Bold cF4EDF9", "Segoe UI")
    gui.AddText("x40 y132 w680 h30", "ROUND CONTROL")
    gui.SetFont("s10 Norm cD6C9E7", "Segoe UI")
    gui.AddText("x40 y190 w195 h26", "Run mode")
    RoundModeDrop := gui.AddDropDownList("x260 y184 w430", ["Standard redemptions", "Auto rounds", "Batch per redemption"])
    RoundModeDrop.Choose(Rounds.Mode = "auto" ? 2 : Rounds.Mode = "batch" ? 3 : 1)
    gui.AddText("x40 y248 w195 h26", "Spins per round")
    RoundCountEdit := gui.AddEdit("x260 y241 w154 h34 Number Background241B30 cFFFFFF", Rounds.BatchSize)
    gui.AddText("x40 y305 w195 h26", "Cooldown (seconds)")
    RoundCooldownEdit := gui.AddEdit("x260 y298 w154 h34 Background241B30 cFFFFFF", Rounds.CooldownMs / 1000)
    BuildDirectSettings(gui)
    RoundBonusCheck := gui.AddCheckbox("x40 y495 w290 h23", "2× bonus punishment")
    RoundBonusCheck.Value := Rounds.BonusPunishment
    RoundNotice := gui.AddText("x40 y522 w700 h30 cD3B7F3", "")
    button := gui.AddButton("x543 y554 w236 h36", "Save changes")
    button.OnEvent("Click", SaveRoundSettings)
}

SaveRoundSettings(*) {
    global Rounds, Queue, Recorder, RoundModeDrop, RoundCountEdit, RoundCooldownEdit, RoundNotice, RoundBonusCheck, ConfigFile
    if IsObject(Queue.Active) || Queue.Count() || HasEffects() || Recorder.Phase != "idle" {
        SetText(RoundNotice, "Pause and clear the queue before changing mode.")
        return
    }
    n := Trim(RoundCountEdit.Value), seconds := Trim(RoundCooldownEdit.Value)
    if !RegExMatch(n, "^\d+$") || Integer(n) < 1 || Integer(n) > 50 || !IsNumber(seconds) || seconds < 0 || seconds > 3600 {
        SetText(RoundNotice, "Spins: 1–50. Cooldown: 0–3600 seconds.")
        return
    }
    mode := RoundModeDrop.Value = 2 ? "auto" : RoundModeDrop.Value = 3 ? "batch" : "normal"
    bonus := RoundBonusCheck.Value
    try {
        SaveDirectSettings()
        MesoIniWrite(mode, ConfigFile, "Rounds", "Mode")
        MesoIniWrite(Integer(n), ConfigFile, "Rounds", "Spins")
        MesoIniWrite(seconds, ConfigFile, "Rounds", "CooldownSeconds")
        MesoIniWrite(bonus, ConfigFile, "Rounds", "BonusPunishment")
    } catch as err {
        SetText(RoundNotice, "Could not save settings")
        LogEvent("Round settings save failed: " err.Message)
        return
    }
    Rounds.Configure(mode, Integer(n), Float(seconds))
    Rounds.BonusPunishment := bonus = 1
    SetText(RoundNotice, "Saved")
    PublishState(true)
}

AcceptSpinRequest(id, preview, viewer, remote) {
    global Queue, Rounds
    if !preview && Rounds.Mode = "batch"
        return Queue.AcceptBatch(id, Rounds.BatchSize, NowMs(), viewer, remote)
    return Queue.Accept(id, preview, NowMs(), viewer, remote)
}

AcceptCooldownSkip(id, viewer) {
    global Queue, Rounds
    result := Queue.AcceptBatch(id, Rounds.BatchSize, NowMs(), viewer, true)
    if result = 1 {
        Rounds.Bonus(NowMs(), Rounds.BatchSize)
        LogEvent("Cooldown skipped | viewer=" viewer " | added=" Rounds.BatchSize)
    }
    return result
}

PublishCooldown(now) {
    global Rounds
    if Rounds.Cooling(now)
        return Line("active", "COOLDOWN", Rounds.CooldownUntil, "Next round", Rounds.CooldownStart)
    return Line("active", "", 0, "", 0)
}

PrepareSpin(job, pool, now) {
    global Clock
    job.Pool := pool
    job.Index := WeightedPick(pool)
    job.P := pool[job.Index].Clone()
    job.P.TimerGeneration := Clock.Generation
    job.Angle := 2160 + NormAngle(-90 - SliceCenter(pool, job.Index))
    job.VisualUntil := 0
    job.Start := now
    job.Phase := "spin"
    job.DisplayId := job.HasOwnProp("FirstResult") ? job.Id "#second" : job.Id
}

SpinEffectCount(job) {
    global Rounds
    if job.HasOwnProp("Spins") && job.Spins = 2
        return job.HasOwnProp("FirstResult") ? 2 : 0
    return Rounds.BonusPunishment ? 2 : 1
}

LandSpin(job, now) {
    global Clock, Rounds
    if job.HasOwnProp("Spins") && job.Spins = 2 && !job.HasOwnProp("FirstResult") {
        job.FirstResult := job.P
        PrepareSpin(job, job.Pool, now)
        PublishState(true)
        return
    }
    job.Phase := "result"
    job.VisualUntil := now + 3000
    if job.HasOwnProp("FirstResult")
        StartEffect(job.FirstResult, job.Preview, now, job.Id)
    if !job.HasOwnProp("FirstResult") && IsSet(Rounds) && Rounds.BonusPunishment {
        choices := []
        for candidate in job.Pool
            if CompatibleWheelPick(candidate, [job.P])
                choices.Push(candidate)
        if choices.Length {
            job.Bonus := choices[WeightedPick(choices)].Clone()
            job.Bonus.TimerGeneration := Clock.Generation
            job.BonusStart := now
        }
    }
    if job.HasOwnProp("Bonus") {
        job.P.BonusPair := true
        job.Bonus.BonusPair := true
    }
    StartEffect(job.P, job.Preview, now, job.Id)
    if job.HasOwnProp("Bonus")
        StartEffect(job.Bonus, job.Preview, now, job.Id)
}

CompatibleWheelPick(candidate, selected) {
    for p in selected
        if candidate.Name = p.Name || candidate.Action = p.Action || EffectsConflict(candidate.Action, p.Action)
            return false
    return true
}
