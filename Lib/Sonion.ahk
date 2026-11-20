SonionQuestion() {
    return "When the onion rings... Do You Answer?"
}

ScheduleSonion(target, now, stage := 0, transcript := 0) {
    global Sonion
    if IsSet(Sonion) && IsObject(Sonion) {
        if IsObject(stage) || !Sonion.Preview
            return
        StopSonion()
    }
    preview := IsObject(stage)
    OpenStreamOutput(false)
    Sonion := {Target: target, Phase: "cue", Next: now + (preview ? 1200 : 10000), Step: 0,
        Replies: 0, Dim: 0, Panel: 0, Phones: [], Scare: 0, Sound: "", RingCheckAt: 0, Flash: 0, Preview: preview, Stage: stage, Transcript: transcript}
}

StartSonionPreview(owner, now) {
    global Sonion
    previousCritical := A_IsCritical
    Critical("On")
    stage := 0
    try {
        if IsObject(Sonion) && !Sonion.Preview
            return false
        StopSonionPreview()
        stage := Gui("+Owner" owner " -MinimizeBox -MaximizeBox -DPIScale", "Sonion Call | Test")
        stage.BackColor := "160F20"
        stage.SetFont("s10 Bold cD7B8F8", "Segoe UI")
        stage.AddText("x34 y27 w566 h25", "SONION CALL TEST")
        stage.SetFont("s16 Norm cFAF0FF", "Segoe UI")
        transcript := stage.AddText("x35 y100 w721 h200 BackgroundTrans", SonionQuestion())
        stage.SetFont("s10 Norm", "Segoe UI")
        stage.AddButton("x670 y22 w99 h34", "Stop").OnEvent("Click", StopSonionPreview)
        stage.OnEvent("Escape", StopSonionPreview)
        stage.OnEvent("Close", StopSonionPreview)
        stage.Show("w802 h576")
        ScheduleSonion(stage.Hwnd, now, stage, transcript)
        return true
    } catch as err {
        if GuiHwndSafe(stage)
            stage.Destroy()
        throw err
    } finally Critical(previousCritical)
}

StopSonionPreview(*) {
    global Sonion
    if IsSet(Sonion) && IsObject(Sonion) && Sonion.Preview
        StopSonion()
}

AdvanceSonion(now) {
    global Sonion, InputLockOwners
    if !IsSet(Sonion) || !IsObject(Sonion)
        return
    call := Sonion
    if call.Preview ? !GuiHwndSafe(call.Stage) : !WinActive("ahk_id " call.Target) {
        StopSonion()
        return
    }
    if now < call.Next
        return
    switch call.Phase {
        case "cue":
            call.Flash := CreateHorrorFlash(SonionBounds(call), "DO YOU ANSWER", true)
            call.FlashStarted := now
            call.Phase := "red"
            call.Next := now + 40
        case "red":
            elapsed := now - call.FlashStarted
            if elapsed >= 1800 {
                CloseHorrorFlash(call.Flash)
                call.Flash := 0
                call.Phase := "reply"
                call.Next := now
            } else {
                UpdateHorrorFlash(call.Flash, elapsed, "DO YOU ANSWER")
                call.Next := now + 40
            }
        case "reply":
            if call.Preview
                AdvanceSonionPreviewReply(call, now)
            else if !InputLockOwners.Count
                AdvanceSonionReply(call, now)
        case "waiting":
            if call.Preview || !InputLockOwners.Count
                ShowSonionPhone(call, now)
        case "ringing":
            ShakeSonionPhone(call, now)
        case "accepted":
            call.Scare := StartScareVisual("jeff", call.Target, now)
            call.Phase := "answered"
            call.Deadline := call.Scare.End
            call.Next := now + 16
            PublishState(true)
        case "answered":
            if now >= call.Deadline
                StopSonion()
            else {
                DrawScareVisual(call.Scare, now)
                call.Next := now + 16
            }
        case "declined":
            StartSonionGlitch(call, now)
        case "glitch":
            if now >= call.Deadline
                StopSonion()
            else
                UpdateSonionGlitch(call, now)
    }
}

AdvanceSonionPreviewReply(call, now) {
    call.Replies += 1
    call.Transcript.Text .= "`nyes"
    if call.Replies = 3 {
        call.Phase := "waiting"
        call.Next := now + 900
    } else
        call.Next := now + 510
}

