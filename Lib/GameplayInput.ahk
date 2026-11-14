; A low-level hook runs only while a blocking punishment is active.
BeginGameplayInputLock(item) {
    global InputLockOwners, GameplayLock
    if InputLockOwners.Count {
        if GameplayLock.Target != item.Target
            return false
    } else {
        GameplayLock := {Target: item.Target, Native: false, Keyboard: 0, Mouse: 0, KeyProc: 0, MouseProc: 0, Modifiers: Map()}
        for vk in [0xA2, 0xA3, 0xA4, 0xA5]
            GameplayLock.Modifiers[vk] := DllCall("user32\GetAsyncKeyState", "Int", vk, "Short") < 0

        ; Prefer the system input gate. The hooks keep standard desktop installs usable.
        GameplayLock.Native := DllCall("user32\BlockInput", "Int", true, "Int") != 0
        nativeError := A_LastError
        hookError := 0
        if !GameplayLock.Native {
            try {
                GameplayLock.KeyProc := CallbackCreate(GameplayKeyboardHook, "", 3)
                GameplayLock.MouseProc := CallbackCreate(GameplayMouseHook, "", 3)
                module := DllCall("kernel32\GetModuleHandleW", "Ptr", 0, "Ptr")
                GameplayLock.Keyboard := DllCall("user32\SetWindowsHookExW", "Int", 13, "Ptr", GameplayLock.KeyProc, "Ptr", module, "UInt", 0, "Ptr")
                hookError := A_LastError
                if GameplayLock.Keyboard {
                    GameplayLock.Mouse := DllCall("user32\SetWindowsHookExW", "Int", 14, "Ptr", GameplayLock.MouseProc, "Ptr", module, "UInt", 0, "Ptr")
                    hookError := A_LastError
                }
            } catch as err {
                LogEvent("Input hook setup failed: " err.Message)
            }
            if !GameplayLock.Keyboard || !GameplayLock.Mouse {
                CloseGameplayInputLock()
                LogEvent("Input lock unavailable | BlockInput=" nativeError " | hooks=" hookError)
                return false
            }
            LogEvent("Input lock: foreground hooks | BlockInput=" nativeError)
        } else
            LogEvent("Input lock: Windows BlockInput")
        ClearHeldGameBindings()
    }
    InputLockOwners[item] := true
    item.InputLock := true
    return true
}

EndGameplayInputLock(item) {
    global InputLockOwners
    if !item.InputLock
        return
    item.InputLock := false
    InputLockOwners.Delete(item)
    if !InputLockOwners.Count
        CloseGameplayInputLock()
}

CloseGameplayInputLock() {
    global GameplayLock
    if !IsObject(GameplayLock)
        return
    lock := GameplayLock
    GameplayLock := 0
    if lock.Native && !DllCall("user32\BlockInput", "Int", false, "Int")
        LogEvent("Windows input unlock returned " A_LastError)
    if lock.Keyboard
        DllCall("user32\UnhookWindowsHookEx", "Ptr", lock.Keyboard)
    if lock.Mouse
        DllCall("user32\UnhookWindowsHookEx", "Ptr", lock.Mouse)
    if lock.KeyProc
        CallbackFree(lock.KeyProc)
    if lock.MouseProc
        CallbackFree(lock.MouseProc)
}

GameplayKeyboardHook(code, message, data) {
    global GameplayLock
    if code >= 0 && IsObject(GameplayLock) && DllCall("user32\GetForegroundWindow", "Ptr") = GameplayLock.Target {
        flags := NumGet(data, 8, "UInt")
        if !(flags & 0x10) {
            vk := NumGet(data, 0, "UInt")
            up := flags & 0x80
            mods := GameplayLock.Modifiers
            if mods.Has(vk)
                mods[vk] := !up
            if vk = 0x7B && !up && (mods[0xA2] || mods[0xA3]) && (mods[0xA4] || mods[0xA5])
                SetTimer(EmergencyStop, -1)
            return 1
        }
    }
    return DllCall("user32\CallNextHookEx", "Ptr", 0, "Int", code, "UPtr", message, "Ptr", data, "Ptr")
}

GameplayMouseHook(code, message, data) {
    global GameplayLock
    if code >= 0 && IsObject(GameplayLock) && !(NumGet(data, 12, "UInt") & 1) {
        if DllCall("user32\GetForegroundWindow", "Ptr") = GameplayLock.Target
            return 1
    }
    return DllCall("user32\CallNextHookEx", "Ptr", 0, "Int", code, "UPtr", message, "Ptr", data, "Ptr")
}

ClearHeldGameBindings() {
    global SharedKeys, GameKeyOwners
    if !IsSet(SharedKeys)
        return
    checked := Map()
    checked.CaseSense := "Off"
    for action, key in SharedKeys.Keys {
        if !IsWheelKey(key) && !checked.Has(key) && !GameKeyOwners.Has(key) && KeyIsPhysical(key)
            try SendLockedInput(key, false)
        checked[key] := true
    }
}

