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
    CancelSequenceAltEnter()
    preview := IsObject(stage)
    OpenStreamOutput(false)
    Sonion := {Target: target, Phase: "cue", Next: now + (preview ? 1200 : 10000), Step: 0,
        Replies: 0, Guard: 0, Dim: 0, Panel: 0, Phones: [], Scare: 0, Sound: "", RingCheckAt: 0, Flash: 0, Preview: preview, Stage: stage, Transcript: transcript}
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
    if call.Preview ? !GuiHwndSafe(call.Stage) : !WinExist("ahk_id " call.Target) {
        StopSonion()
        return
    }
    if now < call.Next
        return
    switch call.Phase {
        case "cue":
            if !call.Preview
                call.Guard := InteractionGuard(call.Target, StopSonionInteraction)
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
    if !WinActive("ahk_id " call.Target) {
        call.Next := now + 20
        return
    }
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
                if IsObject(call.Guard)
                    call.Guard.Close()
                call.Guard := 0
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
    if !call.Preview && !IsObject(call.Guard)
        call.Guard := InteractionGuard(call.Target, StopSonionInteraction)
    if !GuiHwndSafe(call.Dim) {
        call.Dim := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale", "Meso Visual Effect: Darkness")
        call.Dim.BackColor := "050208"
        call.Dim.Show("NA x" b.X " y" b.Y " w" b.W " h" b.H)
        WinSetTransparent(240, "ahk_id " call.Dim.Hwnd)
    }
    firstPhone := call.Phones.Length = 0
    index := call.Phones.Length + 1
    position := SonionPhonePlacement(b, call.Phones)
    phone := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 -DPIScale", "Sonion")
    state := {Gui: phone, Sound: "", Index: index, X: position.X, Y: position.Y, Page: position.Page, RegionApplied: false}
    call.Phones.Push(state)
    call.Panel := phone
    UpdateInteractionPointer(call, firstPhone)
    phone.BackColor := "AC7ACA"
    phone.AddText("x5 y4 w296 h498 Background21162E", "")
    phone.AddText("x12 y12 w282 h482 Background2E1D50", "")
    phone.AddText("x12 y345 w282 h147 Background37245F", "")
    phone.AddText("x107 y19 w92 h23 Background100A1C", "")
    phone.SetFont("s10 Bold cE9D7F8", "Segoe UI")
    phone.AddText("x32 y26 w63 h20 BackgroundTrans", "9:41")
    phone.AddText("x218 y26 w56 h20 Right BackgroundTrans", "● ● ●")
    phone.AddText("x34 y77 w238 h28 Center BackgroundTrans", "INCOMING CALL " index)
    phone.AddText("x74 y111 w158 h159 Background8C5CBA", "")
    caller := SonionUiAsset("sonion_ring.png")
    if !FileExist(caller)
        caller := SonionUiAsset("sonion_ring_default.png")
    call.CallerImage := phone.AddPicture("x76 y113 w154 h155", caller)
    phone.SetFont("s27 Bold cFFFFFF", "Segoe UI")
    phone.AddText("x26 y279 w254 h51 Center BackgroundTrans", "Sonion")
    phone.SetFont("s11 Norm cCBB1EC", "Segoe UI")
    phone.AddText("x29 y335 w248 h29 Center BackgroundTrans", "Ringing…")
    phone.SetFont("s11 Bold", "Segoe UI")
    phone.AddButton("x31 y394 w113 h49", "Decline").OnEvent("Click", AnswerSonion.Bind(false))
    phone.AddButton("x162 y394 w113 h49 Default", "Answer").OnEvent("Click", AnswerSonion.Bind(true))
    phone.AddText("x108 y475 w90 h4 BackgroundDBC3F5", "")
    phone.SetFont("s8 Norm", "Segoe UI")
    state.Pager := phone.AddButton("x83 y446 w140 h22 Hidden", "Other calls")
    state.Pager.OnEvent("Click", CycleSonionPhones)
    call.Page := state.Page
    LayoutSonionPhones(call, now)
    state.Sound := SpecialSound("ringring.mp3", true)
    if !call.HasOwnProp("PhoneClip")
        call.PhoneClip := 0
    call.Phase := "ringing"
    call.Next := now
}

