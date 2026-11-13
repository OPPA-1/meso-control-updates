NowMs() {
    return DllCall("kernel32\GetTickCount64", "UInt64")
}

class SpinQueue {
    __New(limit := 10000) {
        this.Pending := []
        this.Head := 1
        this.Active := 0
        this.Seen := Map()
        this.Paused := false
        this.Limit := limit
        this.Completed := 0
    }
    Count() {
        return Max(0, this.Pending.Length - this.Head + 1)
    }
    Accept(id, preview, now, viewer := "", remote := false, spins := 1) {
        if this.Seen.Has(id)
            return 2
        if this.Count() >= this.Limit
            return -2
        this.Pending.Push({Id: id, Preview: preview, Viewer: viewer, Remote: remote, Spins: spins})
        this.Seen[id] := now
        return 1
    }
    AcceptBatch(id, count, now, viewer := "", remote := true) {
        if this.Seen.Has(id)
            return 2
        count := Max(1, Min(50, Integer(count)))
        if this.Count() + count > this.Limit
            return -2
        loop count
            this.Pending.Push({Id: id "#" A_Index, Preview: false, Viewer: viewer, Remote: remote})
        this.Seen[id] := now
        return 1
    }
    Take(now) {
        if this.Paused || IsObject(this.Active) || this.Count() = 0
            return 0
        item := this.Pending[this.Head]
        this.Head += 1
        if this.Head > 256 {
            rest := []
            loop this.Count()
                rest.Push(this.Pending[this.Head + A_Index - 1])
            this.Pending := rest
            this.Head := 1
        }
        item.Start := now
        item.Phase := "spin"
        this.Active := item
        return item
    }
    Finish() {
        if IsObject(this.Active)
            this.Completed += 1
        this.Active := 0
    }
    Clear() {
        this.Pending := []
        this.Head := 1
    }
    Prune(now) {
        old := []
        for id, tick in this.Seen
            if now - tick > 600000
                old.Push(id)
        for id in old
            this.Seen.Delete(id)
    }
}

class ActivityClock {
    __New() {
        this.Phase := "idle"
        this.Deadline := 0
        this.Total := 0
        this.ClearAt := 0
        this.Generation := 0
    }
    Prep(ms, now) {
        this.Generation += 1
        this.Total := Max(0, ms)
        this.Deadline := now + this.Total
        this.ClearAt := 0
        this.Phase := ms > 0 ? "prep" : "ready"
    }
    Skip() {
        if this.Phase = "prep" {
            this.Phase := "ready"
            this.Deadline := 0
        }
    }
    Start(ms, now) {
        if this.Phase != "ready" || ms <= 0
            return false
        this.Total := ms
        this.Deadline := now + ms
        this.Phase := "activity"
        return true
    }
    Remaining(now) {
        return (this.Phase = "prep" || this.Phase = "activity") ? Max(0, this.Deadline - now) : 0
    }
    Tick(now) {
        if this.Phase = "prep" && now >= this.Deadline
            this.Phase := "ready"
        else if this.Phase = "activity" && now >= this.Deadline {
            this.Phase := "time"
            this.ClearAt := now + 3000
        } else if this.Phase = "time" && now >= this.ClearAt
            this.Phase := "idle"
    }
    Tax(ms, now, generation := -1) {
        if this.Phase != "activity" || (generation >= 0 && generation != this.Generation)
            return 0
        applied := Min(Max(0, ms), this.Remaining(now))
        this.Deadline := Max(now, this.Deadline - applied)
        this.Tick(now)
        return applied
    }
}

ParseTime(value) {
    value := Trim(value)
    if !RegExMatch(value, "^\d{1,6}(:\d{1,2}){0,2}$")
        return -1
    parts := StrSplit(value, ":")
    seconds := 0
    for i, n in parts {
        if i > 1 && n + 0 >= 60
            return -1
        seconds := seconds * 60 + Integer(n)
    }
    return seconds <= 86400 ? seconds * 1000 : -1
}

TimeText(ms) {
    seconds := Max(0, Ceil(ms / 1000))
    return seconds >= 3600 ? Format("{:02}:{:02}:{:02}", Floor(seconds / 3600), Mod(Floor(seconds / 60), 60), Mod(seconds, 60)) : Format("{:02}:{:02}", Floor(seconds / 60), Mod(seconds, 60))
}

NormAngle(angle) {
    return Mod(Mod(angle, 360) + 360, 360)
}

WeightedPick(items, roll := -1.0) {
    total := 0.0
    for p in items
        total += p.Weight
    if total <= 0
        return 0
    if roll < 0
        roll := Random(0.0, total)
    cursor := 0.0
    for i, p in items {
        cursor += p.Weight
        if roll < cursor
            return i
    }
    return items.Length
}

SliceCenter(items, index) {
    total := 0.0
    for p in items
        total += p.Weight
    angle := 0.0
    for i, p in items {
        sweep := 360.0 * p.Weight / total
        if i = index
            return angle + sweep / 2
        angle += sweep
    }
    return 0.0
}

Pack(value) {
    value := StrReplace(String(value), "%", "%25")
    value := StrReplace(value, "|", "%7C")
    value := StrReplace(value, "`r", "%0D")
    return StrReplace(value, "`n", "%0A")
}

Unpack(value) {
    value := StrReplace(value, "%0A", "`n")
    value := StrReplace(value, "%0D", "`r")
    value := StrReplace(value, "%7C", "|")
    return StrReplace(value, "%25", "%")
}

Line(fields*) {
    result := ""
    for value in fields
        result .= (A_Index = 1 ? "" : "|") . Pack(value)
    return result . "`n"
}

