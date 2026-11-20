
OrdinaryChatMessages() {
    return [
        "I suck at this game.",
        "Drake is my favorite Artist!",
        "Chat is better than me.",
        "Soggy cereal is vastly superior to crunchy cereal.",
        "The middle seat on an airplane is the premium spot.",
        "Wet socks aren't actually that bad.",
        "Pineapple on pizza is not that bad.",
        "Using the word 'supper' in the 21st century is a blatant cry for attention.",
        "What is a shower?",
        "I'm a chud. I'm a chud. I'm a chud."
    ]
}

ChooseChatPhrase() {
    static recent := [], lastHorror := ""
    choices := ChatHorrorChoices(lastHorror)
    for phrase in OrdinaryChatMessages() {
        found := false
        for previous in recent {
            if phrase = previous {
                found := true
                break
            }
        }
        if !found
            choices.Push({Text: phrase, Weight: 2})
    }
    selected := choices[WeightedPick(choices)].Text
    if selected = SonionQuestion() || selected = TungChatPhrase() {
        lastHorror := selected
    } else {
        recent.Push(selected)
        if recent.Length > 5
            recent.RemoveAt(1)
    }
    return selected
}

SendChatMessage(p) {
    return p.HasOwnProp("ChatTestMessage") ? p.ChatTestMessage : ChooseChatPhrase()
}

TungChatPhrase() {
    return "he is coming.."
}

ChatHorrorChoices(lastHorror) {
    sonion := SonionQuestion(), tung := TungChatPhrase()
    bias := lastHorror = tung ? 1 : lastHorror = sonion ? -1 : 0
    return [{Text: tung, Weight: 3 - bias}, {Text: sonion, Weight: 3 + bias}]
}

InventorySwapKey() {
    global Punishments, SharedKeys
    if IsSet(SharedKeys)
        return SharedKeys.Keys["inventory"]
    for p in Punishments {
        if p.Action = "Inventory Spam" {
            keys := KeyTokens(p.Keys)
            if keys.Length && SimpleKey(keys[1]) != ""
                return SimpleKey(keys[1])
        }
    }
    return "i"
}

D2LoadoutCoordsForScreen(left, top, width, height, slot) {
    if width < 800 || height < 600 || !IsInteger(slot) || slot < 1 || slot > 20
        throw Error("Display size or loadout slot is invalid")
    if width * 9 >= height * 16 {
        panelWidth := Floor(height * 16 / 9)
        panelHeight := height
    } else {
        panelWidth := width
        panelHeight := Floor(width * 9 / 16)
    }
    scale := panelWidth / 2560.0
    xOffset := Floor((width - panelWidth) / 2)
    yOffset := height - panelHeight
    slotX := Floor(98.0 * scale)
    slotY := Floor(456.0 * scale)
    slotCenter := 118.0 * scale / 2.0
    pitch := 128.0 * scale
    col := Mod(slot - 1, 4)
    row := Floor((slot - 1) / 4)
    return {X: left + xOffset + Floor(slotX + col * pitch + slotCenter), Y: top + yOffset + Floor(slotY + row * pitch + slotCenter)}
}

D2LoadoutCoords(hwnd, slot) {
    if !hwnd || !WinExist("ahk_id " hwnd)
        throw Error("Destiny 2 is not available")
    WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
    bestMonitor := 0
    bestArea := 0
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &left, &top, &right, &bottom)
        overlapWidth := Max(0, Min(wx + ww, right) - Max(wx, left))
        overlapHeight := Max(0, Min(wy + wh, bottom) - Max(wy, top))
        overlapArea := overlapWidth * overlapHeight
        if overlapArea > bestArea {
            bestArea := overlapArea
            bestMonitor := A_Index
        }
    }
    if !bestMonitor
        throw Error("Cannot locate the game monitor")
    MonitorGet(bestMonitor, &left, &top, &right, &bottom)
    return D2LoadoutCoordsForScreen(left, top, right - left, bottom - top, slot)
}

D2LoadoutHover(hwnd, slot) {
    if !WinActive("ahk_id " hwnd)
        return false
    global InputLockOwners
    pos := D2LoadoutCoords(hwnd, slot)
    if InputLockOwners.Count
        return MoveLockedCursor(pos.X, pos.Y)
    return DllCall("user32\SetCursorPos", "Int", pos.X, "Int", pos.Y, "Int") != 0
}

D2LoadoutMouse(down) {
    global InputLockOwners
    if InputLockOwners.Count {
        SendLockedInput("LButton", down)
        return
    }
    DllCall("user32\mouse_event", "UInt", down ? 0x0002 : 0x0004, "Int", 0, "Int", 0, "UInt", 0, "UPtr", 0)
}

