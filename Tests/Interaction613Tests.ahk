#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\InteractionGuard.ahk
#Include ..\Lib\InputPacket.ahk
OnError((err,mode)=>(FileAppend(err.Message " (" err.Line ")`n","*"),ExitApp(1)))
game := Gui("-DPIScale","Guard game"), other := Gui("-DPIScale","Other monitor stand-in")
game.Show("x40 y40 w800 h600")
other.Show("x10 y10 w400 h250")
WinActivate("ahk_id " game.Hwnd)
old := Buffer(16,0)
DllCall("user32\GetClipCursor","Ptr",old)
guard := 0
try {
    guard := InteractionGuard(game.Hwnd,0,true)
    WinActivate("ahk_id " other.Hwnd)
    Sleep(150)
    if !WinActive("ahk_id " game.Hwnd)
        throw Error("An external click must not end or escape the interaction")
    WinGetClientPos(&x,&y,&w,&h,"ahk_id " game.Hwnd)
    DllCall("user32\SetCursorPos","Int",x+w+200,"Int",y+h+200)
    point := Buffer(8,0)
    DllCall("user32\GetCursorPos","Ptr",point)
    if NumGet(point,0,"Int")>=x+w || NumGet(point,4,"Int")>=y+h
        throw Error("Cursor escaped to another monitor")
    SendLockedInput("LAlt",true)
    SendLockedInput("Tab",true)
    SendLockedInput("Tab",false)
    SendLockedInput("LAlt",false)
    Sleep(120)
    if !WinActive("ahk_id " game.Hwnd)
        throw Error("Alt+Tab escaped the interaction")
    guard.Close()
    current := Buffer(16,0)
    DllCall("user32\GetClipCursor","Ptr",current)
    if NumGet(current,0,"Int64")!=NumGet(old,0,"Int64") || NumGet(current,8,"Int64")!=NumGet(old,8,"Int64")
        throw Error("Cursor clip not restored")
    WinActivate("ahk_id " other.Hwnd)
    Sleep(80)
    if !WinActive("ahk_id " other.Hwnd)
        throw Error("Foreground remained locked after cleanup")
    FileAppend("PASS interaction focus recovery, cursor boundary, Alt+Tab block and cleanup`n","*")
} finally {
    if IsObject(guard)
        guard.Close()
    game.Destroy(), other.Destroy()
}
ExitApp()
