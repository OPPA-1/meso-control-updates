RawAccelFolder() {
    global ConfigFile
    return IniRead(ConfigFile, "Input", "RawAccelFolder", "")
}

ChooseRawAccel(*) {
    global ConfigFile
    folder := DirSelect(RawAccelFolder(), 0, "Select the Raw Accel 1.7.1 folder")
    if folder = ""
        return
    if !FileExist(folder "\wrapper.dll") || !FileExist(folder "\Newtonsoft.Json.dll") {
        MsgBox("Select the extracted RawAccel folder containing wrapper.dll and Newtonsoft.Json.dll.", "Meso Control")
        return
    }
    try {
        MesoIniWrite(folder, ConfigFile, "Input", "RawAccelFolder")
        UpdateEditorHint()
    } catch as err {
        MsgBox("Could not save the Raw Accel folder.", "Meso Control")
        LogEvent("Raw Accel folder: " err.Message)
    }
}

SensitivityMultiplier(p, high := -1) {
    if !PunishmentVaries(p)
        return FixedPunishmentValue(p)
    if high < 0
        high := Random(0, 1)
    return high ? 3.0 : 0.25
}

SensitivityStatusPath(directory, pid, now) {
    return directory "\sensitivity-" pid "-" now "-" NewId() ".state"
}

StartSensitivityWorker(item, now) {
    global RuntimeDir
    folder := RawAccelFolder()
    if folder = ""
        throw Error("Link Raw Accel in the punishment settings")
    if !FileExist(folder "\wrapper.dll") || !FileExist(folder "\Newtonsoft.Json.dll")
        throw Error("Raw Accel files not found. Link the RawAccel folder again")
    mutex := DllCall("kernel32\OpenMutexW", "UInt", 0x100000, "Int", false, "WStr", "Local\MesoControlRawAccel", "Ptr")
    if mutex {
        DllCall("kernel32\CloseHandle", "Ptr", mutex)
        throw Error("Raw Accel is still restoring its profile")
    }
    multiplier := SensitivityMultiplier(item.P)
    item.Sensitivity := multiplier
    item.SensitivityFile := SensitivityStatusPath(RuntimeDir, ProcessExist(), now)
    item.SensitivityCheck := 0
    item.SensitivityReady := false
    item.SensitivityStartup := now + 8000
    cmd := UpdateQuote(A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe")
        . " -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "
        . UpdateQuote(A_ScriptDir "\Lib\RawAccelEffect.ps1")
        . " -Folder " UpdateQuote(folder) " -StatusPath " UpdateQuote(item.SensitivityFile)
        . " -ControllerPid " ProcessExist() " -Target " item.Target
        . " -DurationMs " item.Duration " -Multiplier " Format("{:.6f}", multiplier)
    pid := 0
    Run(cmd, A_ScriptDir, "Hide", &pid)
    item.SensitivityPid := pid
    item.End := item.SensitivityStartup
    item.Note := "Applying mouse sensitivity"
}

CheckSensitivityWorker(item, now) {
    if !item.HasOwnProp("SensitivityPid") || item.Phase != "running" || now - item.SensitivityCheck < 75
        return
    item.SensitivityCheck := now
    state := ""
    try state := Trim(FileRead(item.SensitivityFile, "UTF-8"), "`r`n ")
    if SubStr(state, 1, 6) = "error|" {
        BlockEffect(SubStr(state, 7), now)
        return
    }
    fields := StrSplit(state, "|")
    if fields[1] = "ready" && fields.Length = 3 && !item.SensitivityReady {
        item.SensitivityReady := true
        item.Start := Integer(fields[2])
        item.End := Integer(fields[3])
        multiplier := item.Sensitivity
        item.Note := (multiplier > 1 ? "High" : multiplier < 1 ? "Low" : "Normal") "  " multiplier "x"
        LogEvent("Raw Accel active: " item.Note)
    } else if fields[1] = "restored" {
        item.End := Min(item.End, now)
    }
    if state = "" && !ProcessExist(item.SensitivityPid)
        BlockEffect("Raw Accel worker did not start. Check the input log", now)
    else if !item.SensitivityReady && now >= item.SensitivityStartup
        BlockEffect("Raw Accel did not respond", now)
}

StopSensitivityWorker(item) {
    if !item.HasOwnProp("SensitivityFile")
        return
    try WriteAtomic(item.SensitivityFile ".cancel", "cancel")
}
