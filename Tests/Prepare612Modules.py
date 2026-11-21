exec((__import__('pathlib').Path('Tests/Prepare612Core.py').read_text()).split("edit('Lib/Sensitivity.ahk'")[0])
write('Lib/PuzzleModel.ahk',r'''
SlidingPuzzleGrid(value) {
    return value = "4x4" ? "4x4" : "3x3"
}
PuzzleNeighbors(index, n) {
    out := [], row := (index - 1)//n, col := Mod(index - 1, n)
    if row > 0
        out.Push(index - n)
    if row < n - 1
        out.Push(index + n)
    if col > 0
        out.Push(index - 1)
    if col < n - 1
        out.Push(index + 1)
    return out
}
PuzzleAdjacent(a, b, n) {
    return Abs((a - 1)//n - (b - 1)//n) + Abs(Mod(a - 1, n) - Mod(b - 1, n)) = 1
}
PuzzleSolved(board) {
    for index, tile in board
        if tile != (index = board.Length ? 0 : index)
            return false
    return true
}
PuzzleShuffle(n) {
    board := []
    loop n*n
        board.Push(A_Index = n*n ? 0 : A_Index)
    blank := n*n, previous := 0
    loop n*n*12 {
        choices := []
        for neighbor in PuzzleNeighbors(blank, n)
            if neighbor != previous
                choices.Push(neighbor)
        next := choices[Random(1, choices.Length)]
        board[blank] := board[next], board[next] := 0
        previous := blank, blank := next
    }
    if PuzzleSolved(board) {
        next := PuzzleNeighbors(blank, n)[1]
        board[blank] := board[next], board[next] := 0
    }
    return board
}
''')
write('Lib/SlidingPuzzle.ahk',r'''
StartSlidingPuzzle(item, now) {
    global RuntimeDir
    item.PuzzleFile := RuntimeDir "\puzzle-" NewId() ".state"
    item.PuzzleReady := false
    item.PuzzlePid := 0
    item.PuzzleUntil := now + 8000
    grid := PunishmentVaries(item.P) ? Random(3, 4) : SlidingPuzzleGrid(item.P.HasOwnProp("Grid") ? item.P.Grid : "3x3") = "4x4" ? 4 : 3
    cmd := UpdateQuote(A_AhkPath) " " UpdateQuote(A_ScriptDir "\Meso_Sliding_Puzzle.ahk") " " item.Target " " grid " " ProcessExist() " " UpdateQuote(item.PuzzleFile)
    pid := 0
    Run(cmd, A_ScriptDir, "Hide", &pid)
    item.PuzzlePid := pid
    item.End := now + 1000
    item.Note := "Preparing puzzle"
}
AdvanceSlidingPuzzle(item, now) {
    if !item.HasOwnProp("PuzzlePid")
        return
    state := ""
    try state := Trim(FileRead(item.PuzzleFile, "UTF-8"), Chr(13) Chr(10))
    fields := Fields(state)
    if fields.Length >= 5 && fields[1] = item.PuzzlePid {
        switch fields[3] {
            case "ready":
                item.PuzzleReady := true
                item.Note := "Solve puzzle · " fields[4] " moves"
            case "solved":
                FinishEffect("Puzzle solved")
                return
            case "stopped", "error":
                FinishEffect(fields[4])
                return
        }
    }
    if !ProcessExist(item.PuzzlePid) {
        FinishEffect(item.PuzzleReady ? "Puzzle interrupted" : "Puzzle could not start; see input log")
        return
    }
    if !item.PuzzleReady && now >= item.PuzzleUntil {
        FinishEffect("Puzzle startup timed out")
        return
    }
    item.End := now + 1000
}
StopSlidingPuzzle(item) {
    if item.HasOwnProp("PuzzleFile")
        try WriteAtomic(item.PuzzleFile ".cancel", "cancel")
}
''')
write('Lib/InteractionPointer.ahk',r'''
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
''')
write('Lib/ScareLocalAudio.ahk',r'''
ScareVolume(output := false) {
    global ConfigFile
    value := IniRead(ConfigFile, "Audio", output ? "ScareOutputVolume" : "ScareVolume", "100")
    return IsNumber(value) ? Max(0, Min(100, Round(value))) : 100
}
LocalScareMci(command) {
    return DllCall("winmm\mciSendStringW", "WStr", command, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt")
}
PlayLocalScare(name, duration) {
    global LocalScareSounds
    static serial := 0
    if !IsSet(LocalScareSounds)
        LocalScareSounds := Map()
    alias := "mesolocalscare" ++serial
    path := SpecialAudioPath(name)
    if LocalScareMci("open " Chr(34) path Chr(34) " alias " alias) {
        LogEvent("Local jumpscare audio could not open: " name)
        return
    }
    LocalScareMci("setaudio " alias " volume to " ScareVolume()*10)
    if LocalScareMci("play " alias " from 0") {
        LocalScareMci("close " alias)
        LogEvent("Local jumpscare audio could not play: " name)
        return
    }
    LocalScareSounds[alias] := NowMs()+duration
}
AdvanceLocalScares(now) {
    global LocalScareSounds, RuntimeDir
    static lastOnset := ""
    try {
        f := Fields(Trim(FileRead(RuntimeDir "\local-scare-onset.state", "UTF-8"), Chr(13) Chr(10)))
        if f.Length = 4 && f[1] != lastOnset && IsNumber(f[3]) && IsNumber(f[4]) {
            lastOnset := f[1]
            if now-f[3] >= 0 && now-f[3] < 1000 && (f[2]="1.wav" || f[2]="2.wav")
                PlayLocalScare(f[2], f[4]+0)
        }
    }
    if !IsSet(LocalScareSounds)
        return
    for alias, deadline in LocalScareSounds.Clone() {
        if now >= deadline {
            LocalScareMci("close " alias)
            LocalScareSounds.Delete(alias)
        } else
            LocalScareMci("setaudio " alias " volume to " ScareVolume()*10)
    }
}
StopLocalScares() {
    global LocalScareSounds
    if !IsSet(LocalScareSounds)
        return
    for alias in LocalScareSounds
        LocalScareMci("close " alias)
    LocalScareSounds := Map()
}
''')
write('Meso_Sliding_Puzzle.ahk',r'''
#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include Lib\Core.ahk
#Include Lib\PuzzleModel.ahk
#Include Lib\Draw.ahk
#Include Lib\InteractionPointer.ahk
RuntimeDir := A_ScriptDir "\runtime"
DirCreate(RuntimeDir)
if A_Args.Length != 4
    ExitApp(2)
Target := Integer(A_Args[1]), GridSize := Integer(A_Args[2]), ParentPid := Integer(A_Args[3]), StatusPath := A_Args[4]
PuzzleGui := 0, Tiles := [], Header := 0, BlankLabel := 0, Drag := 0, Animation := 0
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
    PuzzleGui.SetFont("s11 Bold cA4FFDB", "Segoe UI")
    Header := PuzzleGui.AddText("x12 y8 w" (GW-24) " h28 Center Background160F20", "SLIDING PUZZLE · Drag tiles into the gap")
    PuzzleGui.SetFont("s14 Bold cA4FFDB", "Segoe UI")
    BlankLabel := PuzzleGui.AddText("Center +0x200 Background241733", "SLIDE HERE")
    loop GridSize*GridSize-1 {
        thumbnail := 0
        if DllCall("dwmapi\DwmRegisterThumbnail", "Ptr", PuzzleGui.Hwnd, "Ptr", Target, "Ptr*", &thumbnail, "Int") < 0
            throw Error("Game preview could not be created")
        Tiles.Push({Thumbnail: thumbnail})
    }
    HookProc := CallbackCreate(PuzzleKeyboardHook, "", 3)
    Hook := DllCall("user32\SetWindowsHookExW", "Int", 13, "Ptr", HookProc, "Ptr", DllCall("kernel32\GetModuleHandleW", "Ptr", 0, "Ptr"), "UInt", 0, "Ptr")
    if !Hook
        throw Error("Keyboard block could not start")
    for vk in [0xA2, 0xA3, 0xA4, 0xA5]
        Mods[vk] := DllCall("user32\GetAsyncKeyState", "Int", vk, "Short") < 0
    OnMessage(0x201, PuzzleMouseDown)
    OnMessage(0x202, PuzzleMouseUp)
    PuzzleGui.OnEvent("Close", (*) => ExitApp())
    PuzzleGui.Show("x" GX " y" GY " w" GW " h" GH)
    WinActivate("ahk_id " PuzzleGui.Hwnd)
    DllCall("user32\ClipCursor", "Ptr", 0)
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
    global Board, Tiles, GridSize, GW, GH, Blank, BlankLabel, Animation, Drag
    blankRect := PuzzleCellRect(Blank)
    BlankLabel.Move(blankRect.X+3, blankRect.Y+3, blankRect.W-6, blankRect.H-6)
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
            ExitApp()
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
PuzzleKeyboardHook(code, message, data) {
    global PuzzleGui, Mods
    if code >= 0 && GuiHwndSafe(PuzzleGui) && WinActive("ahk_id " PuzzleGui.Hwnd) && !(NumGet(data, 8, "UInt") & 0x10) {
        vk := NumGet(data, 0, "UInt"), up := NumGet(data, 8, "UInt") & 0x80
        if Mods.Has(vk)
            Mods[vk] := !up
        if vk=0x7B && !up && (Mods[0xA2] || Mods[0xA3]) && (Mods[0xA4] || Mods[0xA5])
            SetTimer((*) => ExitApp(), -1)
        return 1
    }
    return DllCall("user32\CallNextHookEx", "Ptr", 0, "Int", code, "UPtr", message, "Ptr", data, "Ptr")
}
PuzzleReport(phase, note) {
    global StatusPath, PuzzleGui, Board
    WriteAtomic(StatusPath ".board", Line(Board*))
    WriteAtomic(StatusPath, Line(ProcessExist(), NowMs(), phase, note, GuiHwndSafe(PuzzleGui)))
}
PuzzleCleanup(*) {
    global Hook, HookProc, Tiles, PuzzleGui, Finished, PointerOwner, Target, PreviousClip
    SetTimer(PuzzleTick, 0)
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
        DllCall("user32\ClipCursor", "Ptr", PreviousClip)
        try WinActivate("ahk_id " Target)
    }
}
''')
print('Puzzle, pointer and independent audio modules prepared')