ForegroundTarget() {
    global DestinyOnlyMode, AppGui, SettingsGui, RecorderGui, AltTabActive
    h := WinExist("A")
    if !h || AltTabActive
        return 0
    try {
        exe := StrLower(WinGetProcessName("ahk_id " h))
        title := WinGetTitle("ahk_id " h)
        if exe = "autohotkey64.exe" || exe = "autohotkey32.exe" || exe = "explorer.exe" || exe = "obs64.exe" || exe = "cmd.exe" || exe = "powershell.exe" || exe = "windowsterminal.exe" || exe = "wscript.exe"
            return 0
        if h = GuiHwndSafe(AppGui) || h = GuiHwndSafe(SettingsGui) || h = GuiHwndSafe(RecorderGui)
            return 0
        if title = "Meso Stream Output" || title = "Meso Visual Effect"
            return 0
        if DestinyOnlyMode && exe != "destiny2.exe"
            return 0
        return h
    }
    return 0
}

KeyTokens(text) {
    a := []
    for key in StrSplit(text, ";")
        if Trim(key) != ""
            a.Push(Trim(key))
    return a
}

SimpleKey(key, fallback := "") {
    key := Trim(key, " {}`t")
    aliases := Map("ctrl", "LControl", "control", "LControl", "lctrl", "LControl", "rctrl", "RControl", "shift", "LShift", "alt", "LAlt")
    if aliases.Has(StrLower(key))
        key := aliases[StrLower(key)]
    if key = ""
        return fallback
    if RegExMatch(key, "i)^vk[0-9a-f]{2}sc[0-9a-f]{3}$")
        return key
    try {
        if GetKeyVK(key) || GetKeySC(key) || RegExMatch(key, "i)^(LButton|RButton|MButton|XButton1|XButton2|WheelUp|WheelDown|WheelLeft|WheelRight)$")
            return key
    }
    return fallback
}

KeyIsPhysical(key) {
    try return GetKeyState(key, "P")
    return false
}

InjectDown(key, releaseAt := 0) {
    global EffectOwnedKeys, Effect, GameKeyOwners
    key := SimpleKey(key)
    if key = ""
        throw Error("No valid input key is configured. Check Settings > Keys.")
    if EffectOwnedKeys.Has(key) || GameKeyOwners.Has(key)
        return false
    if !IsObject(Effect) || Effect.Preview || Effect.Phase != "running" || !WinActive("ahk_id " Effect.Target)
        return false
    if KeyIsPhysical(key) && !Effect.InputLock
        return false
    if IsWheelKey(key) {
        SendGameKey(key, true)
    } else {
        SendGameKey(key, true)
        GameKeyOwners[key] := Effect
        EffectOwnedKeys[key] := releaseAt
    }
    Effect.SentDown += 1
    Effect.LastKey := key
    return true
}

InjectUp(key) {
    global EffectOwnedKeys, Effect, GameKeyOwners, InputLockOwners
    key := SimpleKey(key)
    if EffectOwnedKeys.Has(key) {
        if !KeyIsPhysical(key) || InputLockOwners.Count || key = "LAlt" && Effect.P.Action = "Alt+Enter" {
            SendGameKey(key, false)
            if IsObject(Effect)
                Effect.SentUp += 1
        }
        EffectOwnedKeys.Delete(key)
        GameKeyOwners.Delete(key)
    }
}

ReleaseDueKeys(now) {
    global EffectOwnedKeys
    due := []
    for key, tick in EffectOwnedKeys
        if tick && now >= tick
            due.Push(key)
    for key in due
        InjectUp(key)
}

Pulse(key, now, hold := 55) {
    global EffectOwnedKeys
    key := SimpleKey(key)
    if key = ""
        throw Error("Invalid key binding. Choose the actual game key in Settings.")
    if InjectDown(key) {
        if EffectOwnedKeys.Has(key)
            EffectOwnedKeys[key] := NowMs() + Max(20, hold)
        return true
    }
    return false
}

SendGameKey(key, down) {
    global GameInputMethod, InputLockOwners
    if InputLockOwners.Count {
        SendLockedInput(key, down)
        return
    }
    if IsWheelKey(key) {
        if down
            SendEvent("{" key "}")
        return
    }
    token := key
    if !RegExMatch(key, "i)^(LButton|RButton|MButton|XButton1|XButton2|WheelUp|WheelDown|WheelLeft|WheelRight)$") {
        scan := GetKeySC(key)
        if scan
            token := Format("sc{:03X}", scan)
        else {
            vk := GetKeyVK(key)
            if !vk
                throw Error("Unknown game key: " key)
            token := Format("vk{:02X}", vk)
        }
    }
    event := "{Blind}{" token (down ? " down}" : " up}")
    if GameInputMethod = "Input"
        SendInput(event)
    else
        SendEvent(event)
}

