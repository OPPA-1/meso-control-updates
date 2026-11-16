ChaosGlitchFrame(elapsed) {
    frame := Floor(elapsed / 33)
    return {Index: frame, X: Mod(frame * 17, 13) - 6,
        Y: Round(17 * Sin(elapsed / 49) + 9 * Sin(elapsed / 21))}
}

DrawChaosInterference(c, x, y, w, h, frame) {
    loop 6 {
        row := y + Mod(frame * 27 + A_Index * 41, h)
        left := x + Mod(frame * 43 + A_Index * 47, Round(w * .68))
        width := Round(w * .08) + Mod(frame * 31 + A_Index * 19, Round(w * .23))
        color := Mod(A_Index, 2) ? 0x88DA76DE : 0x9964E2D6
        c.Rect(left, row, width, 3 + Mod(frame + A_Index * 3, 10), color)
    }
}

DrawGlitchWheel(c, x, y, elapsed, mode := "wheel", items := 0) {
    frame := ChaosGlitchFrame(elapsed)
    saved := c.Push()
    try {
        c.Transform(x + frame.X, y + frame.Y, 0)
        if mode = "reel" {
            DrawGlitchReel(c, elapsed, items)
        } else {
            c.Ellipse(25, 33, 310, 310, 0xFF14091E, 0xFF60338A, 3)
            c.Ellipse(31, 39, 298, 298, 0xFF14091E, 0xFFC68EFB, 3)
            colors := [0xFF54258F, 0xFF7838B7, 0xFF3F1C70, 0xFF8747C0, 0xFF552769, 0xFF692EB1]
            count := IsObject(items) && items.Length ? items.Length : colors.Length
            sweep := 360.0 / count
            loop count
                c.Pie(40, 48, 280, 280, (A_Index - 1) * sweep + elapsed * .21, Max(0.2, sweep - .5), colors[Mod(A_Index - 1, colors.Length) + 1])
            c.Polygon([[164, 23], [196, 23], [180, 58]], 0xFFEFDCFF)
            c.RoundRect(91, 152, 178, 71, 14, 0xFF170C25, 0xFFAB7BE3, 2)
            c.TextNoWrap("CHAOS WHEEL", 95, 169, 170, 31, 20, 0xFFF5E5FF, true)
        }
        DrawChaosInterference(c, 45, 48, 270, 244, frame.Index)
    } finally c.Pop(saved)
}

DrawGlitchReel(c, elapsed, items) {
    c.RoundRect(25, 33, 310, 290, 18, 0xFF160D23, 0xFF9760C5, 3)
    c.TextNoWrap("CHAOS REEL", 38, 49, 284, 44, 25, 0xFFF5E5FF, true)
    c.RoundRect(42, 100, 276, 201, 16, 0xFF231132, 0xFF654388, 2)
    c.RoundRect(44, 172, 272, 55, 12, 0xFF55217B, 0xFFCF9FFF, 2)
    count := IsObject(items) ? items.Length : 0
    if !count
        return
    scroll := Max(0, elapsed) / 110
    base := Floor(scroll)
    saved := c.Push()
    try {
        c.Clip(55, 104, 250, 193)
        for offset in [-1, 0, 1, 2] {
            index := Mod(base + offset + count, count) + 1
            y := 176 + (offset - (scroll - base)) * 66
            c.TextNoWrap(items[index].Name, 58, y, 244, 46, 18, 0xFFF4E7FF, true)
        }
    } finally c.Pop(saved)
}
