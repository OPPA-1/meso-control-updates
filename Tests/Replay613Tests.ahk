#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\InputPacket.ahk
#Include ..\Lib\MacroCodec.ahk
#Include ..\Lib\RecordedPlayback.ahk
OnError((err,mode)=>(FileAppend(err.Message " (" err.Line ")`n","*"),ExitApp(1)))
GameKeyOwners := Map(), received := [], mouseEvents := [], failed := ""
game := Gui("-DPIScale","Recorded input sink")
game.Show("x60 y40 w800 h600")
WinActivate("ahk_id " game.Hwnd)
proc := CallbackCreate(Observe,"",3)
hook := DllCall("user32\SetWindowsHookExW","Int",13,"Ptr",proc,"Ptr",DllCall("kernel32\GetModuleHandleW","Ptr",0,"Ptr"),"UInt",0,"Ptr")
mouseProc := CallbackCreate(ObserveMouse,"",3)
mouseHook := DllCall("user32\SetWindowsHookExW","Int",14,"Ptr",mouseProc,"Ptr",DllCall("kernel32\GetModuleHandleW","Ptr",0,"Ptr"),"UInt",0,"Ptr")
item := {Phase:"running", Target:game.Hwnd, Index:1, SentDown:0, SentUp:0, LastKey:"", Sequence:[]}
try {
    item.Sequence := ParseMacroText("MESOSEQ1`n" Line(0,"down","vk41sc01E",0,0) "`n" Line(9,"up","vk41sc01E",0,0) "`n" Line(18,"down","vk44sc020",0,0) "`n" Line(29,"up","vk44sc020",0,0))
    if item.Sequence.Length!=4
        throw Error("Existing recordings must remain readable")
    item.Sequence.Push({At:33,Kind:"wheel",Key:"WheelUp",X:360,Y:0})
    item.Sequence.Push({At:37,Kind:"down",Key:"XButton2",X:0,Y:0})
    item.Sequence.Push({At:43,Kind:"up",Key:"XButton2",X:0,Y:0})
    item.Sequence.Push({At:47,Kind:"move",Key:"",X:8,Y:-4})
    StartRecordedPlayback(item)
    deadline := NowMs()+1500
    while !item.ReplayDone && NowMs()<deadline
        Sleep(1)
    if failed!=""
        throw Error(failed)
    if !item.ReplayDone || received.Length!=4 || item.SentDown!=3 || item.SentUp!=3 || GameKeyOwners.Count
        throw Error("Replay lost input edges or failed to release ownership")
    if received[1].VK!=0x41 || received[2].VK!=0x41 || received[3].VK!=0x44 || received[4].VK!=0x44
        throw Error("Replay event order changed")
    if received[2].At<=received[1].At || received[4].At<=received[3].At
        throw Error("Recorded key holds were collapsed")
    wheelFound := false, sideDown := false, sideUp := false, moved := false
    for e in mouseEvents {
        if e.Message=0x20A && e.Data>>16=360
            wheelFound := true
        if e.Message=0x20B && e.Data>>16=2
            sideDown := true
        if e.Message=0x20C && e.Data>>16=2
            sideUp := true
        if e.Message=0x200
            moved := true
    }
    if !wheelFound || !sideDown || !sideUp || !moved
        throw Error("Replay lost wheel magnitude, a side-button edge or mouse movement")
    ; Cancellation must release a key whose recorded up event has not run yet.
    item.Index := 1, item.Sequence := [{At:0,Kind:"down",Key:"vk41sc01E",X:0,Y:0},{At:1000,Kind:"up",Key:"vk41sc01E",X:0,Y:0}]
    StartRecordedPlayback(item)
    Sleep(25)
    StopRecordedPlayback(item)
    if item.ReplayHeld.Count || GameKeyOwners.Count || DllCall("user32\GetAsyncKeyState","Int",0x41,"Short")<0
        throw Error("Cancelled recording left a held key")
    FileAppend("PASS native recorded scan-code order, distinct key holds, cancellation and legacy format`n","*")
} finally {
    StopRecordedPlayback(item)
    DllCall("user32\UnhookWindowsHookEx","Ptr",hook)
    CallbackFree(proc)
    DllCall("user32\UnhookWindowsHookEx","Ptr",mouseHook)
    CallbackFree(mouseProc)
    game.Destroy()
}
ExitApp()
Observe(code,message,data) {
    global received
    if code>=0 && NumGet(data,8,"UInt") & 0x10
        received.Push({VK:NumGet(data,0,"UInt"),At:PerfNowMs()})
    return DllCall("user32\CallNextHookEx","Ptr",0,"Int",code,"UPtr",message,"Ptr",data,"Ptr")
}
WithEffect(item,callback,args*) {
    global failed
    callback(args*)
}
FinishEffect(reason) {
    global failed
    failed := reason
}

ObserveMouse(code,message,data) {
    global mouseEvents
    if code>=0 && NumGet(data,12,"UInt") & 1
        mouseEvents.Push({Message:message,Data:NumGet(data,8,"UInt")})
    return DllCall("user32\CallNextHookEx","Ptr",0,"Int",code,"UPtr",message,"Ptr",data,"Ptr")
}
