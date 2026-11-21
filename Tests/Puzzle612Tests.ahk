
#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\PuzzleModel.ahk
OnError((err, mode) => (FileAppend(err.Message " (" err.File ":" err.Line ")" Chr(10), "*"), ExitApp(1)))
RuntimeDir := A_Temp "\MesoPuzzle612-" NewId()
DirCreate(RuntimeDir)
status := RuntimeDir "\puzzle.state"
game := Gui("-DPIScale","Puzzle test game")
game.BackColor := "56367D"
game.SetFont("s30 cFFFFFF","Segoe UI")
game.AddText("x40 y60 w700 h200","LIVE PUZZLE TEST")
game.Show("x20 y30 w900 h620")
pid := 0
try {
    WinActivate("ahk_id " game.Hwnd)
    cmd := Chr(34) A_AhkPath Chr(34) " " Chr(34) A_ScriptDir "\..\Meso_Sliding_Puzzle.ahk" Chr(34) " " game.Hwnd " 3 " ProcessExist() " " Chr(34) status Chr(34)
    Run(cmd,,, &pid)
    deadline := NowMs()+7500, f := [], text := ""
    while NowMs()<deadline {
        Sleep(50)
        text := ""
        try text := Trim(FileRead(status,"UTF-8"),Chr(13) Chr(10))
        f := Fields(text)
        if f.Length>=5 && (f[3]="ready" || f[3]="error" || f[3]="stopped")
            break
    }
    if f.Length<5 || f[3]!="ready"
        throw Error("Puzzle did not become ready: " text)
    hwnd := Integer(f[5])
    if !WinActive("ahk_id " hwnd)
        throw Error("Puzzle must own foreground so game raw input is suspended")
    ; Focus changes no longer cancel a live puzzle.
    other := Gui("-DPIScale","Puzzle distraction")
    other.Show("x0 y0 w250 h200")
    WinActivate("ahk_id " other.Hwnd)
    Sleep(200)
    if !ProcessExist(pid) || !WinActive("ahk_id " hwnd)
        throw Error("Puzzle must recover from outside activation")
    other.Destroy()
    board := Fields(Trim(FileRead(status ".board","UTF-8"),Chr(13) Chr(10)))
    blank := 0
    for i,tile in board
        if tile="0"
            blank := i
    move := PuzzleNeighbors(blank,3)[1]
    WinGetClientPos(&x,&y,&w,&h,"ahk_id " hwnd)
    col := Mod(move-1,3), row := (move-1)//3
    mx := x+Round((col+.5)*w/3), my := y+46+Round((row+.5)*(h-46)/3)
    DllCall("user32\SetCursorPos","Int",mx,"Int",my)
    PostMessage(0x201,1,0,,"ahk_id " hwnd)
    Sleep(250)
    f := Fields(Trim(FileRead(status,"UTF-8"),Chr(13) Chr(10)))
    if f.Length<5 || f[3]!="ready" || f[4]!="1"
        throw Error("An adjacent tile must slide into the gap")
    WriteAtomic(status ".cancel","cancel")
    deadline := NowMs()+2500
    while ProcessExist(pid) && NowMs()<deadline
        Sleep(30)
    if ProcessExist(pid)
        throw Error("Puzzle failed to cancel and release input")
    if !WinActive("ahk_id " game.Hwnd)
        throw Error("Puzzle cancellation did not return game focus")
    FileAppend("PASS live puzzle startup, legal slide, focus ownership and cancellation" Chr(10),"*")
} finally {
    if pid && ProcessExist(pid)
        ProcessClose(pid)
    game.Destroy()
    try DirDelete(RuntimeDir,true)
}
ExitApp()
