DrawGlitchWheel(c, x, y, elapsed) {
    jitter := Round(17 * Sin(elapsed / 49) + 9 * Sin(elapsed / 21))
    saved := c.Push()
    try {
        c.Transform(x, y + jitter, 0)
        c.Ellipse(25, 33, 310, 310, 0xFF14091E, 0xFF60338A, 3)
        c.Ellipse(31, 39, 298, 298, 0xFF14091E, 0xFFC68EFB, 3)
        colors := [0xFF54258F, 0xFF7838B7, 0xFF3F1C70, 0xFF8747C0, 0xFF552769, 0xFF692EB1]
        for index, color in colors
            c.Pie(40, 48, 280, 280, (index - 1) * 60 + elapsed * .21, 59, color)
        c.Polygon([[164, 23], [196, 23], [180, 58]], 0xFFEFDCFF)
        c.RoundRect(91, 152, 178, 71, 14, 0xFF170C25, 0xFFAB7BE3, 2)
        c.TextNoWrap("CHAOS WHEEL", 95, 169, 170, 31, 20, 0xFFF5E5FF, true)
        frame := Floor(elapsed / 33)
        loop 6 {
            row := 52 + Mod(frame * 27 + A_Index * 41, 266)
            left := 48 + Mod(frame * 43 + A_Index * 47, 150)
            width := 40 + Mod(frame * 31 + A_Index * 19, 99)
            c.Rect(left, row, width, 3 + Mod(frame + A_Index * 3, 10), Mod(A_Index, 2) ? 0xFFDA76DE : 0xFF64E2D6)
        }
    } finally c.Pop(saved)
}
