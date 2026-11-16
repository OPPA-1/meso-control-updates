; A low-level hook runs only while a blocking punishment is active.
BeginGameplayInputLock(item) {
    global InputLockOwners, GameplayLock
    if InputLockOwners.Count {
        if GameplayLock.Target != item.Target
            return false
    } else {
        GameplayLock := {Target: item.Target, Native: false, Keyboard: 0, Mouse: 0, KeyProc: 0, MouseProc: 0, Modifiers: Map(), Anchor: 0, PreviousClip: 0}
        for vk in [0xA2, 0xA3, 0xA4, 0xA5]
            GameplayLock.Modifiers[vk] := DllCall("user32\GetAsyncKeyState", "Int", vk, "Short") < 0

        ; Block system input and keep foreground hooks active for mouse and keyboard events.
        GameplayLock.Native := DllCall("user32\BlockInput", "Int", true, "Int") != 0
        nativeError := A_LastError
        hookError := 0
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
        if !GameplayLock.Native && (!GameplayLock.Keyboard || !GameplayLock.Mouse) {
            CloseGameplayInputLock()
            LogEvent("Input lock unavailable | BlockInput=" nativeError " | hooks=" hookError)
            return false
        }
        LogEvent(GameplayLock.Native ? "Input lock: Windows BlockInput plus foreground hooks" : "Input lock: foreground hooks | BlockInput=" nativeError)
        ClearHeldGameBindings()
    }
    InputLockOwners[item] := true
    item.InputLock := true
    RefreshGameplayMouseLock()
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
    else
        RefreshGameplayMouseLock()
}

CloseGameplayInputLock() {
    global GameplayLock
    if !IsObject(GameplayLock)
        return
    lock := GameplayLock
    ReleaseGameplayMouseClip(lock)
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

RefreshGameplayMouseLock() {
    global GameplayLock, InputLockOwners
    lock := GameplayLock
    if !IsObject(lock)
        return
    for owner in InputLockOwners {
        if owner.P.Action = "Random Loadout" {
            ReleaseGameplayMouseClip(lock)
            return
        }
    }
    if !WinActive("ahk_id " lock.Target)
        return
    current := Buffer(16, 0)
    if !DllCall("user32\GetClipCursor", "Ptr", current, "Int")
        return
    if IsObject(lock.Anchor) && SameMouseClip(current, lock.Anchor)
        return
    point := Buffer(8, 0)
    if !DllCall("user32\GetCursorPos", "Ptr", point, "Int")
        return
    x := NumGet(point, 0, "Int"), y := NumGet(point, 4, "Int")
    anchor := Buffer(16, 0)
    NumPut("Int", x, "Int", y, "Int", x + 1, "Int", y + 1, anchor)
    if DllCall("user32\ClipCursor", "Ptr", anchor, "Int")
        lock.PreviousClip := current, lock.Anchor := anchor
}

ReleaseGameplayMouseClip(lock) {
    if !IsObject(lock.Anchor)
        return
    current := Buffer(16, 0)
    if DllCall("user32\GetClipCursor", "Ptr", current, "Int") && SameMouseClip(current, lock.Anchor)
        DllCall("user32\ClipCursor", "Ptr", lock.PreviousClip, "Int")
    lock.Anchor := 0
    lock.PreviousClip := 0
}

SameMouseClip(a, b) {
    return NumGet(a, 0, "Int64") = NumGet(b, 0, "Int64") && NumGet(a, 8, "Int64") = NumGet(b, 8, "Int64")
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

SendGameplayMouse(dx, dy, flags) {
    event := Buffer(40, 0)
    NumPut("Int", dx, "Int", dy, "UInt", 0, "UInt", flags, event, 8)
    return DllCall("user32\SendInput", "UInt", 1, "Ptr", event, "Int", event.Size, "UInt") = 1
}

SetRawMouseSink(hwnd := 0) {
    rid := Buffer(8 + A_PtrSize, 0)
    NumPut("UShort", 1, "UShort", 2, "UInt", hwnd ? 0x100 : 1, "Ptr", hwnd, rid)
    return DllCall("user32\RegisterRawInputDevices", "Ptr", rid, "UInt", 1, "UInt", rid.Size, "Int") != 0
}
