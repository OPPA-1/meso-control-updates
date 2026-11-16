CreateHorrorFlash(bounds, word := "", wideText := false) {
    style := "+AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale"
    state := {Tint: 0, TextGui: 0, Bars: [], LastAlpha: 150, LastDistort: -160, Word: word}
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
        words := Gui(style, "Meso Horror Words")
        state.TextGui := words
        words.BackColor := "010101"
        words.MarginX := 0
        words.MarginY := 0
        fontSize := wideText ? Max(13, Min(96, Round(w / 22), Round(h / 6))) : Max(52, Min(108, Round(w / 16)))
        tx := Round(w * 0.03), ty := Round(h * 0.38)
        tw := Round(w * 0.94), th := Round(h * 0.20)
        state.Origin := [tx, ty, tw, th]
        words.SetFont("s" fontSize " Bold c910C13", "Segoe UI Black")
        state.Shadow := words.AddText("x" (tx + 8) " y" (ty + 6) " w" tw " h" th " Center +0x200 BackgroundTrans", word)
        words.SetFont("s" fontSize " Bold cFFFFFF", "Segoe UI Black")
        state.Main := words.AddText("x" tx " y" ty " w" tw " h" th " Center +0x200 BackgroundTrans", word)
        words.Show(placement)
        WinSetTransColor("010101", "ahk_id " words.Hwnd)
        return state
    } catch as err {
        CloseHorrorFlash(state)
        throw err
    }
}

UpdateHorrorFlash(state, elapsed, word) {
    if word != state.Word {
        state.Word := word
        state.Shadow.Text := word
        state.Main.Text := word
    }
    if elapsed - state.LastDistort < 160
        return
    state.LastDistort := elapsed
    origin := state.Origin
    dx := Random(-13, 13), dy := Random(-8, 8)
    try state.Shadow.Move(origin[1] + dx + 9, origin[2] + dy + 6)
    try state.Main.Move(origin[1] + dx, origin[2] + dy)
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
    }
}
