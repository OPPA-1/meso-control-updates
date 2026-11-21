; Replay uses its own monotonic clock rather than the wheel's UI timer.
StartRecordedPlayback(item) {
    item.ReplayClock := PerfNowMs(), item.ReplayHeld := Map(), item.ReplayDone := false
    item.ReplayHeld.CaseSense := "Off"
    item.ReplayPeriod := DllCall("winmm\timeBeginPeriod","UInt",1,"UInt") = 0
    item.ReplayTimer := (*) => TickRecordedPlayback(item)
    SetTimer(item.ReplayTimer,1)
}
TickRecordedPlayback(item) {
    global GameKeyOwners
    if item.Phase != "running" || item.ReplayDone
        return
    if !WinActive("ahk_id " item.Target) {
        WithEffect(item,FinishEffect,"Recording stopped: game lost focus")
        return
    }
    previous := A_IsCritical
    Critical("On")
    try {
        elapsed := PerfNowMs()-item.ReplayClock, count := 0
        while item.Index <= item.Sequence.Length && item.Sequence[item.Index].At <= elapsed && count < 256 {
            e := item.Sequence[item.Index]
            switch e.Kind {
                case "down":
                    if !item.ReplayHeld.Has(e.Key) && !GameKeyOwners.Has(e.Key) {
                        SendLockedInput(e.Key,true)
                        item.ReplayHeld[e.Key] := true
                        GameKeyOwners[e.Key] := item
                        item.SentDown += 1, item.LastKey := e.Key
                    }
                case "up":
                    ReleaseRecordedKey(item,e.Key)
                case "move":
                    input := Buffer(40,0)
                    NumPut("Int",e.X,"Int",e.Y,input,8)
                    NumPut("UInt",0x2001,input,20) ; Relative move, do not coalesce discrete samples.
                    if DllCall("user32\SendInput","UInt",1,"Ptr",input,"Int",40,"UInt") != 1
                        throw Error("Windows refused recorded mouse movement")
                case "wheel":
                    delta := e.X ? e.X : (e.Key="WheelDown" || e.Key="WheelLeft" ? -120 : 120)
                    input := Buffer(40,0)
                    NumPut("Int",delta,"UInt",InStr(e.Key,"Left") || InStr(e.Key,"Right") ? 0x1000 : 0x800,input,16)
                    if DllCall("user32\SendInput","UInt",1,"Ptr",input,"Int",40,"UInt") != 1
                        throw Error("Windows refused recorded wheel input")
            }
            item.Index += 1, count += 1
        }
        if item.Index > item.Sequence.Length {
            item.ReplayDone := true
            StopRecordedPlayback(item)
        }
    } catch as err {
        WithEffect(item,FinishEffect,"Recording: " err.Message)
    } finally Critical(previous)
}
ReleaseRecordedKey(item,key) {
    global GameKeyOwners
    if !item.ReplayHeld.Has(key)
        return
    ; Always release what this replay pressed, even if the physical key is held.
    SendLockedInput(key,false)
    item.ReplayHeld.Delete(key)
    if GameKeyOwners.Has(key) && GameKeyOwners[key]=item
        GameKeyOwners.Delete(key)
    item.SentUp += 1
}
StopRecordedPlayback(item) {
    if !item.HasOwnProp("ReplayTimer")
        return
    SetTimer(item.ReplayTimer,0)
    item.DeleteProp("ReplayTimer")
    for key in item.ReplayHeld.Clone()
        try ReleaseRecordedKey(item,key)
    if item.ReplayPeriod {
        DllCall("winmm\timeEndPeriod","UInt",1)
        item.ReplayPeriod := false
    }
}
