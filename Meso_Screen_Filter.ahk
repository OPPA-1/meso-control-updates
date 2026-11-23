#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include Lib\Core.ahk
#Include Lib\PunishmentOptions.ahk
#Include Lib\ScreenFilter.ahk
#Include Lib\VisualCursor.ahk
RuntimeDir := A_ScriptDir "\runtime"
DirCreate(RuntimeDir)
if A_Args.Length != 6 || (A_Args[1] != "blur" && A_Args[1] != "split")
    ExitApp(2)
Mode := A_Args[1], Target := Integer(A_Args[2]), ParentPid := Integer(A_Args[5]), StatusPath := A_Args[6]
Amount := FixedPunishmentValue({Action: "Hazy Vision", Value: Float(A_Args[4])})
Duration := Max(100, Min(3600000, Integer(A_Args[3]))), Finish := NowMs()+Duration
Host := 0, Mag := 0, Device := 0, Device3 := 0, CompositionTarget := 0, Visual := 0, Content := 0, Blur := 0
Initialized := false, CursorHidden := false, Closing := false, LastBounds := "", Frame := 0, MagLibrary := 0
CursorOwner := {}
OnExit(FilterCleanup)
OnMessage(0x8001, (*) => ExitApp())
OnMessage(0x21, (*) => 3)
try {
    DllCall("user32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    FilterReport("starting", "Preparing live screen")
    if !ProcessExist(ParentPid) || !WinActive("ahk_id " Target) || FileExist(StatusPath ".cancel")
        throw Error("Game is not focused or effect was cancelled")
    MagLibrary := DllCall("kernel32\LoadLibraryW", "WStr", A_WinDir "\System32\Magnification.dll", "Ptr")
    if !MagLibrary
        throw Error("Windows magnification library could not load")
    Initialized := DllCall("Magnification\MagInitialize", "Int") != 0
    if !Initialized
        throw Error("Windows magnification could not start")
    WinGetClientPos(&x, &y, &w, &h, "ahk_id " Target)
    bounds := ScreenFilterBounds(Mode, x, y, w, h)
    Host := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020 +0x02000000 -DPIScale", "Meso Screen Filter")
    Host.BackColor := "000000"
    Mag := DllCall("user32\CreateWindowExW", "UInt", 0x00080020, "WStr", "Magnifier", "WStr", "", "UInt", 0x50000000,
        "Int", 0, "Int", 0, "Int", bounds.W, "Int", h, "Ptr", Host.Hwnd, "Ptr", 0,
        "Ptr", DllCall("kernel32\GetModuleHandleW", "Ptr", 0, "Ptr"), "Ptr", 0, "Ptr")
    if !Mag || !DllCall("user32\SetLayeredWindowAttributes", "Ptr", Mag, "UInt", 0, "UChar", 255, "UInt", 2, "Int")
        throw Error("Live screen source could not start")
    matrix := Buffer(36, 0)
    NumPut("Float", 1, matrix, 0), NumPut("Float", 1, matrix, 16), NumPut("Float", 1, matrix, 32)
    if !DllCall("Magnification\MagSetWindowTransform", "Ptr", Mag, "Ptr", matrix, "Int")
        throw Error("Live screen transform could not start")
    Host.Show("NA x" x " y" y " w" bounds.W " h" h)
    iid := ScreenFilterGuid("{C37EA93A-E7AA-450D-B16F-9746CB0407F3}")
    factory := Mode = "blur" ? "dcomp\DCompositionCreateDevice3" : "dcomp\DCompositionCreateDevice2"
    ScreenFilterCheck(DllCall(factory, "Ptr", 0, "Ptr", iid, "Ptr*", &Device, "Int"), "Screen composition")
    ScreenFilterCheck(ScreenFilterCall(Device, 6, "Ptr", Host.Hwnd, "Int", 1, "Ptr*", &CompositionTarget), "Screen target")
    ScreenFilterCheck(ScreenFilterCall(Device, 7, "Ptr*", &Visual), "Screen visual")
    ScreenFilterCheck(ScreenFilterCall(Device, 11, "Ptr", Mag, "Ptr*", &Content), "Live screen surface")
    ScreenFilterCheck(ScreenFilterCall(Visual, 15, "Ptr", Content), "Live screen content")
    if Mode = "blur" {
        iid3 := ScreenFilterGuid("{0987CB06-F916-48BF-8D35-CE7641781BD9}")
        ScreenFilterCheck(ScreenFilterCall(Device, 0, "Ptr", iid3, "Ptr*", &Device3), "Blur device")
        ScreenFilterCheck(ScreenFilterCall(Device3, 24, "Ptr*", &Blur), "Gaussian blur")
        ; The float overload follows the animation overload in the Windows COM ABI.
        ScreenFilterCheck(ScreenFilterCall(Blur, 5, "Float", Amount), "Blur strength")
        ScreenFilterCheck(ScreenFilterCall(Blur, 6, "Int", 1), "Blur border")
        ScreenFilterCheck(ScreenFilterCall(Blur, 3, "UInt", 0, "Ptr", 0, "UInt", 0), "Blur input")
        ScreenFilterCheck(ScreenFilterCall(Visual, 10, "Ptr", Blur), "Blur visual")
    }
    ScreenFilterCheck(ScreenFilterCall(CompositionTarget, 3, "Ptr", Visual), "Screen root")
    CursorHidden := HideVisualCursor(CursorOwner)
    FilterFrame()
    ScreenFilterCheck(ScreenFilterCall(Device, 3), "Screen commit")
    FilterReport("ready", "Active")
    SetTimer(FilterFrame, 16)
} catch as err {
    FilterReport("error", err.Message)
    LogEvent("Screen filter: " err.Message)
    ExitApp(4)
}
return

FilterFrame() {
    global Mode, Target, ParentPid, StatusPath, Finish, Host, Mag, Device, Visual, LastBounds, Closing, Frame, CursorOwner
    if Closing
        return
    if NowMs() >= Finish || !ProcessExist(ParentPid) || FileExist(StatusPath ".cancel") || !WinActive("ahk_id " Target) {
        FilterReport("stopped", "Finished")
        ExitApp()
    }
    try {
        MaintainVisualCursor(CursorOwner)
        WinGetClientPos(&x, &y, &w, &h, "ahk_id " Target)
        if w < 100 || h < 100
            throw Error("Game window has no usable client area")
        b := ScreenFilterBounds(Mode, x, y, w, h)
        key := x "|" y "|" w "|" h
        if key != LastBounds {
            if !DllCall("user32\SetWindowPos", "Ptr", Host.Hwnd, "Ptr", 0, "Int", b.X, "Int", b.Y, "Int", b.W, "Int", b.H, "UInt", 0x14, "Int")
                throw Error("Screen filter could not move")
            DllCall("user32\MoveWindow", "Ptr", Mag, "Int", 0, "Int", 0, "Int", b.W, "Int", b.H, "Int", 0)
            if Mode = "split" {
                transform := Buffer(24, 0)
                NumPut("Float", -1, "Float", 0, "Float", 0, "Float", 1, "Float", Float(b.W), "Float", 0, transform)
                ScreenFilterCheck(ScreenFilterCall(Visual, 8, "Ptr", transform), "Half-screen reflection")
            }
            rect := Buffer(16, 0)
            NumPut("Int", b.SourceX, "Int", b.SourceY, "Int", b.SourceX+b.W, "Int", b.SourceY+b.H, rect)
            excluded := Buffer(A_PtrSize, 0)
            NumPut("Ptr", Host.Hwnd, excluded)
            if !DllCall("Magnification\MagSetWindowFilterList", "Ptr", Mag, "UInt", 0, "Int", 1, "Ptr", excluded, "Int")
                throw Error("Screen filter source exclusion failed")
            if !DllCall("Magnification\MagSetWindowSource", "Ptr", Mag, "Ptr", rect, "Int")
                throw Error("Live screen source unavailable")
            ScreenFilterCheck(ScreenFilterCall(Device, 3), "Screen resize")
            LastBounds := key
        }
        DllCall("user32\InvalidateRect", "Ptr", Mag, "Ptr", 0, "Int", false)
        Frame += 1
        if Mod(Frame, 60) = 0
            FilterReport("ready", "Active")
    } catch as err {
        FilterReport("error", err.Message)
        LogEvent("Screen filter: " err.Message)
        ExitApp(5)
    }
}

FilterReport(state, note) {
    global StatusPath, Finish
    try WriteAtomic(StatusPath, Line(ProcessExist(), NowMs(), state, note, Finish))
}

FilterCleanup(*) {
    global Closing, Host, Mag, Initialized, CursorHidden, Blur, Visual, Content, CompositionTarget, Device3, Device, StatusPath, MagLibrary, CursorOwner
    if Closing
        return
    Closing := true
    SetTimer(FilterFrame, 0)
    if CursorHidden
        try RestoreVisualCursor(CursorOwner)
    ScreenFilterRelease(&Blur)
    ScreenFilterRelease(&Visual)
    ScreenFilterRelease(&Content)
    ScreenFilterRelease(&CompositionTarget)
    ScreenFilterRelease(&Device3)
    ScreenFilterRelease(&Device)
    if GuiHwndSafe(Host)
        Host.Destroy()
    if Initialized
        DllCall("Magnification\MagUninitialize", "Int")
    if MagLibrary
        DllCall("kernel32\FreeLibrary", "Ptr", MagLibrary)
    try FileDelete(StatusPath ".cancel")
}