MoveLockedCursor(x, y) {
    left := SysGet(76), top := SysGet(77)
    w := Max(1, SysGet(78)), h := Max(1, SysGet(79))
    nx := Min(65535, Max(0, Floor((x - left + 0.5) * 65536 / w)))
    ny := Min(65535, Max(0, Floor((y - top + 0.5) * 65536 / h)))
    return SendGameplayMouse(nx, ny, 0xC001)
}

SendGameplayMouse(dx, dy, flags := 0x2001, tag := 0) {
    event := Buffer(40, 0)
    NumPut("Int", dx, "Int", dy, "UInt", 0, "UInt", flags, event, 8)
    NumPut("UPtr", tag, event, 32)
    return DllCall("user32\SendInput", "UInt", 1, "Ptr", event, "Int", event.Size, "UInt") = 1
}

SetRawMouseSink(hwnd := 0) {
    rid := Buffer(8 + A_PtrSize, 0)
    NumPut("UShort", 1, "UShort", 2, "UInt", hwnd ? 0x100 : 1, "Ptr", hwnd, rid)
    return DllCall("user32\RegisterRawInputDevices", "Ptr", rid, "UInt", 1, "UInt", rid.Size, "Int") != 0
}

StartRawSensitivity(item) {
    global AppGui, RawSensitivity
    if !SetRawMouseSink(AppGui.Hwnd)
        throw Error("Windows could not register raw mouse input (" A_LastError ")")
    multiplier := SensitivityMultiplier(item.P)
    item.Sensitivity := multiplier
    item.RawRemainderX := 0.0
    item.RawRemainderY := 0.0
    item.RawCorrections := []
    RawSensitivity := item
    item.Note := (multiplier > 1 ? "High" : multiplier < 1 ? "Low" : "Normal") "  " multiplier "x"
}

SensitivityMultiplier(p) {
    return PunishmentVaries(p) ? (Random(0, 1) ? 3.0 : 0.25) : Max(0.1, Min(5.0, p.Value))
}

RawMouseCorrection(delta, multiplier, &remainder) {
    adjustment := delta * (multiplier - 1) + remainder
    whole := Round(adjustment)
    remainder := adjustment - whole
    return whole
}

ProcessRawSensitivity(wParam, lParam, *) {
    global RawSensitivity, InputLockOwners
    item := RawSensitivity
    if !IsObject(item) || InputLockOwners.Count || item.Sensitivity = 1 || NowMs() >= item.End
        return
    if DllCall("user32\GetForegroundWindow", "Ptr") != item.Target
        return
    static report := Buffer(48, 0), correctionTag := 0x4D534F36
    header := 8 + A_PtrSize * 2
    size := report.Size
    read := DllCall("user32\GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", report, "UInt*", &size, "UInt", header, "UInt")
    if read < header + 24 || read > report.Size
        return
    if NumGet(report, 0, "UInt") != 0 || NumGet(report, header + 20, "UInt") = correctionTag
        return
    if !NumGet(report, 8, "Ptr") || NumGet(report, header, "UShort") & 1
        return
    dx := NumGet(report, header + 12, "Int")
    dy := NumGet(report, header + 16, "Int")
    if !dx && !dy
        return
    if Abs(dx) > 32767 || Abs(dy) > 32767
        return
    ; The injected correction is tagged. Also ignore a matching echo if a driver strips that tag.
    now := NowMs()
    while item.RawCorrections.Length && item.RawCorrections[1][3] < now
        item.RawCorrections.RemoveAt(1)
    for i, sent in item.RawCorrections {
        if sent[1] = dx && sent[2] = dy {
            item.RawCorrections.RemoveAt(i)
            return
        }
    }
    rx := item.RawRemainderX, ry := item.RawRemainderY
    x := RawMouseCorrection(dx, item.Sensitivity, &rx)
    y := RawMouseCorrection(dy, item.Sensitivity, &ry)
    item.RawRemainderX := rx, item.RawRemainderY := ry
    if !x && !y
        return
    ; Keep the echo buffer bounded at high polling rates.
    if item.RawCorrections.Length >= 128
        item.RawCorrections.RemoveAt(1)
    if SendGameplayMouse(x, y, 0x2001, correctionTag)
        item.RawCorrections.Push([x, y, now + 12])
    else {
        item.Note := "Windows rejected mouse input"
        item.End := now
        LogEvent("Mouse sensitivity: SendInput failed (" A_LastError ")")
    }
    ; Let Windows handle WM_INPUT cleanup for this window.
}

StopRawSensitivity(item) {
    global RawSensitivity
    if RawSensitivity != item
        return
    RawSensitivity := 0
    SetRawMouseSink()
}