CrouchPulseTiming(p) {
    hold := p.HasOwnProp("Value") && IsNumber(p.Value) && p.Value > 0 ? Max(40, Min(500, Round(p.Value))) : 120
    return {Hold: hold, Gap: 140}
}

EffectForegroundName() {
    try return WinGetProcessName("A")
    return "no foreground application"
}

EffectUiText() {
    global ActiveEffects, LastEffectMessage
    if !ActiveEffects.Length
        return LastEffectMessage
    if ActiveEffects.Length > 1 {
        names := ""
        for item in ActiveEffects
            names .= (names = "" ? "" : "  +  ") item.P.Name
        return names
    }
    return WithEffect(ActiveEffects[1], CurrentEffectUiText)
}

CurrentEffectUiText() {
    global Effect
    if Effect.Preview
        return "PREVIEW ONLY | " Effect.P.Name
    if Effect.Phase = "waiting" || Effect.Phase = "blocked"
        return Effect.Note
    if Effect.SentDown
        return "LIVE | " Effect.P.Name " | " Effect.LastKey " | " Effect.SentDown " key-downs sent"
    return "LIVE | " Effect.P.Name " | " Effect.Note
}

ExitConfirmDelay(p) {
    if p.HasOwnProp("Value") && IsNumber(p.Value) && p.Value > 0
        return Max(1, Min(2000, Round(p.Value)))
    return 50
}

StartEffect(p, preview, now, owner := "") {
    global ActiveEffects, SharedKeys
    keys := KeyTokens(p.Keys)
    shared := SharedKeysForAction(p.Action, keys)
    if shared.Length {
        ; Retain extra legacy cycle keys until one of its shared fields is set.
        if p.Action = "Cycle Keys" && keys.Length && !SharedKeys.Edited.Has("weapon1") && !SharedKeys.Edited.Has("weapon2") && !SharedKeys.Edited.Has("weapon3") && keys.Length != shared.Length
            shared := keys
        keys := shared
    }
    owned := Map()
    owned.CaseSense := "Off"
    duration := p.Action = "Random Loadout" ? Max(7000, Round(p.Duration * 1000)) : Max(100, Round(p.Duration * 1000))
    item := {P: p, Preview: preview, Owner: owner, Phase: preview ? "preview" : "waiting", Start: now, End: now + duration, Duration: duration, WaitUntil: now + 15000, Target: 0, Next: now, Step: 0, Note: preview ? "Preview - no game input" : "Waiting for game focus", Keys: keys, Sequence: [], Index: 1, LastMove: now, SentDown: 0, SentUp: 0, LastKey: "", LastWaitLog: 0, OwnedKeys: owned, InputLock: false, VisualPid: 0, VisualFile: "", VisualReady: false, VisualCheck: 0, VisualLaunch: 0, Sensitivity: 0}
    ActiveEffects.Push(item)
    WithEffect(item, BeginEffect, now)
    return item
}

WithEffect(item, callback, args*) {
    global Effect, EffectOwnedKeys
    previous := Effect, previousKeys := EffectOwnedKeys
    previousCritical := A_IsCritical
    Critical("On")
    Effect := item
    EffectOwnedKeys := item.OwnedKeys
    try return callback(args*)
    finally {
        Effect := previous, EffectOwnedKeys := previousKeys
        Critical(previousCritical)
    }
}

BeginEffect(now) {
    global Effect, Clock, LastEffectMessage, GameInputMethod
    p := Effect.P, preview := Effect.Preview
    LogEvent("Effect requested: " p.Name " | action=" p.Action " | preview=" preview " | keys=" p.Keys " | method=" GameInputMethod " | foreground=" EffectForegroundName())
    LastEffectMessage := preview ? "PREVIEW ONLY - Live spin sends game inputs" : "Starting " p.Name
    if preview
        return
    supported := false
    for name in ActionNames()
        if p.Action = name
            supported := true
    if !supported {
        BlockEffect("Unsupported action: " p.Action, now)
        return
    }
    if p.Action = "Jumpscare" {
        QueueRandomScare(ForegroundTarget(), now)
        Effect.Phase := "running"
        Effect.Note := "Jumpscare queued"
        Effect.End := now + 300
        return
    }
    if p.Action = "Time Tax" {
        Effect.Phase := "running"
        applied := Clock.Tax(120000, now, p.HasOwnProp("TimerGeneration") ? p.TimerGeneration : Clock.Generation)
        Effect.Note := applied > 0 ? "Removed " TimeText(applied) " from activity time" : "No running activity timer - skipped"
        return
    }
    Effect.End := Effect.WaitUntil
    TryActivateEffect(now)
}

