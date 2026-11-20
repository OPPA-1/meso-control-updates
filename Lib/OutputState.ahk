EmptyState() {
    return {Pid: 0, Revision: 0, PublishedAt: 0, Wheel: ["wheel", "idle", "", "0", "0", "", "0", "0", "", "1", "wheel", "0"], DisplayMode: "wheel", Items: [], Slots: ["slots", "idle", "", "0", "0", "0", "0", "0", "", "", "", ""], Pools: Map(), Timer: ["timer", "idle", "0", "0", "0"], Active: ["active", "", "0", "", "0"], ActiveItems: [], FirstResult: "", Bonus: "", BonusStart: 0, GlitchStart: 0, GlitchEnd: 0, Queue: 0, Paused: false, Guides: false, Score: ["score", "0", "0", "0"], HorrorEvents: [], Sounds: [], Scare: []}
}

RequireOutputFields(fields, count, tag) {
    if fields.Length < count
        throw Error("Incomplete output record: " tag)
}

RequireOutputNumber(value, tag) {
    if !IsNumber(value)
        throw Error("Invalid output number: " tag)
    return value + 0
}

RequireOutputPhase(value, allowed, tag) {
    if !InStr("|" allowed "|", "|" value "|")
        throw Error("Invalid output phase: " tag)
}

ParseOutputState(data) {
    next := EmptyState()
    seen := Map()
    data := LTrim(data, Chr(0xFEFF))
    for row in StrSplit(data, "`n") {
        if Trim(row, "`r`t ") = ""
            continue
        f := Fields(row)
        if !f.Length
            continue
        tag := f[1]
        switch tag {
            case "meta":
                RequireOutputFields(f, 4, tag)
                next.Revision := Integer(f[2])
                next.Pid := Integer(f[3])
                next.PublishedAt := RequireOutputNumber(f[4], tag)
                if next.Revision < 0 || next.Pid <= 0
                    throw Error("Invalid output metadata")
            case "status":
                RequireOutputFields(f, 4, tag)
                next.Queue := Max(0, Integer(f[2]))
                next.Paused := f[3] = "1"
                next.Guides := f[4] = "1"
            case "wheel":
                RequireOutputFields(f, 8, tag)
                RequireOutputPhase(f[2], "idle|announce|spin|hold|result", tag)
                RequireOutputNumber(f[4], tag)
                RequireOutputNumber(f[5], tag)
                RequireOutputNumber(f[7], tag)
                while f.Length < 12
                    f.Push(f.Length = 10 ? "wheel" : f.Length = 11 ? "0" : "")
                if f[11] != "reel" && f[11] != "wheel"
                    f[11] := "wheel"
                next.DisplayMode := f[11]
                next.Wheel := f
            case "item":
                RequireOutputFields(f, 3, tag)
                weight := RequireOutputNumber(f[3], tag)
                if weight <= 0
                    throw Error("Invalid wheel weight")
                next.Items.Push({Name: f[2], Weight: weight})
            case "slots":
                RequireOutputFields(f, 12, tag)
                RequireOutputPhase(f[2], "idle|spin|wait|hold", tag)
                RequireOutputNumber(f[4], tag)
                RequireOutputNumber(f[8], tag)
                reel := Integer(f[6]), locked := Integer(f[7])
                if reel < 0 || reel > 4 || locked < 0 || locked > 4
                    throw Error("Invalid reel index")
                next.Slots := f
            case "pool":
                RequireOutputFields(f, 3, tag)
                reel := Integer(f[2])
                if reel < 1 || reel > 4
                    throw Error("Invalid reel pool")
                pool := []
                loop f.Length - 2
                    pool.Push(f[A_Index + 2])
                next.Pools[reel] := pool
            case "timer":
                RequireOutputFields(f, 5, tag)
                RequireOutputPhase(f[2], "idle|prep|ready|activity|time", tag)
                RequireOutputNumber(f[3], tag)
                RequireOutputNumber(f[4], tag)
                RequireOutputNumber(f[5], tag)
                next.Timer := f
            case "score":
                RequireOutputFields(f, 4, tag)
                if f[2] != "0" && f[2] != "1"
                    throw Error("Invalid scoreboard visibility")
                for i in [3, 4] {
                    if !RegExMatch(f[i], "^\d{1,4}$") || Integer(f[i]) > 9999
                        throw Error("Invalid scoreboard score")
                }
                next.Score := f
            case "active":
                RequireOutputFields(f, 5, tag)
                RequireOutputNumber(f[3], tag)
                RequireOutputNumber(f[5], tag)
                if !next.ActiveItems.Length
                    next.Active := f
                if f[2] != ""
                    next.ActiveItems.Push(f)
            case "first":
                RequireOutputFields(f, 2, tag)
                next.FirstResult := f[2]
            case "bonus":
                RequireOutputFields(f, 3, tag)
                next.Bonus := f[2]
                next.BonusStart := RequireOutputNumber(f[3], tag)
            case "glitch":
                RequireOutputFields(f, 3, tag)
                next.GlitchStart := RequireOutputNumber(f[2], tag)
                next.GlitchEnd := RequireOutputNumber(f[3], tag)
            case "sound":
                RequireOutputFields(f, 5, tag)
                if !InStr("|321.wav|glitch.mp3|ringring.mp3|scare1|scare2|", "|" f[3] "|")
                    throw Error("Unknown special audio")
                next.Sounds.Push({Id: f[2], Name: f[3], Repeat: f[4] = "1", Until: RequireOutputNumber(f[5], tag)})
            case "scare":
                RequireOutputFields(f, 4, tag)
                if !InStr("|scare1|scare2|jeff|", "|" f[2] "|")
                    throw Error("Unknown jumpscare image")
                RequireOutputNumber(f[3], tag)
                RequireOutputNumber(f[4], tag)
                next.Scare := f
            case "horror":
                RequireOutputFields(f, 3, tag)
                if f[2] = ""
                    throw Error("Invalid horror event identifier")
                next.HorrorEvents.Push({Id: f[2], Due: RequireOutputNumber(f[3], tag)})
            default:
                continue
        }
        seen[tag] := true
    }
    for tag in ["meta", "status", "wheel", "slots", "timer", "active"] {
        if !seen.Has(tag)
            throw Error("Missing output record: " tag)
    }
    if next.Wheel[2] != "idle" && !next.Items.Length
        throw Error("Active wheel has no segments")
    return next
}


