InitUpdates() {
    global Updates, ConfigFile
    DirCreate(A_ScriptDir "\.updates")
    repository := IniRead(ConfigFile, "Updates", "GitHubRepo", "OPPA-1/meso-control-updates")
    auto := IniRead(ConfigFile, "Updates", "ForceAuto", "1") = "1"
    Updates := {Pid: 0, Operation: "", LastCheck: auto ? NowMs() - 600000 : NowMs(), AutoCheck: auto, Ready: FileExist(A_ScriptDir "\.updates\ready.json") != "", Requested: false, Applying: false, StartedAt: 0, Message: repository = "" ? "Repository not set" : "Ready", Version: "", Repository: repository}
    state := IniRead(A_ScriptDir "\.updates\status.ini", "Update", "State", "")
    if state = "installed" || state = "repaired"
        Updates.Message := IniRead(A_ScriptDir "\.updates\status.ini", "Update", "Message", Updates.Message)
    if Updates.Ready
        Updates.Message := "Update ready to install"
}

UpdateQuote(value) {
    if InStr(value, Chr(34)) || InStr(value, "`n") || InStr(value, "`r")
        throw Error("Invalid command argument")
    return Chr(34) value Chr(34)
}

NormalizeGitHubRepository(value) {
    value := Trim(value)
    value := RegExReplace(value, "i)^https://github\.com/", "")
    value := RTrim(value, "/")
    return RegExMatch(value, "^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$") ? value : ""
}

