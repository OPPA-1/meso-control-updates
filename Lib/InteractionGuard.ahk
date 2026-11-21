; Temporary foreground ownership for live, interactive sequences. Previews never acquire it.
class InteractionGuard {
    __New(target, escape := 0, blockKeys := false, parentPid := 0) {
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
            ; Synthetic game inputs (Enter and Ctrl+V) pass, but app-switch chords do not.
            alt := this.Mods[0xA4] || this.Mods[0xA5]
            ctrl := this.Mods[0xA2] || this.Mods[0xA3]
            if vk=0x5B || vk=0x5C || vk=0xA4 || vk=0xA5 || vk=0x12
                || vk=0x09 && (alt || ctrl) || vk=0x1B && (alt || ctrl)
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
        if this.Hook
            DllCall("user32\UnhookWindowsHookEx","Ptr",this.Hook)
        if this.Proc
            CallbackFree(this.Proc)
        this.Hook := 0, this.Proc := 0
        current := Buffer(16,0)
        if DllCall("user32\GetClipCursor","Ptr",current)
            && NumGet(current,0,"Int64")=NumGet(this.Rect,0,"Int64")
            && NumGet(current,8,"Int64")=NumGet(this.Rect,8,"Int64")
            DllCall("user32\ClipCursor","Ptr",this.Previous)
    }
}
