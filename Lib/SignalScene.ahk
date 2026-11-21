ScheduleSignalScene(lastDisappear) {
    global SignalScene
    StopSignalScene()
    SignalScene.Phase := "waiting"
    SignalScene.Due := lastDisappear + 10000
    SignalScene.LastDisappear := lastDisappear
}

StartSignalScene(now) {
    global SignalScene
    HorrorGameRectangle(&x, &y, &w, &h)
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale", "Meso Signal")
    g.BackColor := "010101"
    g.MarginX := 0
    g.MarginY := 0
    cards := []
    cw := Min(430, Floor(w * 0.35))
    ch := Min(220, Floor(h * 0.28))
    loop 5 {
        i := A_Index
        xx := Round((w - cw) * Mod(i * 0.19, 0.82))
        yy := Round((h - ch) * Mod(i * 0.23, 0.87))
        parts := []
        parts.Push({C: g.AddText("x" xx " y" yy " w" cw " h" ch " Background20101B", ""), X: 0, Y: 0})
        parts.Push({C: g.AddText("x" xx " y" yy " w" cw " h3 BackgroundD33857", ""), X: 0, Y: 0})
        g.SetFont("s12 Bold cFFC6D1", "Segoe UI")
        header := g.AddText("x" (xx + 14) " y" (yy + 14) " w" (cw - 28) " h26 Background20101B", "SIGNAL LOST")
        parts.Push({C: header, X: 14, Y: 14})
        g.SetFont("s20 Bold cFFFFFF", "Segoe UI")
        label := g.AddText("x" (xx + 14) " y" (yy + 57) " w" (cw - 137) " h75 Background20101B", "HE IS HERE")
        parts.Push({C: label, X: 14, Y: 57})
        g.SetFont("s9 Norm cB7859A", "Consolas")
        code := g.AddText("x" (xx + 14) " y" (yy + ch - 48) " w" (cw - 28) " h32 Background20101B", "0x0000  >>>  signal intercepted")
        parts.Push({C: code, X: 14, Y: ch - 48})
        if FileExist(A_ScriptDir "\ui_layer_03.png") {
            pic := g.AddPicture("x" (xx + cw - 119) " y" (yy + 39) " w100 h150 Background20101B", A_ScriptDir "\ui_layer_03.png")
            parts.Push({C: pic, X: cw - 119, Y: 39})
        }
        cards.Push({Parts: parts, Label: label, Code: code, X: xx, Y: yy, W: cw, H: ch})
    }
    g.Show("NoActivate x" x " y" y " w" w " h" h)
    WinSetTransColor("010101 232", "ahk_id " g.Hwnd)
    SignalScene.Gui := g
    SignalScene.Cards := cards
    SignalScene.Start := now
    SignalScene.End := now + 5000
    SignalScene.Next := now
    SignalScene.Phase := "running"
    SignalScene.Width := w
    SignalScene.Height := h
}

ProcessSignalScene(now) {
    global SignalScene
    if SignalScene.Phase = "waiting" {
        if now >= SignalScene.Due {
            try StartSignalScene(now)
            catch as err {
                StopSignalScene()
                LogEvent("Signal overlay: " err.Message)
            }
        }
        return
    }
    if SignalScene.Phase != "running"
        return
    if now >= SignalScene.End {
        StopSignalScene()
        return
    }
    if now < SignalScene.Next
        return
    SignalScene.Next := now + 140
    t := (now - SignalScene.Start) / 1000
    for i, card in SignalScene.Cards {
        xx := Max(0, Min(SignalScene.Width - card.W, card.X + Round(26 * Sin(t * 3.0 + i))))
        yy := Max(0, Min(SignalScene.Height - card.H, card.Y + Round(16 * Cos(t * 2.3 + i))))
        for part in card.Parts
            part.C.Move(xx + part.X, yy + part.Y)
        card.Code.Text := Format("0x{:04X}  >>>  SIGNAL {}", Mod(Floor(t * 3000) + i * 111, 65535), Mod(Floor(t * 3) + i, 2) ? "OVERRUN" : "LOST")
    }
    left := SignalScene.End - now
    if left < 600 && GuiHwndSafe(SignalScene.Gui)
        WinSetTransColor("010101 " Max(0, Round(232 * left / 600)), "ahk_id " SignalScene.Gui.Hwnd)
}

StopSignalScene() {
    global SignalScene
    if !IsSet(SignalScene) || !IsObject(SignalScene)
        return
    SignalScene.Phase := "idle"
    if GuiHwndSafe(SignalScene.Gui)
        try SignalScene.Gui.Destroy()
    SignalScene.Gui := 0
    SignalScene.Cards := []
    SignalScene.Due := 0
    SignalScene.End := 0
}
