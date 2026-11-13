SharedKeySpecs() {
    return [
        ["shoot", "Fire", "LButton"], ["aim", "ADS", "RButton"],
        ["grenade", "Grenade", "q"], ["class", "Class Ability", "v"], ["airmove", "Air Move", "x"],
        ["forward", "Move Forward", "w"], ["back", "Move Backward", "s"],
        ["left", "Move Left", "a"], ["right", "Move Right", "d"],
        ["inventory", "Inventory", "i"], ["jump", "Jump", "Space"], ["crouch", "Crouch", "LControl"],
        ["weapon1", "Weapon 1", "1"], ["weapon2", "Weapon 2", "2"], ["weapon3", "Weapon 3", "3"],
        ["reload", "Reload", "r"], ["interact", "Interact", "e"], ["super", "Super", "f"],
        ["finisher", "Finisher", "g"], ["prismatic", "Prismatic", "b"], ["renegades", "Renegades Ability", "t"]
    ]
}

SharedActions() {
    static actions := Map(
        "Movement Jam", ["forward", "back", "left", "right"],
        "Spam Crouch", ["crouch"], "Spam Jump", ["jump"], "Random Shoot", ["shoot"],
        "Look Down + Shoot", ["shoot"], "Inventory Spam", ["inventory"],
        "Use Super", ["super"], "Cycle Keys", ["weapon1", "weapon2", "weapon3"]
    )
    return actions
}

SharedKeysForAction(action, legacy := "") {
    global SharedKeys
    if !IsSet(SharedKeys) || !SharedActions().Has(action)
        return []
    keys := []
    for i, id in SharedActions()[action] {
        ; Preserve older per-effect custom keys until the shared field is explicitly changed.
        key := SharedKeys.Keys[id]
        if !SharedKeys.Edited.Has(id) && IsObject(legacy) && i <= legacy.Length {
            old := SimpleKey(legacy[i])
            if old != "" && old != SharedKeys.Defaults[id]
                key := old
        }
        keys.Push(key)
    }
    return keys
}

LoadSharedKeys(path, punishments, chat) {
    keys := Map(), defaults := Map(), edited := Map(), customEffects := Map()
    for spec in SharedKeySpecs() {
        keys[spec[1]] := spec[3]
        defaults[spec[1]] := spec[3]
        if chat.Bindings.Has(spec[1])
            keys[spec[1]] := SimpleKey(chat.Bindings[spec[1]], spec[3])
    }
    for p in punishments {
        if !SharedActions().Has(p.Action)
            continue
        previous := KeyTokens(p.Keys)
        for i, id in SharedActions()[p.Action] {
            if i <= previous.Length && !customEffects.Has(id) {
                key := SimpleKey(previous[i])
                if key != "" && key != defaults[id] {
                    keys[id] := key
                    customEffects[id] := true
                }
            }
        }
    }
    for id, key in keys {
        saved := SimpleKey(IniRead(path, "SharedKeybinds", id, ""))
        if saved != "" {
            keys[id] := saved
            edited[id] := true
        }
    }
    return {Keys: keys, Defaults: defaults, Edited: edited}
}

JoinKeys(keys) {
    text := ""
    for key in keys
        text .= (text = "" ? "" : ";") key
    return text
}

BuildSharedKeySettings(gui) {
    global SharedKeys, SharedKeyButtons
    SharedKeyButtons := Map()
    gui.SetFont("s10 Norm cD6C9E7", "Segoe UI")
    for i, spec in SharedKeySpecs() {
        x := i <= 11 ? 40 : 420
        y := 142 + Mod(i - 1, 11) * 41
        gui.AddText("x" x " y" y + 5 " w142 h23", spec[2])
        button := gui.AddButton("x" x + 149 " y" y " w176 h30", SharedKeys.Keys[spec[1]])
        button.OnEvent("Click", BeginSharedKeyCapture.Bind(spec[1]))
        SharedKeyButtons[spec[1]] := button
    }
}

BeginSharedKeyCapture(id, *) {
    global SharedBindHook, SharedBindId, SharedKeyButtons
    StopEditorKeyCapture()
    StopSharedKeyCapture()
    SharedBindId := id
    SharedBindHook := InputHook("L0 T8 I1")
    SharedBindHook.KeyOpt("{All}", "NS")
    SharedBindHook.OnKeyDown := SharedKeyboardCaptured
    SharedBindHook.OnEnd := SharedCaptureEnded
    SharedKeyButtons[id].Text := "Waiting for input"
    SharedBindHook.Start()
}

SharedKeyboardCaptured(hook, vk, sc) {
    if vk != 0x1B {
        code := Format("vk{:02X}sc{:03X}", vk, sc)
        CaptureSharedKey(SimpleKey(GetKeyName(code), code))
    } else
        StopSharedKeyCapture()
}

SharedCaptureEnded(hook) {
    global SharedBindHook
    if SharedBindHook = hook
        StopSharedKeyCapture()
}

CaptureSharedKey(key) {
    global SharedBindHook, SharedBindId, SharedKeys, ConfigFile, SettingsGui, SelectedEditorIndex, Chat
    if !IsObject(SharedBindHook) || !GuiHwndSafe(SettingsGui) || !WinActive("ahk_id " SettingsGui.Hwnd)
        return false
    id := SharedBindId
    try {
        MesoIniWrite(key, ConfigFile, "SharedKeybinds", id)
        SharedKeys.Keys[id] := key
        SharedKeys.Edited[id] := true
        if Chat.Bindings.Has(id) {
            Chat.Bindings[id] := ChatKeyToken(key)
            RefreshChatSharedKey(id, Chat.Bindings[id])
        }
        if SelectedEditorIndex
            UpdateEditorHint()
    } catch as err {
        LogEvent("Shared key could not save: " err.Message)
        MsgBox("Could not save the keybind.", "Meso Control", "Iconx")
    } finally StopSharedKeyCapture()
    return true
}

StopSharedKeyCapture() {
    global SharedBindHook, SharedBindId, SharedKeyButtons, SharedKeys
    if !IsObject(SharedBindHook)
        return
    hook := SharedBindHook, id := SharedBindId
    SharedBindHook := 0, SharedBindId := ""
    hook.Stop()
    try SharedKeyButtons[id].Text := SharedKeys.Keys[id]
}

ChatKeyToken(key) {
    if AllowedChatKey(key)
        return key
    return Format("vk{:02X}sc{:03X}", GetKeyVK(key), GetKeySC(key))
}
