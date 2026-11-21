#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
OnError((err,mode)=>(FileAppend(err.Message " (" err.Line ")`n","*"),ExitApp(1)))
RuntimeDir := A_Temp "\MesoMirror613-" NewId()
DirCreate(RuntimeDir)
game := Gui("-Caption -DPIScale","Mirror pixel test")
for tile in [[0,0,"FF0000"],[400,0,"00FF00"],[0,300,"0000FF"],[400,300,"FFFF00"]]
    game.AddText("x" tile[1] " y" tile[2] " w400 h300 Background" tile[3],"")
game.Show("x60 y40 w800 h600")
CoordMode("Pixel","Screen")
try {
    for axis,expected in [[0x00FF00,0xFF0000,0xFFFF00,0x0000FF],[0x0000FF,0xFFFF00,0xFF0000,0x00FF00],[0xFFFF00,0x0000FF,0x00FF00,0xFF0000]] {
        WinActivate("ahk_id " game.Hwnd)
        status := RuntimeDir "\mirror" axis ".state", pid := 0
        cmd := Chr(34) A_AhkPath Chr(34) " " Chr(34) A_ScriptDir "\..\Meso_Visual_Effect.ahk" Chr(34) " mirror " game.Hwnd " 6000 " axis " " ProcessExist() " " Chr(34) status Chr(34)
        Run(cmd,,, &pid)
        try {
            deadline := NowMs()+3500, packet := []
            while NowMs()<deadline {
                Sleep(50)
                try packet := Fields(Trim(FileRead(status,"UTF-8"),"`r`n"))
                if packet.Length>=4 && (packet[3]="ready" || packet[3]="error")
                    break
            }
            if packet.Length<4 || packet[3]!="ready"
                throw Error("Mirror startup " axis ": " (packet.Length>=4 ? packet[4] : "no status"))
            Sleep(650)
            for i,offset in [[200,150],[600,150],[200,450],[600,450]] {
                color := PixelGetColor(60+offset[1],40+offset[2])
                if color != expected[i]
                    throw Error("Mirror axis " axis " quadrant " i ": " Format("{:06X}",color) " expected " Format("{:06X}",expected[i]))
            }
            ; A real source change must appear in the reflected output, not a stale screenshot.
            game[1].Opt("BackgroundCC00CC")
            DllCall("user32\InvalidateRect","Ptr",game[1].Hwnd,"Ptr",0,"Int",true)
            Sleep(350)
            destination := axis=1 ? [600,150] : axis=2 ? [200,450] : [600,450]
            if PixelGetColor(60+destination[1],40+destination[2]) != 0xCC00CC
                throw Error("Mirror live source did not refresh")
            game[1].Opt("BackgroundFF0000")
            FileAppend("PASS rendered mirror axis " axis ", live source refresh and Display Capture pixels`n","*")
        } finally {
            WriteAtomic(status ".cancel","cancel")
            Sleep(150)
            if ProcessExist(pid)
                ProcessClose(pid)
        }
    }
} finally {
    game.Destroy()
    DirDelete(RuntimeDir,true)
}
ExitApp()