BlockEffect(message, now) {
    global Effect, LastEffectMessage
    if !IsObject(Effect)
        return
    Effect.Phase := "blocked"
    Effect.Note := message
    Effect.End := now + 4000
    LastEffectMessage := message
    LogEvent("Blocked " Effect.P.Name ": " message)
}

TryActivateEffect(now) {
    global Effect, DestinyOnlyMode, LastEffectMessage, GameInputMethod, Chat, ChatEnabled
    global RuntimeDir, ActiveEffects, VisualHits, ChatEffect
    if !IsObject(Effect) || Effect.Phase != "waiting"
        return false
    if now >= Effect.WaitUntil {
        FinishEffect("No game focus within 15 seconds - no input sent")
        return false
    }
    target := ForegroundTarget()
    if !target {
        Effect.Note := DestinyOnlyMode ? "Waiting for Destiny 2 - click back into the game" : "Waiting for a permitted foreground game"
        LastEffectMessage := Effect.Note
        if !Effect.LastWaitLog || now - Effect.LastWaitLog >= 3000 {
            LogEvent(Effect.Note " | current=" EffectForegroundName())
            Effect.LastWaitLog := now
        }
        return false
    }
    if Effect.P.Action = "Chat Control" && (!ChatEnabled || !ChatForegroundAllowed(target)) {
        Effect.Note := "Waiting for the configured chat-control game"
        return false
    }
    p := Effect.P
    for other in ActiveEffects {
        if other != Effect && other.Phase = "running" && EffectsConflict(other.P.Action, p.Action) {
            Effect.Note := "Waiting for " other.P.Name
            return false
        }
    }
    permission := GamePermissionProblem(target)
    if permission != "" {
        BlockEffect(permission, now)
        return false
    }
    Effect.Target := target
    Effect.Start := now
    Effect.End := now + Effect.Duration
    Effect.Next := now
    Effect.LastMove := now
    Effect.Phase := "running"
    Effect.Note := "Active"
    LastEffectMessage := "LIVE | " p.Name
    if p.Action = "Chat Control" {
        ChatEffect := Effect
        Chat.Reset()
        Effect.Note := "Chat control active"
    }
    if p.Action = "Recorded Sequence" {
        Effect.Sequence := LoadMacro(p.Keys)
        if !Effect.Sequence.Length {
            BlockEffect("Recording missing or invalid", now)
            return false
        }
        Effect.End := now + Max(100, Effect.Sequence[Effect.Sequence.Length].At + 100)
    } else if IsVisualEffect(p.Action) {
        types := Map("Lights Out", "dark", "Tunnel Vision", "zoom", "Wide View", "wide", "Screen Shuffle", "puzzle", "Invert Screen", "mirror", "Drunk Vision", "drunk")
        hit := PunishmentVaries(p) && (p.Action = "Lights Out" || p.Action = "Tunnel Vision" || p.Action = "Wide View") ? VisualHits.Get(p.Action, 0) + 1 : 0
        parameter := VisualStrength(p, hit)
        Effect.VisualFile := RuntimeDir "\visual-" ProcessExist() "-" NewId() ".state"
        Effect.VisualLaunch := now
        Effect.Note := "Starting visual effect"
        cmd := Chr(34) A_AhkPath Chr(34) " " Chr(34) A_ScriptDir "\Meso_Visual_Effect.ahk" Chr(34) " " types[p.Action] " " target " " Effect.Duration " " parameter " " ProcessExist() " " Chr(34) Effect.VisualFile Chr(34)
        try {
            pid := 0
            Run(cmd, A_ScriptDir, "", &pid)
            Effect.VisualPid := pid
            Effect.VisualHit := hit
        } catch as err {
            BlockEffect("Visual effect could not launch: " err.Message, now)
            return false
        }
    } else if p.Action = "Turn M&K Off" || p.Action = "Random Loadout" {
        if BeginGameplayInputLock(Effect) {
            Effect.Note := "Input blocked"
        } else if p.Action = "Turn M&K Off" {
            BlockEffect("Input block unavailable. Restart Meso Control as administrator.", now)
            return false
        } else {
            Effect.InputLockUnavailable := true
            Effect.Note := "Loadout Roulette | Input block unavailable"
            LogEvent("Loadout Roulette will run without input blocking")
        }
    } else if p.Action = "Change Mouse Sensitivity" {
        try StartSensitivityWorker(Effect, now)
        catch as err {
            BlockEffect(err.Message, now)
            return false
        }
    } else if p.Action = "Return to Orbit"
        Effect.End += 350
    LogEvent("Input active: " p.Name " | target=" target " | exe=" EffectForegroundName() " | keys=" p.Keys " | method=" GameInputMethod " | admin=" A_IsAdmin)
    return true
}

