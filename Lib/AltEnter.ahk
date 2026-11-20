AltEnterPlan(duration, gap) {
    gap := Max(100, gap)
    count := Max(2, 2 * Ceil((Floor(duration / gap) + 1) / 2))
    return {Count: count, Duration: Max(duration, (count - 1) * gap + 60)}
}

RestoreAltEnter(item) {
    global PendingAltEnterRestores
    if !item.HasOwnProp("AltEnterCount") || !Mod(item.AltEnterCount, 2)
        return
    if CompleteAltEnterPair(item)
        return
    if !IsSet(PendingAltEnterRestores)
        PendingAltEnterRestores := Map()
    PendingAltEnterRestores[item.Target] := item
}

CompleteAltEnterPair(item) {
    global GameKeyOwners
    if IsSet(GameKeyOwners) {
        for key in ["Enter", "LAlt"]
            if GameKeyOwners.Has(key) && GameKeyOwners[key] != item
                return false
    }
    if !WinActive("ahk_id " item.Target)
        return false
    SendGameKey("Enter", false)
    SendGameKey("LAlt", true)
    try {
        SendGameKey("Enter", true)
        Sleep(35)
    } finally {
        SendGameKey("Enter", false)
        SendGameKey("LAlt", false)
    }
    item.AltEnterCount += 1
    LogEvent("Alt+Enter restored its starting mode after interruption")
    return true
}

AdvanceAltEnterRestores() {
    global PendingAltEnterRestores, AltTabActive
    if !IsSet(PendingAltEnterRestores) || IsSet(AltTabActive) && AltTabActive
        return
    for target, item in PendingAltEnterRestores.Clone() {
        if !WinExist("ahk_id " target) || CompleteAltEnterPair(item)
            PendingAltEnterRestores.Delete(target)
    }
}
