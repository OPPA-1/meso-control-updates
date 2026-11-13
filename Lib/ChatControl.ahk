LoadChatSettings() {
    global ConfigFile, ChatEnabled, ChatGameExe
    ChatEnabled := IniRead(ConfigFile, "ChatControl", "Enabled", "1") = "1"
    ChatGameExe := StrLower(Trim(IniRead(ConfigFile, "ChatControl", "GameExe", "destiny2.exe")))
    policy := ChatPolicy()
    selectedMode := StrLower(IniRead(ConfigFile, "ChatControl", "CommandMode", "queue"))
    policy.Mode := selectedMode = "anytime" ? "anytime" : "queue"
    policy.RepeatEnabled := IniRead(ConfigFile, "ChatControl", "RepeatEnabled", "1") = "1"
    customCount := IniRead(ConfigFile, "ChatCommands", "Count", "")
    if customCount != "" && IsNumber(customCount) && Integer(customCount) >= 0 && Integer(customCount) <= 60 {
        saved := Map()
        loop Integer(customCount) {
            command := StrLower(Trim(IniRead(ConfigFile, "ChatCommands", "Name" A_Index, "")))
            key := Trim(IniRead(ConfigFile, "ChatCommands", "Key" A_Index, ""))
            if ChatCommandNameValid(command) && AllowedChatKey(key) && !saved.Has(command) {
                saved[command] := key
                policy.HoldEnabled[command] := IniRead(ConfigFile, "ChatCommands", "Hold" A_Index, DefaultChatHold(command) ? "1" : "0") = "1"
                policy.HoldMs[command] := ChatHoldDuration(IniRead(ConfigFile, "ChatCommands", "HoldMs" A_Index, "2000"))
            }
        }
        policy.Bindings := saved
    } else {
        for command, original in policy.Bindings {
            key := IniRead(ConfigFile, "ChatBindings", command, original)
            if AllowedChatKey(key)
                policy.Bindings[command] := key
        }
    }
    for name, key in BuiltInRewardChatKeys() {
        if !policy.Bindings.Has(name) || SubStr(name, 1, 5) = "emote"
            policy.Bindings[name] := key
    }
    for name, key in policy.Bindings {
        if !policy.HoldEnabled.Has(name)
            policy.HoldEnabled[name] := DefaultChatHold(name)
        if !policy.HoldMs.Has(name)
            policy.HoldMs[name] := 2000
    }
    for field in ["BannedText", "BannedInputs"] {
        values := []
        for item in StrSplit(IniRead(ConfigFile, "ChatControl", field, ""), "|")
            if Trim(item) != ""
                values.Push(StrLower(Trim(item)))
        policy.%field% := values
    }
    return policy
}

ChatBridgeBasePath() {
    localData := EnvGet("LOCALAPPDATA")
    if localData = ""
        localData := A_AppData
    return localData "\MesoControl\ChatBridge"
}

ChatBridgeInboxPath() {
    return ChatBridgeBasePath() "\Inbox"
}

ChatBridgeRepliesPath() {
    return ChatBridgeBasePath() "\Replies"
}

ChatBridgeInitialize() {
    global ChatRelayInbox, ChatRelayReplies
    DirCreate(ChatRelayInbox)
    DirCreate(ChatRelayReplies)
    Loop Files, ChatRelayInbox "\*.tmp", "F" {
        try FileDelete(A_LoopFileFullPath)
    }
    Loop Files, ChatRelayInbox "\*.msg", "F" {
        try {
            if DateDiff(A_Now, FileGetTime(A_LoopFileFullPath, "M"), "Seconds") > 20
                FileDelete(A_LoopFileFullPath)
        }
    }
    Loop Files, ChatRelayReplies "\*.tmp", "F" {
        try FileDelete(A_LoopFileFullPath)
    }
    Loop Files, ChatRelayReplies "\*.ack", "F" {
        try {
            if DateDiff(A_Now, FileGetTime(A_LoopFileFullPath, "M"), "Seconds") > 120
                FileDelete(A_LoopFileFullPath)
        }
    }
}