Fields(line) {
    a := StrSplit(RTrim(line, "`r"), "|")
    for i, v in a
        a[i] := Unpack(v)
    return a
}

StageIniFile(path) {
    staged := path ".meso-" ProcessExist() "-" A_TickCount "-" Random(10000, 99999) ".ini"
    loop 25 {
        try {
            if FileExist(path)
                FileCopy(path, staged, 1)
            else {
                file := FileOpen(staged, "w", "UTF-16")
                if !IsObject(file)
                    throw Error("Cannot open settings file")
                file.Close()
            }
            return staged
        } catch as err {
            if A_Index = 25
                throw Error("Settings file is busy or read-only: " path, -1, err.Message)
            Sleep(70)
        }
    }
}

CommitIniFile(staged, path) {
    loop 25 {
        try {
            FileMove(staged, path, 1)
            try DllCall("kernel32\WritePrivateProfileStringW", "Ptr", 0, "Ptr", 0, "Ptr", 0, "WStr", path)
            return true
        } catch as err {
            if A_Index = 25
                throw Error("Could not replace settings file: " path, -1, err.Message)
            Sleep(70)
        }
    }
}

MesoIniWrite(value, path, section, key) {
    loop 25 {
        try {
            IniWrite(value, path, section, key)
            return true
        } catch as err {
            if A_Index = 25
                throw Error("Settings file is locked: " path, -1, err.Message)
            Sleep(70)
        }
    }
}

MesoIniDelete(path, section) {
    loop 25 {
        try {
            IniDelete(path, section)
            return true
        } catch as err {
            if A_Index = 25
                throw Error("Settings file is locked: " path, -1, err.Message)
            Sleep(70)
        }
    }
}

ParseMesoPacket(text) {
    packetParts := Fields(text)
    if packetParts.Length < 3
        return 0
    requestMode := packetParts[1]
    if requestMode != "spin" && requestMode != "preview" && requestMode != "skip" && requestMode != "chat"
        return 0
    requestId := packetParts[2]
    if !RegExMatch(requestId, "^[A-Za-z0-9_-]{1,100}$")
        return 0
    viewerName := packetParts[3]
    if requestMode = "chat" {
        if packetParts.Length != 5 || !RegExMatch(packetParts[4], "^\d{1,16}$") || StrLen(packetParts[5]) > 160
            return 0
        return {Mode: requestMode, Id: requestId, Viewer: viewerName, Sent: Integer(packetParts[4]), Message: packetParts[5]}
    }
    if packetParts.Length != 3
        return 0
    return {Mode: requestMode, Id: requestId, Viewer: viewerName, Sent: 0, Message: ""}
}

WriteAtomic(path, text) {
    tmp := path . ".tmp"
    file := FileOpen(tmp, "w", "UTF-8-RAW")
    if !IsObject(file)
        throw Error("Cannot write " . path)
    file.Write(text)
    file.Close()
    FileMove(tmp, path, 1)
}

GuiHwndSafe(g) {
    try {
        h := IsObject(g) ? g.Hwnd : 0
        return h && DllCall("user32\IsWindow", "Ptr", h) ? h : 0
    }
    return 0
}

ApplyGuiIcon(g, path := "") {
    static handles := Map()
    h := GuiHwndSafe(g)
    if path = ""
        path := A_ScriptDir "\Meso_Icon.ico"
    if !h || !FileExist(path)
        return false
    if !handles.Has(path) {
        large := DllCall("user32\LoadImageW", "Ptr", 0, "WStr", path, "UInt", 1, "Int", 48, "Int", 48, "UInt", 0x10, "Ptr")
        small := DllCall("user32\LoadImageW", "Ptr", 0, "WStr", path, "UInt", 1, "Int", 16, "Int", 16, "UInt", 0x10, "Ptr")
        handles[path] := {Large: large, Small: small}
    }
    icons := handles[path]
    if icons.Large
        SendHwnd(h, 0x80, 1, icons.Large)
    if icons.Small
        SendHwnd(h, 0x80, 0, icons.Small)
    return icons.Large != 0 || icons.Small != 0
}

ClampWindow(&x, &y, w, h) {
    left := SysGet(76), top := SysGet(77), width := SysGet(78), height := SysGet(79)
    if x + Min(w, 80) < left || x > left + width - 80
        x := left + 30
    if y < top || y > top + height - 40
        y := top + 30
}

LogEvent(message, directory := "") {
    if directory = ""
        directory := A_ScriptDir "\runtime"
    try {
        DirCreate(directory)
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " message "`n", directory "\Meso.log", "UTF-8")
    }
}

NewId() {
    guid := Buffer(16, 0), text := Buffer(80, 0)
    DllCall("ole32\CoCreateGuid", "Ptr", guid)
    DllCall("ole32\StringFromGUID2", "Ptr", guid, "Ptr", text, "Int", 40)
    return StrGet(text)
}

GetMapKeys(obj) {
    a := []
    for k, v in obj
        a.Push(k)
    return a
}

SendHwnd(hwnd, msg, wParam := 0, lParam := 0) {
    return DllCall("user32\SendMessageW", "Ptr", hwnd, "UInt", msg, "UPtr", wParam, "Ptr", lParam, "Ptr")
}


PerfNowMs() {
    static frequency := 0
    if !frequency
        DllCall("kernel32\QueryPerformanceFrequency", "Int64*", &frequency)
    counter := 0
    DllCall("kernel32\QueryPerformanceCounter", "Int64*", &counter)
    return counter * 1000.0 / frequency
}