AdvanceEffect(now) {
    global ActiveEffects
    for item in ActiveEffects.Clone()
        WithEffect(item, AdvanceOneEffect, now)
}

AdvanceOneEffect(now) {
    global Effect, AltTabActive, EffectOwnedKeys, InputLockOwners
    if !IsObject(Effect)
        return
    if Effect.Phase = "waiting" {
        if !TryActivateEffect(now)
            return
    }
    ReleaseDueKeys(now)
    CheckVisualWorker(now)
    CheckSensitivityWorker(Effect, now)
    if now >= Effect.End {
        FinishEffect()
        return
    }
    if Effect.Preview || Effect.Phase = "blocked" || Effect.P.Action = "Time Tax"
        return
    if !WinActive("ahk_id " Effect.Target) || AltTabActive {
        FinishEffect("Game lost focus: " EffectForegroundName())
        return
    }
    if now < Effect.Next
        return
    if InputLockOwners.Count && !Effect.InputLock && !IsVisualEffect(Effect.P.Action) && Effect.P.Action != "Change Mouse Sensitivity"
        return
    p := Effect.P
    keys := Effect.Keys
    first := keys.Length ? keys[1] : ""
    switch p.Action {
        case "Movement Jam":
            movement := keys.Length >= 4 ? [SimpleKey(keys[1], "w"), SimpleKey(keys[2], "s"), SimpleKey(keys[3], "a"), SimpleKey(keys[4], "d")] : ["w", "s", "a", "d"]
            for i, source in movement {
                opposite := movement[i + (Mod(i, 2) ? 1 : -1)]
                if source = opposite
                    continue
                if KeyIsPhysical(source) && !KeyIsPhysical(opposite)
                    InjectDown(opposite)
                else if EffectOwnedKeys.Has(opposite)
                    InjectUp(opposite)
            }
            Effect.Next := now + 25
        case "Spam Crouch":
            timing := CrouchPulseTiming(p)
            Pulse(SimpleKey(first, "LControl"), now, timing.Hold)
            Effect.Next := NowMs() + timing.Hold + timing.Gap
        case "Spam Jump":
            Pulse(SimpleKey(first, "Space"), now, 55)
            Effect.Next := now + 145
        case "Spam Key":
            Pulse(SimpleKey(first, "Ctrl"), now, 55)
            Effect.Next := now + 140
        case "Inventory Spam":
            Pulse(SimpleKey(first, "i"), now, 45)
            Effect.Next := now + 170
        case "Random Shoot":
            Pulse(SimpleKey(first, "LButton"), now, Random(35, 70))
            Effect.Next := now + Random(95, 200)
        case "Cycle Keys":
            if !keys.Length
                keys := ["1", "2", "3"]
            Pulse(SimpleKey(keys[Mod(Effect.Step, keys.Length) + 1]), now, 40)
            Effect.Step += 1
            Effect.Next := now + 140
        case "Use Super":
            if Effect.Step = 0 {
                Pulse(SimpleKey(first, "f"), now, 80)
                Effect.Step := 1
            }
            Effect.Next := Effect.End
        case "Spin 360":
            dx := Round(7 * Max(1, Min(1500, p.Value > 0 ? p.Value : 180)))
            SendGameplayMouse(dx, 0, 1)
            Effect.Next := now + 10
        case "Look Down + Shoot":
            if Effect.Step < 12 {
                DllCall("user32\mouse_event", "UInt", 1, "Int", 0, "Int", 120, "UInt", 0, "UPtr", 0)
                Effect.Step += 1
                Effect.Next := now + 18
            } else if Effect.Step = 12 {
                Pulse(SimpleKey(first, "LButton"), now, 1000)
                Effect.Step += 1
                Effect.Next := Effect.End
            }
        case "Exit Desktop":
            if Effect.Step = 0 {
                if !keys.Length || keys[1] = "+{Esc}" {
                    InjectDown("LShift", now + 35)
                    Pulse("Esc", now, 35)
                } else {
                    SendEvent(keys[1])
                }
                Effect.Step := 1
                Effect.Next := now + ExitConfirmDelay(p)
            } else if Effect.Step = 1 {
                Pulse(SimpleKey(keys.Length >= 2 ? keys[2] : "Enter", "Enter"), now, 45)
                Effect.Step := 2
                Effect.Next := Effect.End
            }
        case "Return to Orbit":
            if Effect.Step = 0 {
                Pulse(SimpleKey(first, "Tab"), now, 40)
                Effect.Step := 1
                Effect.Next := now + 350
            } else if Effect.Step = 1 {
                Effect.End := now + Round(Max(5, p.Duration) * 1000)
                InjectDown(keys.Length >= 2 ? SimpleKey(keys[2], "o") : "o", Effect.End)
                Effect.Step := 2
                Effect.Next := Effect.End
            }
        case "Random Loadout":
            if Effect.Step = 0 {
                Effect.InventoryKey := InventorySwapKey()
                if Pulse(Effect.InventoryKey, now, 110) {
                    Effect.Note := Effect.HasOwnProp("InputLockUnavailable") ? "Opening inventory | input lock unavailable" : "Opening inventory"
                    Effect.Step := 1
                    Effect.Next := now + 1150
                } else
                    Effect.Next := now + 100
            } else if Effect.Step = 1 {
                if Pulse("Left", now, 110) {
                    Effect.Note := "Opening loadouts"
                    Effect.Step := 2
                    Effect.Next := now + 1050
                } else
                    Effect.Next := now + 100
            } else if Effect.Step = 2 {
                maxSlot := p.Value >= 1 ? Max(1, Min(20, Round(p.Value))) : 12
                Effect.LoadoutSlot := Random(1, maxSlot)
                try {
                    if !D2LoadoutHover(Effect.Target, Effect.LoadoutSlot)
                        throw Error("Game was not focused")
                    pos := D2LoadoutCoords(Effect.Target, Effect.LoadoutSlot)
                    Effect.Note := "Selecting loadout " Effect.LoadoutSlot
                    LogEvent("Loadout slot " Effect.LoadoutSlot " hovered at " pos.X "," pos.Y)
                    Effect.Step := 3
                    Effect.Next := now + 300
                } catch as err {
                    FinishEffect("Loadout target unavailable: " err.Message)
                    return
                }
            } else if Effect.Step = 3 {
                if !Effect.InputLock && KeyIsPhysical("LButton") {
                    Effect.Next := now + 100
                    return
                }
                D2LoadoutMouse(true)
                Effect.LoadoutMouseDown := true
                Effect.LastKey := "LButton"
                Effect.SentDown += 1
                Effect.Step := 4
                Effect.Next := now + 115
            } else if Effect.Step = 4 {
                D2LoadoutMouse(false)
                Effect.LoadoutMouseDown := false
                Effect.SentUp += 1
                Effect.Note := "Waiting for loadout " Effect.LoadoutSlot
                Effect.Step := 5
                Effect.Next := now + 1850
            } else if Effect.Step = 5 {
                if Pulse(Effect.InventoryKey, now, 110) {
                    Effect.Note := "Returning to game"
                    Effect.Step := 6
                    Effect.Next := now + 450
                } else
                    Effect.Next := now + 100
            } else if Effect.Step = 6 {
                FinishEffect("Loadout slot " Effect.LoadoutSlot " clicked")
            }
        case "Alt+Enter":
            if Effect.Step = 0 {
                if !InjectDown("LAlt") {
                    Effect.Next := now + 100
                    return
                }
                Effect.Step := 1
            }
            if Pulse("Enter", now, 35)
                Effect.Next := now + Round(FixedPunishmentValue(p) * 1000)
            else
                Effect.Next := now + 50
        case "Send Chat":
            if Effect.Step = 0 {
                if !Pulse(SimpleKey(first, "Enter"), now, 35)
                    return
                Effect.Tabs := Random(0, 3)
                Effect.Step := 1
                Effect.Next := now + 180
            } else if Effect.Step = 1 && Effect.Tabs {
                if Pulse("Tab", now, 35)
                    Effect.Tabs -= 1
                Effect.Next := now + 90
            } else if Effect.Step = 1 {
                message := SendChatMessage(p)
                savedClipboard := ClipboardAll()
                try {
                    A_Clipboard := message
                    SendEvent("^v")
                    ; Give the game time to read the clipboard before restoring it.
                    Effect.Clipboard := savedClipboard
                    Effect.ClipboardSequence := DllCall("user32\GetClipboardSequenceNumber", "UInt")
                } catch as err {
                    A_Clipboard := savedClipboard
                    throw err
                }
                Effect.Note := message
                Effect.Step := 2
                Effect.Next := now + 110
            } else if Effect.Step = 2 {
                RestoreEffectClipboard(Effect)
                if !Pulse(SimpleKey(first, "Enter"), now, 35)
                    return
                if Effect.Note = TungChatPhrase()
                    ScheduleHorror(now + 15000)
                else if Effect.Note = SonionQuestion()
                    ScheduleSonion(Effect.Target, now)
                Effect.Step := 3
                Effect.Next := Effect.End
            }
        case "Custom Sequence":
            if Effect.Index <= keys.Length {
                key := keys[Effect.Index]
                SendEvent(InStr(key, "{") || RegExMatch(key, "^[+^!#]") ? key : "{" key "}")
                Effect.Index += 1
                Effect.Next := now + 100
            } else
                Effect.Next := Effect.End
        case "Chat Control":
            RunChatInput(now)
        case "Recorded Sequence":
            replayed := 0
            while Effect.Index <= Effect.Sequence.Length && Effect.Sequence[Effect.Index].At <= now - Effect.Start && replayed < 32 {
                e := Effect.Sequence[Effect.Index]
                switch e.Kind {
                    case "down": InjectDown(e.Key)
                    case "up": InjectUp(e.Key)
                    case "move": DllCall("user32\mouse_event", "UInt", 1, "Int", e.X, "Int", e.Y, "UInt", 0, "UPtr", 0)
                    case "wheel": SendEvent("{" e.Key "}")
                }
                Effect.Index += 1
                replayed += 1
            }
            Effect.Next := now + 5
        case "Drunk Vision":
            movement := SharedKeysForAction("Movement Jam")
            if !movement.Length
                movement := ["w", "s", "a", "d"]
            for i, original in movement {
                inverse := movement[i + (Mod(i, 2) ? 1 : -1)]
                if original = inverse
                    continue
                if KeyIsPhysical(original) && !KeyIsPhysical(inverse) && Random(1, 3) != 1
                    Pulse(inverse, now, Random(130, 250))
            }
            if Random(1, 7) = 1 {
                drift := Random(1, 2) = 1 ? movement[3] : movement[4]
                Pulse(drift, now, 160)
            }
            Effect.Next := now + Random(190, 390)
        case "Turn M&K Off":
            RefreshGameplayMouseLock()
            Effect.Next := now + 15
        case "Lights Out", "Tunnel Vision", "Wide View", "Screen Shuffle", "Invert Screen", "Change Mouse Sensitivity":
            Effect.Next := now + 50
    }
}

