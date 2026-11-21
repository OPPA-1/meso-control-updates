#Requires AutoHotkey v2.0 64-bit
#SingleInstance Ignore
#Include Lib\Core.ahk
#Include Lib\InteractionGuard.ahk
#Include Lib\OutputState.ahk
#Include Lib\Draw.ahk
#Include Lib\GlitchWheel.ahk
#Include Lib\HorrorFlash.ahk
#Include Lib\WheelLabels.ahk
#Include Lib\SlotLabels.ahk
#Include Lib\SignalScene.ahk
#Include Lib\SonionScream.ahk
#Include Lib\SonionGlitch.ahk
#Include Lib\SonionRingtone.ahk
#Include Lib\ScareAssets.ahk
#Include Lib\ScareLocalAudio.ahk
#Include Lib\EffectLabels.ahk
#Include Lib\ScareAudio1.ahk
#Include Lib\ScareAudio2.ahk
#Include Lib\StreamScares.ahk
RuntimeDir := A_ScriptDir "\runtime"
DirCreate(RuntimeDir)
IconPath := A_ScriptDir "\Meso_Icon.ico"
SharedLargeIcon := 0
SharedSmallIcon := 0
ConfigFile := A_ScriptDir "\Meso_Chaos.ini"
OutputLayoutFile := RuntimeDir "\output-layout.ini"
try DllCall("user32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
GdipToken := GdipStart()
Front := Surface(1920, 1080)
Back := Surface(1920, 1080)
Front.Clear()
Back.Clear()
Front.Flush()
State := EmptyState()
LastRead := 0
LastData := ""
LastDrawKey := ""
PanelKeys := Map()
RenderStats := {Active: false, Start: 0, Count: 0, Total: 0.0, Fps: 0.0, Ms: 0.0}
LastAlive := NowMs()
OutputReadError := ""
OutputRenderError := ""
OutputHealthLastTick := 0
OutputHealthLastBody := ""
OutputLastLoggedError := ""
LastWheelId := ""
ReelSprites := Map()
Disk := 0
WheelLabelLayouts := []
WheelHub := BuildWheelHub()
DrawBusy := false
OutputClosing := false
OutputUpdating := false
OutputUpdateStarted := 0
OutputStopRequested := false
OutputCleanupDone := false
TimerResolutionActive := false
TickIndex := 0
LastTickSound := 0
LandPlayed := false
LastSlotId := ""
LastSlotTick := 0
LastSlotLocked := 0
AudioSettings := Map()
AudioPaths := Map()
AudioReady := Map()
LastSoundSync := 0
HorrorSoundPath := A_ScriptDir "\1.wav"
FigureSoundPath := A_ScriptDir "\2.wav"
FigureState := "idle"
FigureGui := 0
FigurePicture := 0
FigureStarted := 0
FigureDue := 0
FigureEnd := 0
FigureNext := 0
FigureVisibleUntil := 0
FigureAlpha := 0
FigureMajor := false
FigureLastDisappear := 0
SmallTungLastPosition := 0
ScreenDamage := {Until: 0, Parts: []}
SignalScene := {Phase: "idle", Due: 0, Start: 0, End: 0, Next: 0, Gui: 0, Cards: [], Tick: 0}
HorrorSeen := Map()
HorrorQueue := []
HorrorActive := false
HorrorStarted := 0
HorrorUntil := 0
SpeechVoice := 0
SpeechJobId := ""
SpeechStarted := 0
SpeechWaiting := false
SpeechLastTick := 0
HorrorLastAudioCheck := 0
HorrorFlash := 0
Borderless := false
GuideRects := [[0, 0, 800, 800, "CHAOS DISPLAY"], [800, 0, 1120, 480, "ACTIVITY SLOTS"], [800, 480, 1120, 180, "ACTIVE PUNISHMENT"], [800, 660, 1120, 360, "ACTIVITY TIMER"], [0, 800, 800, 280, "RUN TALLY"]]
OutputGui := Gui("-DPIScale -Resize -MaximizeBox", "Meso Stream Output")
OutputGui.BackColor := "00FF00"
OutputGui.MarginX := 0
OutputGui.MarginY := 0
OutputGui.OnEvent("Close", RequestOutputClose)
OutputGui.OnEvent("Size", OutputSized)
ApplyGuiIcon(OutputGui)
OnMessage(0xF, PaintOutput)
OnMessage(0x14, EraseOutput)
OnMessage(0x232, SaveOutputPosition)
OnMessage(0x8002, RequestOutputClose)
OnMessage(0x8003, StopSpecialEffects)
OnMessage(0x8004, (*) => Reload())
OnMessage(0x8005, PauseRendererForUpdate)
OnMessage(0x8006, ResumeRendererAfterUpdate)
OnExit(OutputExit)
mon := MonitorGetCount() >= 2 ? (MonitorGetPrimary() = 1 ? 2 : 1) : MonitorGetPrimary()
MonitorGetWorkArea(mon, &ml, &mt, &mr, &mb)
x := IniRead(OutputLayoutFile, "Output", "X", ml) + 0
y := IniRead(OutputLayoutFile, "Output", "Y", mt) + 0
ClampWindow(&x, &y, 1920, 1080)
OutputGui.Show("NoActivate x" x " y" y " w1920 h1080")
RefreshAudioSettings(true)
try WriteAtomic(RuntimeDir "\output.info", ProcessExist() "`n" OutputGui.Hwnd "`n" A_ScriptFullPath)
TimerResolutionActive := DllCall("winmm\timeBeginPeriod", "UInt", 1, "UInt") = 0
RunRenderLoop()
ExitApp()
return

#HotIf WinActive("Meso Stream Output ahk_class AutoHotkeyGUI")
F11::ToggleOutputBorder()
#HotIf

ReadState(now) {
    global State, RuntimeDir, LastData, LastRead, LastAlive, OutputReadError
    if now - LastRead < 50
        return
    LastRead := now
    try {
        data := FileRead(RuntimeDir "\output.state", "UTF-8")
        if data != LastData {
            next := ParseOutputState(data)
            State := next
            LastData := data
        }
        OutputReadError := ""
    } catch as err {
        OutputReadError := err.Message
    }
    if State.Pid && ProcessExist(State.Pid)
        LastAlive := now
    else if now - LastAlive > 2000 {
        State := EmptyState()
        LastData := ""
        if now - LastAlive > 20000
            RequestOutputClose()
    }
}

PublishOutputHealth() {
    global State, RuntimeDir, LastAlive, OutputReadError, OutputRenderError
    global OutputHealthLastTick, OutputHealthLastBody, OutputLastLoggedError, RenderStats
    now := NowMs()
    status := "waiting"
    detail := "Waiting for controller"
    if OutputRenderError != "" {
        status := "error"
        detail := "Drawing: " OutputRenderError
    } else if OutputReadError != "" {
        status := "error"
        detail := "Connection: " OutputReadError
    } else if State.Pid && ProcessExist(State.Pid) {
        status := "connected"
        active := State.Wheel[2] != "idle" || State.Slots[2] != "idle" || State.Timer[2] != "idle" || State.ActiveItems.Length || State.Score[2] = "1" || State.Guides
        detail := active ? "Rendering previews" : "Ready - no active preview"
        if (State.Wheel[2] = "spin" || State.Slots[2] = "spin") && RenderStats.Fps > 0
            detail .= " | " Round(RenderStats.Fps) " fps / " Round(RenderStats.Ms, 1) " ms"
        if now - State.PublishedAt > 5000 {
            status := "waiting"
            detail := "Waiting for controller update"
        }
    }
    body := status "|" detail
    if body = OutputHealthLastBody && now - OutputHealthLastTick < 1000
        return
    try {
        WriteAtomic(RuntimeDir "\output-health.info", Line(ProcessExist(), now, status, detail))
        OutputHealthLastTick := now
        OutputHealthLastBody := body
    }
    if status = "error" && detail != OutputLastLoggedError {
        LogEvent("Stream output: " detail)
        OutputLastLoggedError := detail
    } else if status != "error"
        OutputLastLoggedError := ""
}

Render() {
    global DrawBusy, Back, Front, State, LastWheelId, Disk, TickIndex, LastTickSound, LandPlayed, OutputGui, OutputClosing, OutputStopRequested, OutputRenderError, PanelKeys, GuideRects
    if DrawBusy || OutputClosing || OutputStopRequested
        return
    DrawBusy := true
    try {
        started := PerfNowMs()
        now := NowMs()
        ReadState(now)
        w := State.Wheel, s := State.Slots
        keys := OutputPanelKeys(State, now)
        changed := []
        for index, key in keys
            if !PanelKeys.Has(index) || PanelKeys[index] != key
                changed.Push(index)
        if !changed.Length
            return
        if (w[3] "|" w[11]) != LastWheelId {
            if IsObject(Disk) {
                Disk.Dispose()
                Disk := 0
            }
            DisposeWheelLabelCache()
            DisposeReelSprites()
            if State.Items.Length {
                if w[11] = "reel"
                    BuildReelSprites(State.Items)
                else
                    Disk := BuildDisk(State.Items)
            }
            LastWheelId := w[3] "|" w[11]
            TickIndex := 0
            LastTickSound := 0
            LandPlayed := false
        }
        Back.CopyFrom(Front)
        for index in changed {
            rect := GuideRects[index]
            saved := Back.Push()
            try {
                Back.Clip(rect[1], rect[2], rect[3], rect[4])
                Back.Rect(rect[1], rect[2], rect[3], rect[4], 0xFF00FF00)
                switch index {
                    case 1:
                        if State.GlitchEnd > now
                            RenderChaosGlitch(Back, now)
                        else if w[2] != "idle"
                            DrawChaosPanel(Back, now)
                    case 2:
                        if s[2] != "idle"
                            DrawSlots(Back, now)
                    case 3:
                        if State.ActiveItems.Length
                            DrawActive(Back, now)
                    case 4:
                        if State.Timer[2] != "idle"
                            DrawTimer(Back, now)
                    case 5:
                        if State.Score[2] = "1"
                            DrawScoreboard(Back)
                }
                if State.Guides
                    DrawGuides(Back, index)
            } finally Back.Pop(saved)
        }
        Back.Flush()
        Critical(20)
        tmp := Front
        Front := Back
        Back := tmp
        PanelKeys := keys
        Critical("Off")
        DllCall("user32\InvalidateRect", "Ptr", OutputGui.Hwnd, "Ptr", 0, "Int", 0)
        DllCall("user32\UpdateWindow", "Ptr", OutputGui.Hwnd)
        UpdateRenderStats(now, PerfNowMs() - started, w[2] = "spin" || s[2] = "spin")
        OutputRenderError := ""
    } catch as err {
        OutputRenderError := err.Message
    } finally {
        DrawBusy := false
        PublishOutputHealth()
    }
}

DrawChaosPanel(c, now, glitchElapsed := -1) {
    global State, Disk
    if State.DisplayMode = "reel"
        DrawChaosReel(c, now, glitchElapsed)
    else if IsObject(Disk)
        DrawWheel(c, now, glitchElapsed)
    if State.FirstResult != "" {
        c.RoundRect(34, 33, 380, 45, 12, 0xFF170D24, 0xFF8151B4, 1)
        c.Text("FIRST  " State.FirstResult, 51, 40, 346, 31, 16, 0xFFF9F5FF, true, 0)
    }
    if State.Bonus != ""
        DrawSpinBonus(c, State.Bonus, now - State.BonusStart)
}

RenderChaosGlitch(c, now) {
    global State
    elapsed := Max(0, now - State.GlitchStart)
    if !State.Items.Length {
        DrawGlitchWheel(c, 220, 220, elapsed, State.DisplayMode)
        return
    }
    frame := ChaosGlitchFrame(elapsed)
    saved := c.Push()
    try {
        c.Transform(frame.X, frame.Y, 0)
        DrawChaosPanel(c, now, elapsed)
        DrawChaosInterference(c, 32, 20, 736, 750, frame.Index)
    } finally c.Pop(saved)
}

BuildDisk(items) {
    global WheelLabelLayouts
    WheelLabelLayouts := []
    c := Surface(800, 800, true)
    c.Clear(0x00000000)
    c.Ellipse(36, 36, 728, 728, 0xFF100818, 0xFF402361, 2)
    c.Ellipse(43, 43, 714, 714, 0, 0xFFB37AFF, 3)
    total := 0.0
    for p in items
        total += p.Weight
    angle := 0.0
    colors := [0xFF47217D, 0xFF682BB2, 0xFF54258F, 0xFF7D3AC3, 0xFF3F1C70, 0xFF64399B]
    for i, p in items {
        sweep := 360.0 * p.Weight / total
        color := p.Weight <= 1 ? 0xFFAB2CE0 : colors[Mod(i - 1, colors.Length) + 1]
        c.Pie(58, 58, 684, 684, angle, sweep, color)
        layout := FitWheelLabel(c, p.Name, sweep)
        layout.Center := angle + sweep / 2
        CacheWheelLabel(layout)
        WheelLabelLayouts.Push(layout)
        angle += sweep
    }
    c.Flush()
    return c
}

DrawWheel(c, now, glitchElapsed := -1) {
    global State, Disk, TickIndex, LastTickSound, LandPlayed, WheelLabelLayouts, WheelHub
    w := State.Wheel
    t := w[2] = "announce" ? 0.0 : Min(1.0, Max(0.0, (now - (w[4] + 0)) / 5000))
    rotation := glitchElapsed >= 0 && w[2] = "idle" ? Mod(glitchElapsed * .55, 360) : (w[5] + 0) * (1 - (1 - t) ** 3)
    c.RotateImage(Disk.Image, rotation, 400, 400, 800, 800)
    total := 0.0
    for p in State.Items
        total += p.Weight
    current := 0.0
    pointer := NormAngle(-90 - rotation)
    detected := 0
    for i, p in State.Items {
        sweep := 360.0 * p.Weight / total
        if pointer >= current && pointer < current + sweep
            detected := i
        if i <= WheelLabelLayouts.Length
            DrawCachedWheelLabel(c, WheelLabelLayouts[i], rotation)
        current += sweep
    }
    c.ImageAt(WheelHub.Image, 296, 296, 208, 208)
    c.Polygon([[373, 20], [427, 20], [400, 79]], 0xFF231032)
    c.Polygon([[382, 25], [418, 25], [400, 65]], 0xFFF4E9FF)
    if w[2] = "result" {
        c.RoundRect(110, 300, 580, 200, 24, 0xFF160C24, 0xFFC792FF, 3)
        c.Text("PUNISHMENT", 135, 316, 530, 30, 16, 0xFFCBA9F6, true)
        DrawFittedDisplay(c, w[6], 135, 352, 530, 112, 38, 16)
    } else if w[2] = "hold" {
        c.RoundRect(150, 728, 500, 55, 16, 0xFF190D27, 0xFFB477F7, 2)
        DrawFittedDisplay(c, w[6], 165, 735, 470, 40, 22, 12)
    }
    DrawViewerBadge(c)
    if w[2] = "announce" {
        c.RoundRect(142, 338, 516, 95, 22, 0xF0160A24, 0xFFBA8DEE, 2)
        c.TextNoWrap("SPINNING WHEEL", 156, 360, 490, 47, 31, 0xFFF4E9FF, true)
    }
    if w[2] = "spin" && detected != TickIndex && now - LastTickSound >= 65 {
        TickIndex := detected
        if PlayAlias("mesotick")
            LastTickSound := now
    }
    if (w[2] = "hold" || w[2] = "result") && !LandPlayed {
        LandPlayed := true
        PlayAlias("mesoland", true)
    }
}

DrawSpinBonus(c, title, elapsed) {
    motion := 1 - Min(1, Max(0, elapsed / 520))
    y := 506 + Round(35 * motion ** 3)
    c.RoundRect(106, y, 588, 108, 20, 0xFF171127, 0xFFA4FFDB, 4)
    c.RoundRect(119, y + 13, 115, 82, 14, 0xFFA4FFDB)
    c.TextNoWrap("2×", 126, y + 21, 102, 64, 45, 0xFF233040, true)
    c.TextNoWrap("BONUS PUNISHMENT", 251, y + 11, 420, 28, 19, 0xFFA4FFDB, true, 0)
    DrawFittedDisplay(c, title, 251, y + 42, 420, 53, 29, 17)
}

DrawViewerBadge(c) {
    global State
    w := State.Wheel
    if w.Length < 12 || w[10] != "1" || w[9] = ""
        return
    c.RoundRect(150, 653, 500, 71, 20, 0xEE190D29, 0xFFAD72E6, 2)
    c.RoundRect(167, 668, 5, 42, 2, 0xFFB38AFF)
    c.TextNoWrap("REDEEMED BY", 193, 662, 415, 22, 13, 0xFFC8A4EF, true)
    c.TextNoWrap("@" w[9], 193, 686, 415, 29, 23, 0xFFFFFFFF, true)
}

BuildReelSprites(items) {
    global ReelSprites
    for item in items {
        label := item.Name
        if ReelSprites.Has(label)
            continue
        sprite := Surface(545, 85, true)
        try {
            sprite.Clear(0x00000000)
            DrawFittedDisplay(sprite, StrUpper(label), 5, 6, 535, 73, 34, 14)
            sprite.Flush()
            ReelSprites[label] := sprite
        } catch as err {
            sprite.Dispose()
            throw err
        }
    }
}

DisposeReelSprites() {
    global ReelSprites
    for name, sprite in ReelSprites
        if IsObject(sprite)
            sprite.Dispose()
    ReelSprites := Map()
}

DrawChaosReel(c, now, glitchElapsed := -1) {
    global State, ReelSprites, TickIndex, LastTickSound, LandPlayed
    w := State.Wheel
    n := State.Items.Length
    if !n
        return
    c.RoundRect(28, 25, 744, 750, 32, 0xFF13091F, 0xFF7644A8, 3)
    c.RoundRect(55, 52, 690, 104, 19, 0xFF26143E)
    c.TextNoWrap("CHAOS REEL", 73, 68, 650, 60, 39, 0xFFF9F3FF, true)
    c.RoundRect(81, 180, 638, 454, 27, 0xFF1E1030, 0xFF513275, 2)
    c.RoundRect(101, 339, 598, 118, 18, 0xFF442067, 0xFFD0A4FF, 3)
    c.RoundRect(103, 351, 7, 94, 3, 0xFFD9B2FF)
    c.RoundRect(690, 351, 7, 94, 3, 0xFFD9B2FF)
    c.Polygon([[117, 399], [82, 380], [82, 418]], 0xFFDCBDFF)
    c.Polygon([[683, 399], [718, 380], [718, 418]], 0xFFDCBDFF)
    selected := Max(0, Min(n-1, (w[7]+0) - 1))
    target := n * 9 + selected
    t := w[2] = "announce" ? 0.0 : Min(1.0, Max(0.0, (now-(w[4]+0)) / 5000))
    position := glitchElapsed >= 0 && w[2] = "idle" ? glitchElapsed / 72 : target * (1 - (1-t)**3)
    base := Floor(position)
    fract := position - base
    saved := c.Push()
    try {
        c.Clip(115, 197, 570, 422)
        for offset in [-2, -1, 0, 1, 2] {
            key := Mod(base + offset + n * 100, n) + 1
            label := State.Items[key].Name
            y := 351 + (offset-fract)*135
            distance := Abs(offset - fract)
            if distance <= 0.65
                c.RoundRect(122, y-5, 557, 106, 15, 0xDD4A2671)
            else
                c.RoundRect(122, y-5, 557, 106, 15, distance < 1.55 ? 0xFF28163B : 0xFF20132E)
            if ReelSprites.Has(label)
                c.ImageAt(ReelSprites[label].Image, 126, y+6, 545, 85)
            else
                DrawFittedDisplay(c, StrUpper(label), 128, y+6, 540, 83, 34, 14)
        }
    } finally c.Pop(saved)
    if w[2] = "spin" {
        index := Mod(base, n) + 1
        if index != TickIndex && now - LastTickSound >= 70 {
            TickIndex := index
            if PlayAlias("mesotick")
                LastTickSound := now
        }
    }
    if (w[2] = "hold" || w[2] = "result") && !LandPlayed {
        LandPlayed := true
        PlayAlias("mesoland", true)
    }
    if w[2] = "announce" {
        c.RoundRect(178, 356, 444, 87, 18, 0xF0150925, 0xFFC391F7, 2)
        c.TextNoWrap("SPINNING WHEEL", 185, 366, 430, 59, 29, 0xFFFFFFFF, true)
    }
    DrawViewerBadge(c)
}

DrawSlots(c, now) {
    global State, LastSlotId, LastSlotTick, LastSlotLocked
    s := State.Slots
    if s[3] != LastSlotId {
        LastSlotId := s[3]
        LastSlotTick := 0
        LastSlotLocked := 0
    }
    if s[2] = "spin" && now - LastSlotTick >= 95 {
        if PlayAlias("mesoslottick")
            LastSlotTick := now
    }
    if s[2] != "idle" && s[7] + 0 > LastSlotLocked
        PlayAlias("mesoslotland", true)
    LastSlotLocked := s[7] + 0
    c.RoundRect(818, 18, 1084, 444, 24, 0xFF120B1D, 0xFF694094, 2)
    c.Text("ACTIVITY ROULETTE", 846, 33, 800, 39, 23, 0xFFDEC8F9, true, 0)
    labels := ["CATEGORY", "LOCATION / TYPE", "ACTIVITY", "CLASS"]
    for i, label in labels {
        x := 842 + (i - 1) * 263
        locked := i <= (s[7] + 0)
        moving := s[2] = "spin" && ((s[5] = "1" && !locked) || (s[5] != "1" && i = s[6] + 0))
        c.Text(label, x, 85, 245, 28, 13, 0xFFBDA1DB, true)
        border := moving ? 0xFF9D55E6 : locked ? 0xFFC199EF : 0xFF3E2852
        c.RoundRect(x, 123, 245, 253, 18, 0xFF20122F, border, 2)
        c.Rect(x + 12, 202, 221, 96, 0xFF2E1942)
        final := s[8 + i]
        if moving && State.Pools.Has(i) && State.Pools[i].Length {
            pool := State.Pools[i]
            duration := s[5] = "1" ? 1700 + 700 * i : 1450
            t := Min(1.0, Max(0.0, (now - (s[4] + 0)) / duration))
            index := 1
            for k, v in pool
                if v = final
                    index := k
            target := pool.Length * 9 + index - 1
            position := target * (1 - (1 - t) ** 3)
            base := Floor(position)
            fraction := position - base
            clip := c.Push()
            c.Clip(x + 9, 132, 227, 235)
            for offset in [-1, 0, 1] {
                value := pool[Mod(base + offset + pool.Length * 100, pool.Length) + 1]
                y := 192 + (offset - fraction) * 116
                DrawSlotLabel(c, value, x + 18, y)
            }
            c.Pop(clip)
        } else if locked
            DrawSlotLabel(c, final, x + 18, 192)
        else
            c.Text("?", x + 18, 164, 209, 168, 54, 0xFF66467D, true)
        c.Text(locked ? "LOCKED" : moving ? "ROLLING" : "REEL " i, x, 391, 245, 28, 12, locked ? 0xFFD5ACFF : 0xFF826398, true)
    }
}

DrawActive(c, now) {
    global State
    items := []
    for row in State.ActiveItems
        if now < row[3]+0
            items.Push(row)
    if !items.Length
        return
    c.RoundRect(823, 498, 1074, 144, 24, 0xFF170D24, 0xFF8151B4, 2)
    if items.Length = 1 && items[1][2] = "COOLDOWN" {
        c.TextNoWrap("COOLDOWN", 847, 505, 1026, 40, 29, 0xFFE3C9FF, true)
        c.TextNoWrap(TimeText(Max(0, items[1][3]+0-now)), 847, 547, 1026, 82, 57, 0xFFFFFFFF, true)
        return
    }
    bonus := false
    for item in items
        if item.Length >= 6 && item[6] = "1"
            bonus := true
    c.TextNoWrap(bonus ? "2× BONUS ACTIVE" : items.Length>1 ? "ACTIVE PUNISHMENTS" : "ACTIVE PUNISHMENT", 849, 504, 1022, 32, bonus ? 23 : 19, bonus ? 0xFFA4FFDB : 0xFFC4A2E5, true)
    rows := Min(items.Length, 3)
    loop rows {
        item := items[A_Index]
        y := items.Length=1 ? 545 : 540+(A_Index-1)*29
        note := CompactEffectNote(item[4])
        isWaiting := note="Focus game" || note="Queued"
        sensitivity := RegExMatch(note,"^(High|Low)  ")
        detail := isWaiting ? note : InStr(note,"Solve puzzle") ? "Solve to continue" : Format("{:.1f}s", Max(0, item[3]+0-now)/1000)
        pair := item.Length>=6 && item[6]="1"
        label := (pair ? "2× " : "") SubStr(item[2],1,50)
        c.TextNoWrap(label, 855, y, 1008, items.Length=1 ? 42 : 29, items.Length=1 ? 31 : 23, 0xFFFFFFFF, true)
        if items.Length=1 {
            rise := sensitivity ? Round(8*(1-Min(1,Max(0,now-item[5])/420))**2) : 0
            color := sensitivity ? (SubStr(note,1,4)="High" ? 0xFFE0B5FF : 0xFFAFE3FA) : 0xFFD2ACFF
            c.TextNoWrap(note!="" && !isWaiting ? note " · " detail : detail, 855, 593-rise, 1008, 28, 20, color, true)
        } else
            c.TextNoWrap(sensitivity ? note : detail, 1690, y, 168, 29, 17, 0xFFD2ACFF, true, 2)
    }
    if items.Length>3
        c.TextNoWrap("+" (items.Length-3) " more", 855, 623, 1008, 18, 12, 0xFFC4A2E5, true)
}

DrawTimer(c, now) {
    global State
    t := State.Timer
    phase := t[2]
    remaining := Max(0, t[3] + 0 - now)
    if phase = "prep" && remaining = 0
        phase := "ready"
    if phase = "activity" && remaining = 0
        phase := "time"
    c.RoundRect(823, 680, 1074, 318, 26, 0xFF160D21, 0xFF8151B4, 2)
    label := phase = "prep" ? "PREP TIME" : phase = "ready" ? "READY" : phase = "time" ? "TIME!" : "ACTIVITY TIME"
    value := phase = "ready" ? "PRESS START" : phase = "time" ? "00:00" : TimeText(remaining)
    c.Text(label, 860, 695, 1000, 65, 46, 0xFFE8D7FF, true)
    c.Text(value, 865, 770, 990, 137, phase = "ready" ? 59 : 91, 0xFFF9F5FF, true)
    ratio := (phase = "prep" || phase = "activity") && t[4] + 0 > 0 ? Min(1.0, remaining / (t[4] + 0)) : phase = "ready" ? 1.0 : 0.0
    c.RoundRect(865, 941, 990, 11, 5, 0xFF372043)
    if ratio > 0.01
        c.RoundRect(865, 941, Max(11, 990 * ratio), 11, 5, 0xFFB97CFF)
}

DrawScoreboard(c) {
    global State
    meso := State.Score[3] + 0
    chat := State.Score[4] + 0
    c.RoundRect(24, 824, 752, 232, 24, 0xFF120B1D, 0xFF8C58BF, 2)
    c.RoundRect(40, 840, 328, 200, 18, 0xFF221335)
    c.RoundRect(432, 840, 328, 200, 18, 0xFF191220)
    c.RoundRect(72, 858, 48, 4, 2, 0xFFC390FF)
    c.RoundRect(480, 858, 48, 4, 2, 0xFFC9B7E0)
    c.TextNoWrap("MESO", 72, 874, 264, 32, 21, 0xFFDFC6FF, true)
    c.TextNoWrap("TWITCH CHAT", 464, 874, 264, 32, 21, 0xFFE5D9EF, true)
    c.TextNoWrap(String(meso), 64, 912, 280, 112, 82, 0xFFFFFFFF, true)
    c.TextNoWrap(String(chat), 456, 912, 280, 112, 82, 0xFFFFFFFF, true)
    c.Ellipse(374, 916, 52, 52, 0xFF2E1B42, 0xFF74518F, 1)
    c.TextNoWrap("VS", 374, 923, 52, 38, 15, 0xFFCEB6E7, true)
}

DrawGuides(c, only := 0) {
    global GuideRects
    for index, r in GuideRects {
        if only && index != only
            continue
        DllCall("gdiplus\GdipDrawRectangle", "Ptr", c.G, "Ptr", c.Pen(0xFFFC487D, 2), "Float", r[1] + 2, "Float", r[2] + 2, "Float", r[3] - 4, "Float", r[4] - 4)
        c.Rect(r[1] + 7, r[2] + 7, 340, 28, 0xFF251436)
        c.Text(r[5], r[1] + 13, r[2] + 8, 328, 26, 15, 0xFFFFFFFF, true, 0)
    }
}

PaintOutput(wParam, lParam, msg, hwnd) {
    global OutputGui, Front, OutputClosing
    if OutputClosing || hwnd != GuiHwndSafe(OutputGui)
        return
    ps := Buffer(A_PtrSize = 8 ? 72 : 64, 0)
    dc := DllCall("user32\BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr")
    if dc && IsObject(Front) && Front.DC
        DllCall("gdi32\BitBlt", "Ptr", dc, "Int", 0, "Int", 0, "Int", 1920, "Int", 1080, "Ptr", Front.DC, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
    DllCall("user32\EndPaint", "Ptr", hwnd, "Ptr", ps)
    return 0
}

EraseOutput(wParam, lParam, msg, hwnd) {
    global OutputGui, OutputClosing
    if !OutputClosing && hwnd = GuiHwndSafe(OutputGui)
        return 1
}

OutputSized(gui, state, width, height) {
    global OutputClosing, OutputStopRequested
    if !OutputClosing && !OutputStopRequested && state != -1 && (width != 1920 || height != 1080)
        SetTimer(FixCanvasSize, -50)
}

FixCanvasSize() {
    global OutputGui, OutputClosing, OutputStopRequested
    if !OutputClosing && !OutputStopRequested && GuiHwndSafe(OutputGui)
        OutputGui.Show("NoActivate w1920 h1080")
}

ToggleOutputBorder() {
    global OutputGui, Borderless
    Borderless := !Borderless
    OutputGui.Opt(Borderless ? "-Caption" : "+Caption")
    OutputGui.Show("NoActivate w1920 h1080")
}

SaveOutputPosition(wParam := 0, lParam := 0, msg := 0, hwnd := 0) {
    global OutputGui, OutputLayoutFile
    if hwnd && hwnd != OutputGui.Hwnd
        return
    try {
        WinGetPos(&x, &y,,, "ahk_id " OutputGui.Hwnd)
        IniWrite(x, OutputLayoutFile, "Output", "X")
        IniWrite(y, OutputLayoutFile, "Output", "Y")
    }
}

RequestOutputClose(*) {
    global OutputStopRequested
    OutputStopRequested := true
    SetTimer(FixCanvasSize, 0)
    SetTimer(FinishOutputClose, -20)
    return true
}

FinishOutputClose() {
    global DrawBusy
    if DrawBusy {
        SetTimer(FinishOutputClose, -20)
        return
    }
    ExitApp()
}

RefreshAudioSettings(force := false) {
    global ConfigFile, AudioSettings, AudioReady, AudioPaths, LastSoundSync, HorrorSoundPath, FigureSoundPath
    now := NowMs()
    if !force && now - LastSoundSync < 1000
        return
    LastSoundSync := now
    sounds := [
        {Alias: "mesotick", Path: IniRead(ConfigFile, "Wheel", "TickSound", ""), Volume: IniRead(ConfigFile, "Wheel", "TickVolume", "55") + 0},
        {Alias: "mesoland", Path: IniRead(ConfigFile, "Wheel", "LandSound", ""), Volume: IniRead(ConfigFile, "Wheel", "LandVolume", "80") + 0},
        {Alias: "mesoslottick", Path: IniRead(ConfigFile, "Slots", "TickSound", ""), Volume: IniRead(ConfigFile, "Slots", "TickVolume", "55") + 0},
        {Alias: "mesoslotland", Path: IniRead(ConfigFile, "Slots", "LandSound", ""), Volume: IniRead(ConfigFile, "Slots", "LandVolume", "80") + 0},
        {Alias: "mesohorror", Path: HorrorSoundPath, Volume: ScareVolume(true)/100 * Min(100, 1.5 * (IniRead(ConfigFile, "Audio", "SequenceVolume", IniRead(ConfigFile, "Audio", "HorrorVolume", "75")) + 0))},
        {Alias: "mesofigure", Path: FigureSoundPath, Volume: ScareVolume(true)/100 * Min(100, 1.5 * (IniRead(ConfigFile, "Audio", "SequenceVolume", IniRead(ConfigFile, "Audio", "HorrorVolume", "75")) + 0))}
    ]
    for sound in sounds {
        alias := sound.Alias
        path := Trim(sound.Path)
        volume := Round(Max(0, Min(100, sound.Volume)))
        signature := path "|" volume
        if AudioSettings.Has(alias) && AudioSettings[alias] = signature {
            if AudioReady.Has(alias) && AudioReady[alias]
                continue
            if path = "" || !FileExist(path)
                continue
        }
        AudioSettings[alias] := signature
        if AudioReady.Has(alias) && AudioReady[alias] && AudioPaths.Has(alias) && AudioPaths[alias] = path {
            Mci("setaudio " alias " volume to " (volume * 10))
            continue
        }
        AudioPaths[alias] := path
        AudioReady[alias] := false
        Mci("close " alias)
        if path = "" || !FileExist(path)
            continue
        code := Mci("open " Chr(34) path Chr(34) " alias " alias)
        if code {
            LogEvent("Audio open failed for " alias ": " MciError(code))
            continue
        }
        Mci("set " alias " time format milliseconds")
        Mci("setaudio " alias " volume to " (volume * 10))
        AudioReady[alias] := true
    }
}

PlayAlias(alias, interrupt := false) {
    global AudioReady
    if !AudioReady.Has(alias) || !AudioReady[alias]
        return false
    if !interrupt && MciStatus(alias, "mode") = "playing"
        return false
    if interrupt
        Mci("stop " alias)
    if Mci("seek " alias " to start")
        return false
    return Mci("play " alias) = 0
}

PlayHorror15Seconds() {
    Mci("stop mesohorror")
    if Mci("seek mesohorror to start")
        return false
    return Mci("play mesohorror from 0 to 15000") = 0
}

ProcessWheelVoice(now) {
    global State, SpeechVoice, SpeechJobId, SpeechStarted, SpeechWaiting, ConfigFile, RuntimeDir
    w := State.Wheel
    if w[2] != "announce" || w[12] != "1" {
        if SpeechWaiting && IsObject(SpeechVoice)
            try SpeechVoice.Speak("", 3)
        SpeechWaiting := false
        return
    }
    jobId := w[3]
    if jobId = ""
        return
    if jobId != SpeechJobId {
        SpeechJobId := jobId
        SpeechStarted := now
        SpeechWaiting := false
        try {
            if !IsObject(SpeechVoice)
                SpeechVoice := ComObject("SAPI.SpVoice")
            voice := SpeechVoice
            voice.Volume := Max(0, Min(100, Integer(IniRead(ConfigFile, "Audio", "SpinAnnouncementVolume", "85"))))
            voice.Rate := 0
            voice.Speak("Spinning Wheel", 3)
            SpeechWaiting := true
        } catch as err {
            LogEvent("TTS startup: " err.Message)
            WriteAtomic(RuntimeDir "\tts.done", Line(jobId, "error", now))
            return
        }
    }
    if SpeechWaiting {
        done := false
        try done := SpeechVoice.WaitUntilDone(0)
        if done || now - SpeechStarted >= 3000 {
            if !done && IsObject(SpeechVoice)
                try SpeechVoice.Speak("", 3)
            SpeechWaiting := false
            WriteAtomic(RuntimeDir "\tts.done", Line(jobId, done ? "done" : "timeout", now))
        }
    }
}

Mci(cmd) {
    return DllCall("winmm\mciSendStringW", "WStr", cmd, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt")
}

MciStatus(alias, field) {
    answer := Buffer(512, 0)
    if MciRaw("status " alias " " field, answer, 256)
        return ""
    return Trim(StrGet(answer.Ptr, "UTF-16"))
}

MciRaw(cmd, buffer, chars) {
    return DllCall("winmm\mciSendStringW", "WStr", cmd, "Ptr", buffer.Ptr, "UInt", chars, "Ptr", 0, "UInt")
}

MciError(code) {
    message := Buffer(512, 0)
    DllCall("winmm\mciGetErrorStringW", "UInt", code, "Ptr", message.Ptr, "UInt", 256, "Int")
    return Trim(StrGet(message.Ptr, "UTF-16"))
}

OutputExit(reason, code) {
    StopOutputSpecialSounds()
    global Front, Back, Disk, GdipToken, OutputGui, OutputClosing, OutputCleanupDone, DrawBusy, TimerResolutionActive, RuntimeDir, WheelHub, SpeechVoice
    if OutputCleanupDone
        return
    if DrawBusy && reason != "Shutdown" && reason != "Logoff" {
        RequestOutputClose()
        return 1
    }
    Critical("On")
    OutputClosing := true
    OutputCleanupDone := true
    SetTimer(FixCanvasSize, 0)
    SetTimer(FinishOutputClose, 0)
    OnMessage(0xF, PaintOutput, 0)
    OnMessage(0x14, EraseOutput, 0)
    OnMessage(0x232, SaveOutputPosition, 0)
    SaveOutputPosition()
    if GuiHwndSafe(OutputGui)
        OutputGui.Destroy()
    StopHorror()
    CancelFigure()
    ClearScreenDamage()
    if IsObject(SpeechVoice)
        try SpeechVoice.Speak("", 3)
    SpeechVoice := 0
    for alias in ["mesotick", "mesoland", "mesoslottick", "mesoslotland", "mesohorror", "mesofigure"]
        Mci("close " alias)
    DisposeWheelLabelCache()
    DisposeReelSprites()
    if IsObject(WheelHub) {
        WheelHub.Dispose()
        WheelHub := 0
    }
    if IsObject(Disk) {
        Disk.Dispose()
        Disk := 0
    }
    if IsObject(Front) {
        Front.Dispose()
        Front := 0
    }
    if IsObject(Back) {
        Back.Dispose()
        Back := 0
    }
    GdipStop(&GdipToken)
    if TimerResolutionActive {
        TimerResolutionActive := false
        DllCall("winmm\timeEndPeriod", "UInt", 1)
    }
    try FileDelete(RuntimeDir "\output.info")
    try FileDelete(RuntimeDir "\output-health.info")
}


BuildWheelHub() {
    c := Surface(208, 208, true)
    c.Clear(0x00000000)
    saved := c.Push()
    try {
        c.Transform(-296, -296, 0)
        c.Ellipse(307, 307, 186, 186, 0xFF100919, 0xFFBF8DFF, 3)
        c.Ellipse(318, 318, 164, 164, 0, 0xFF3D2557, 1)
        c.Text("MESO", 318, 355, 164, 42, 31, 0xFFF8F1FF, true)
        c.Text("CHAOS", 318, 402, 164, 30, 15, 0xFFC69CEF, true)
    } finally c.Pop(saved)
    c.Flush()
    return c
}

DisposeWheelLabelCache() {
    global WheelLabelLayouts
    for layout in WheelLabelLayouts {
        if layout.HasOwnProp("Sprite") && IsObject(layout.Sprite) {
            layout.Sprite.Dispose()
            layout.Sprite := 0
        }
    }
    WheelLabelLayouts := []
}

UpdateRenderStats(now, elapsed, moving) {
    global RenderStats
    if !moving {
        RenderStats.Active := false
        return
    }
    if !RenderStats.Active {
        RenderStats.Active := true
        RenderStats.Start := now
        RenderStats.Count := 0
        RenderStats.Total := 0.0
        RenderStats.Fps := 0.0
    }
    RenderStats.Count += 1
    RenderStats.Total += Max(0, elapsed)
    if now - RenderStats.Start >= 1000 {
        RenderStats.Fps := RenderStats.Count * 1000.0 / (now - RenderStats.Start)
        RenderStats.Ms := RenderStats.Total / RenderStats.Count
        RenderStats.Start := now
        RenderStats.Count := 0
        RenderStats.Total := 0.0
    }
}


RunRenderLoop() {
    global OutputClosing, OutputStopRequested, State, OutputUpdating, OutputUpdateStarted
    nextFrame := PerfNowMs()
    lastAudioTick := 0
    lastHorrorTick := 0
    while !OutputClosing && !OutputStopRequested {
        Sleep(-1)
        if OutputClosing || OutputStopRequested
            break
        clockNow := NowMs()
        if OutputUpdating {
            if clockNow-OutputUpdateStarted > 45000
                ResumeRendererAfterUpdate()
            Sleep(15)
            continue
        }
        ReadState(clockNow)
        if clockNow - lastAudioTick >= 1000 {
            RefreshAudioSettings()
            lastAudioTick := clockNow
        }
        if clockNow - lastHorrorTick >= 50 {
            try ProcessWheelVoice(clockNow)
            catch as err {
                LogEvent("Voice playback issue: " err.Message)
            }
            try ProcessHorrorEvents(clockNow)
            catch as err {
                LogEvent("Horror overlay update failed: " err.Message)
                StopHorror()
            }
            try ProcessSignalScene(clockNow)
            try ProcessFigure(clockNow)
            catch as err {
                LogEvent("Triple T effect failed: " err.Message)
                CancelFigure()
            }
            try ProcessScreenDamage(clockNow)
            catch as err {
                LogEvent("Screen damage stopped: " err.Message)
                ClearScreenDamage()
            }
            PublishRendererSequenceState(clockNow)
            lastHorrorTick := clockNow
        }
        now := PerfNowMs()
        if now >= nextFrame {
            Render()
            moving := State.Wheel[2] = "spin" || State.Slots[2] = "spin"
            period := moving ? 1000.0 / 60.0 : 50.0
            nextFrame += period
            if nextFrame < PerfNowMs() - period
                nextFrame := PerfNowMs() + 1
        }
        SyncSpecialSounds(NowMs())
        wait := nextFrame - PerfNowMs()
        if wait > 0
            DllCall("kernel32\Sleep", "UInt", Max(1, Min(10, Floor(wait))))
    }
}
ProcessHorrorEvents(now) {
    global State, HorrorSeen, HorrorQueue, HorrorActive
    for event in State.HorrorEvents {
        if HorrorSeen.Has(event.Id)
            continue
        HorrorSeen[event.Id] := now
        if now - event.Due > 3000
            continue
        HorrorQueue.Push(event)
    }
    if HorrorActive {
        UpdateHorror(now)
        return
    }
    if HorrorQueue.Length && now >= HorrorQueue[1].Due {
        event := HorrorQueue.RemoveAt(1)
        StartHorror(now)
    }
}

StartHorror(now) {
    global HorrorActive, HorrorStarted, HorrorUntil, HorrorLastAudioCheck, FigureState, FigureDue
    global AudioReady, HorrorSoundPath
    RefreshAudioSettings()
    if !FileExist(HorrorSoundPath) {
        LogEvent("Horror audio missing: " HorrorSoundPath)
        return false
    }
    if !AudioReady.Has("mesohorror") || !AudioReady["mesohorror"] {
        LogEvent("Horror audio unavailable. Check that 1.wav is a valid PCM WAV.")
        return false
    }
    duration := 15000
    try CreateHorrorOverlay()
    catch as err {
        LogEvent("Horror overlay could not open: " err.Message)
        StopHorror()
        return false
    }
    if !PlayHorror15Seconds() {
        LogEvent("Horror playback could not start")
        StopHorror()
        return false
    }
    global RuntimeDir
    HorrorStarted := NowMs()
    WriteAtomic(RuntimeDir "\local-scare-onset.state", Line(NewId(), "1.wav", HorrorStarted, 15000))
    CancelFigure()
    FigureState := "wait"
    FigureDue := HorrorStarted + 20000
    HorrorUntil := HorrorStarted + 15000
    HorrorLastAudioCheck := HorrorStarted
    HorrorActive := true
    UpdateHorror(HorrorStarted)
    LogEvent("HE IS COMING! audio and overlay started (" duration " ms)")
    return true
}

HorrorWordAt(elapsed) {
    firstWords := ["I", "SAID", "HE", "IS", "COMING!!"]
    firstTimes := [480, 650, 420, 430, 870]
    remaining := elapsed
    for i, duration in firstTimes {
        if remaining < duration
            return firstWords[i]
        remaining -= duration
    }
    loopWords := ["HE", "IS", "COMING!!"]
    loopTimes := [490, 430, 850]
    remaining := Mod(remaining, 1770)
    for i, duration in loopTimes {
        if remaining < duration
            return loopWords[i]
        remaining -= duration
    }
    return "COMING!!"
}

HorrorGameRectangle(&x, &y, &w, &h) {
    target := WinExist("ahk_exe destiny2.exe")
    if target {
        try {
            WinGetClientPos(&x, &y, &w, &h, "ahk_id " target)
            if w >= 600 && h >= 300
                return
        }
    }
    primary := MonitorGetPrimary()
    MonitorGet(primary, &left, &top, &right, &bottom)
    x := left
    y := top
    w := right - left
    h := bottom - top
}

CreateHorrorOverlay() {
    global HorrorFlash
    if IsObject(HorrorFlash)
        StopHorror()
    HorrorGameRectangle(&x, &y, &w, &h)
    HorrorFlash := CreateHorrorFlash({X: x, Y: y, W: w, H: h}, "", false, WinExist("ahk_exe destiny2.exe"), (*) => (StopHorror(), RequestInteractionEmergency()))
}

UpdateHorror(now) {
    global HorrorActive, HorrorStarted, HorrorUntil, HorrorLastAudioCheck, HorrorFlash
    if !HorrorActive
        return
    if now >= HorrorUntil {
        StopHorror()
        return
    }
    if now - HorrorLastAudioCheck >= 240 {
        HorrorLastAudioCheck := now
        if now - HorrorStarted > 1200 && MciStatus("mesohorror", "mode") = "stopped" {
            StopHorror()
            return
        }
    }
    elapsed := now - HorrorStarted
    UpdateHorrorFlash(HorrorFlash, elapsed, HorrorWordAt(elapsed))
}

StopHorror() {
    global HorrorActive, HorrorStarted, HorrorUntil, HorrorFlash
    HorrorActive := false
    Mci("stop mesohorror")
    CloseHorrorFlash(HorrorFlash)
    HorrorFlash := 0
    HorrorStarted := 0
    HorrorUntil := 0
}

StartFigureMajor(now) {
    global FigureState, FigureStarted, FigureEnd, FigureSoundPath, AudioReady
    if !FileExist(A_ScriptDir "\ui_layer_03.png") || !FileExist(FigureSoundPath) {
        LogEvent("Triple T asset missing")
        FigureState := "idle"
        return
    }
    RefreshAudioSettings()
    if !AudioReady.Has("mesofigure") || !AudioReady["mesofigure"] {
        LogEvent("Triple T audio is unavailable")
        FigureState := "idle"
        return
    }
    global RuntimeDir
    WriteAtomic(RuntimeDir "\local-scare-onset.state", Line(NewId(), "2.wav", now, 7000))
    FigureStarted := now
    FigureEnd := now + 7000
    FigureState := "major"
    if !ShowFigure(true, 35) {
        FigureState := "idle"
        return
    }
    if !PlayAlias("mesofigure", true) {
        LogEvent("Triple T audio could not play")
        DestroyFigureWindow()
        FigureState := "idle"
    }
}

ShowFigure(major, alpha := 255) {
    global FigureGui, FigurePicture, FigureAlpha, FigureMajor, SmallTungLastPosition
    DestroyFigureWindow()
    HorrorGameRectangle(&gx, &gy, &gw, &gh)
    pic := A_ScriptDir "\ui_layer_03.png"
    if !FileExist(pic)
        return false
    if major {
        height := Min(Round(gh * 1.10), 1100)
        width := Round(height * 2 / 3)
        left := gx + gw - Round(width * 0.66)
        top := gy + gh - height + Round(gh * 0.05)
    } else {
        width := Random(60, 130)
        height := Round(width * 1.5)
        left := Random(gx + 18, Max(gx + 19, gx + gw - width - 18))
        top := Random(gy + 15, Max(gy + 16, gy + gh - height - 15))
    }
    if !major
        SmallTungLastPosition := {X: left, Y: top, W: width, H: height}
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale", "Triple T")
    g.BackColor := "010101"
    g.MarginX := 0
    g.MarginY := 0
    try {
        FigurePicture := g.AddPicture("x0 y0 w" width " h" height " BackgroundTrans", pic)
        g.Show("NoActivate x" left " y" top " w" width " h" height)
        FigureGui := g
        FigureMajor := major
        FigureAlpha := alpha
        WinSetTransColor("010101 " alpha, "ahk_id " g.Hwnd)
        return true
    } catch as err {
        LogEvent("Triple T overlay error: " err.Message)
        if GuiHwndSafe(g)
            try g.Destroy()
        FigureGui := 0
        FigurePicture := 0
        return false
    }
}

DestroyFigureWindow() {
    global FigureGui, FigurePicture
    if GuiHwndSafe(FigureGui)
        try FigureGui.Destroy()
    FigureGui := 0
    FigurePicture := 0
}

ProcessFigure(now) {
    global FigureState, FigureDue, FigureStarted, FigureEnd, FigureNext, FigureVisibleUntil, FigureGui, FigureAlpha, FigureMajor, FigureLastDisappear
    if FigureState = "idle"
        return
    if FigureState = "wait" {
        if now >= FigureDue
            StartFigureMajor(now)
        return
    }
    if FigureState = "major" {
        if now >= FigureEnd {
            Mci("stop mesofigure")
            DestroyFigureWindow()
            FigureState := "stalk"
            global RuntimeDir
    WriteAtomic(RuntimeDir "\local-scare-onset.state", Line(NewId(), "2.wav", now, 7000))
    FigureStarted := now
            FigureEnd := now + 15000
            FigureNext := now + Random(400, 1550)
            FigureVisibleUntil := 0
            FigureLastDisappear := now
            return
        }
        elapsed := now - FigureStarted
        left := FigureEnd - now
        opacity := Round(Min(255, 255 * elapsed / 450, 255 * left / 1450))
        if Abs(opacity - FigureAlpha) >= 6 && GuiHwndSafe(FigureGui) {
            FigureAlpha := Max(0, opacity)
            try WinSetTransColor("010101 " FigureAlpha, "ahk_id " FigureGui.Hwnd)
        }
        return
    }
    if FigureState = "stalk" {
        if now >= FigureEnd {
            if GuiHwndSafe(FigureGui)
                FigureLastDisappear := now
            ScheduleSignalScene(FigureLastDisappear ? FigureLastDisappear : now)
            FigureState := "idle"
            DestroyFigureWindow()
            return
        }
        if FigureVisibleUntil && now >= FigureVisibleUntil {
            FigureLastDisappear := now
            try AddScreenDamage(now)
            DestroyFigureWindow()
            FigureVisibleUntil := 0
            FigureNext := now + Random(650, 2200)
        }
        if !FigureVisibleUntil && now >= FigureNext {
            if ShowFigure(false, Random(125, 230))
                FigureVisibleUntil := now + Random(115, 410)
            else
                FigureNext := now + 1300
        }
    }
}

AddScreenDamage(now) {
    global SmallTungLastPosition, ScreenDamage
    if !IsObject(SmallTungLastPosition)
        return
    pos := SmallTungLastPosition
    if ScreenDamage.Parts.Length >= 20
        return
    sourceWidth := Min(150, Max(44, Round(pos.W * Random(0.6, 0.9))))
    width := Max(60, Round(sourceWidth * 2.5))
    height := Round(width * 1.5)
    HorrorGameRectangle(&gx, &gy, &gw, &gh)
    if width > gw || height > gh {
        ratio := Min(gw / width, gh / height)
        width := Max(1, Floor(width * ratio))
        height := Max(1, Floor(height * ratio))
    }
    left := Max(gx, Min(gx + gw - width, pos.X + Round((pos.W - width) / 2)))
    top := Max(gy, Min(gy + gh - height, pos.Y + Round((pos.H - height) / 2)))
    asset := A_ScriptDir "\Ui\tung_damage.png"
    if !FileExist(asset) {
        LogEvent("Screen damage silhouette missing")
        return
    }
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale", "Meso Screen Damage")
    g.BackColor := "010101"
    g.MarginX := 0
    g.MarginY := 0
    try {
        g.AddPicture("x0 y0 w" width " h" height " BackgroundTrans", asset)
        g.Show("NoActivate x" left " y" top " w" width " h" height)
        WinSetTransColor("010101 255", "ahk_id " g.Hwnd)
        ScreenDamage.Parts.Push({Gui: g, Until: now + 60000})
        ScreenDamage.Until := Max(ScreenDamage.Until, now + 60000)
    } catch as err {
        if GuiHwndSafe(g)
            try g.Destroy()
        LogEvent("Screen damage: " err.Message)
    }
}

ProcessScreenDamage(now) {
    global ScreenDamage
    if !ScreenDamage.Parts.Length
        return
    pending := []
    nextEnd := 0
    for item in ScreenDamage.Parts {
        if now >= item.Until {
            if GuiHwndSafe(item.Gui)
                try item.Gui.Destroy()
        } else {
            pending.Push(item)
            nextEnd := Max(nextEnd, item.Until)
        }
    }
    ScreenDamage.Parts := pending
    ScreenDamage.Until := nextEnd
}

ClearScreenDamage() {
    global ScreenDamage, SmallTungLastPosition
    if !IsObject(ScreenDamage)
        return
    for item in ScreenDamage.Parts {
        if GuiHwndSafe(item.Gui)
            try item.Gui.Destroy()
    }
    ScreenDamage.Parts := []
    ScreenDamage.Until := 0
    SmallTungLastPosition := 0
}

CancelFigure() {
    StopSignalScene()
    global FigureState, FigureDue, FigureStarted, FigureEnd, FigureNext, FigureVisibleUntil
    FigureState := "idle"
    FigureDue := 0
    FigureStarted := 0
    FigureEnd := 0
    FigureNext := 0
    FigureVisibleUntil := 0
    Mci("stop mesofigure")
    DestroyFigureWindow()
}

StopSpecialEffects(wParam := 0, lParam := 0, msg := 0, hwnd := 0) {
    StopOutputSpecialSounds()
    global HorrorQueue
    HorrorQueue := []
    StopHorror()
    CancelFigure()
    ClearScreenDamage()
    return 0
}

PauseRendererForUpdate(controller, *) {
    global OutputUpdating, OutputUpdateStarted, AudioReady, RuntimeDir
    OutputUpdating := true
    OutputUpdateStarted := NowMs()
    StopOutputSpecialSounds()
    StopHorror()
    CancelFigure()
    ClearScreenDamage()
    for alias in ["mesotick","mesoland","mesoslottick","mesoslotland","mesohorror","mesofigure"]
        Mci("close " alias)
    AudioReady := Map()
    WriteAtomic(RuntimeDir "\output-update-ready.state", Line(ProcessExist(),controller))
}
ResumeRendererAfterUpdate(*) {
    global OutputUpdating
    OutputUpdating := false
    RefreshAudioSettings(true)
}

PublishRendererSequenceState(now) {
    global HorrorActive, HorrorQueue, FigureState, SignalScene, RuntimeDir
    static last := 0
    if now-last < 250
        return
    last := now
    busy := HorrorActive || HorrorQueue.Length || FigureState!="idle" || SignalScene.Phase!="idle"
    try WriteAtomic(RuntimeDir "\sequence-busy.state",Line(ProcessExist(),now,busy ? 1 : 0))
}