MesoChatPacket(raw) {
    parts := Fields(raw)
    if parts.Length = 4 && parts[1] = "mesochat3" {
        if !RegExMatch(parts[2], "^[A-Za-z0-9_-]{1,100}$")
            return 0
        if !RegExMatch(parts[3], "^[A-Za-z0-9_]{1,25}$")
            return 0
        if !ChatCommandNameValid(parts[4])
            return 0
        return {Id: parts[2], Viewer: parts[3], Token: parts[4], Message: "", LegacySent: 0, IsCommand: true}
    }
    if parts.Length = 4 && parts[1] = "mesochat2" {
        if !RegExMatch(parts[2], "^[A-Za-z0-9_-]{1,100}$")
            return 0
        if !RegExMatch(parts[3], "^[A-Za-z0-9_]{1,25}$")
            return 0
        if StrLen(parts[4]) > 160 || !RegExMatch(StrLower(parts[4]), "^![a-z][a-z0-9_]{0,19} [a-z0-9][a-z0-9_-]{0,23}$")
            return 0
        return {Id: parts[2], Viewer: parts[3], Message: parts[4], LegacySent: 0, IsCommand: false}
    }
    old := ParseMesoPacket(raw)
    if IsObject(old) && old.Mode = "chat"
        return {Id: old.Id, Viewer: old.Viewer, Message: old.Message, LegacySent: old.Sent, IsCommand: false}
    return 0
}

ChatRelayResult(code) {
    global Chat
    switch code {
        case 1:
            return "QUEUED|Command queued"
        case -1:
            return "OFF|Wheel Controller off"
        case -2:
            return "WAIT|Chat Takes Control not active"
        case -3:
            return "DISABLED|Chat control disabled"
        case -4:
            return "FOCUS|Game not focused"
        case -5:
            return "REJECTED|" Chat.LastReason
        case -6:
            return "INVALID|Invalid command token"
        case -7:
            return "UNKNOWN|Unknown command"
    }
    return "ERROR|Command not accepted"
}

ProcessChatRelayFile(path, fileId) {
    global Chat
    size := FileGetSize(path)
    if size > 1024 {
        FileDelete(path)
        ChatBridgeEvent("Relay: message too large")
        return "INVALID|Message too large"
    }
    age := DateDiff(A_Now, FileGetTime(path, "M"), "Seconds")
    raw := Trim(FileRead(path, "UTF-8"), "`r`n ")
    FileDelete(path)
    if age > 12 || age < -10 {
        ChatBridgeEvent("Relay: expired message")
        return "EXPIRED|Message expired"
    }
    packet := MesoChatPacket(raw)
    if !IsObject(packet) || packet.Id != fileId {
        ChatBridgeEvent("Relay: invalid command packet")
        return "INVALID|Invalid command packet"
    }
    viewer := NormalizeViewer(packet.Viewer)
    if viewer = "" {
        ChatBridgeEvent("Relay: invalid viewer")
        return "INVALID|Invalid viewer"
    }
    now := NowMs()
    if packet.LegacySent && (now - packet.LegacySent > 3000 || packet.LegacySent > now + 100) {
        ChatBridgeEvent("Relay: old message expired")
        return "EXPIRED|Old message expired"
    }
    command := packet.IsCommand ? packet.Token : ChatRelayAction(packet.Message)
    if command = "" {
        ChatBridgeEvent("Received · @" viewer " · invalid command")
        return "INVALID|Invalid chat command"
    }
    ChatBridgeEvent("Received · @" viewer " · " command)
    code := ReceiveChatInput(packet.Id, viewer, command, now)
    return ChatRelayResult(code)
}

