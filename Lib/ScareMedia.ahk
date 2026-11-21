EnsureScareState() {
    global SpecialSounds, ScareQueue, ActiveScare
    if !IsSet(SpecialSounds)
        SpecialSounds := Map()
    if !IsSet(ScareQueue)
        ScareQueue := []
    if !IsSet(ActiveScare)
        ActiveScare := 0
}

SpecialSound(name, repeat := false, duration := 0, publish := true) {
    global SpecialSounds
    EnsureScareState()
    OpenStreamOutput(false)
    id := NewId()
    SpecialSounds[id] := {Name: name, Repeat: repeat, Until: duration ? NowMs() + duration : 0}
    if publish
        PublishState(true)
    return id
}

StopSpecialSound(id) {
    global SpecialSounds
    EnsureScareState()
    if id != "" && SpecialSounds.Has(id) {
        SpecialSounds.Delete(id)
        PublishState(true)
    }
}

SpecialAudioState(now) {
    global SpecialSounds
    EnsureScareState()
    body := ""
    for id, sound in SpecialSounds.Clone() {
        if sound.Until && now >= sound.Until {
            SpecialSounds.Delete(id)
            continue
        }
        body .= Line("sound", id, sound.Name, sound.Repeat ? 1 : 0, sound.Until)
    }
    return body
}

QueueRandomScare(target, now) {
    global ScareQueue
    EnsureScareState()
    OpenStreamOutput(false)
    previous := ScareQueue.Length ? ScareQueue[ScareQueue.Length].Due : 0
    due := previous ? Max(now, previous) + Random(2000, 30000) : now + Random(1000, 60000)
    event := {Name: Random(1, 2) = 1 ? "scare1" : "scare2", Target: target, Due: due}
    ScareQueue.Push(event)
    return event
}

AdvanceScares(now) {
    global ScareQueue, ActiveScare
    EnsureScareState()
    if IsObject(ActiveScare) {
        if now >= ActiveScare.End || !WinActive("ahk_id " ActiveScare.Target) {
            StopScareVisual(ActiveScare)
            ActiveScare := 0
        } else
            DrawScareVisual(ActiveScare, now)
    }
    if !IsObject(ActiveScare) && ScareQueue.Length && now >= ScareQueue[1].Due {
        event := ScareQueue.RemoveAt(1)
        target := event.Target ? event.Target : ForegroundTarget()
        if target && WinActive("ahk_id " target) {
            ActiveScare := StartScareVisual(event.Name, target, now)
            PublishState(true)
        }
    }
}

StartScareVisual(name, target, now) {
    def := ScareDefinition(name)
    monitor := DllCall("user32\MonitorFromWindow", "Ptr", target, "UInt", 2, "Ptr")
    info := Buffer(40, 0)
    NumPut("UInt", 40, info)
    if !DllCall("user32\GetMonitorInfoW", "Ptr", monitor, "Ptr", info)
        throw Error("Could not find the game monitor")
    x := NumGet(info, 4, "Int"), y := NumGet(info, 8, "Int")
    w := NumGet(info, 12, "Int") - x, h := NumGet(info, 16, "Int") - y
    state := {Name: name, Target: target, Start: now, End: now + def.Duration, Definition: def,
        Token: 0, Image: 0, Surface: 0, Gui: 0, Sound: "", X: x, Y: y, W: w, H: h}
    try {
        state.Token := GdipStart()
        source := SonionUiAsset(name = "jeff" ? "sonion_jeff.png" : name = "scare2" ? "omni.png" : "scare1.png")
        pic := 0
        if DllCall("gdiplus\GdipLoadImageFromFile", "WStr", source, "Ptr*", &pic) || !pic
            throw Error("Jumpscare image could not load")
        state.Image := pic
        state.Surface := Surface(w, h)
        state.Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080020 -DPIScale", "Meso Jumpscare")
        DrawScareVisual(state, now)
        state.Gui.Show("NA x" x " y" y " w" w " h" h)
        PlayLocalScare(name = "jeff" ? "321.wav" : name, def.Duration)
        state.Sound := SpecialSound(name = "jeff" ? "321.wav" : name, false, def.Duration, false)
        return state
    } catch as err {
        StopScareVisual(state)
        throw err
    }
}

DrawScareVisual(state, now) {
    canvas := state.Surface
    canvas.Clear(0x00000000)
    DrawScareFrame(canvas, state.Image, state.Definition, now - state.Start, state.W, state.H)
    canvas.Flush()
    point := Buffer(8, 0), size := Buffer(8, 0), source := Buffer(8, 0), blend := Buffer(4, 0)
    NumPut("Int", state.X, "Int", state.Y, point)
    NumPut("Int", state.W, "Int", state.H, size)
    NumPut("UChar", 255, "UChar", 1, blend, 2)
    if !DllCall("user32\UpdateLayeredWindow", "Ptr", state.Gui.Hwnd, "Ptr", 0, "Ptr", point, "Ptr", size,
        "Ptr", canvas.DC, "Ptr", source, "UInt", 0, "Ptr", blend, "UInt", 2)
        throw Error("Could not draw jumpscare")
}

StopScareVisual(state) {
    if !IsObject(state)
        return
    state.End := NowMs()
    StopSpecialSound(state.Sound)
    state.Sound := ""
    if GuiHwndSafe(state.Gui)
        try state.Gui.Destroy()
    if IsObject(state.Surface)
        state.Surface.Dispose()
    if state.Image {
        DllCall("gdiplus\GdipDisposeImage", "Ptr", state.Image)
        state.Image := 0
    }
    if state.Token {
        token := state.Token
        GdipStop(&token)
        state.Token := 0
    }
}

CancelScares() {
    global ScareQueue, ActiveScare
    EnsureScareState()
    ScareQueue := []
    StopLocalScares()
    StopScareVisual(ActiveScare)
    ActiveScare := 0
}