OutputPanelKeys(state, now) {
    guide := "|guide:" (state.Guides ? 1 : 0)
    wheel := state.Wheel
    slots := state.Slots
    active := state.Active
    timer := state.Timer
    wheelKey := Line(wheel*) "|" state.FirstResult "|" state.Bonus
    if state.Bonus != "" && now - state.BonusStart < 460
        wheelKey .= "|bonus:" Floor(now / 16)
    if state.GlitchEnd > now
        wheelKey .= "|glitch:" Floor(now / 34)
    for p in state.Items
        wheelKey .= Line(p.Name, p.Weight)
    if wheel[2] = "spin"
        wheelKey .= "|frame:" now
    slotKey := Line(slots*)
    if slots[2] = "spin"
        slotKey .= "|frame:" now
    activeKey := "idle"
    rows := state.ActiveItems.Length ? state.ActiveItems : [active]
    for item in rows {
        if item[2] = "" || now >= item[3] + 0
            continue
        activeKey .= Line(item*) "|" Format("{:.1f}", (item[3] + 0 - now) / 1000)
        if RegExMatch(item[4], "^(High|Low)  ") && now - item[5] < 450
            activeKey .= "|" Floor(now / 16)
    }
    timerKey := Line(timer*)
    if timer[2] = "prep" || timer[2] = "activity" {
        remaining := Max(0, timer[3] + 0 - now)
        timerKey .= "|" TimeText(remaining) "|" Floor(now / 100)
    }
    return Map(1, wheelKey guide, 2, slotKey guide, 3, activeKey guide, 4, timerKey guide, 5, Line(state.Score*) guide)
}