HasEffects(owner := "") {
    global ActiveEffects
    if owner = ""
        return ActiveEffects.Length > 0
    for item in ActiveEffects
        if item.Owner = owner
            return true
    return false
}

CancelEffects(reason := "") {
    global ActiveEffects
    StopSonion()
    CancelScares()
    for item in ActiveEffects.Clone()
        WithEffect(item, FinishEffect, reason)
}

FinishEffect(reason := "") {
    global Effect, EffectOwnedKeys, GameKeyOwners, ActiveEffects, LastEffectMessage, ChatEffect, Chat, ChatMouseActions, ChatRepeatJobs
    if !IsObject(Effect)
        return
    if Effect.HasOwnProp("LoadoutMouseDown") && Effect.LoadoutMouseDown {
        try D2LoadoutMouse(false)
        Effect.LoadoutMouseDown := false
    }
    if ChatEffect = Effect {
        Chat.Reset()
        ChatMouseActions := Map()
        ChatRepeatJobs := Map()
        ChatEffect := 0
    }
    for key in EffectOwnedKeys.Clone() {
        try InjectUp(key)
        catch as err
            LogEvent("Input release failed: " err.Message)
        if GameKeyOwners.Has(key)
            GameKeyOwners.Delete(key)
    }
    try RestoreEffectClipboard(Effect)
    try StopSensitivityWorker(Effect)
    try EndGameplayInputLock(Effect)
    if Effect.VisualFile != "" {
        try WriteAtomic(Effect.VisualFile ".cancel", "cancel")
        if Effect.VisualPid {
            previousDetect := A_DetectHiddenWindows
            DetectHiddenWindows(true)
            try PostMessage(0x8001, 0, 0,, "ahk_pid " Effect.VisualPid " ahk_class AutoHotkeyGUI")
            DetectHiddenWindows(previousDetect)
        }
    }
    outcome := reason != "" ? reason : Effect.Phase = "blocked" ? Effect.Note : Effect.Preview ? "Preview only - no input" : "Finished"
    summary := Effect.P.Name ": " outcome
    if !Effect.Preview
        summary .= " | " Effect.SentDown " key-downs sent"
    LastEffectMessage := summary
    LogEvent(summary " | key-ups=" Effect.SentUp " | last-key=" Effect.LastKey)
    for index, item in ActiveEffects {
        if item = Effect {
            ActiveEffects.RemoveAt(index)
            break
        }
    }
}

