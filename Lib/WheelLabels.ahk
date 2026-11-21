WheelLabelBox(sweep) {
    if sweep < 10 {
        radius := 300.0, width := 68.0, margin := 0.2, padding := 1.0, maxHeight := 30.0
    } else if sweep < 24 {
        radius := 250.0, width := 156.0, margin := 0.65, padding := 6.0, maxHeight := 42.0
    } else {
        radius := 230.0, width := 184.0, margin := 1.0, padding := 8.0, maxHeight := 68.0
    }
    half := Max(0.0, Min(80.0, sweep / 2 - margin)) * 0.0174532925199433
    height := Max(0.0, Min(maxHeight, 2 * (radius - width / 2) * Tan(half) - padding))
    return {Radius: radius, W: width, H: height, Lines: sweep < 24 ? 1 : 2, Size: sweep < 10 ? 18 : sweep < 24 ? 18 : 21}
}

WheelLabelName(name, sweep) {
    name := RegExReplace(Trim(name), "\s+", " ")
    if name = "Chat Confession"
        name := "Send Chat"
    if name = "Time Tax -2:00"
        return "-2:00"
    if sweep < 10 && InStr(StrLower(name), "exit")
        return "EXIT"
    return StrUpper(name)
}

WheelJoinWords(words, first, last) {
    result := ""
    loop Max(0, last - first + 1) {
        word := words[first + A_Index - 1]
        result .= (result = "" ? "" : " ") word
    }
    return result
}

FitDisplayText(c, text, width, height, maxSize := 21, minSize := 9, maxLines := 2, preferTwo := false) {
    text := RegExReplace(Trim(text), "\s+", " ")
    if height < 8 || width < 8 || text = ""
        return {Lines: [], Size: 8, LineH: 0}
    candidates := [[text]]
    words := StrSplit(text, " ")
    if maxLines > 1 && words.Length > 1 {
        loop words.Length - 1
            candidates.Push([WheelJoinWords(words, 1, A_Index), WheelJoinWords(words, A_Index + 1, words.Length)])
    }
    maxSize := Max(minSize, Floor(maxSize))
    loop maxSize - minSize + 1 {
        size := maxSize - A_Index + 1
        best := 0, bestCost := 1000000000.0
        for lines in candidates {
            wide := 0.0, narrow := 1000000.0, lineH := 0.0
            for line in lines {
                measured := c.MeasureText(line, size, true)
                wide := Max(wide, measured.W)
                narrow := Min(narrow, measured.W)
                lineH := Max(lineH, measured.H)
            }
            lineH := Ceil(lineH + 1)
            if wide > width - 6 || lineH * lines.Length > height - 2
                continue
            penalty := preferTwo ? (lines.Length = 2 ? 0 : 100000) : (lines.Length = 1 ? 0 : 100000)
            cost := penalty + wide - narrow
            if cost < bestCost {
                bestCost := cost
                best := {Lines: lines, Size: size, LineH: lineH}
            }
        }
        if IsObject(best)
            return best
    }
    size := Min(minSize, Floor(height / 1.5))
    if size < 7
        return {Lines: [], Size: 7, LineH: 0}
    shortened := text
    loop StrLen(text) + 1 {
        display := shortened = text ? text : shortened "…"
        measured := c.MeasureText(display, size, true)
        if measured.W <= width - 6 && Ceil(measured.H + 1) <= height - 2
            return {Lines: [display], Size: size, LineH: Ceil(measured.H + 1)}
        if StrLen(shortened) = 0
            break
        shortened := RTrim(SubStr(shortened, 1, -1))
    }
    return {Lines: [], Size: size, LineH: 0}
}

FitWheelLabel(c, name, sweep) {
    box := WheelLabelBox(sweep)
    fit := FitDisplayText(c, WheelLabelName(name, sweep), box.W, box.H, box.Size, 9, box.Lines, box.Lines = 2)
    return {Radius: box.Radius, W: box.W, H: box.H, Lines: fit.Lines, Size: fit.Size, LineH: fit.LineH, Center: 0.0}
}

DrawWheelLabel(c, layout, rotation) {
    if !layout.Lines.Length
        return
    angle := NormAngle(rotation + layout.Center)
    radians := angle * 0.0174532925199433
    x := 400 + Cos(radians) * layout.Radius
    y := 400 + Sin(radians) * layout.Radius
    turn := angle > 90 && angle < 270 ? angle + 180 : angle
    saved := c.Push()
    try {
        c.Transform(x, y, turn)
        c.Clip(-layout.W / 2, -layout.H / 2, layout.W, layout.H)
        top := -(layout.LineH * layout.Lines.Length) / 2
        for i, line in layout.Lines {
            ly := top + (i - 1) * layout.LineH
            c.TextNoWrap(line, -layout.W / 2 + 1, ly + 1, layout.W - 2, layout.LineH, layout.Size, 0xFF160623, true)
            c.TextNoWrap(line, -layout.W / 2, ly, layout.W - 2, layout.LineH, layout.Size, 0xFFF9F5FF, true)
        }
    } finally c.Pop(saved)
}

DrawFittedDisplay(c, text, x, y, w, h, maxSize, minSize := 16) {
    fitted := FitDisplayText(c, text, w, h, maxSize, minSize, 2)
    top := y + (h - fitted.LineH * fitted.Lines.Length) / 2
    for i, line in fitted.Lines
        c.TextNoWrap(line, x, top + (i - 1) * fitted.LineH, w, fitted.LineH, fitted.Size, 0xFFF9F5FF, true)
}


CacheWheelLabel(layout) {
    if !layout.Lines.Length
        return
    w := Max(1, Ceil(layout.W)), h := Max(1, Ceil(layout.H))
    sprite := Surface(w, h, true)
    try {
        sprite.Clear(0x00000000)
        top := (h - layout.LineH * layout.Lines.Length) / 2
        for i, line in layout.Lines {
            y := top + (i - 1) * layout.LineH
            sprite.TextNoWrap(line, 1, y + 1, w - 2, layout.LineH, layout.Size, 0xFF160623, true)
            sprite.TextNoWrap(line, 0, y, w - 2, layout.LineH, layout.Size, 0xFFF9F5FF, true)
        }
        sprite.Flush()
        layout.Sprite := sprite
    } catch as err {
        sprite.Dispose()
        throw err
    }
}

DrawCachedWheelLabel(c, layout, rotation) {
    if !layout.HasOwnProp("Sprite") || !IsObject(layout.Sprite)
        return
    angle := NormAngle(rotation + layout.Center)
    radians := angle * 0.0174532925199433
    x := 400 + Cos(radians) * layout.Radius
    y := 400 + Sin(radians) * layout.Radius
    turn := angle > 90 && angle < 270 ? angle + 180 : angle
    saved := c.Push()
    try {
        c.Transform(x, y, turn)
        c.ImageAt(layout.Sprite.Image, -layout.Sprite.W / 2, -layout.Sprite.H / 2, layout.Sprite.W, layout.Sprite.H)
    } finally c.Pop(saved)
}