SonionPhoneCapacity(bounds) {
    return Max(1, Floor(bounds.W / 306)) * Max(1, Floor(bounds.H / 506))
}

SonionPhonePages(phones) {
    pages := 1
    for phone in phones
        pages := Max(pages, phone.Page + 1)
    return pages
}

SonionRectsOverlap(ax, ay, aw, ah, bx, by, bw, bh) {
    return ax < bx + bw && bx < ax + aw && ay < by + bh && by < ay + ah
}

SonionPhoneFits(x, y, other) {
    ; A phone may overlap another bezel, but both answer/decline rows stay clear, even while shaking.
    return !SonionRectsOverlap(x - 5, y - 3, 316, 512, other.X + 23, other.Y + 386, 260, 65)
        && !SonionRectsOverlap(x + 23, y + 386, 260, 65, other.X - 5, other.Y - 3, 316, 512)
}

SonionPhonePlacement(bounds, phones) {
    maxX := Max(0, bounds.W - 306), maxY := Max(0, bounds.H - 506)
    if !phones.Length
        return {X: maxX // 2, Y: maxY // 2, Page: 0}
    page := phones[phones.Length].Page
    marginX := Min(8, maxX // 2), marginY := Min(8, maxY // 2)
    loop 600 {
        x := Random(marginX, maxX - marginX), y := Random(marginY, maxY - marginY)
        fits := true
        for other in phones {
            if other.Page = page && !SonionPhoneFits(x, y, other) {
                fits := false
                break
            }
        }
        if fits
            return {X: x, Y: y, Page: page}
    }
    ; Keep every call and ringtone; use another page only when no unobstructed button row fits.
    return {X: Random(0, maxX), Y: Random(0, maxY), Page: page + 1}
}

CycleSonionPhones(*) {
    global Sonion
    if !IsObject(Sonion) || Sonion.Phase != "ringing"
        return
    pages := SonionPhonePages(Sonion.Phones)
    Sonion.Page := Mod(Sonion.Page + pages - 1, pages)
    LayoutSonionPhones(Sonion, NowMs())
}

LayoutSonionPhones(call, now) {
    bounds := SonionBounds(call)
    pages := SonionPhonePages(call.Phones)
    cursor := Buffer(8, 0)
    DllCall("user32\GetCursorPos", "Ptr", cursor)
    mx := NumGet(cursor, 0, "Int"), my := NumGet(cursor, 4, "Int")
    for p in call.Phones {
        p.Pager.Visible := pages > 1
        if p.Page != call.Page {
            p.Gui.Hide()
            continue
        }
        x := bounds.X + Min(p.X, Max(0, bounds.W - 306))
        y := bounds.Y + Min(p.Y, Max(0, bounds.H - 506))
        hover := mx >= x - 6 && mx <= x + 312 && my >= y - 6 && my <= y + 512
        dx := hover ? 0 : Round(5 * Sin(now / 47 + p.Index))
        dy := hover ? 0 : Round(3 * Sin(now / 29 + p.Index))
        x := Max(bounds.X, Min(x + dx, bounds.X + Max(0, bounds.W - 306)))
        y := Max(bounds.Y, Min(y + dy, bounds.Y + Max(0, bounds.H - 506)))
        p.Gui.Show("NA x" x " y" y " w306 h506")
        if !p.RegionApplied {
            WinSetRegion("0-0 w306 h506 R55-55", "ahk_id " p.Gui.Hwnd)
            p.RegionApplied := true
        }
    }
}

ShakeSonionPhone(call, now) {
    UpdateInteractionPointer(call)
    LayoutSonionPhones(call, now)
    call.Next := now + 16
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
    if call.HasOwnProp("Guard") && IsObject(call.Guard)
        call.Guard.Close()
    call.Guard := 0
    CloseInteractionPointer(call)
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

StopSonionInteraction(*) {
    StopSonion()
    RequestInteractionEmergency()
}
