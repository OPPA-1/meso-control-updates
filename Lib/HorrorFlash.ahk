CreateHorrorFlash(bounds, word := "", wideText := false) {
    style := "+AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale"
    state := {Tint: 0, TextGui: 0, TextToken: 0, TextSurface: 0, Bars: [], LastAlpha: 150,
        LastDistort: -160, Word: word, OffsetX: 0, OffsetY: 0}
    w := bounds.W, h := bounds.H
    try {
        tint := Gui(style, "Meso Horror Tint")
        state.Tint := tint
        tint.BackColor := "57060C"
        tint.MarginX := 0
        tint.MarginY := 0
        colors := ["A31225", "3B040A", "8E0A1D", "290007", "AB1029", "360309", "8B0F20"]
        for i, color in colors {
            y := Round(h * i * 0.12)
            bw := Round(w * (0.34 + Mod(i * 19, 53) / 100))
            x := Round(w * (Mod(i * 29, 47) / 100))
            state.Bars.Push(tint.AddText("x" x " y" y " w" bw " h" (2 + Mod(i * 3, 7)) " Background" color, ""))
        }
        placement := "NoActivate x" bounds.X " y" bounds.Y " w" w " h" h
        tint.Show(placement)
        WinSetTransparent(state.LastAlpha, "ahk_id " tint.Hwnd)
        words := Gui(style " +E0x00080000", "Meso Horror Words")
        state.TextGui := words
        fontSize := wideText ? Max(13, Min(96, Round(w / 22), Round(h / 6))) : Max(52, Min(108, Round(w / 16)))
        tx := Round(w * 0.03), ty := Round(h * 0.38)
        tw := Round(w * 0.94), th := Round(h * 0.20)
        state.TextX := bounds.X
        state.TextY := bounds.Y + ty - 20
        state.TextWidth := w
        state.TextHeight := th + 40
        state.FontSize := Round(fontSize * 4 / 3)
        state.Origin := [tx, 20, tw, th]
        state.TextToken := GdipStart()
        state.TextSurface := Surface(state.TextWidth, state.TextHeight)
        DrawHorrorWord(state)
        words.Show("NoActivate x" state.TextX " y" state.TextY " w" w " h" state.TextHeight)
        return state
    } catch as err {
        CloseHorrorFlash(state)
        throw err
    }
}

DrawHorrorWord(state) {
    canvas := state.TextSurface
    canvas.Clear(0xFF010101)
    if state.Word != "" {
        b := state.Origin
        x := b[1] + state.OffsetX, y := b[2] + state.OffsetY
        canvas.Text(state.Word, x + 9, y + 6, b[3], b[4], state.FontSize, 0xFF910C13, true)
        canvas.Text(state.Word, x, y, b[3], b[4], state.FontSize, 0xFFFFFFFF, true)
    }
    canvas.Flush()
    origin := Buffer(8, 0), size := Buffer(8, 0), source := Buffer(8, 0)
    NumPut("Int", state.TextX, "Int", state.TextY, origin)
    NumPut("Int", state.TextWidth, "Int", state.TextHeight, size)
    if !DllCall("user32\UpdateLayeredWindow", "Ptr", state.TextGui.Hwnd, "Ptr", 0, "Ptr", origin, "Ptr", size,
        "Ptr", canvas.DC, "Ptr", source, "UInt", 0x00010101, "Ptr", 0, "UInt", 1, "Int")
        throw Error("Could not draw the horror text overlay (" A_LastError ")")
}

UpdateHorrorFlash(state, elapsed, word) {
    changed := word != state.Word
    state.Word := word
    if elapsed - state.LastDistort < 160 {
        if changed
            DrawHorrorWord(state)
        return
    }
    state.LastDistort := elapsed
    state.OffsetX := Random(-13, 13), state.OffsetY := Random(-8, 8)
    DrawHorrorWord(state)
    origin := state.Origin
    alpha := Round(147 + 17 * Sin(elapsed / 360.0))
    if Abs(alpha - state.LastAlpha) >= 3 && GuiHwndSafe(state.Tint) {
        state.LastAlpha := alpha
        try WinSetTransparent(alpha, "ahk_id " state.Tint.Hwnd)
    }
    for i, bar in state.Bars {
        if Mod(i, 3) = Mod(Floor(elapsed / 160), 3)
            try bar.Move(, Round((i * 0.12 + Random(-2, 2) / 100) * origin[4] * 4))
    }
}

CloseHorrorFlash(state) {
    if IsObject(state) {
        for g in [state.TextGui, state.Tint]
            if GuiHwndSafe(g)
                try g.Destroy()
        if IsObject(state.TextSurface) {
            state.TextSurface.Dispose()
            state.TextSurface := 0
        }
        if state.TextToken {
            token := state.TextToken
            GdipStop(&token)
            state.TextToken := 0
        }
    }
}