RestoreEffectClipboard(item) {
    if !item.HasOwnProp("Clipboard")
        return
    if item.ClipboardSequence = DllCall("user32\GetClipboardSequenceNumber", "UInt")
        A_Clipboard := item.Clipboard
    item.DeleteProp("Clipboard")
}

IsWheelKey(key) {
    return RegExMatch(key, "i)^Wheel(Up|Down|Left|Right)$")
}

IsVisualEffect(action) {
    return InStr("|Lights Out|Tunnel Vision|Wide View|Screen Shuffle|Invert Screen|Drunk Vision|", "|" action "|") > 0
}

EffectsConflict(a, b) {
    if a = b
        return a = "Chat Control" || a = "Random Loadout" || a = "Wide View" || a = "Change Mouse Sensitivity" || a = "Alt+Enter" || a = "Send Chat"
    return (a = "Alt+Enter" || a = "Random Loadout") && b = "Send Chat"
        || (b = "Alt+Enter" || b = "Random Loadout") && a = "Send Chat"
        || a = "Alt+Enter" && b = "Random Loadout" || b = "Alt+Enter" && a = "Random Loadout"
}

SendLockedInput(key, down) {
    static buttons := Map("lbutton", [0x2, 0x4, 0], "rbutton", [0x8, 0x10, 0],
        "mbutton", [0x20, 0x40, 0], "xbutton1", [0x80, 0x100, 1], "xbutton2", [0x80, 0x100, 2],
        "wheelup", [0x800, 0, 120], "wheeldown", [0x800, 0, -120],
        "wheelright", [0x1000, 0, 120], "wheelleft", [0x1000, 0, -120])
    event := Buffer(40, 0)
    if buttons.Has(StrLower(key)) {
        button := buttons[StrLower(key)]
        flags := button[down ? 1 : 2]
        if !flags
            return
        NumPut("Int", button[3], "UInt", flags, event, 16)
    } else {
        scan := GetKeySC(key)
        flags := (down ? 0 : 2) | (scan ? 8 : 0) | (scan & 0x100 ? 1 : 0)
        NumPut("UInt", 1, event)
        NumPut("UShort", scan ? 0 : GetKeyVK(key), "UShort", scan & 0xFF, "UInt", flags, event, 8)
    }
    if DllCall("user32\SendInput", "UInt", 1, "Ptr", event, "Int", event.Size, "UInt") != 1
        throw Error("Windows did not send " key)
}

