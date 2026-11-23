CreatePuzzleBadges(owner, imagePath := "") {
    token := GdipStart(), image := 0
    badges := {Token: token, Image: 0, Items: []}
    try {
        if DllCall("gdiplus\GdipLoadImageFromFile", "WStr", imagePath != "" ? imagePath : A_ScriptDir "\Meso_Icon.png", "Ptr*", &image, "Int") || !image
            throw Error("The Meso puzzle icon could not load")
        badges.Image := image
        loop 2 {
            g := Gui("+Owner" owner " +AlwaysOnTop -Caption +ToolWindow +E0x08080020 -DPIScale", "Meso Puzzle Badge")
            badges.Items.Push({Gui: g, Canvas: 0, Size: 0})
        }
        return badges
    } catch as err {
        ClosePuzzleBadges(badges)
        throw err
    }
}

PositionPuzzleBadges(badges, x, y, w, h) {
    size := Max(24, Min(54, Round(Min(w, h)*0.20)))
    points := [[x+w-size-14, y+14], [x+14, y+h-size-14]]
    for i, item in badges.Items {
        if item.Size != size {
            if IsObject(item.Canvas)
                item.Canvas.Dispose()
            item.Canvas := Surface(size, size)
            item.Canvas.Clear(0)
            item.Canvas.ImageAt(badges.Image, 1, 1, size-2, size-2)
            item.Canvas.Flush()
            item.Size := size
        }
        destination := Buffer(8, 0), dimensions := Buffer(8, 0), origin := Buffer(8, 0), blend := Buffer(4, 0)
        NumPut("Int", points[i][1], "Int", points[i][2], destination)
        NumPut("Int", size, "Int", size, dimensions)
        NumPut("UChar", 255, "UChar", 1, blend, 2)
        if !DllCall("user32\UpdateLayeredWindow", "Ptr", item.Gui.Hwnd, "Ptr", 0, "Ptr", destination,
            "Ptr", dimensions, "Ptr", item.Canvas.DC, "Ptr", origin, "UInt", 0, "Ptr", blend, "UInt", 2, "Int")
            throw Error("The Meso puzzle badge could not be drawn")
        item.Gui.Show("NA x" points[i][1] " y" points[i][2] " w" size " h" size)
    }
}

ClosePuzzleBadges(badges) {
    if !IsObject(badges) || !badges.HasOwnProp("Items")
        return
    for item in badges.Items {
        if GuiHwndSafe(item.Gui)
            item.Gui.Destroy()
        if IsObject(item.Canvas)
            item.Canvas.Dispose()
    }
    badges.Items := []
    if badges.Image
        DllCall("gdiplus\GdipDisposeImage", "Ptr", badges.Image)
    badges.Image := 0
    token := badges.Token
    GdipStop(&token)
    badges.Token := 0
}
