
UpdateInteractionPointer(owner, center := false) {
    if !owner.HasOwnProp("Pointer") {
        token := GdipStart()
        owner.Pointer := {Token: token, Gui: 0, Canvas: 0}
        try {
            p := owner.Pointer
            p.Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08080020 -DPIScale", "Meso Pointer")
            p.Canvas := Surface(72, 72)
            p.Canvas.Clear(0)
            p.Canvas.Ellipse(7, 7, 50, 50, 0x3321EAC2, 0xDDA4FFDB, 2)
            p.Canvas.Polygon([[29, 23], [29, 60], [39, 49], [47, 65], [54, 61], [46, 46], [60, 45]], 0xFF140C22)
            p.Canvas.Polygon([[31, 27], [31, 55], [39, 44], [48, 61], [50, 60], [42, 43], [55, 43]], 0xFFFFFFFF)
            p.Canvas.Flush()
        } catch as err {
            CloseInteractionPointer(owner)
            throw err
        }
    }
    point := Buffer(8, 0)
    DllCall("user32\GetCursorPos", "Ptr", point)
    x := NumGet(point, 0, "Int"), y := NumGet(point, 4, "Int")
    if center && owner.HasOwnProp("Target") {
        WinGetClientPos(&gx, &gy, &gw, &gh, "ahk_id " owner.Target)
        x := gx + gw//2, y := gy + gh//2 + 140
        DllCall("user32\SetCursorPos", "Int", x, "Int", y)
    }
    p := owner.Pointer
    destination := Buffer(8, 0), size := Buffer(8, 0), origin := Buffer(8, 0), blend := Buffer(4, 0)
    NumPut("Int", x - 31, "Int", y - 27, destination)
    NumPut("Int", 72, "Int", 72, size)
    NumPut("UChar", 255, "UChar", 1, blend, 2)
    DllCall("user32\UpdateLayeredWindow", "Ptr", p.Gui.Hwnd, "Ptr", 0, "Ptr", destination, "Ptr", size,
        "Ptr", p.Canvas.DC, "Ptr", origin, "UInt", 0, "Ptr", blend, "UInt", 2)
    p.Gui.Show("NA")
}
CloseInteractionPointer(owner) {
    if !owner.HasOwnProp("Pointer")
        return
    p := owner.Pointer
    if GuiHwndSafe(p.Gui)
        p.Gui.Destroy()
    if IsObject(p.Canvas)
        p.Canvas.Dispose()
    GdipStop(&p.Token)
    owner.DeleteProp("Pointer")
}