GamePermissionProblem(hwnd) {
    if A_IsAdmin
        return ""
    process := 0, token := 0
    try {
        pid := WinGetPID("ahk_id " hwnd)
        process := DllCall("kernel32\OpenProcess", "UInt", 0x1000, "Int", 0, "UInt", pid, "Ptr")
        if process && DllCall("advapi32\OpenProcessToken", "Ptr", process, "UInt", 8, "Ptr*", &token) {
            data := Buffer(4, 0), length := 0
            if DllCall("advapi32\GetTokenInformation", "Ptr", token, "Int", 20, "Ptr", data, "UInt", 4, "UInt*", &length) && NumGet(data, 0, "UInt")
                return "Game is elevated - restart Meso Control as administrator"
        }
    } finally {
        if token
            DllCall("kernel32\CloseHandle", "Ptr", token)
        if process
            DllCall("kernel32\CloseHandle", "Ptr", process)
    }
    return ""
}

CheckVisualWorker(now) {
    global Effect, LastEffectMessage, VisualHits
    if !IsObject(Effect) || Effect.Preview || Effect.Phase != "running" || Effect.VisualFile = "" || now - Effect.VisualCheck < 100
        return
    Effect.VisualCheck := now
    failure := ""
    try {
        f := Fields(Trim(FileRead(Effect.VisualFile, "UTF-8"), "`r`n"))
        if f.Length >= 5 && IsNumber(f[1]) && Integer(f[1]) = Effect.VisualPid {
            if f[3] = "ready" && !Effect.VisualReady && IsNumber(f[5]) {
                Effect.VisualReady := true
                if Effect.VisualHit
                    VisualHits[Effect.P.Action] := Max(VisualHits.Get(Effect.P.Action, 0), Effect.VisualHit)
                Effect.End := f[5] + 0
                Effect.Note := "Active"
                LogEvent("Visual worker ready: " Effect.P.Name)
            } else if f[3] = "error" {
                failure := f[4]
            } else if f[3] = "stopped" {
                Effect.End := Min(Effect.End, now)
                return
            }
        }
    }
    if failure = "" && Effect.VisualPid && !ProcessExist(Effect.VisualPid) && now - Effect.VisualLaunch > 200
        failure := "Visual worker exited; see runtime\Meso.log"
    if failure = "" && !Effect.VisualReady && now - Effect.VisualLaunch > 3000
        failure := "Visual worker did not become ready; see runtime\Meso.log"
    if failure != "" {
        try WriteAtomic(Effect.VisualFile ".cancel", "cancel")
        Effect.Note := "Visual effect failed: " failure
        LastEffectMessage := Effect.Note
        Effect.Phase := "blocked"
        Effect.End := now + 3000
        LogEvent(Effect.Note)
    }
}