RunUpdateHelper(operation, extras := "") {
    global Updates
    if Updates.Pid && ProcessExist(Updates.Pid)
        return false
    command := UpdateQuote(A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe") " -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File " UpdateQuote(A_ScriptDir "\Lib\GitHubUpdateTools.ps1") " -Operation " operation " -Root " UpdateQuote(A_ScriptDir) extras
    try {
        statusFile := A_ScriptDir "\.updates\status.ini"
        if FileExist(statusFile)
            FileDelete(statusFile)
        Updates.Operation := operation
        Updates.StartedAt := NowMs()
        Updates.Version := ""
        Updates.Message := operation = "Check" ? "Connecting to GitHub..." : operation = "StageLocal" ? "Validating local ZIP..." : operation = "Apply" ? "Installing update..." : operation = "Revert" ? "Restoring previous version..." : "Repairing update..."
        Run(command, A_ScriptDir, "Hide", &pid)
        Updates.Pid := pid
        RefreshUpdateStatus()
        return true
    } catch as err {
        Updates.Pid := 0
        Updates.Message := "Couldn't launch updater: " err.Message
        return false
    }
}

RollbackAvailable() {
    path := A_ScriptDir "\.updates\transaction.json"
    if !FileExist(path)
        return false
    try return RegExMatch(FileRead(path, "UTF-8"), '"State"\s*:\s*"complete"') > 0
    return false
}

BuildUpdateSettings(gui) {
    global Updates, UpdateStatusLabel, UpdateAutoCheck, UpdateRepoEdit, UpdateInstallButton, UpdateRollbackButton
    gui.SetFont("s12 Bold cF4EDF9", "Segoe UI")
    gui.AddText("x40 y130 w700 h28", "UPDATES")
    gui.SetFont("s9 Norm cD6C9E7", "Segoe UI")
    gui.AddText("x40 y159 w735 h21", "Meso Control " IniRead(A_ScriptDir "\version.ini", "App", "Version", "6.1.2"))
    UpdateStatusLabel := gui.AddText("x40 y180 w735 h43 cD3B7F3", Updates.Message)
    gui.AddText("x40 y239 w730 h22", "Repository  (owner/repo)")
    UpdateRepoEdit := gui.AddEdit("x40 y270 w555 h34 Background241B30 cFFFFFF", Updates.Repository)
    b := gui.AddButton("x607 y270 w169 h34", "Save")
    b.OnEvent("Click", SaveUpdateRepository)
    b := gui.AddButton("x40 y326 w230 h40", "Check online")
    b.OnEvent("Click", CheckUpdatesNow)
    b := gui.AddButton("x282 y326 w235 h40", "Choose local ZIP")
    b.OnEvent("Click", ChooseLocalUpdate)
    UpdateInstallButton := gui.AddButton("x530 y326 w246 h40", "Install update")
    UpdateInstallButton.Enabled := Updates.Ready
    UpdateInstallButton.OnEvent("Click", RequestUpdateInstall)
    UpdateAutoCheck := gui.AddCheckbox("x40 y390 w700 h29", "Always Check & Force new updates")
    UpdateAutoCheck.Value := Updates.AutoCheck
    UpdateAutoCheck.OnEvent("Click", SaveUpdatePreferences)
    gui.SetFont("s9 Bold cD6C9E7", "Segoe UI")
    gui.AddText("x40 y474 w290 h22", "RELEASE TOOLS")
    gui.AddText("x530 y474 w246 h22", "MAINTENANCE")
    gui.SetFont("s9 Norm cD6C9E7", "Segoe UI")
    b := gui.AddButton("x40 y506 w293 h37", "Create release")
    b.OnEvent("Click", OpenReleaseBuilder)
    b := gui.AddButton("x530 y506 w246 h37", "Repair update")
    b.OnEvent("Click", RepairInterruptedUpdate)
    UpdateRollbackButton := gui.AddButton("x530 y553 w246 h37", "Restore previous version")
    UpdateRollbackButton.Enabled := RollbackAvailable()
    UpdateRollbackButton.OnEvent("Click", RevertPreviousUpdate)
}

SaveUpdateRepository(*) {
    global Updates, UpdateRepoEdit, ConfigFile
    repository := NormalizeGitHubRepository(UpdateRepoEdit.Value)
    if repository = "" {
        Updates.Message := "Use a valid public repository: owner/repo"
        return
    }
    try MesoIniWrite(repository, ConfigFile, "Updates", "GitHubRepo")
    catch as err {
        Updates.Message := "Cannot save repository: " err.Message
        return
    }
    Updates.Repository := repository
    UpdateRepoEdit.Value := repository
    Updates.LastCheck := NowMs() - 600000
    Updates.Message := "Repository saved"
}

SaveUpdatePreferences(*) {
    global Updates, UpdateAutoCheck, ConfigFile
    selected := UpdateAutoCheck.Value = 1
    try MesoIniWrite(selected ? 1 : 0, ConfigFile, "Updates", "ForceAuto")
    catch as err {
        Updates.Message := "Could not save update preference: " err.Message
        return
    }
    Updates.AutoCheck := selected
    Updates.LastCheck := selected ? NowMs() - 600000 : NowMs()
    Updates.Message := selected ? "Automatic updates on · Every 10 minutes" : "Automatic updates off"
}

CheckUpdatesNow(*) {
    global Updates, UpdateRepoEdit
    repository := NormalizeGitHubRepository(UpdateRepoEdit.Value)
    if repository = "" {
        Updates.Message := "Set a repository first"
        return
    }
    if repository != Updates.Repository {
        Updates.Message := "Save the repository first"
        return
    }
    Updates.LastCheck := NowMs()
    RunUpdateHelper("Check", " -Repository " UpdateQuote(repository))
}

ChooseLocalUpdate(*) {
    global Updates
    if Updates.Pid && ProcessExist(Updates.Pid)
        return
    zip := FileSelect(1, , "Select a Meso Control release ZIP", "ZIP archives (*.zip)")
    if zip = ""
        return
    RunUpdateHelper("StageLocal", " -LocalZip " UpdateQuote(zip))
}

RequestUpdateInstall(*) {
    global Updates
    if !Updates.Ready {
        Updates.Message := "Check online or choose a local ZIP first."
        return
    }
    Updates.Requested := true
    Updates.Message := "Update requested. It will install after all active rounds and effects finish."
}

UpdateCanInstall(now) {
    global Queue, Rounds, Slots, Clock, Recorder, HorrorEvents, DirectPending
    global SettingsGui, PendingAltEnterRestores
    if GuiHwndSafe(SettingsGui) || SequenceBusy(now) || IsSet(PendingAltEnterRestores) && PendingAltEnterRestores.Count
        return false
    if IsObject(Queue.Active) || HasEffects() || DirectPending.Length || Recorder.Phase != "idle" || Slots.Phase = "spin" || Clock.Phase = "prep" || Clock.Phase = "activity" || Rounds.Phase = "running" || Rounds.Cooling(now)
        return false
    for event in HorrorEvents
        if now < event.Due + 100000
            return false
    return true
}

RefreshUpdateStatus(*) {
    global Updates, SettingsGui, UpdateStatusLabel, UpdateInstallButton, UpdateRollbackButton
    if !IsSet(Updates)
        return
    if Updates.Pid {
        statusFile := A_ScriptDir "\.updates\status.ini"
        state := IniRead(statusFile, "Update", "State", "")
        message := IniRead(statusFile, "Update", "Message", "")
        workerActive := ProcessExist(Updates.Pid) != 0
        if workerActive {
            if state = "working" && message != "" && message != "Check"
                Updates.Message := message
            else if Updates.Operation = "Check" && NowMs() - Updates.StartedAt > 45000 && state != "working"
                Updates.Message := "Checking for updates..."
            if NowMs() - Updates.StartedAt > 240000 && (Updates.Operation = "Check" || Updates.Operation = "StageLocal") {
                try ProcessClose(Updates.Pid)
                Updates.Pid := 0
                Updates.Operation := ""
                Updates.Message := "Update check timed out. Check your connection and retry."
                Updates.Version := ""
                LogEvent("Updater timed out")
            }
        } else {
            Updates.Pid := 0
            Updates.Operation := ""
            Updates.Version := IniRead(statusFile, "Update", "Version", "")
            Updates.Ready := FileExist(A_ScriptDir "\.updates\ready.json") != ""
            if (state = "" || state = "working") {
                Updates.Message := FileExist(A_ScriptDir "\.updates\last-error.txt") ? "Update failed. See .updates\last-error.txt" : "Update check stopped unexpectedly. Try again."
                Updates.Version := ""
                LogEvent("Updater exited without a final result")
            } else {
                Updates.Message := message != "" ? message : "Update check finished"
                if state = "error"
                    LogEvent("Updater error: " Updates.Message)
            }
        }
    }
    if GuiHwndSafe(SettingsGui) && IsSet(UpdateStatusLabel) && IsObject(UpdateStatusLabel) {
        try SetText(UpdateStatusLabel, Updates.Message (Updates.Version != "" ? "`nVersion " Updates.Version : ""))
        if IsSet(UpdateInstallButton) && IsObject(UpdateInstallButton)
            try UpdateInstallButton.Enabled := Updates.Ready && !Updates.Requested && !(Updates.Pid && ProcessExist(Updates.Pid))
        if IsSet(UpdateRollbackButton) && IsObject(UpdateRollbackButton)
            try UpdateRollbackButton.Enabled := RollbackAvailable() && !(Updates.Pid && ProcessExist(Updates.Pid))
    }
}

UpdatesTick(now) {
    global Updates, OutputPid, OutputEnabled, Queue, ConfigFile
    if !IsSet(Updates)
        return false
    if Updates.AutoCheck && Updates.Ready
        Updates.Requested := true
    if !Updates.Pid && Updates.Requested && Updates.Ready && UpdateCanInstall(now) {
        try {
            SaveAppSettings()
            SavePending()
            SaveUpdateSession()
        } catch as err {
            Updates.Requested := false
            Updates.Message := "Cannot save session before updating: " err.Message
            return false
        }
        extras := " -Interpreter " UpdateQuote(A_AhkPath) " -ControllerPid " ProcessExist() " -RendererPid 0 -KeepRenderer" (OutputEnabled ? " -ResumeOutput" : "")
        if RunUpdateHelper("Apply", extras) {
            Updates.Requested := false
            Updates.Applying := true
            ExitApp()
            return true
        }
    }
    if !Updates.Pid && Updates.AutoCheck && !Updates.Ready && !Updates.Requested && Updates.Repository != "" && now - Updates.LastCheck >= 600000 {
        Updates.LastCheck := now
        RunUpdateHelper("Check", " -Repository " UpdateQuote(Updates.Repository))
    }
    return false
}

OpenReleaseBuilder(*) {
    try Run(UpdateQuote(A_ComSpec) " /c " UpdateQuote(A_ScriptDir "\CREATE_RELEASE.cmd"), A_ScriptDir)
    catch as err
        MsgBox("Could not open the release builder: " err.Message, "Meso Control")
}

RepairInterruptedUpdate(*) {
    global Updates, OutputPid, OutputEnabled, Queue
    if Updates.Pid && ProcessExist(Updates.Pid)
        return
    if !UpdateCanInstall(NowMs()) {
        Updates.Message := "Finish or stop active tasks before repairing."
        return
    }
    if MsgBox("Repair an unfinished update? Meso Control will restart automatically.", "Repair Meso Control", "YesNo Default2") != "Yes"
        return
    Queue.Paused := true
    try {
        SaveAppSettings()
        SavePending()
    } catch as err {
        Updates.Message := "Cannot save session before repair: " err.Message
        return
    }
    if RunUpdateHelper("Repair", " -Interpreter " UpdateQuote(A_AhkPath) " -ControllerPid " ProcessExist() " -RendererPid 0 -KeepRenderer" (OutputEnabled ? " -ResumeOutput" : "")) {
        CloseStreamOutput()
        ExitApp()
    }
}

RevertPreviousUpdate(*) {
    global Updates, OutputPid, OutputEnabled, Queue
    if Updates.Pid && ProcessExist(Updates.Pid)
        return
    if !RollbackAvailable() {
        Updates.Message := "No previous version backup available"
        return
    }
    if !UpdateCanInstall(NowMs()) {
        Updates.Message := "Finish active rounds and timers before restoring."
        return
    }
    if MsgBox("Restore the previous Meso Control version? Current app files will be replaced. Settings, profiles, and recordings stay intact.", "Restore previous version", "YesNo Default2 Icon?") != "Yes"
        return
    Queue.Paused := true
    try {
        SaveAppSettings()
        SavePending()
    } catch as err {
        Updates.Message := "Could not save session: " err.Message
        Queue.Paused := false
        return
    }
    extras := " -Interpreter " UpdateQuote(A_AhkPath) " -ControllerPid " ProcessExist() " -RendererPid 0 -KeepRenderer" (OutputEnabled ? " -ResumeOutput" : "")
    if RunUpdateHelper("Revert", extras) {
        CloseStreamOutput()
        ExitApp()
    }
    Queue.Paused := false
}

SaveUpdateSession() {
    global Queue, AppGui, Slots, Clock, OutputEnabled, OutputPid, Guides, VisualHits, RuntimeDir
    WinGetPos(&x, &y, &w, &h, "ahk_id " AppGui.Hwnd)
    visible := DllCall("user32\IsWindowVisible", "Ptr", AppGui.Hwnd, "Int")
    nl := Chr(10)
    text := "[Session]" nl "SavedAt=" NowMs() nl "Paused=" (Queue.Paused ? 1 : 0) nl "Completed=" Queue.Completed nl "X=" x nl "Y=" y nl "Visible=" visible nl "Output=" (OutputEnabled ? 1 : 0) nl "Guides=" (Guides ? 1 : 0) nl
    text .= "[Clock]" nl "Phase=" Clock.Phase nl "Generation=" Clock.Generation nl
    text .= "[Slots]" nl "Phase=" Slots.Phase nl "Locked=" Slots.Locked nl "Id=" Slots.Id nl
    for i, value in Slots.Values
        text .= "Value" i "=" value nl
    text .= "[VisualHits]" nl
    for action, count in VisualHits
        text .= action "=" count nl
    WriteAtomic(A_ScriptDir "\.updates\session.ini", text)
    seen := ""
    for id, tick in Queue.Seen
        seen .= Line(id, tick)
    WriteAtomic(RuntimeDir "\update-seen.state", seen)
}
RestoreUpdateSession() {
    global Queue, AppGui, Slots, Clock, OutputEnabled, OutputPid, Guides, VisualHits, RuntimeDir, OutputCheck, GuideCheck, OutputReloadUntil
    path := A_ScriptDir "\.updates\session.ini"
    if !FileExist(path)
        return false
    try {
        age := NowMs() - Integer(IniRead(path, "Session", "SavedAt", "0"))
        if age < 0 || age > 600000
            return false
        Queue.Paused := IniRead(path, "Session", "Paused", "0") = "1"
        Queue.Completed := Integer(IniRead(path, "Session", "Completed", "0"))
        Guides := IniRead(path, "Session", "Guides", "0") = "1"
        OutputEnabled := IniRead(path, "Session", "Output", "0") = "1"
        OutputPid := OutputEnabled ? ExistingStreamOutputPid() : 0
        if IsSet(OutputCheck)
            OutputCheck.Value := OutputEnabled
        if IsSet(GuideCheck)
            GuideCheck.Enabled := OutputEnabled
        if OutputPid {
            renderer := StreamOutputWindow(OutputPid)
            OutputReloadUntil := NowMs()+5000
            if renderer
                SetTimer((*) => PostMessage(0x8004, 0, 0,, "ahk_id " renderer), -800)
        }
        Clock.Phase := IniRead(path, "Clock", "Phase", "idle") = "ready" ? "ready" : "idle"
        Clock.Generation := Integer(IniRead(path, "Clock", "Generation", "0"))
        Slots.Phase := "idle"
        Slots.Locked := Integer(IniRead(path, "Slots", "Locked", "0"))
        Slots.Id := IniRead(path, "Slots", "Id", "")
        loop 4
            Slots.Values[A_Index] := IniRead(path, "Slots", "Value" A_Index, "")
        for action in ["Lights Out", "Tunnel Vision", "Wide View"]
            VisualHits[action] := Integer(IniRead(path, "VisualHits", action, "0"))
        try {
            for row in StrSplit(FileRead(RuntimeDir "\update-seen.state", "UTF-8"), Chr(10)) {
                f := Fields(row)
                if f.Length = 2 && IsNumber(f[2])
                    Queue.Seen[f[1]] := f[2]+0
            }
            FileDelete(RuntimeDir "\update-seen.state")
        }
        x := Integer(IniRead(path, "Session", "X", "0")), y := Integer(IniRead(path, "Session", "Y", "0"))
        WinMove(x, y,,, "ahk_id " AppGui.Hwnd)
        if IniRead(path, "Session", "Visible", "1") = "1"
            AppGui.Show("NA")
        else
            AppGui.Hide()
        return true
    } catch as err {
        LogEvent("Update session: " err.Message)
        return false
    } finally {
        try FileDelete(path)
    }
}