ReadChatRelay(*) {
    static working := false
    global ChatRelayInbox, ChatRelayReplies
    if working
        return
    working := true
    try {
        count := 0
        Loop Files, ChatRelayInbox "\*.msg", "F" {
            count += 1
            if count > 40
                break
            fileId := RegExReplace(A_LoopFileName, "i)\.msg$")
            path := A_LoopFileFullPath
            if !RegExMatch(fileId, "^[A-Za-z0-9_-]{1,100}$") {
                try FileDelete(path)
                LogEvent("Chat relay invalid request filename")
                continue
            }
            reply := "ERROR|Chat relay failed"
            try reply := ProcessChatRelayFile(path, fileId)
            catch as err {
                LogEvent("Chat relay processing failed: " err.Message)
                ChatBridgeEvent("Relay: processing failed")
            }
            try WriteAtomic(ChatRelayReplies "\" fileId ".ack", reply)
            catch as err
                LogEvent("Chat relay acknowledgement failed: " err.Message)
        }
    } catch as err {
        LogEvent("Chat relay polling failed: " err.Message)
    } finally {
        working := false
    }
}

CopyChatRelayArguments(*) {
    global ChatSettingsStatus
    A_Clipboard := "//B //NoLogo " Chr(34) A_ScriptDir "\Meso_Chat_Command_Trigger.vbs" Chr(34) " " Chr(34) "%userName%" Chr(34) " " Chr(34) "%rawInput%" Chr(34)
    SetText(ChatSettingsStatus, "Command arguments copied")
}

TestChatRelay(*) {
    global ChatRelayInbox, ChatRelayReplies, ChatSettingsStatus
    id := "test" ProcessExist() A_TickCount Random(10000, 99999)
    tmp := ChatRelayInbox "\" id ".tmp"
    receipt := ChatRelayReplies "\" id ".ack"
    try {
        DirCreate(ChatRelayInbox)
        DirCreate(ChatRelayReplies)
        FileAppend("mesochat3|" id "|mesotest|jump", tmp, "UTF-8-RAW")
        FileMove(tmp, ChatRelayInbox "\" id ".msg")
        ReadChatRelay()
        if FileExist(receipt) {
            status := FileRead(receipt, "UTF-8")
            FileDelete(receipt)
            SetText(ChatSettingsStatus, "Relay · " StrReplace(status, "|", " · "))
        } else
            SetText(ChatSettingsStatus, "Relay test: no acknowledgement")
    } catch as err {
        try FileDelete(tmp)
        SetText(ChatSettingsStatus, "Relay test failed")
        LogEvent("Local chat relay test failed: " err.Message)
    }
}

ChatForegroundAllowed(target) {
    global ChatGameExe
    for modifier in ["LAlt", "RAlt", "LWin", "RWin"]
        if GetKeyState(modifier, "P")
            return false
    try return target && WinActive("ahk_id " target) && StrLower(WinGetProcessName("ahk_id " target)) = ChatGameExe
    return false
}

ChatBridgeEvent(message) {
    global ChatBridgeStatus, ChatRuntimeStatusLabel
    ChatBridgeStatus := message
    if IsSet(ChatRuntimeStatusLabel) && IsObject(ChatRuntimeStatusLabel)
        try SetText(ChatRuntimeStatusLabel, message)
    LogEvent("Chat: " message)
}

ReceiveChatInput(id, viewer, text, sent) {
    global Chat, ChatEnabled, ChatEffect, WheelControllerEnabled
    effect := ChatEffect
    if !WheelControllerEnabled {
        ChatBridgeEvent("Received · @" viewer " · Wheel Controller off")
        return -1
    }
    if !ChatEnabled {
        ChatBridgeEvent("Received · @" viewer " · Chat control disabled")
        return -3
    }
    token := ChatToken(text)
    if token = "" {
        ChatBridgeEvent("Received · @" viewer " · invalid command")
        return -6
    }
    if !Chat.Bindings.Has(token) && !Chat.Bindings.Has(ChatAlias(token)) {
        ChatBridgeEvent("Unknown chat command · " token)
        return -7
    }
    if !IsObject(effect) || effect.Preview || effect.Phase != "running" || effect.P.Action != "Chat Control" {
        ChatBridgeEvent("Received · @" viewer " · waiting for Chat Takes Control")
        return -2
    }
    now := NowMs()
    if now >= effect.End || !ChatForegroundAllowed(effect.Target) {
        ChatBridgeEvent("Received · @" viewer " · game not focused")
        return -4
    }
    if !Chat.Accept(id, viewer, text, sent, now, effect.Start) {
        ChatBridgeEvent("Received · @" viewer " · " Chat.LastReason)
        return -5
    }
    ChatBridgeEvent((Chat.Mode = "anytime" ? "Accepted" : "Queued") " · @" viewer " · " token)
    return 1
}

ChatRepeatStyle(command) {
    key := StrLower(command.Key)
    if !command.HasOwnProp("Repeat") || !command.Repeat
        return "none"
    if SubStr(key, 1, 6) = "mouse-"
        return "mouse"
    if InStr("|forward|back|left|right|sprint|crouch|aim|", "|" command.Token "|")
        return "held"
    if command.Hold || InStr("|shoot|interact|jump|reload|melee|grenade|", "|" command.Token "|")
        return "pulse"
    return "none"
}

RunChatMouse(now) {
    global ChatMouseActions
    if !IsSet(ChatMouseActions) || !IsObject(ChatMouseActions)
        ChatMouseActions := Map()
    expired := []
    for id, job in ChatMouseActions {
        if now >= job.End {
            expired.Push(id)
            continue
        }
        if now < job.Next
            continue
        repeated := job.HasOwnProp("Repeat") && job.Repeat
        stepX := repeated ? 42 : 20
        stepY := repeated ? 34 : 16
        dx := job.Direction = "mouse-left" ? -stepX : job.Direction = "mouse-right" ? stepX : 0
        dy := job.Direction = "mouse-up" ? -stepY : job.Direction = "mouse-down" ? stepY : 0
        DllCall("user32\mouse_event", "UInt", 1, "Int", dx, "Int", dy, "UInt", 0, "UPtr", 0)
        job.Next := now + (repeated ? 24 : 45)
    }
    for id in expired
        ChatMouseActions.Delete(id)
}

RunChatRepeats(now) {
    global ChatRepeatJobs, EffectOwnedKeys, Effect
    if !IsSet(ChatRepeatJobs) || !IsObject(ChatRepeatJobs)
        ChatRepeatJobs := Map()
    expired := []
    for id, job in ChatRepeatJobs {
        if now >= job.End {
            expired.Push(id)
            continue
        }
        if now < job.Next
            continue
        try {
            if job.Style = "held" {
                if EffectOwnedKeys.Has(job.Key) && !KeyIsPhysical(job.Key) {
                    SendGameKey(job.Key, true)
                    if IsObject(Effect)
                        Effect.SentDown += 1
                }
                job.Next := now + 115
            } else if job.Style = "pulse" {
                if !EffectOwnedKeys.Has(job.Key) && !KeyIsPhysical(job.Key)
                    Pulse(job.Key, now, 65)
                job.Next := now + 115
            }
        } catch as err {
            LogEvent("Chat repeat input stopped: " err.Message)
            expired.Push(id)
        }
    }
    for id in expired
        ChatRepeatJobs.Delete(id)
}

RunChatInput(now) {
    global Chat, ChatEnabled, Effect, EffectOwnedKeys, ChatMouseActions, ChatRepeatJobs
    if !ChatEnabled || !ChatForegroundAllowed(Effect.Target) {
        FinishEffect("Chat control stopped")
        return
    }
    RunChatMouse(now)
    RunChatRepeats(now)
    if Chat.Mode = "queue" && (EffectOwnedKeys.Count || ChatMouseActions.Count || ChatRepeatJobs.Count) {
        Effect.Next := now + 15
        return
    }
    command := Chat.Take(now)
    if !IsObject(command) {
        Effect.Next := now + 15
        return
    }
    key := StrLower(command.Key)
    remaining := Max(20, Effect.End - now)
    duration := Min(command.Duration, remaining)
    style := ChatRepeatStyle(command)
    sent := false
    if SubStr(key, 1, 6) = "mouse-" {
        if command.Hold || style = "mouse" {
            id := command.Token "_" now "_" Random(10000, 99999)
            ChatMouseActions[id] := {Direction: key, End: now + (command.Hold ? duration : Min(900, remaining)), Next: now, Repeat: style = "mouse"}
            sent := true
        } else {
            dx := key = "mouse-left" ? -75 : key = "mouse-right" ? 75 : 0
            dy := key = "mouse-up" ? -60 : key = "mouse-down" ? 60 : 0
            DllCall("user32\mouse_event", "UInt", 1, "Int", dx, "Int", dy, "UInt", 0, "UPtr", 0)
            sent := true
        }
    } else {
        input := SimpleKey(command.Key)
        if style = "pulse" {
            if !EffectOwnedKeys.Has(input) && !KeyIsPhysical(input) {
                sent := Pulse(command.Key, now, 65)
                if sent {
                    id := command.Token "_" now "_" Random(10000, 99999)
                    ChatRepeatJobs[id] := {Style: "pulse", Key: input, End: now + (command.Hold ? duration : Min(900, remaining)), Next: now + 115}
                }
            }
        } else if EffectOwnedKeys.Has(input) && Chat.Mode = "anytime" {
            EffectOwnedKeys[input] := Max(EffectOwnedKeys[input], now + duration)
            sent := true
        } else
            sent := Pulse(command.Key, now, duration)
        if sent && style = "held" {
            id := command.Token "_" now "_" Random(10000, 99999)
            ChatRepeatJobs[id] := {Style: "held", Key: input, End: now + duration, Next: now + 115}
        }
    }
    Effect.Note := "@" command.Viewer " · " StrUpper(command.Token)
    ChatBridgeEvent((sent ? "Windows input issued" : "Input busy") " · @" command.Viewer " · " command.Token)
    Effect.Next := now + 15
}

ChatBanLines(text) {
    result := []
    for row in StrSplit(StrReplace(text, "`r", ""), "`n") {
        word := StrLower(Trim(row))
        if word != "" && StrLen(word) <= 100 && !InStr(word, "|")
            result.Push(word)
    }
    return result
}

ChatJoin(list, delimiter := "`r`n") {
    text := ""
    for value in list
        text .= (A_Index > 1 ? delimiter : "") value
    return text
}

BuildChatSettings(gui) {
    global Chat, ChatEnabled, ChatGameExe, ChatEnableCheck, ChatExeEdit, ChatBindingList, ChatCommandEdit, ChatBindingEdit, ChatBannedTextEdit, ChatBannedInputEdit, ChatSettingsStatus, ChatRuntimeStatusLabel, ChatBridgeStatus, ChatHoldCheck, ChatHoldMsEdit, ChatModeDrop, ChatRepeatCheck
    gui.SetFont("s12 Bold cF4EDF9", "Segoe UI")
    gui.AddText("x40 y128 w700 h28", "CHAT TAKES CONTROL")
    gui.SetFont("s9 Norm cD6C9E7", "Segoe UI")
    ChatEnableCheck := gui.AddCheckbox("x40 y165 w280 h26", "Enable chat control")
    ChatEnableCheck.Value := ChatEnabled
    gui.AddText("x350 y169 w108 h23", "Game process")
    ChatExeEdit := gui.AddEdit("x459 y164 w317 h28 Background241B30 cFFFFFF", ChatGameExe)
    gui.AddText("x40 y205 w106 h22", "Command mode")
    ChatModeDrop := gui.AddDropDownList("x151 y200 w254", ["Queue commands", "Anytime (overlap)"])
    ChatModeDrop.Choose(Chat.Mode = "anytime" ? 2 : 1)
    ChatRepeatCheck := gui.AddCheckbox("x432 y202 w300 h26", "Repeat chat inputs")
    ChatRepeatCheck.Value := Chat.RepeatEnabled
    gui.AddText("x40 y243 w362 h21", "COMMANDS")
    ChatBindingList := gui.AddListView("x40 y265 w365 h180 NoSortHdr -Multi Background181323 cFFFFFF", ["Command", "Game input", "Hold", "ms"])
    ChatBindingList.ModifyCol(1, 120)
    ChatBindingList.ModifyCol(2, 102)
    ChatBindingList.ModifyCol(3, 50)
    ChatBindingList.ModifyCol(4, 65)
    DarkTable(ChatBindingList)
    for command, key in Chat.Bindings {
        enabled := Chat.HoldEnabled.Has(command) && Chat.HoldEnabled[command]
        ms := Chat.HoldMs.Has(command) ? Chat.HoldMs[command] : 2000
        ChatBindingList.Add("", command, key, enabled ? "Yes" : "No", ms)
    }
    ChatBindingList.OnEvent("ItemSelect", ChatBindingSelected)
    gui.AddText("x428 y243 w346 h21", "BLOCKED PHRASES")
    ChatBannedTextEdit := gui.AddEdit("x428 y265 w348 h77 Multi Background241B30 cFFFFFF", ChatJoin(Chat.BannedText))
    gui.AddText("x428 y352 w347 h21", "BLOCKED INPUTS")
    ChatBannedInputEdit := gui.AddEdit("x428 y373 w348 h71 Multi Background241B30 cFFFFFF", ChatJoin(Chat.BannedInputs))
    gui.AddText("x40 y454 w131 h20", "Command")
    gui.AddText("x182 y454 w120 h20", "Game input")
    ChatCommandEdit := gui.AddEdit("x40 y477 w132 h28 Background241B30 cFFFFFF", "")
    ChatBindingEdit := gui.AddEdit("x182 y477 w121 h28 Background241B30 cFFFFFF", "")
    ChatHoldCheck := gui.AddCheckbox("x40 y508 w149 h28", "Hold down")
    gui.AddText("x196 y514 w72 h20", "Hold (ms)")
    ChatHoldMsEdit := gui.AddEdit("x276 y509 w129 h26 Number Background241B30 cFFFFFF", "2000")
    b := gui.AddButton("x40 y546 w111 h29", "Add command")
    b.OnEvent("Click", AddChatCommand)
    b := gui.AddButton("x160 y546 w110 h29", "Update")
    b.OnEvent("Click", SetChatBinding)
    b := gui.AddButton("x280 y546 w125 h29", "Delete")
    b.OnEvent("Click", RemoveChatCommand)
    gui.AddText("x428 y457 w348 h21", "LIVE CHAT")
    ChatRuntimeStatusLabel := gui.AddText("x428 y482 w348 h44 cD3B7F3", ChatBridgeStatus)
    b := gui.AddButton("x428 y530 w160 h29", "Copy command args")
    b.OnEvent("Click", CopyChatRelayArguments)
    b := gui.AddButton("x596 y530 w180 h29", "Test relay")
    b.OnEvent("Click", TestChatRelay)
    ChatSettingsStatus := gui.AddText("x40 y584 w380 h37 cD3B7F3", "")
    b := gui.AddButton("x543 y583 w236 h36", "Save changes")
    b.OnEvent("Click", SaveChatSettings)
}

ChatBindingSelected(control, index, selected) {
    global ChatCommandEdit, ChatBindingEdit, ChatBindingList, ChatHoldCheck, ChatHoldMsEdit
    if selected {
        ChatCommandEdit.Value := ChatBindingList.GetText(index, 1)
        ChatBindingEdit.Value := ChatBindingList.GetText(index, 2)
        ChatHoldCheck.Value := ChatBindingList.GetText(index, 3) = "Yes"
        ChatHoldMsEdit.Value := ChatBindingList.GetText(index, 4)
    }
}

SetChatBinding(*) {
    global ChatCommandEdit, ChatBindingEdit, ChatBindingList, ChatSettingsStatus, ChatHoldCheck, ChatHoldMsEdit
    row := ChatBindingList.GetNext()
    if !row {
        SetText(ChatSettingsStatus, "Select a command row first.")
        return
    }
    name := StrLower(Trim(ChatCommandEdit.Value))
    key := Trim(ChatBindingEdit.Value)
    current := ChatBindingList.GetText(row, 1)
    fixed := BuiltInRewardChatKeys()
    if fixed.Has(current) && current != name {
        SetText(ChatSettingsStatus, "This command name is fixed.")
        return
    }
    if fixed.Has(name) && SubStr(name, 1, 5) = "emote"
        key := fixed[name]
    if !ChatCommandNameValid(name) || !AllowedChatKey(key) {
        SetText(ChatSettingsStatus, "Use a simple command name and a permitted game input.")
        return
    }
    loop ChatBindingList.GetCount()
        if A_Index != row && StrLower(ChatBindingList.GetText(A_Index, 1)) = name {
            SetText(ChatSettingsStatus, "That command name already exists.")
            return
        }
    ms := ChatHoldDuration(ChatHoldMsEdit.Value)
    global SharedKeys
    if SharedKeys.Keys.Has(name)
        key := ChatKeyToken(SharedKeys.Keys[name])
    ChatBindingList.Modify(row, "", name, key, ChatHoldCheck.Value ? "Yes" : "No", ms)
    SetText(ChatSettingsStatus, "Updated · Save to apply")
}

AddChatCommand(*) {
    global ChatCommandEdit, ChatBindingEdit, ChatBindingList, ChatSettingsStatus, ChatHoldCheck, ChatHoldMsEdit
    name := StrLower(Trim(ChatCommandEdit.Value))
    key := Trim(ChatBindingEdit.Value)
    if !ChatCommandNameValid(name) || !AllowedChatKey(key) {
        SetText(ChatSettingsStatus, "Name: a-z, 0-9, _ or -. Input: one allowed key.")
        return
    }
    if ChatBindingList.GetCount() >= 60 {
        SetText(ChatSettingsStatus, "Maximum 60 commands.")
        return
    }
    loop ChatBindingList.GetCount()
        if StrLower(ChatBindingList.GetText(A_Index, 1)) = name {
            SetText(ChatSettingsStatus, "That command already exists.")
            return
        }
    ms := ChatHoldDuration(ChatHoldMsEdit.Value)
    ChatBindingList.Add("", name, key, ChatHoldCheck.Value ? "Yes" : "No", ms)
    SetText(ChatSettingsStatus, "Added · Save to apply")
}

RemoveChatCommand(*) {
    global ChatBindingList, ChatSettingsStatus, ChatCommandEdit, ChatBindingEdit
    row := ChatBindingList.GetNext()
    if !row {
        SetText(ChatSettingsStatus, "Select a command row first.")
        return
    }
    if BuiltInRewardChatKeys().Has(ChatBindingList.GetText(row, 1)) {
        SetText(ChatSettingsStatus, "This command is built in.")
        return
    }
    ChatBindingList.Delete(row)
    ChatCommandEdit.Value := ""
    ChatBindingEdit.Value := ""
    SetText(ChatSettingsStatus, "Removed · Save to apply")
}

SaveChatSettings(*) {
    global Chat, ChatEnabled, ChatGameExe, ChatEnableCheck, ChatExeEdit, ChatBindingList, ChatBannedTextEdit, ChatBannedInputEdit, ChatSettingsStatus, ConfigFile, ChatEffect, ChatModeDrop, ChatRepeatCheck, SharedKeys
    exe := StrLower(Trim(ChatExeEdit.Value))
    if !RegExMatch(exe, "^[a-z0-9][a-z0-9_. -]{0,100}\.exe$") || InStr("|explorer.exe|cmd.exe|powershell.exe|pwsh.exe|chrome.exe|msedge.exe|firefox.exe|wscript.exe|cscript.exe|windowsterminal.exe|", "|" exe "|") {
        SetText(ChatSettingsStatus, "Enter a game executable name, not a system process.")
        return
    }
    bindings := Map()
    holdEnabled := Map()
    holdMs := Map()
    loop ChatBindingList.GetCount() {
        command := StrLower(Trim(ChatBindingList.GetText(A_Index, 1)))
        key := Trim(ChatBindingList.GetText(A_Index, 2))
        if !ChatCommandNameValid(command) || !AllowedChatKey(key) || bindings.Has(command) {
            SetText(ChatSettingsStatus, "Fix duplicate or invalid commands before saving.")
            return
        }
        bindings[command] := key
        holdEnabled[command] := ChatBindingList.GetText(A_Index, 3) = "Yes"
        holdMs[command] := ChatHoldDuration(ChatBindingList.GetText(A_Index, 4))
    }
    if bindings.Count = 0 {
        SetText(ChatSettingsStatus, "Add at least one command before saving.")
        return
    }
    bannedText := ChatBanLines(ChatBannedTextEdit.Value)
    bannedInputs := ChatBanLines(ChatBannedInputEdit.Value)
    Critical("On")
    try {
        staged := StageIniFile(ConfigFile)
        try {
            IniWrite(ChatEnableCheck.Value = 1 ? 1 : 0, staged, "ChatControl", "Enabled")
            IniWrite(exe, staged, "ChatControl", "GameExe")
            IniWrite(ChatModeDrop.Value = 2 ? "anytime" : "queue", staged, "ChatControl", "CommandMode")
            IniWrite(ChatRepeatCheck.Value = 1 ? 1 : 0, staged, "ChatControl", "RepeatEnabled")
            try IniDelete(staged, "ChatControl", "Prefix")
            IniWrite(ChatJoin(bannedText, "|"), staged, "ChatControl", "BannedText")
            IniWrite(ChatJoin(bannedInputs, "|"), staged, "ChatControl", "BannedInputs")
            try IniDelete(staged, "ChatCommands")
            IniWrite(bindings.Count, staged, "ChatCommands", "Count")
            index := 0
            for command, key in bindings {
                index += 1
                IniWrite(command, staged, "ChatCommands", "Name" index)
                IniWrite(key, staged, "ChatCommands", "Key" index)
                IniWrite(holdEnabled[command] ? 1 : 0, staged, "ChatCommands", "Hold" index)
                IniWrite(holdMs[command], staged, "ChatCommands", "HoldMs" index)
            }
            CommitIniFile(staged, ConfigFile)
        } catch as err {
            try FileDelete(staged)
            throw err
        }
    } catch as err {
        SetText(ChatSettingsStatus, "Save failed (file busy). Try again.")
        LogEvent("Chat settings save failed: " err.Message)
        return
    } finally {
        Critical("Off")
    }
    if IsObject(ChatEffect)
        WithEffect(ChatEffect, FinishEffect, "Chat settings changed")
    ChatEnabled := ChatEnableCheck.Value = 1
    ChatGameExe := exe
    Chat.Bindings := bindings
    for name, key in BuiltInRewardChatKeys()
        if !Chat.Bindings.Has(name) || SubStr(name, 1, 5) = "emote"
            Chat.Bindings[name] := key
    ApplySharedChatKeys()
    Chat.HoldEnabled := holdEnabled
    Chat.HoldMs := holdMs
    Chat.Mode := ChatModeDrop.Value = 2 ? "anytime" : "queue"
    Chat.RepeatEnabled := ChatRepeatCheck.Value = 1
    Chat.BannedText := bannedText
    Chat.BannedInputs := bannedInputs
    Chat.Reset()
    SetText(ChatSettingsStatus, "Saved")
}

BuiltInRewardChatKeys() {
    return Map("class", "v", "airmove", "x", "emote1", "Up", "emote2", "Left", "emote3", "Down", "emote4", "Right")
}

ApplySharedChatKeys() {
    global Chat, SharedKeys
    for name, key in SharedKeys.Keys {
        if Chat.Bindings.Has(name) && (SharedKeys.Edited.Has(name) || !Chat.Bindings[name] || Chat.Bindings[name] = SharedKeys.Defaults[name])
            Chat.Bindings[name] := ChatKeyToken(key)
    }
}

RefreshChatSharedKey(name, key) {
    global ChatBindingList, SettingsGui
    if !IsSet(ChatBindingList) || !GuiHwndSafe(SettingsGui)
        return
    loop ChatBindingList.GetCount()
        if ChatBindingList.GetText(A_Index, 1) = name
            ChatBindingList.Modify(A_Index, "Col2", key)
}
