FitSlotLabel(c, text, width := 209, height := 104) {
    static layouts := Map()
    text := RegExReplace(Trim(text), "\s+", " ")
    key := width "|" height "|" text
    if layouts.Has(key)
        return layouts[key]
    if layouts.Count >= 512
        layouts.Clear()
    fitted := FitDisplayText(c, text, width, height, 28, 12, 2)
    layouts[key] := fitted
    return fitted
}

DrawSlotLabel(c, text, x, y, w := 209, h := 116) {
    fitted := FitSlotLabel(c, text, w, h - 12)
    top := y + (h - fitted.LineH * fitted.Lines.Length) / 2
    for i, line in fitted.Lines {
        ly := top + (i - 1) * fitted.LineH
        c.TextNoWrap(line, x + 1, ly + 1, w, fitted.LineH, fitted.Size, 0xFF10071C, true)
        c.TextNoWrap(line, x, ly, w, fitted.LineH, fitted.Size, 0xFFF9F5FF, true)
    }
}
