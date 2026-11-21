
#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include Lib\Core.ahk
#Include Lib\InteractionGuard.ahk
#Include Lib\PuzzleModel.ahk
#Include Lib\Draw.ahk
#Include Lib\InteractionPointer.ahk
RuntimeDir := A_ScriptDir "\runtime"
DirCreate(RuntimeDir)
if A_Args.Length != 4
    ExitApp(2)
Target := Integer(A_Args[1]), GridSize := Integer(A_Args[2]), ParentPid := Integer(A_Args[3]), StatusPath := A_Args[4]
PuzzleGui := 0, Tiles := [], Header := 0, BlankLabel := 0, GapIcons := [], Guard := 0, Drag := 0, Animation := 0
Moves := 0, Finished := false, Hook := 0, HookProc := 0, Mods := Map(), PointerOwner := {Target: Target}
Board := PuzzleShuffle(GridSize = 4 ? 4 : 3)
GridSize := GridSize = 4 ? 4 : 3
Blank := 0
for i, tile in Board
    if !tile
        Blank := i
PreviousClip := Buffer(16, 0)
DllCall("user32\GetClipCursor", "Ptr", PreviousClip)
OnExit(PuzzleCleanup)
OnError(PuzzleFatal)
try {
    DllCall("user32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
    if !ProcessExist(ParentPid) || !WinActive("ahk_id " Target)
        throw Error("Game is not focused")
    WinGetClientPos(&GX, &GY, &GW, &GH, "ahk_id " Target)
    if GW < 300 || GH < 300
        throw Error("Game window is too small")
    PuzzleGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "Meso Sliding Puzzle")
    PuzzleGui.BackColor := "160F20"
    PuzzleGui.MarginX := 0, PuzzleGui.MarginY := 0
    PuzzleGui.SetFont("s11 Bold cBD8CF4", "Segoe UI")
    Header := PuzzleGui.AddText("x12 y8 w" (GW-24) " h28 Center Background160F20", "SLIDING PUZZLE · Drag tiles into the gap")
    PuzzleGui.SetFont("s14 Bold cBD8CF4", "Segoe UI")
    BlankLabel := PuzzleGui.AddText("x0 y0 w1 h1 Center +0x200 Background241733", "SLIDE HERE")
    loop 2
        GapIcons.Push(PuzzleGui.AddPicture("x0 y0 w1 h1", A_ScriptDir "\Meso_Icon.png"))
    loop GridSize*GridSize-1 {
        thumbnail := 0
        if DllCall("dwmapi\DwmRegisterThumbnail", "Ptr", PuzzleGui.Hwnd, "Ptr", Target, "Ptr*", &thumbnail, "Int") < 0
            throw Error("Game preview could not be created")
        Tiles.Push({Thumbnail: thumbnail})
    }
    OnMessage(0x201, PuzzleMouseDown)
    OnMessage(0x202, PuzzleMouseUp)
    PuzzleGui.OnEvent("Close", (*) => ExitApp())
    PuzzleGui.Show("x" GX " y" GY " w" GW " h" GH)
    WinActivate("ahk_id " PuzzleGui.Hwnd)
    Guard := InteractionGuard(PuzzleGui.Hwnd, (*) => (RequestInteractionEmergency(), ExitApp()), true, ParentPid)
    UpdateInteractionPointer(PointerOwner, true)
    RenderPuzzle(NowMs())
    PuzzleReport("ready", Moves)
    SetTimer(PuzzleTick, 15)
} catch as err {
    Finished := true
    PuzzleReport("error", err.Message)
    LogEvent("Sliding Puzzle: " err.Message)
    ExitApp(1)
}
return
PuzzleCellRect(cell) {
    global GridSize, GW, GH
    col := Mod(cell-1, GridSize), row := (cell-1)//GridSize
    top := 46, height := GH-top
    x := Round(col*GW/GridSize), y := top + Round(row*height/GridSize)
    return {X: x, Y: y, W: Round((col+1)*GW/GridSize)-x, H: top+Round((row+1)*height/GridSize)-y}
}
RenderPuzzle(now) {
    global Board, Tiles, GridSize, GW, GH, Blank, BlankLabel, GapIcons, Animation, Drag
    blankRect := PuzzleCellRect(Blank)
    ; Move the gap controls only when the blank changes, then erase the old static-control pixels.
    if !BlankLabel.HasOwnProp("Cell") || BlankLabel.Cell != Blank {
        BlankLabel.Move(blankRect.X+3, blankRect.Y+3, blankRect.W-6, blankRect.H-6)
        iconSize := Max(24, Min(54, Round(Min(blankRect.W,blankRect.H)*0.20)))
        GapIcons[1].Move(blankRect.X+blankRect.W-iconSize-14, blankRect.Y+14, iconSize,iconSize)
        GapIcons[2].Move(blankRect.X+14, blankRect.Y+blankRect.H-iconSize-14, iconSize,iconSize)
        BlankLabel.Cell := Blank
        DllCall("user32\RedrawWindow","Ptr",BlankLabel.Gui.Hwnd,"Ptr",0,"Ptr",0,"UInt",0x185)
    }
    for index, id in Board {
        if !id
            continue
        r := PuzzleCellRect(index)
        if IsObject(Animation) && Animation.Id = id {
            amount := Min(1, Max(0, (now - Animation.Start)/160))
            eased := 1-(1-amount)**3
            r.X := Round(Animation.X + (r.X-Animation.X)*eased)
            r.Y := Round(Animation.Y + (r.Y-Animation.Y)*eased)
        } else if IsObject(Drag) && Drag.Id = id {
            r.X := Round(r.X + Drag.DX), r.Y := Round(r.Y + Drag.DY)
        }
        sourceIndex := id-1, col := Mod(sourceIndex, GridSize), row := sourceIndex//GridSize
        props := Buffer(48, 0)
        NumPut("UInt", 0x1F, props)
        NumPut("Int", r.X+3, "Int", r.Y+3, "Int", r.X+r.W-3, "Int", r.Y+r.H-3, props, 4)
        NumPut("Int", Round(col*GW/GridSize), "Int", Round(row*GH/GridSize), "Int", Round((col+1)*GW/GridSize), "Int", Round((row+1)*GH/GridSize), props, 20)
        NumPut("UChar", 255, props, 36)
        NumPut("Int", true, "Int", true, props, 40)
        if DllCall("dwmapi\DwmUpdateThumbnailProperties", "Ptr", Tiles[id].Thumbnail, "Ptr", props, "Int") < 0
            throw Error("Could not refresh puzzle tile")
    }
}
PuzzleTick() {
    global Target, ParentPid, PuzzleGui, Finished, StatusPath, Drag, Animation, Moves, Header, Board, PointerOwner
    try {
        if !ProcessExist(ParentPid) || !WinExist("ahk_id " Target) || FileExist(StatusPath ".cancel")
            ExitApp()
        if !WinActive("ahk_id " PuzzleGui.Hwnd)
            return ; The interaction guard restores foreground; a drag never cancels the board.
        now := NowMs()
        if IsObject(Animation) && now >= Animation.Start+160 {
            Animation := 0
            if PuzzleSolved(Board) {
                Finished := true
                PuzzleReport("solved", Moves)
                Header.Text := "PUZZLE SOLVED"
                SetTimer((*) => ExitApp(), -250)
                return
            }
        }
        if IsObject(Drag) {
            if !GetKeyState("LButton", "P")
                PuzzleMouseUp()
            else {
                point := Buffer(8, 0)
                DllCall("user32\GetCursorPos", "Ptr", point)
                dx := NumGet(point, 0, "Int")-Drag.MouseX, dy := NumGet(point, 4, "Int")-Drag.MouseY
                Drag.DX := Drag.ToX ? Min(Abs(Drag.ToX), Max(0, dx*(Drag.ToX>0 ? 1 : -1)))*(Drag.ToX>0 ? 1 : -1) : 0
                Drag.DY := Drag.ToY ? Min(Abs(Drag.ToY), Max(0, dy*(Drag.ToY>0 ? 1 : -1)))*(Drag.ToY>0 ? 1 : -1) : 0
            }
        }
        UpdateInteractionPointer(PointerOwner)
        RenderPuzzle(now)
    } catch as err {
        Finished := true
        PuzzleReport("error", err.Message)
        LogEvent("Sliding Puzzle: " err.Message " (" err.Line ")")
        ExitApp(1)
    }
}
PuzzleMouseDown(wParam, lParam, msg, hwnd) {
    global PuzzleGui, GridSize, Board, Blank, Drag, Animation, GX, GY, Finished
    if Finished || IsObject(Animation) || !WinActive("ahk_id " PuzzleGui.Hwnd)
        return
    point := Buffer(8, 0)
    DllCall("user32\GetCursorPos", "Ptr", point)
    x := NumGet(point, 0, "Int"), y := NumGet(point, 4, "Int")
    for index, id in Board {
        r := PuzzleCellRect(index)
        if id && x>=GX+r.X && x<GX+r.X+r.W && y>=GY+r.Y && y<GY+r.Y+r.H && PuzzleAdjacent(index, Blank, GridSize) {
            to := PuzzleCellRect(Blank)
            Drag := {Id: id, Cell: index, MouseX: x, MouseY: y, DX: 0, DY: 0, ToX: to.X-r.X, ToY: to.Y-r.Y}
            DllCall("user32\SetCapture", "Ptr", PuzzleGui.Hwnd)
            return 0
        }
    }
}
PuzzleMouseUp(*) {
    global Drag, Board, Blank, Animation, Moves, Header
    if !IsObject(Drag)
        return
    d := Drag, Drag := 0
    DllCall("user32\ReleaseCapture")
    origin := PuzzleCellRect(d.Cell)
    distance := Abs(d.DX)+Abs(d.DY), full := Abs(d.ToX)+Abs(d.ToY)
    if distance >= full*0.18 || distance < 5 {
        Board[Blank] := d.Id, Board[d.Cell] := 0
        Blank := d.Cell
        Moves += 1
        Header.Text := "SLIDING PUZZLE · " Moves " moves"
        PuzzleReport("ready", Moves)
    }
    Animation := {Id: d.Id, Start: NowMs(), X: origin.X+d.DX, Y: origin.Y+d.DY}
}
PuzzleReport(phase, note) {
    global StatusPath, PuzzleGui, Board
    WriteAtomic(StatusPath ".board", Line(Board*))
    WriteAtomic(StatusPath, Line(ProcessExist(), NowMs(), phase, note, GuiHwndSafe(PuzzleGui)))
}
PuzzleCleanup(*) {
    global Hook, HookProc, Tiles, PuzzleGui, Finished, PointerOwner, Target, PreviousClip, Guard
    SetTimer(PuzzleTick, 0)
    if IsObject(Guard)
        Guard.Close()
    if Hook
        DllCall("user32\UnhookWindowsHookEx", "Ptr", Hook)
    if HookProc
        CallbackFree(HookProc)
    CloseInteractionPointer(PointerOwner)
    for tile in Tiles
        DllCall("dwmapi\DwmUnregisterThumbnail", "Ptr", tile.Thumbnail)
    focused := GuiHwndSafe(PuzzleGui) && WinActive("ahk_id " PuzzleGui.Hwnd)
    if GuiHwndSafe(PuzzleGui)
        PuzzleGui.Destroy()
    if !Finished
        try PuzzleReport("stopped", "Puzzle interrupted")
    if focused && WinExist("ahk_id " Target) {
        try WinActivate("ahk_id " Target)
    }
}

PuzzleFatal(err, mode) {
    global Finished
    Finished := true
    try PuzzleReport("error",err.Message)
    try LogEvent("Sliding Puzzle: " err.Message " (" err.Line ")")
    ExitApp(1)
}
