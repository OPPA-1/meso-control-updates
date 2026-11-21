; Temporary foreground ownership for live, interactive sequences. Previews never acquire it.
class InteractionGuard {
    __New(target, escape := 0, blockKeys := false, parentPid := 0) {
        global RuntimeDir
        this.Registry := (IsSet(RuntimeDir) ? RuntimeDir : A_Temp "\MesoInteraction613") "\interactions"
        DirCreate(this.Registry)
        this.Lease := this.Registry "\" NewId() ".guard"
        this.Registered := false
        this.Target := target, this.Escape := escape, this.BlockKeys := blockKeys
        this.ParentPid := parentPid, this.Closed := false, this.Hook := 0, this.Proc := 0
        this.Previous := Buffer(16, 0), this.Rect := Buffer(16, 0), this.Mods := Map()
        DllCall("user32\GetClipCursor", "Ptr", this.Previous)
        for vk in [0xA2,0xA3,0xA4,0xA5]
            this.Mods[vk] := DllCall("user32\GetAsyncKeyState", "Int", vk, "Short") < 0
        this.Timer := ObjBindMethod(this, "Refresh")
        this.ExitHandler := ObjBindMethod(this, "Close")
        OnExit(this.ExitHandler)
        try {
            this.Proc := CallbackCreate(ObjBindMethod(this, "Keyboard"), "", 3)
            this.Hook := DllCall("user32\SetWindowsHookExW", "Int", 13, "Ptr", this.Proc,
                "Ptr", DllCall("kernel32\GetModuleHandleW", "Ptr", 0, "Ptr"), "UInt", 0, "Ptr")
            if !this.Hook
                throw Error("Interaction keyboard guard could not start")
            this.Register()
            this.Refresh()
            SetTimer(this.Timer, 15)
        } catch as err {
            this.Close()
            throw err
        }
    }
    Refresh(*) {
        if this.Closed
            return
        if !DllCall("user32\IsWindow", "Ptr", this.Target) || this.ParentPid && !ProcessExist(this.ParentPid) {
            this.Abort()
            return
        }
        try {
            if !this.OwnsForeground()
                return
            if !WinActive("ahk_id " this.Target) {
                ; Attach only while returning focus, including after a drag activates another window.
                fg := DllCall("user32\GetForegroundWindow", "Ptr")
                thread := DllCall("user32\GetWindowThreadProcessId", "Ptr", fg, "Ptr", 0, "UInt")
                own := DllCall("kernel32\GetCurrentThreadId", "UInt")
                attached := thread && thread != own && DllCall("user32\AttachThreadInput", "UInt", own, "UInt", thread, "Int", true)
                try DllCall("user32\SetForegroundWindow", "Ptr", this.Target)
                finally {
                    if attached
                        DllCall("user32\AttachThreadInput", "UInt", own, "UInt", thread, "Int", false)
                }
            }
            WinGetClientPos(&x,&y,&w,&h,"ahk_id " this.Target)
            if w > 0 && h > 0 {
                NumPut("Int",x,"Int",y,"Int",x+w,"Int",y+h,this.Rect)
                DllCall("user32\ClipCursor", "Ptr", this.Rect)
            }
        }
    }
    Keyboard(code, message, data) {
        if code >= 0 && !this.Closed {
            vk := NumGet(data,0,"UInt"), flags := NumGet(data,8,"UInt"), up := flags & 0x80
            if this.Mods.Has(vk)
                this.Mods[vk] := !up
            if vk = 0x7B && !up && (this.Mods[0xA2] || this.Mods[0xA3]) && (this.Mods[0xA4] || this.Mods[0xA5]) {
                SetTimer(ObjBindMethod(this,"Abort"),-1)
                return 1
            }
            ; Key-up events always pass so a modifier held before the sequence cannot get stuck.
            if up
                return DllCall("user32\CallNextHookEx","Ptr",0,"Int",code,"UPtr",message,"Ptr",data,"Ptr")
            ; Synthetic game inputs (Enter and Ctrl+V) pass, but app-switch chords do not.
            alt := this.Mods[0xA4] || this.Mods[0xA5]
            ctrl := this.Mods[0xA2] || this.Mods[0xA3]
            if vk=0x5B || vk=0x5C || vk=0xA4 || vk=0xA5 || vk=0x12
                || alt || vk=0x09 && ctrl || vk=0x1B && (alt || ctrl)
                || this.BlockKeys && !(flags & 0x10)
                return 1
        }
        return DllCall("user32\CallNextHookEx","Ptr",0,"Int",code,"UPtr",message,"Ptr",data,"Ptr")
    }
    Abort(*) {
        if this.Closed
            return
        callback := this.Escape
        this.Close()
        if IsObject(callback)
            callback.Call()
    }
    Close(*) {
        if this.Closed
            return
        this.Closed := true
        SetTimer(this.Timer,0)
        OnExit(this.ExitHandler,0)
        this.Timer := 0, this.ExitHandler := 0
        if this.Hook
            DllCall("user32\UnhookWindowsHookEx","Ptr",this.Hook)
        if this.Proc
            CallbackFree(this.Proc)
        this.Hook := 0, this.Proc := 0
        if this.Registered {
            mutex := this.LockRegistry()
            try {
                try FileDelete(this.Lease)
                if !this.LiveLeases().Length {
                    previous := this.Previous
                    try {
                        packet := Fields(Trim(FileRead(this.Registry "\original.state","UTF-8"),"`r`n"))
                        if packet.Length=4
                            NumPut("Int",Integer(packet[1]),"Int",Integer(packet[2]),"Int",Integer(packet[3]),"Int",Integer(packet[4]),previous)
                    }
                    DllCall("user32\ClipCursor","Ptr",previous)
                    try FileDelete(this.Registry "\original.state")
                }
            } finally this.UnlockRegistry(mutex)
            this.Registered := false
        }
    }
    LockRegistry() {
        mutex := DllCall("kernel32\CreateMutexW","Ptr",0,"Int",false,"WStr","Local\MesoInteractionGuard613","Ptr")
        if !mutex || DllCall("kernel32\WaitForSingleObject","Ptr",mutex,"UInt",500,"UInt")>0x80 {
            if mutex
                DllCall("kernel32\CloseHandle","Ptr",mutex)
            throw Error("Interaction ownership is busy")
        }
        return mutex
    }
    UnlockRegistry(mutex) {
        DllCall("kernel32\ReleaseMutex","Ptr",mutex)
        DllCall("kernel32\CloseHandle","Ptr",mutex)
    }
    LiveLeases() {
        result := []
        loop files this.Registry "\*.guard" {
            try {
                packet := Fields(Trim(FileRead(A_LoopFileFullPath,"UTF-8"),"`r`n"))
                if packet.Length=3 && ProcessExist(Integer(packet[1])) && DllCall("user32\IsWindow","Ptr",Integer(packet[2])) {
                    result.Push({Path:A_LoopFileFullPath, Target:Integer(packet[2]), Priority:Integer(packet[3])})
                    continue
                }
                FileDelete(A_LoopFileFullPath)
            }
        }
        return result
    }
    Register() {
        mutex := this.LockRegistry()
        try {
            if !this.LiveLeases().Length
                WriteAtomic(this.Registry "\original.state",Line(NumGet(this.Previous,0,"Int"),NumGet(this.Previous,4,"Int"),NumGet(this.Previous,8,"Int"),NumGet(this.Previous,12,"Int")))
            WriteAtomic(this.Lease,Line(ProcessExist(),this.Target,this.BlockKeys ? 100 : 50))
            this.Registered := true
        } finally this.UnlockRegistry(mutex)
    }
    OwnsForeground() {
        priority := this.BlockKeys ? 100 : 50
        for lease in this.LiveLeases()
            if lease.Priority>priority || lease.Priority=priority && StrCompare(lease.Path,this.Lease)>0
                return false
        return true
    }

}

RequestInteractionEmergency(*) {
    global RuntimeDir
    try {
        info := StrSplit(Trim(FileRead(RuntimeDir "\controller.info","UTF-8"),"`r`n"),"`n","`r")
        if info.Length>=3 && WinExist("ahk_id " Integer(info[2])) && WinGetPID("ahk_id " Integer(info[2]))=Integer(info[3])
            PostMessage(0x8009,0,0,,"ahk_id " Integer(info[2]))
    }
}