AdvanceSonionReply(call, now) {
    switch call.Step {
        case 0:
            SendEvent("{Enter}")
            call.Step := 1
            call.Next := now + 135
        case 1:
            saved := ClipboardAll()
            A_Clipboard := "yes"
            call.Clipboard := saved
            call.ClipboardSequence := DllCall("user32\GetClipboardSequenceNumber", "UInt")
            SendEvent("^v")
            call.Step := 2
            call.Next := now + 110
        case 2:
            RestoreEffectClipboard(call)
            SendEvent("{Enter}")
            call.Replies += 1
            call.Step := 0
            if call.Replies = 3 {
                call.Phase := "waiting"
                call.Next := now + Random(10000, 30000)
            } else
                call.Next := now + 160
    }
}

SonionBounds(call) {
    WinGetClientPos(&x, &y, &w, &h, "ahk_id " call.Target)
    return {X: x, Y: y, W: w, H: h}
}

ShowSonionPhone(call, now) {
    b := SonionBounds(call)
    if !GuiHwndSafe(call.Dim) {
        call.Dim := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale", "Meso Visual Effect: Darkness")
        call.Dim.BackColor := "050208"
        call.Dim.Show("NA x" b.X " y" b.Y " w" b.W " h" b.H)
        WinSetTransparent(240, "ahk_id " call.Dim.Hwnd)
    }
    index := call.Phones.Length + 1
    phone := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 -DPIScale", "Sonion")
    state := {Gui: phone, Sound: "", Index: index}
    call.Phones.Push(state)
    call.Panel := phone
    phone.BackColor := "AC7ACA"
    phone.AddText("x4 y4 w216 h362 Background21162E", "")
    phone.AddText("x10 y10 w204 h348 Background2E1D50", "")
    phone.SetFont("s9 Bold cE9D7F8", "Segoe UI")
    phone.AddText("x22 y27 w180 h20 Center BackgroundTrans", "INCOMING CALL " index)
    caller := SonionUiAsset("sonion_ring.png")
    if !FileExist(caller)
        caller := SonionUiAsset("sonion_ring_default.png")
    call.CallerImage := phone.AddPicture("x55 y69 w114 h113", caller)
    phone.SetFont("s22 Bold cFFFFFF", "Segoe UI")
    phone.AddText("x15 y192 w194 h44 Center BackgroundTrans", "Sonion")
    phone.SetFont("s10 Norm cCBB1EC", "Segoe UI")
    phone.AddText("x15 y243 w194 h24 Center BackgroundTrans", "Ringing…")
    phone.SetFont("s10 Bold", "Segoe UI")
    phone.AddButton("x14 y297 w94 h39", "Decline").OnEvent("Click", AnswerSonion.Bind(false))
    phone.AddButton("x116 y297 w94 h39", "Answer").OnEvent("Click", AnswerSonion.Bind(true))
    capacity := SonionPhoneCapacity(b)
    phone.SetFont("s8 Norm", "Segoe UI")
    state.Pager := phone.AddButton("x42 y341 w140 h22 Hidden", "Other calls")
    state.Pager.OnEvent("Click", CycleSonionPhones)
    call.Page := Floor((index - 1) / capacity)
    LayoutSonionPhones(call, now)
    state.Sound := SpecialSound("ringring.mp3", true)
    if !call.HasOwnProp("PhoneClip")
        call.PhoneClip := 0
    call.Phase := "ringing"
    call.Next := now
}

SonionPhoneCapacity(bounds) {
    return Max(1, Floor((bounds.W - 20) / 240)) * Max(1, Floor((bounds.H - 20) / 386))
}

CycleSonionPhones(*) {
    global Sonion
    if !IsObject(Sonion) || Sonion.Phase != "ringing"
        return
    capacity := SonionPhoneCapacity(SonionBounds(Sonion))
    pages := Ceil(Sonion.Phones.Length / capacity)
    Sonion.Page := Mod(Sonion.Page + pages - 1, pages)
    LayoutSonionPhones(Sonion, NowMs())
}

