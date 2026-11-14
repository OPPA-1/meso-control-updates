#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include Lib\Core.ahk
#Include Lib\PunishmentOptions.ahk
RuntimeDir := A_ScriptDir "\runtime"
DirCreate(RuntimeDir)
if A_Args.Length != 6
    ExitApp(2)
mode := A_Args[1]
target := Integer(A_Args[2])
duration := Max(100, Min(3600000, Integer(A_Args[3])))
amount := mode = "puzzle" ? 1.0 : Float(A_Args[4])
grid := mode = "puzzle" && RegExMatch(A_Args[4], "^[2-5]x[2-6]$") ? StrSplit(A_Args[4], "x") : [2, 3]
PuzzleRows := Integer(grid[1]), PuzzleColumns := Integer(grid[2])
WideThumbnail := 0
WideCursorHidden := false
parent := Integer(A_Args[5])
StatusPath := A_Args[6]
finish := 0
mag := 0
PuzzleMags := []
PuzzleOrder := []
MagLibrary := 0
initialized := false
EffectGui := 0
MirrorDevice := 0
MirrorTarget := 0
MirrorVisual := 0
MirrorSurface := 0
MirrorD3DDevice := 0
MirrorD3DContext := 0
MirrorDXGIDevice := 0
DarkPanel := 0
WorkerClosing := false
LastBounds := ""
LastRect := ""
TimerResolutionActive := false
FrameCount := 0
FrameStatStart := 0
StartupTick := NowMs()
try DllCall("user32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
OnExit(Cleanup)
OnMessage(0x8001, (*) => ExitApp())
OnMessage(0x21, (*) => 3)
try {
    ReportVisual("starting", "Preparing " mode)
    if !ProcessExist(parent) || !WinActive("ahk_id " target) || FileExist(StatusPath ".cancel")
        throw Error("Game is not focused or effect was cancelled")
    WinGetClientPos(&x, &y, &w, &h, "ahk_id " target)
    if w < 100 || h < 100
        throw Error("Game window has no usable client area")
    effectStyle := mode = "mirror" ? "+AlwaysOnTop -Caption +ToolWindow +E0x08000020 +0x02000000 -DPIScale" : "+AlwaysOnTop -Caption +ToolWindow +E0x08080020 +0x02000000 -DPIScale"
    if mode = "wide"
        effectStyle := "+AlwaysOnTop -Caption +ToolWindow +E0x08000020 -DPIScale"
    EffectGui := Gui(effectStyle, mode = "dark" ? "Meso Visual Effect: Darkness" : "Meso Visual Effect")
    EffectGui.BackColor := "000000"
    EffectGui.MarginX := 0
    EffectGui.MarginY := 0
    opacity := 255
    if mode = "wide" || mode = "zoom" || mode = "puzzle" || mode = "drunk" || mode = "mirror" {
        MagLibrary := DllCall("kernel32\LoadLibraryW", "WStr", A_WinDir "\System32\Magnification.dll", "Ptr")
        if !MagLibrary
            throw Error("Windows magnification library could not load")
        initialized := DllCall("Magnification\MagInitialize", "Int")
        if !initialized
            throw Error("Windows magnification initialization failed")
    }
    if mode = "dark" {
        opacity := Round(FixedPunishmentValue({Action: "Lights Out", Value: amount}))
        DarkPanel := EffectGui.AddText("x0 y0 w" w " h" h " Background050208", "")
    } else if mode = "wide" {
        amount := FixedPunishmentValue({Action: "Wide View", Value: amount})
        if DllCall("dwmapi\DwmRegisterThumbnail", "Ptr", EffectGui.Hwnd, "Ptr", target, "Ptr*", &WideThumbnail, "Int") < 0
            throw Error("Game preview could not be created")
    } else if mode = "zoom" || mode = "puzzle" || mode = "drunk" || mode = "mirror" {
        amount := mode = "zoom" ? FixedPunishmentValue({Action: "Tunnel Vision", Value: amount}) : mode = "drunk" ? 1.17 : 1.0
        excluded := Buffer(A_PtrSize, 0)
        NumPut("Ptr", EffectGui.Hwnd, excluded)
        count := mode = "puzzle" ? PuzzleRows * PuzzleColumns : 1
        loop count {
            bounds := mode = "puzzle" ? PuzzleCell(A_Index - 1, w, h) : [0, 0, w, h]
            cellX := bounds[1], cellY := bounds[2]
            tileW := bounds[3] - cellX, tileH := bounds[4] - cellY
            control := DllCall("user32\CreateWindowExW", "UInt", mode = "mirror" ? 0x00080020 : 0x00000020, "WStr", "Magnifier", "WStr", "", "UInt", 0x50000000, "Int", cellX, "Int", cellY, "Int", tileW, "Int", tileH, "Ptr", EffectGui.Hwnd, "Ptr", 0, "Ptr", DllCall("kernel32\GetModuleHandleW", "Ptr", 0, "Ptr"), "Ptr")
            if !control
                throw Error("Windows magnifier control could not be created (" A_LastError ")")
            if mode = "mirror" && !DllCall("user32\SetLayeredWindowAttributes", "Ptr", control, "UInt", 0, "UChar", 255, "UInt", 2, "Int")
                throw Error("Live mirror source transparency initialization failed (" A_LastError ")")
            matrix := Buffer(36, 0)
            NumPut("Float", amount, matrix, 0)
            NumPut("Float", amount, matrix, 16)
            NumPut("Float", 1.0, matrix, 32)
            if !DllCall("Magnification\MagSetWindowTransform", "Ptr", control, "Ptr", matrix, "Int")
                throw Error("Magnifier transform failed (" A_LastError ")")
            if mode = "mirror" {
                if !DllCall("Magnification\MagSetWindowFilterList", "Ptr", control, "UInt", 0, "Int", 1, "Ptr", excluded, "Int")
                    throw Error("Mirror source exclusion failed (" A_LastError ")")
            } else {
                try DllCall("Magnification\MagSetWindowFilterList", "Ptr", control, "UInt", 0, "Int", 1, "Ptr", excluded, "Int")
            }
            if mode = "puzzle"
                PuzzleMags.Push(control)
            else
                mag := control
        }
        if mode = "puzzle" {
            loop count
                PuzzleOrder.Push(A_Index - 1)
            loop count - 1 {
                a := count - A_Index + 1, b := Random(1, a)
                temp := PuzzleOrder[a]
                PuzzleOrder[a] := PuzzleOrder[b]
                PuzzleOrder[b] := temp
            }
            unchanged := true
            for i, value in PuzzleOrder
                if value != i - 1
                    unchanged := false
            if unchanged {
                PuzzleOrder[1] := 1
                PuzzleOrder[2] := 0
            }
        }
    } else
        throw Error("Unknown visual effect")
    if mode != "mirror" && mode != "wide" && !DllCall("user32\SetLayeredWindowAttributes", "Ptr", EffectGui.Hwnd, "UInt", 0, "UChar", opacity, "UInt", 2, "Int")
        throw Error("Visual transparency initialization failed (" A_LastError ")")
    if !WinActive("ahk_id " target) || FileExist(StatusPath ".cancel")
        throw Error("Game lost focus during visual startup")
    EffectGui.Show("NoActivate x" x " y" y " w" w " h" h)
    if mode = "wide" {
        OnMessage(0x20, HideOverlayCursor)
        WideCursorHidden := DllCall("Magnification\MagShowSystemCursor", "Int", false, "Int") != 0
        if !WideCursorHidden
            LogEvent("Wide View could not hide the Windows system cursor")
    }
    if !DllCall("user32\IsWindowVisible", "Ptr", EffectGui.Hwnd, "Int")
        throw Error("Visual overlay window did not become visible")
    finish := NowMs() + duration
    TimerResolutionActive := DllCall("winmm\timeBeginPeriod", "UInt", 1, "UInt") = 0
    UpdateVisualFrame(true)
    if mode = "mirror"
        InitializeLiveMirror(w, h)
    FrameStatStart := PerfNowMs()
    ReportVisual("ready", "Active")
    RunVisualFrames()
} catch as err {
    ReportVisual("error", err.Message)
    try FileAppend(A_NowUTC " | " mode " | " err.Message "`n", RuntimeDir "\visual-errors.log", "UTF-8")
    LogEvent("Visual effect failed: " err.Message)
    ExitApp(4)
}
return

ReportVisual(state, detail := "") {
    global StatusPath, finish
    try WriteAtomic(StatusPath, Line(ProcessExist(), NowMs(), state, detail, finish))
}

HideOverlayCursor(wParam, lParam, msg, hwnd) {
    global EffectGui
    if hwnd = EffectGui.Hwnd {
        DllCall("user32\SetCursor", "Ptr", 0, "Ptr")
        return 1
    }
}

MakeRect(left, top, right, bottom) {
    r := Buffer(16, 0)
    NumPut("Int", left, "Int", top, "Int", right, "Int", bottom, r)
    return r
}

SetVisualSource(control, left, top, right, bottom) {
    rect := MakeRect(left, top, right, bottom)
    if !DllCall("Magnification\MagSetWindowSource", "Ptr", control, "Ptr", rect, "Int")
        throw Error("Visual source unavailable (" A_LastError ")")
}

RunVisualFrames() {
    global mode, WorkerClosing, FrameCount, FrameStatStart
    period := mode = "dark" ? 100.0 : 1000.0 / 60.0
    nextFrame := PerfNowMs()
    while !WorkerClosing {
        Sleep(-1)
        now := PerfNowMs()
        if now >= nextFrame {
            UpdateVisualFrame()
            FrameCount += 1
            if now - FrameStatStart >= 2000 {
                if mode = "drunk" || mode = "mirror"
                    ReportVisual("ready", "Active " Round(FrameCount * 1000.0 / (now - FrameStatStart)) " ticks/s")
                FrameCount := 0
                FrameStatStart := now
            }
            nextFrame += period
            if nextFrame < PerfNowMs() - period
                nextFrame := PerfNowMs() + period
        }
        remaining := nextFrame - PerfNowMs()
        if remaining > 1.5
            DllCall("kernel32\Sleep", "UInt", Min(8, Max(1, Floor(remaining - 0.5))))
    }
}

UpdateVisualFrame(force := false) {
    global mode, target, parent, finish, EffectGui, mag, amount, StatusPath, LastBounds, LastRect
    global WorkerClosing, DarkPanel, PuzzleMags, PuzzleOrder, StartupTick, MirrorVisual, WideThumbnail
    if WorkerClosing
        return
    if NowMs() >= finish || !ProcessExist(parent) || FileExist(StatusPath ".cancel") {
        ReportVisual("stopped", "Finished")
        ExitApp()
    }
    if !WinActive("ahk_id " target) {
        ReportVisual("stopped", "Game lost focus")
        ExitApp()
    }
    try {
        WinGetClientPos(&x, &y, &w, &h, "ahk_id " target)
        if w < 100 || h < 100
            throw Error("Game window has no usable client area")
        bounds := x "|" y "|" w "|" h
        changed := force || bounds != LastBounds
        if mode = "dark"
            DllCall("user32\SetWindowPos", "Ptr", EffectGui.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13, "Int")
        if changed {
            if !DllCall("user32\SetWindowPos", "Ptr", EffectGui.Hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", 0x14, "Int")
                throw Error("Visual overlay position update failed")
            if mode = "mirror" && MirrorVisual
                ResizeLiveMirror(w, h)
            if mag
                DllCall("user32\MoveWindow", "Ptr", mag, "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", 0)
            if WideThumbnail
                ResizeWideThumbnail(WideThumbnail, w, h, amount)
            for i, control in PuzzleMags {
                rect := PuzzleCell(i - 1, w, h)
                DllCall("user32\MoveWindow", "Ptr", control, "Int", rect[1], "Int", rect[2], "Int", rect[3] - rect[1], "Int", rect[4] - rect[2], "Int", 0)
            }
            if IsObject(DarkPanel)
                DarkPanel.Move(0, 0, w, h)
            LastBounds := bounds
        }
        if mag {
            if mode = "drunk" {
                t := (NowMs() - StartupTick) / 1000.0
                rw := Max(1, Round(w / amount)), rh := Max(1, Round(h / amount))
                ox := Round(w * (0.028 * Sin(t * 2.7) + 0.011 * Sin(t * 5.1)))
                oy := Round(h * (0.025 * Cos(t * 2.0) + 0.010 * Sin(t * 4.4)))
                left := x + Floor((w - rw) / 2) + ox
                top := y + Floor((h - rh) / 2) + oy
                rectKey := left "|" top "|" rw "|" rh
                if rectKey != LastRect {
                    SetVisualSource(mag, left, top, left + rw, top + rh)
                    LastRect := rectKey
                }
            } else if changed {
                if mode = "zoom" {
                    rw := Max(1, Round(w / amount)), rh := Max(1, Round(h / amount))
                    left := x + Floor((w - rw) / 2), top := y + Floor((h - rh) / 2)
                    SetVisualSource(mag, left, top, left + rw, top + rh)
                } else
                    SetVisualSource(mag, x, y, x + w, y + h)
            }
        }
        if mode != "dark" && mode != "wide" {
            filters := [EffectGui.Hwnd]
            previousDetect := A_DetectHiddenWindows
            DetectHiddenWindows(true)
            for hwnd in WinGetList("Meso Visual Effect: Darkness ahk_class AutoHotkeyGUI")
                filters.Push(hwnd)
            DetectHiddenWindows(previousDetect)
            filterKey := ""
            for hwnd in filters
                filterKey .= "|" hwnd
            static previousFilter := ""
            if filterKey != previousFilter {
                previousFilter := filterKey
                excluded := Buffer(filters.Length * A_PtrSize, 0)
                for index, hwnd in filters
                    NumPut("Ptr", hwnd, excluded, (index - 1) * A_PtrSize)
                for control in (mag ? [mag] : PuzzleMags)
                    try DllCall("Magnification\MagSetWindowFilterList", "Ptr", control, "UInt", 0, "Int", filters.Length, "Ptr", excluded, "Int")
            }
        }
        if changed {
            for i, control in PuzzleMags {
                rect := PuzzleCell(PuzzleOrder[i], w, h)
                SetVisualSource(control, x + rect[1], y + rect[2], x + rect[3], y + rect[4])
            }
        }
        if mag
            DllCall("user32\InvalidateRect", "Ptr", mag, "Ptr", 0, "Int", 0)
        for control in PuzzleMags
            DllCall("user32\InvalidateRect", "Ptr", control, "Ptr", 0, "Int", 0)
    } catch as err {
        ReportVisual("error", err.Message)
        try FileAppend(A_NowUTC " | " mode " | " err.Message "`n", A_ScriptDir "\runtime\visual-errors.log", "UTF-8")
        LogEvent("Visual effect stopped: " err.Message)
        ExitApp(5)
    }
}

PuzzleCell(index, w, h) {
    global PuzzleRows, PuzzleColumns
    row := index // PuzzleColumns, col := Mod(index, PuzzleColumns)
    return [Floor(w * col / PuzzleColumns), Floor(h * row / PuzzleRows),
        Floor(w * (col + 1) / PuzzleColumns), Floor(h * (row + 1) / PuzzleRows)]
}

ResizeWideThumbnail(thumbnail, w, h, scale) {
    sw := Round(w * scale), sh := Round(h * scale)
    x := Floor((w - sw) / 2), y := Floor((h - sh) / 2)
    props := Buffer(48, 0)
    NumPut("UInt", 0x19, "Int", x, "Int", y, "Int", x + sw, "Int", y + sh, props)
    NumPut("Int", 1, "Int", 1, props, 40)
    if DllCall("dwmapi\DwmUpdateThumbnailProperties", "Ptr", thumbnail, "Ptr", props, "Int") < 0
        throw Error("Game preview could not be resized")
}

DCompInvoke(interfacePtr, index, args*) {
    if !interfacePtr
        throw Error("DirectComposition interface is not available")
    vtable := NumGet(interfacePtr, "Ptr")
    method := NumGet(vtable, index * A_PtrSize, "Ptr")
    if !method
        throw Error("DirectComposition method " index " is unavailable")
    callArgs := [method, "Ptr", interfacePtr]
    for arg in args
        callArgs.Push(arg)
    callArgs.Push("Int")
    return DllCall(callArgs*)
}

MirrorCheck(hr, operation) {
    if hr < 0
        throw Error(operation " failed (" Format("0x{:08X}", hr & 0xFFFFFFFF) ")")
}

MirrorGuid(text) {
    guid := Buffer(16, 0)
    MirrorCheck(DllCall("ole32\CLSIDFromString", "WStr", text, "Ptr", guid.Ptr, "Int"), "GUID initialization")
    return guid
}

InitializeLiveMirror(w, h) {
    global EffectGui, MirrorDevice, MirrorTarget, MirrorVisual, MirrorSurface
    global MirrorD3DDevice, MirrorD3DContext, MirrorDXGIDevice, mag
    if !mag
        throw Error("Layered magnifier child is missing")
    sourceStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", mag, "Int", -20, "Ptr")
    if !(sourceStyle & 0x00080000)
        throw Error("Layered magnifier child is unavailable")
    outputStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", EffectGui.Hwnd, "Int", -20, "Ptr")
    if outputStyle & 0x00080000
        throw Error("Composition host must be non-layered")
    hr := DllCall("d3d11\D3D11CreateDevice", "Ptr", 0, "UInt", 1, "Ptr", 0, "UInt", 0x20, "Ptr", 0, "UInt", 0, "UInt", 7, "Ptr*", &MirrorD3DDevice, "Ptr", 0, "Ptr*", &MirrorD3DContext, "Int")
    if hr < 0
        hr := DllCall("d3d11\D3D11CreateDevice", "Ptr", 0, "UInt", 5, "Ptr", 0, "UInt", 0x20, "Ptr", 0, "UInt", 0, "UInt", 7, "Ptr*", &MirrorD3DDevice, "Ptr", 0, "Ptr*", &MirrorD3DContext, "Int")
    MirrorCheck(hr, "Direct3D device initialization")
    iidDXGI := MirrorGuid("{54ec77fa-1377-44e6-8c32-88fd5f44c84c}")
    MirrorCheck(DCompInvoke(MirrorD3DDevice, 0, "Ptr", iidDXGI.Ptr, "Ptr*", &MirrorDXGIDevice), "Direct3D graphics interface")
    iidDComp := MirrorGuid("{C37EA93A-E7AA-450D-B16F-9746CB0407F3}")
    MirrorCheck(DllCall("dcomp\DCompositionCreateDevice2", "Ptr", MirrorDXGIDevice, "Ptr", iidDComp.Ptr, "Ptr*", &MirrorDevice, "Int"), "DirectComposition initialization")
    MirrorCheck(DCompInvoke(MirrorDevice, 6, "Ptr", EffectGui.Hwnd, "Int", 1, "Ptr*", &MirrorTarget), "Composition window target")
    MirrorCheck(DCompInvoke(MirrorDevice, 7, "Ptr*", &MirrorVisual), "Composition visual")
    MirrorCheck(DCompInvoke(MirrorDevice, 11, "Ptr", mag, "Ptr*", &MirrorSurface), "Layered magnifier surface")
    MirrorCheck(DCompInvoke(MirrorVisual, 15, "Ptr", MirrorSurface), "Live magnifier content")
    ResizeLiveMirror(w, h, false)
    MirrorCheck(DCompInvoke(MirrorTarget, 3, "Ptr", MirrorVisual), "Composition root")
    cloaked := Buffer(4, 0)
    NumPut("Int", 1, cloaked)
    MirrorCheck(DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", mag, "UInt", 14, "Ptr", cloaked.Ptr, "UInt", 4, "Int"), "Layered magnifier cloaking")
    MirrorCheck(DCompInvoke(MirrorDevice, 3), "Live horizontal mirror commit")
}

ResizeLiveMirror(w, h, commit := true) {
    global MirrorDevice, MirrorVisual
    if !MirrorVisual
        return
    matrix := Buffer(24, 0)
    NumPut("Float", -1.0, "Float", 0.0, "Float", 0.0, "Float", 1.0, "Float", Float(w), "Float", 0.0, matrix)
    MirrorCheck(DCompInvoke(MirrorVisual, 7, "Ptr", matrix.Ptr), "Horizontal reflection transform")
    if commit
        MirrorCheck(DCompInvoke(MirrorDevice, 3), "Horizontal reflection resize")
}

ReleaseMirrorInterface(&interfacePtr) {
    if interfacePtr {
        ptr := interfacePtr
        interfacePtr := 0
        try DCompInvoke(ptr, 2)
    }
}

Cleanup(*) {
    global EffectGui, MirrorDevice, MirrorTarget, MirrorVisual, MirrorSurface
    global MirrorD3DDevice, MirrorD3DContext, MirrorDXGIDevice
    global initialized, MagLibrary, WorkerClosing, StatusPath, mag, DarkPanel, PuzzleMags, PuzzleOrder, TimerResolutionActive, WideThumbnail, WideCursorHidden
    if WorkerClosing
        return
    WorkerClosing := true
    if WideCursorHidden {
        try DllCall("Magnification\MagShowSystemCursor", "Int", true, "Int")
        WideCursorHidden := false
    }
    if WideThumbnail
        try DllCall("dwmapi\DwmUnregisterThumbnail", "Ptr", WideThumbnail, "Int")
    ReleaseMirrorInterface(&MirrorSurface)
    ReleaseMirrorInterface(&MirrorVisual)
    ReleaseMirrorInterface(&MirrorTarget)
    ReleaseMirrorInterface(&MirrorDevice)
    ReleaseMirrorInterface(&MirrorDXGIDevice)
    ReleaseMirrorInterface(&MirrorD3DContext)
    ReleaseMirrorInterface(&MirrorD3DDevice)
    if GuiHwndSafe(EffectGui)
        try EffectGui.Destroy()
    EffectGui := 0
    DarkPanel := 0
    mag := 0
    PuzzleMags := []
    PuzzleOrder := []
    if initialized {
        initialized := false
        try DllCall("Magnification\MagUninitialize", "Int")
    }
    if MagLibrary {
        handle := MagLibrary
        MagLibrary := 0
        DllCall("kernel32\FreeLibrary", "Ptr", handle)
    }
    if TimerResolutionActive {
        TimerResolutionActive := false
        DllCall("winmm\timeEndPeriod", "UInt", 1, "UInt")
    }
    try FileDelete(StatusPath ".cancel")
}
