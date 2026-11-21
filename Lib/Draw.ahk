#DllLoad gdiplus.dll

GdipStart() {
    input := Buffer(A_PtrSize = 8 ? 24 : 16, 0), token := 0
    NumPut("UInt", 1, input)
    status := DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", input, "Ptr", 0, "Int")
    if status != 0 || !token
        throw Error("GDI+ could not start. Status: " status)
    return token
}

GdipStop(&token) {
    if !token
        return
    activeToken := token
    token := 0
    DllCall("gdiplus\GdiplusShutdown", "Ptr", activeToken)
}

class Surface {
    __New(w, h, image := false) {
        this.W := w, this.H := h, this.G := 0, this.Image := 0, this.DC := 0, this.Bitmap := 0, this.Old := 0
        this.Brushes := Map(), this.Pens := Map(), this.Fonts := Map(), this.Formats := Map(), this.Family := 0
        if image {
            bitmap := 0, graphics := 0
            if DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)
                throw Error("Image allocation failed")
            DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)
            this.Image := bitmap, this.G := graphics
        } else {
            this.DC := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
            info := Buffer(40, 0), bits := 0
            NumPut("UInt", 40, "Int", w, "Int", -h, "UShort", 1, "UShort", 32, info)
            this.Bitmap := DllCall("gdi32\CreateDIBSection", "Ptr", this.DC, "Ptr", info, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
            if !this.Bitmap
                throw Error("Canvas allocation failed")
            this.Old := DllCall("gdi32\SelectObject", "Ptr", this.DC, "Ptr", this.Bitmap, "Ptr")
            graphics := 0
            DllCall("gdiplus\GdipCreateFromHDC", "Ptr", this.DC, "Ptr*", &graphics)
            this.G := graphics
        }
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", this.G, "Int", 4)
        DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", this.G, "Int", 4)
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", this.G, "Int", 6)
        family := 0
        DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &family)
        this.Family := family
    }
    Brush(color) {
        if !this.Brushes.Has(color) {
            b := 0
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", color, "Ptr*", &b)
            this.Brushes[color] := b
        }
        return this.Brushes[color]
    }
    Pen(color, width := 1) {
        key := color "|" width
        if !this.Pens.Has(key) {
            p := 0
            DllCall("gdiplus\GdipCreatePen1", "UInt", color, "Float", width, "Int", 2, "Ptr*", &p)
            this.Pens[key] := p
        }
        return this.Pens[key]
    }
    Font(size, bold := false) {
        size := Round(size, 1)
        key := size "|" bold
        if !this.Fonts.Has(key) {
            f := 0
            DllCall("gdiplus\GdipCreateFont", "Ptr", this.Family, "Float", size, "Int", bold ? 1 : 0, "Int", 2, "Ptr*", &f)
            this.Fonts[key] := f
        }
        return this.Fonts[key]
    }
    Text(text, x, y, w, h, size := 20, color := 0xFFF5F0FF, bold := false, align := 1) {
        if !this.Formats.Has(align) {
            f := 0
            DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "UInt", 0, "Ptr*", &f)
            DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", f, "Int", align)
            DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", f, "Int", 1)
            DllCall("gdiplus\GdipSetStringFormatTrimming", "Ptr", f, "Int", 3)
            this.Formats[align] := f
        }
        r := Buffer(16)
        NumPut("Float", x, "Float", y, "Float", w, "Float", h, r)
        DllCall("gdiplus\GdipDrawString", "Ptr", this.G, "WStr", text, "Int", -1, "Ptr", this.Font(size, bold), "Ptr", r, "Ptr", this.Formats[align], "Ptr", this.Brush(color))
    }
    SingleLineFormat(align := 1) {
        key := "single|" align
        if !this.Formats.Has(key) {
            f := 0
            DllCall("gdiplus\GdipCreateStringFormat", "Int", 0x1000, "UInt", 0, "Ptr*", &f)
            DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", f, "Int", align)
            DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", f, "Int", 1)
            DllCall("gdiplus\GdipSetStringFormatTrimming", "Ptr", f, "Int", 0)
            this.Formats[key] := f
        }
        return this.Formats[key]
    }
    MeasureText(text, size := 20, bold := false) {
        rect := Buffer(16, 0), measured := Buffer(16, 0), fitted := 0, lines := 0
        NumPut("Float", 20000.0, "Float", 20000.0, rect, 8)
        status := DllCall("gdiplus\GdipMeasureString", "Ptr", this.G, "WStr", text, "Int", -1, "Ptr", this.Font(size, bold), "Ptr", rect, "Ptr", this.SingleLineFormat(0), "Ptr", measured, "Int*", &fitted, "Int*", &lines, "Int")
        if status != 0
            throw Error("Text measurement failed: " status)
        return {W: NumGet(measured, 8, "Float"), H: NumGet(measured, 12, "Float")}
    }
    TextNoWrap(text, x, y, w, h, size := 20, color := 0xFFF5F0FF, bold := false, align := 1) {
        rect := Buffer(16, 0)
        NumPut("Float", x, "Float", y, "Float", w, "Float", h, rect)
        DllCall("gdiplus\GdipDrawString", "Ptr", this.G, "WStr", text, "Int", -1, "Ptr", this.Font(size, bold), "Ptr", rect, "Ptr", this.SingleLineFormat(align), "Ptr", this.Brush(color))
    }
    Transform(x, y, angle) {
        DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", this.G, "Float", x, "Float", y, "Int", 0)
        DllCall("gdiplus\GdipRotateWorldTransform", "Ptr", this.G, "Float", angle, "Int", 0)
    }
    Clear(color := 0xFF00FF00) {
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", this.G, "UInt", color)
    }
    Rect(x, y, w, h, color) {
        DllCall("gdiplus\GdipFillRectangle", "Ptr", this.G, "Ptr", this.Brush(color), "Float", x, "Float", y, "Float", w, "Float", h)
    }
    RoundRect(x, y, w, h, r, color, border := 0, thick := 1) {
        path := 0
        DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path)
        d := r * 2
        for arc in [[x, y, 180], [x + w - d, y, 270], [x + w - d, y + h - d, 0], [x, y + h - d, 90]]
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path, "Float", arc[1], "Float", arc[2], "Float", d, "Float", d, "Float", arc[3], "Float", 90)
        DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
        DllCall("gdiplus\GdipFillPath", "Ptr", this.G, "Ptr", this.Brush(color), "Ptr", path)
        if border
            DllCall("gdiplus\GdipDrawPath", "Ptr", this.G, "Ptr", this.Pen(border, thick), "Ptr", path)
        DllCall("gdiplus\GdipDeletePath", "Ptr", path)
    }
    Ellipse(x, y, w, h, color, border := 0, thick := 1) {
        if color
            DllCall("gdiplus\GdipFillEllipse", "Ptr", this.G, "Ptr", this.Brush(color), "Float", x, "Float", y, "Float", w, "Float", h)
        if border
            DllCall("gdiplus\GdipDrawEllipse", "Ptr", this.G, "Ptr", this.Pen(border, thick), "Float", x, "Float", y, "Float", w, "Float", h)
    }
    Pie(x, y, w, h, start, sweep, color) {
        DllCall("gdiplus\GdipFillPie", "Ptr", this.G, "Ptr", this.Brush(color), "Float", x, "Float", y, "Float", w, "Float", h, "Float", start, "Float", sweep)
        DllCall("gdiplus\GdipDrawPie", "Ptr", this.G, "Ptr", this.Pen(0xFFB885FA, 1.3), "Float", x, "Float", y, "Float", w, "Float", h, "Float", start, "Float", sweep)
    }
    Polygon(points, color) {
        data := Buffer(points.Length * 8)
        for i, pt in points
            NumPut("Float", pt[1], "Float", pt[2], data, (i - 1) * 8)
        DllCall("gdiplus\GdipFillPolygon", "Ptr", this.G, "Ptr", this.Brush(color), "Ptr", data, "Int", points.Length, "Int", 0)
    }
    Push() {
        state := 0
        DllCall("gdiplus\GdipSaveGraphics", "Ptr", this.G, "UInt*", &state)
        return state
    }
    Pop(state) {
        DllCall("gdiplus\GdipRestoreGraphics", "Ptr", this.G, "UInt", state)
    }
    Clip(x, y, w, h) {
        DllCall("gdiplus\GdipSetClipRect", "Ptr", this.G, "Float", x, "Float", y, "Float", w, "Float", h, "Int", 0)
    }
    ImageAt(image, x, y, w, h) {
        DllCall("gdiplus\GdipDrawImageRect", "Ptr", this.G, "Ptr", image, "Float", x, "Float", y, "Float", w, "Float", h)
    }
    RotateImage(image, angle, cx, cy, w, h) {
        state := this.Push()
        DllCall("gdiplus\GdipTranslateWorldTransform", "Ptr", this.G, "Float", cx, "Float", cy, "Int", 0)
        DllCall("gdiplus\GdipRotateWorldTransform", "Ptr", this.G, "Float", angle, "Int", 0)
        this.ImageAt(image, -w / 2, -h / 2, w, h)
        this.Pop(state)
    }
    CopyFrom(other) {
        this.Flush()
        if !this.DC || !other.DC
            throw Error("Copy requires two display surfaces")
        if !DllCall("gdi32\BitBlt", "Ptr", this.DC, "Int", 0, "Int", 0, "Int", this.W, "Int", this.H, "Ptr", other.DC, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
            throw Error("Frame copy failed")
        DllCall("gdi32\GdiFlush")
    }
    Flush() {
        DllCall("gdiplus\GdipFlush", "Ptr", this.G, "Int", 1)
    }
    Dispose() {
        if this.G {
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", this.G)
            this.G := 0
        }
        for k, b in this.Brushes
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", b)
        this.Brushes.Clear()
        for k, p in this.Pens
            DllCall("gdiplus\GdipDeletePen", "Ptr", p)
        this.Pens.Clear()
        for k, f in this.Fonts
            DllCall("gdiplus\GdipDeleteFont", "Ptr", f)
        this.Fonts.Clear()
        for k, f in this.Formats
            DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", f)
        this.Formats.Clear()
        if this.Family {
            DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", this.Family)
            this.Family := 0
        }
        if this.Image {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", this.Image)
            this.Image := 0
        }
        if this.DC {
            if this.Old
                DllCall("gdi32\SelectObject", "Ptr", this.DC, "Ptr", this.Old)
            if this.Bitmap
                DllCall("gdi32\DeleteObject", "Ptr", this.Bitmap)
            DllCall("gdi32\DeleteDC", "Ptr", this.DC)
            this.DC := 0
            this.Bitmap := 0
            this.Old := 0
        }
    }
}

WrapDisplay(text, width := 16) {
    words := StrSplit(StrReplace(text, "_", " "), " ")
    line := "", out := ""
    for word in words {
        if StrLen(line) + StrLen(word) + 1 > width && line != "" {
            out .= (out = "" ? "" : "`n") line
            line := word
        } else
            line .= (line = "" ? "" : " ") word
    }
    return out . (out = "" ? "" : "`n") . line
}
