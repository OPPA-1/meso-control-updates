#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\ScreenFilter.ahk
#Include ..\Lib\Draw.ahk
#Include ..\Lib\PuzzleBadge.ahk
#Include ..\Lib\VisualCursor.ahk
OnError((err,mode)=>(FileAppend(err.Message " (" err.File ":" err.Line ")`n","*"),ExitApp(1)))
RuntimeDir := A_Temp "\MesoFilter614-" NewId()
DirCreate(RuntimeDir)
CoordMode("Pixel","Screen")
game := Gui("-Caption -DPIScale","614 live screen test")
for tile in [[0,0,"FF0000"],[400,0,"00FF00"],[0,300,"0000FF"],[400,300,"FFFF00"]]
    game.AddText("x" tile[1] " y" tile[2] " w400 h300 Background" tile[3],"")
game.Show("x60 y40 w800 h600")
pid := 0, status := "", badges := 0, cursorA := {}, cursorB := {}, cursorLib := 0
try {
    b := ScreenFilterBounds("split",-1920,0,1920,1080)
    if b.X!=-1920 || b.W!=960 || b.SourceX!=-960
        throw Error("Half-screen coordinates failed on a left monitor")
    WinActivate("ahk_id " game.Hwnd)
    status := RuntimeDir "\split.state"
    pid := StartFilter614("split", game.Hwnd, 1, status)
    for i,offset in [[200,150],[600,150],[200,450],[600,450]] {
        expected := i<=2 ? 0x00FF00 : 0xFFFF00
        if PixelGetColor(60+offset[1],40+offset[2])!=expected
            throw Error("Mirror Screen did not copy the right half to both sides, quadrant " i)
    }
    game["Static2"].Opt("BackgroundCC00CC")
    DllCall("user32\InvalidateRect","Ptr",game["Static2"].Hwnd,"Ptr",0,"Int",true)
    Sleep(350)
    if PixelGetColor(260,190)!=0xCC00CC || PixelGetColor(660,190)!=0xCC00CC
        throw Error("Mirror Screen did not refresh live gameplay")
    StopFilter614(pid,status)
    pid := 0
    game["Static2"].Opt("Background00FF00")
    DllCall("user32\InvalidateRect","Ptr",game["Static2"].Hwnd,"Ptr",0,"Int",true)
    Sleep(100)
    red := []
    for amount in [3,25] {
        status := RuntimeDir "\blur" amount ".state"
        pid := StartFilter614("blur",game.Hwnd,amount,status)
        color := PixelGetColor(60+410,40+150)
        red.Push((color>>16)&255)
        StopFilter614(pid,status)
        pid := 0
    }
    if red[2]<red[1]+20
        throw Error("Changing blur strength did not change rendered pixels: " red[1] " / " red[2])
    Sleep(120)
    if PixelGetColor(260,190)!=0xFF0000 || PixelGetColor(660,190)!=0x00FF00
        throw Error("Screen filters did not restore the original display")
    game.BackColor := "241733"
    for ctrl in game
        ctrl.Visible := false
    game.Show()
    badges := CreatePuzzleBadges(game.Hwnd,A_ScriptDir "\..\Meso_Icon.png")
    PositionPuzzleBadges(badges,60,40,800,600)
    Sleep(200)
    ; Alpha corners show the gap color, while the image center keeps its purple artwork.
    for point in [[60+800-54-14,40+14],[60+14,40+600-54-14]] {
        if PixelGetColor(point[1],point[2])!=0x241733
            throw Error("Puzzle badge has an opaque square background")
        color := PixelGetColor(point[1]+27,point[2]+38)
        if color=0x241733 || ((color>>16)&255)=((color>>8)&255) && ((color>>8)&255)=(color&255)
            throw Error("Puzzle badge did not render its purple Meso artwork")
    }
    cursorLib := DllCall("kernel32\LoadLibraryW","WStr",A_WinDir "\System32\Magnification.dll","Ptr")
    if !cursorLib || !DllCall("Magnification\MagInitialize","Int")
        throw Error("Cursor test could not initialize magnification")
    if !HideVisualCursor(cursorA) || !HideVisualCursor(cursorB)
        throw Error("Visual cursor ownership could not start")
    if RestoreVisualCursor(cursorA) || !FileExist(cursorB.CursorLease)
        throw Error("Ending one effect released another effect's hidden cursor")
    if !RestoreVisualCursor(cursorB)
        throw Error("The last visual effect did not restore the system cursor")
    FileAppend("PASS live Mirror Screen pixels, source refresh, Gaussian blur strength, effect cleanup, transparent Meso puzzle badges and overlapping cursor ownership`n","*")
} finally {
    if pid
        StopFilter614(pid,status)
    ClosePuzzleBadges(badges)
    if cursorLib {
        RestoreVisualCursor(cursorA)
        RestoreVisualCursor(cursorB)
        DllCall("Magnification\MagUninitialize","Int")
        DllCall("kernel32\FreeLibrary","Ptr",cursorLib)
    }
    game.Destroy()
    DirDelete(RuntimeDir,true)
}
ExitApp()

StartFilter614(mode,target,amount,status) {
    WinActivate("ahk_id " target)
    pid := 0
    command := Chr(34) A_AhkPath Chr(34) " /ErrorStdOut=UTF-8 " Chr(34) A_ScriptDir "\..\Meso_Screen_Filter.ahk" Chr(34)
    command .= " " mode " " target " 12000 " amount " " ProcessExist() " " Chr(34) status Chr(34)
    Run(command,,, &pid)
    deadline := NowMs()+7000, packet := []
    while NowMs()<deadline {
        Sleep(50)
        try packet := Fields(Trim(FileRead(status,"UTF-8"),"`r`n"))
        if packet.Length>=4 && (packet[3]="ready" || packet[3]="error")
            break
    }
    if packet.Length<4 || packet[3]!="ready" {
        if ProcessExist(pid)
            ProcessClose(pid)
        throw Error(mode " startup: " (packet.Length>=4 ? packet[4] : "no status"))
    }
    Sleep(500)
    return pid
}

StopFilter614(pid,status) {
    WriteAtomic(status ".cancel","cancel")
    deadline := NowMs()+2500
    while ProcessExist(pid) && NowMs()<deadline
        Sleep(30)
    if ProcessExist(pid) {
        ProcessClose(pid)
        throw Error("Screen filter did not stop after cancellation")
    }
}
