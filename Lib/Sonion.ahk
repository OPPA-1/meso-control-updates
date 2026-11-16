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
    Sonion := {Target: target, Phase: "cue", Next: now + (preview ? 1200 : 10000), Step: 0,
        Replies: 0, Dim: 0, Panel: 0, Sound: false, RingCheckAt: 0, Flash: 0, Preview: preview, Stage: stage, Transcript: transcript}
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
            KeepSonionRinging(call, now)
            ShakeSonionPhone(call, now)
        case "answered":
            if GuiHwndSafe(call.Panel) && now >= call.HideAt
                CloseSonionWindows(call)
            if now >= call.Deadline
                StopSonion()
            else
                call.Next := now + 60
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

SonionUiAsset(name) {
    SplitPath(A_LineFile,, &scriptFolder)
    return scriptFolder "\..\Ui\" name
}

SonionBounds(call) {
    WinGetClientPos(&x, &y, &w, &h, "ahk_id " call.Target)
    return {X: x, Y: y, W: w, H: h}
}

ShowSonionPhone(call, now) {
    b := SonionBounds(call)
    call.Dim := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale", "Meso Visual Effect: Darkness")
    call.Dim.BackColor := "050208"
    call.Dim.Show("NA x" b.X " y" b.Y " w" b.W " h" b.H)
    WinSetTransparent(240, "ahk_id " call.Dim.Hwnd)
    call.X := b.X + (b.W - 306) // 2
    call.Y := b.Y + (b.H - 506) // 2
    phone := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 -DPIScale", "Sonion")
    call.Panel := phone
    phone.BackColor := "AC7ACA"
    phone.AddText("x5 y4 w296 h498 Background21162E", "")
    phone.AddText("x12 y12 w282 h482 Background2E1D50", "")
    phone.AddText("x12 y345 w282 h147 Background37245F", "")
    phone.AddText("x107 y19 w92 h23 Background100A1C", "")
    phone.SetFont("s10 Bold cE9D7F8", "Segoe UI")
    phone.AddText("x32 y26 w63 h20 BackgroundTrans", "9:41")
    phone.AddText("x218 y26 w56 h20 Right BackgroundTrans", "● ● ●")
    phone.AddText("x34 y77 w238 h28 Center BackgroundTrans", "INCOMING CALL")
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
    phone.Show("NA x" call.X " y" call.Y " w306 h506")
    WinSetRegion("0-0 w306 h506 R55-55", "ahk_id " phone.Hwnd)
    call.PhoneClip := 0
    call.Phase := "ringing"
    call.Next := now
    PlaySonionSound(call, "ringring.mp3", true)
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
    cursor := Buffer(8, 0)
    DllCall("user32\GetCursorPos", "Ptr", cursor)
    x := NumGet(cursor, 0, "Int"), y := NumGet(cursor, 4, "Int")
    inside := Abs(x - (call.X + 153)) <= 163 && Abs(y - (call.Y + 253)) <= 271
    dx := Round((inside ? 2 : 12) * Sin(now / 47))
    dy := Round((inside ? 1 : 7) * Sin(now / 29))
    DllCall("user32\SetWindowPos", "Ptr", call.Panel.Hwnd, "Ptr", -1, "Int", call.X + dx, "Int", call.Y + dy, "Int", 0, "Int", 0, "UInt", 0x11)
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
        if !call.Preview && !WinActive("ahk_id " call.Target) {
            if !WinActive("ahk_id " GuiHwndSafe(call.Panel)) {
                StopSonion()
                return
            }
            try WinActivate("ahk_id " call.Target)
        }
        StopSonionSound(call)
        CloseSonionWindows(call)
        now := NowMs()
        if answer {
            call.Phase := "answered"
            call.Next := now
            call.HideAt := now + 3200
            call.Deadline := now + 12000
            if call.Preview
                call.Transcript.Text := "Answered"
            ShowSonionScare(call)
            PlaySonionSound(call, "321.wav")
        } else {
            call.Phase := "declined"
            call.Next := now + 5000
            if call.Preview
                call.Transcript.Text := "Declined. Glitch starts in five seconds."
        }
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

SonionMediaFile(dir, name) {
    if name = "ringring.mp3" {
        custom := SonionUiAsset(name)
        if FileExist(custom)
            return custom
        data := SonionRingtoneData()
    } else
        data := name = "321.wav" ? SonionScreamData() : SonionGlitchData()
    path := dir "\sonion-603-" name
    size := 0
    if !DllCall("crypt32\CryptStringToBinaryW", "WStr", data, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0, "Int")
        throw Error("Sonion audio size could not be read")
    bytes := Buffer(size)
    if !DllCall("crypt32\CryptStringToBinaryW", "WStr", data, "UInt", 0, "UInt", 1, "Ptr", bytes, "UInt*", &size, "Ptr", 0, "Ptr", 0, "Int")
        throw Error("Sonion audio could not be decoded")
    audio := FileOpen(path, "w")
    try audio.RawWrite(bytes, size)
    finally audio.Close()
    return path
}

SonionMci(command, response := 0, chars := 0) {
    return DllCall("winmm\mciSendStringW", "WStr", command, "Ptr", response, "UInt", chars, "Ptr", 0)
}

KeepSonionRinging(call, now) {
    if !call.Sound || now < call.RingCheckAt
        return
    call.RingCheckAt := now + 120
    mode := Buffer(32, 0)
    if !SonionMci("status mesosonion mode", mode, 16) && StrGet(mode, "UTF-16") = "stopped"
        SonionMci("play mesosonion from 0")
}

StopSonionSound(call) {
    if call.Sound {
        SonionMci("close mesosonion")
        call.Sound := false
    }
}

PlaySonionSound(call, name, repeat := false) {
    global RuntimeDir
    try {
        StopSonionSound(call)
        path := SonionMediaFile(RuntimeDir, name)
        device := name = "321.wav" ? "waveaudio" : "mpegvideo"
        status := SonionMci("open " Chr(34) path Chr(34) " type " device " alias mesosonion")
        if status
            throw Error("Windows audio open returned " status)
        call.Sound := true
        SonionMci("setaudio mesosonion volume to 1000")
        status := SonionMci("play mesosonion from 0" (repeat ? " repeat" : ""))
        if status && repeat
            status := SonionMci("play mesosonion from 0")
        if status
            throw Error("Windows audio playback returned " status)
    } catch as err {
        StopSonionSound(call)
        LogEvent("Sonion audio: " err.Message)
    }
}
