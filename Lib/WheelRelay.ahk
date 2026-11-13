WheelRelayBasePath() {
    localData := EnvGet("LOCALAPPDATA")
    if localData = ""
        localData := A_AppData
    return localData "\MesoControl\WheelBridge"
}

WheelRelayParse(raw) {
    tokens := StrSplit(Trim(raw, "`r`n "), "|")
    if tokens.Length != 3 || tokens[1] != "mesowheel2"
        return 0
    action := tokens[2]
    if action != "spin" && action != "preview" && action != "skip" && action != "double" && !RegExMatch(action, "^direct[1-5]$")
        return 0
    viewer := tokens[3] = "-" ? "" : tokens[3]
    if viewer != "" && !RegExMatch(viewer, "^[A-Za-z0-9_]{1,25}$")
        return 0
    return {Mode: action, Viewer: viewer}
}

WheelRelayInitialize() {
    global WheelRelayInbox, WheelRelayReplies
    DirCreate(WheelRelayInbox)
    DirCreate(WheelRelayReplies)
    Loop Files, WheelRelayInbox "\*.req", "F" {
        try FileDelete(A_LoopFileFullPath)
    }
    Loop Files, WheelRelayInbox "\*.tmp", "F" {
        try FileDelete(A_LoopFileFullPath)
    }
    Loop Files, WheelRelayReplies "\*.ack", "F" {
        try FileDelete(A_LoopFileFullPath)
    }
}

WheelRelayAccept(mode, viewer, id) {
    global WheelControllerEnabled, Queue, Rounds, LastEffectMessage
    if !WheelControllerEnabled && mode != "preview" {
        LogEvent("Wheel relay rejected: controller off | mode=" mode)
        return "OFF|Wheel Controller is off"
    }
    if Queue.Paused && mode != "preview" {
        LogEvent("Wheel relay rejected: queue paused | mode=" mode)
        return "PAUSED|Spin queue is paused"
    }
    if SubStr(mode, 1, 6) = "direct"
        return AcceptDirectReward(Integer(SubStr(mode, 7)), viewer, id)
    if mode = "double"
        accepted := Queue.Accept(id, false, NowMs(), viewer, true, 2)
    else if mode = "skip"
        accepted := AcceptCooldownSkip(id, viewer)
    else
        accepted := AcceptSpinRequest(id, mode = "preview", viewer, true)
    if accepted = -2
        return "FULL|Spin queue is full"
    if accepted = 2
        return "DUPLICATE|Request already received"
    if accepted != 1
        return "ERROR|Spin request rejected"
    caption := mode = "skip" ? "Cooldown skip queued" : mode = "preview" ? "Preview queued" : mode = "double" ? "Double spin queued" : "Spin queued"
    LastEffectMessage := caption (viewer != "" ? " · @" viewer : "")
    LogEvent("Wheel relay accepted: " caption " | viewer=" viewer " | id=" id)
    UpdateMainUi()
    PublishState(true)
    return "QUEUED|" caption
}

ReadWheelRelay(*) {
    static reading := false
    global WheelRelayInbox, WheelRelayReplies
    if reading
        return
    reading := true
    try {
        seen := 0
        Loop Files, WheelRelayInbox "\*.req", "F" {
            seen += 1
            if seen > 30
                break
            path := A_LoopFileFullPath
            id := RegExReplace(A_LoopFileName, "\.req$", "")
            if !RegExMatch(id, "^w[A-Za-z0-9_-]{2,75}$") {
                try FileDelete(path)
                LogEvent("Wheel relay ignored an invalid request filename")
                continue
            }
            result := "ERROR|Could not read request"
            try {
                modified := FileGetTime(path, "M")
                age := DateDiff(A_Now, modified, "Seconds")
                length := FileGetSize(path)
                if length > 180 || length < 13 {
                    result := "INVALID|Invalid request size"
                } else if age > 10 || age < -3 {
                    result := "EXPIRED|Request expired"
                } else {
                    payload := FileRead(path, "UTF-8")
                    req := WheelRelayParse(payload)
                    result := IsObject(req) ? WheelRelayAccept(req.Mode, req.Viewer, id) : "INVALID|Invalid request"
                }
                FileDelete(path)
            } catch as err {
                LogEvent("Wheel relay read failed: " err.Message)
                try FileDelete(path)
            }
            try WriteAtomic(WheelRelayReplies "\" id ".ack", result)
            catch as err
                LogEvent("Wheel relay acknowledgement failed: " err.Message)
        }
    } catch as err {
        LogEvent("Wheel relay polling failed: " err.Message)
    } finally {
        reading := false
    }
}
