BalanceRecordedEvents(events) {
    result := [], held := Map()
    previous := 0
    for e in events {
        if e.At < previous || e.At > 60000 || e.At < 0
            throw Error("Invalid recording timing")
        if e.Kind = "down" {
            if held.Has(e.Key)
                continue
            held[e.Key] := true
        } else if e.Kind = "up" {
            if !held.Has(e.Key)
                continue
            held.Delete(e.Key)
        }
        result.Push(e.Clone())
        previous := e.At
    }
    for key in held
        result.Push({At: Min(60000, previous + 50), Kind: "up", Key: key, X: 0, Y: 0})
    return result
}

MacroKeyValid(key) {
    if RegExMatch(key, "i)^vk[0-9a-f]{2}sc[0-9a-f]{3}$")
        return true
    if RegExMatch(key, "i)^(LButton|RButton|MButton|XButton1|XButton2|WheelUp|WheelDown|WheelLeft|WheelRight)$")
        return true
    try return GetKeyVK(key) || GetKeySC(key)
    return false
}

ParseMacroText(text) {
    result := []
    try {
        rows := StrSplit(LTrim(text, Chr(0xFEFF)), "`n")
        if !rows.Length || Trim(rows[1], "`r`n`t ") != "MESOSEQ1"
            return []
        previous := 0
        loop rows.Length - 1 {
            row := rows[A_Index + 1]
            if Trim(row, "`r`n`t ") = ""
                continue
            f := Fields(row)
            if f.Length != 5 || !RegExMatch(f[1], "^\d+$") || !IsNumber(f[4]) || !IsNumber(f[5])
                return []
            at := Integer(f[1])
            if at < previous || at > 60000 || result.Length >= 5200
                return []
            if f[2] != "down" && f[2] != "up" && f[2] != "move" && f[2] != "wheel"
                return []
            if f[2] != "move" && !MacroKeyValid(f[3])
                return []
            if Abs(Float(f[4])) > 100000 || Abs(Float(f[5])) > 100000
                return []
            result.Push({At: at, Kind: f[2], Key: f[3], X: Integer(f[4]), Y: Integer(f[5])})
            previous := at
        }
    } catch {
        return []
    }
    return result
}
