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