LayoutSonionPhones(call, now) {
    bounds := SonionBounds(call)
    columns := Max(1, Floor((bounds.W - 20) / 240))
    capacity := SonionPhoneCapacity(bounds)
    pages := Ceil(call.Phones.Length / capacity)
    cursor := Buffer(8, 0)
    DllCall("user32\GetCursorPos", "Ptr", cursor)
    mx := NumGet(cursor, 0, "Int"), my := NumGet(cursor, 4, "Int")
    for p in call.Phones {
        p.Pager.Visible := pages > 1
        if Floor((p.Index - 1) / capacity) != call.Page {
            p.Gui.Hide()
            continue
        }
        slot := Mod(p.Index - 1, capacity)
        x := bounds.X + 12 + Mod(slot, columns) * 240
        y := bounds.Y + 12 + Floor(slot / columns) * 386
        hover := mx >= x - 6 && mx <= x + 230 && my >= y - 6 && my <= y + 376
        dx := hover ? 0 : Round(5 * Sin(now / 47 + p.Index))
        dy := hover ? 0 : Round(3 * Sin(now / 29 + p.Index))
        p.Gui.Show("NA x" x + dx " y" y + dy " w224 h370")
    }
}

ShakeSonionPhone(call, now) {
    global InputLockOwners
    if !call.Preview && !InputLockOwners.Count {
        clip := Buffer(16, 0), screen := Buffer(16, 0)
        left := SysGet(76), top := SysGet(77)
        NumPut("Int", left, "Int", top, "Int", left + SysGet(78), "Int", top + SysGet(79), screen)
        if DllCall("user32\GetClipCursor", "Ptr", clip, "Int") && !SameMouseClip(clip, screen) {
            if DllCall("user32\ClipCursor", "Ptr", 0, "Int")
                call.PhoneClip := clip, call.PhoneScreen := screen
        }
    }
    LayoutSonionPhones(call, now)
    call.Next := now + 38
}

AnswerSonion(answer, *) {
    global Sonion
    if !IsObject(Sonion) || Sonion.Phase != "ringing"
        return
    previousCritical := A_IsCritical
    Critical("On")
    try {
        call := Sonion
        if !answer {
            ShowSonionPhone(call, NowMs())
            return
        }
        CloseSonionWindows(call)
        call.Phase := "accepted"
        call.Next := NowMs() + Random(5000, 20000)
        if call.Preview
            call.Transcript.Text := "Answered"
    } catch as err {
        LogEvent("Sonion response: " err.Message)
        StopSonion()
    } finally Critical(previousCritical)
}

ShowSonionScare(call, imagePath := "") {
    if imagePath = ""
        imagePath := SonionUiAsset("sonion_jeff.png")
    b := SonionBounds(call)
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale", "Sonion")
    call.Panel := g
    g.BackColor := "08050C"
    w := Min(b.W, Round(b.H * 1.765))
    h := Round(w / 1.765)
    g.AddPicture("x" (b.W - w)//2 " y" (b.H - h)//2 " w" w " h" h, imagePath)
    g.Show("NA x" b.X " y" b.Y " w" b.W " h" b.H)
}

StartSonionGlitch(call, now) {
    call.Phase := "glitch"
    call.Start := now
    call.Deadline := now + 7000
    PrepareSonionGlitch(call)
    if call.Preview
        call.Transcript.Text := call.GlitchMode = "reel" ? "Chaos reel glitch" : "Chaos wheel glitch"
    else
        StartSonionPunishments(call, now)
    PlaySonionSound(call, "glitch.mp3")
    ShowSonionGlitch(call, now)
    if !call.Preview
        PublishState(true)
}

StartSonionPunishments(call, now) {
    global ActiveEffects, Clock, SonionGlitchId
    call.Id := NewId()
    SonionGlitchId := call.Id
    selected := []
    choices := call.GlitchItems.Clone()
    while choices.Length && ActiveEffects.Length < 3 {
        p := choices.RemoveAt(WeightedPick(choices))
        if p.Action = "Send Chat" || !CompatibleWheelPick(p, selected) || !CompatibleActivePick(p, ActiveEffects)
            continue
        candidate := p.Clone()
        candidate.TimerGeneration := Clock.Generation
        selected.Push(candidate)
        StartEffect(candidate, false, now, call.Id)
    }
}

SonionGlitchRoom(count) {
    global ActiveEffects, SonionGlitchId, Sonion
    if ActiveEffects.Length + count <= 3
        return true
    if IsSet(Sonion) && IsObject(Sonion) && !Sonion.Preview && Sonion.Phase = "glitch"
        return false
    return !IsSet(SonionGlitchId) || !HasEffects(SonionGlitchId)
}

PrepareSonionGlitch(call) {
    global WheelDisplayMode, Queue
    call.GlitchMode := IsSet(WheelDisplayMode) && WheelDisplayMode = "reel" ? "reel" : "wheel"
    call.GlitchItems := EligiblePunishments()
    call.GlitchDisplay := call.GlitchItems
    if !call.Preview && IsSet(Queue) && IsObject(Queue.Active) && Queue.Active.HasOwnProp("Pool")
        call.GlitchDisplay := Queue.Active.Pool
}

ShowSonionGlitch(call, now) {
    if !call.HasOwnProp("GlitchMode")
        PrepareSonionGlitch(call)
    b := SonionBounds(call)
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080020 -DPIScale", "Sonion")
    call.Panel := g
    call.GlitchToken := GdipStart()
    call.GlitchSurface := Surface(360, 360)
    call.X := b.X + Max(0, b.W - 385), call.Y := b.Y + 24
    UpdateSonionGlitch(call, now)
    g.Show("NA x" call.X " y" call.Y " w360 h360")
}

UpdateSonionGlitch(call, now) {
    c := call.GlitchSurface
    c.Clear(0xFF00FF00)
    DrawGlitchWheel(c, 0, 0, now - call.Start, call.GlitchMode, call.GlitchDisplay)
    c.Flush()
    origin := Buffer(8, 0), size := Buffer(8, 0), source := Buffer(8, 0)
    NumPut("Int", call.X, "Int", call.Y, origin)
    NumPut("Int", 360, "Int", 360, size)
    if !DllCall("user32\UpdateLayeredWindow", "Ptr", call.Panel.Hwnd, "Ptr", 0, "Ptr", origin, "Ptr", size,
        "Ptr", c.DC, "Ptr", source, "UInt", 0x0000FF00, "Ptr", 0, "UInt", 1, "Int")
        throw Error("Glitch wheel could not be painted (" A_LastError ")")
    call.Next := now + 33
}

CompatibleActivePick(candidate, effects) {
    for effect in effects
        if !CompatibleWheelPick(candidate, [effect.P])
            return false
    return true
}

CloseSonionWindows(call) {
    for phone in call.Phones {
        StopSpecialSound(phone.Sound)
        if GuiHwndSafe(phone.Gui)
            try phone.Gui.Destroy()
    }
    call.Phones := []
    if call.HasOwnProp("PhoneClip") && IsObject(call.PhoneClip) && WinActive("ahk_id " call.Target) {
        current := Buffer(16, 0)
        if DllCall("user32\GetClipCursor", "Ptr", current, "Int") && SameMouseClip(current, call.PhoneScreen)
            DllCall("user32\ClipCursor", "Ptr", call.PhoneClip, "Int")
        call.PhoneClip := 0
    }
    for field in ["Panel", "Dim"] {
        g := call.%field%
        call.%field% := 0
        if GuiHwndSafe(g)
            try g.Destroy()
    }
}

StopSonion() {
    global Sonion
    if !IsSet(Sonion) || !IsObject(Sonion)
        return
    call := Sonion
    Sonion := 0
    StopSonionSound(call)
    StopScareVisual(call.Scare)
    try RestoreEffectClipboard(call)
    CloseHorrorFlash(call.Flash)
    CloseSonionWindows(call)
    if call.HasOwnProp("GlitchSurface")
        call.GlitchSurface.Dispose()
    if call.HasOwnProp("GlitchToken") {
        token := call.GlitchToken
        GdipStop(&token)
    }
    if GuiHwndSafe(call.Stage)
        try call.Stage.Destroy()
}

StopSonionSound(call) {
    StopSpecialSound(call.Sound)
    call.Sound := ""
}

PlaySonionSound(call, name, repeat := false) {
    StopSonionSound(call)
    call.Sound := SpecialSound(name, repeat)
}
