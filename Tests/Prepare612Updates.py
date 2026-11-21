exec((__import__('pathlib').Path('Tests/Prepare612Core.py').read_text()).split("edit('Lib/Sensitivity.ahk'")[0])
edit('Lib/Updates.ahk','IniRead(ConfigFile, "Updates", "AutoCheck", "0")','IniRead(ConfigFile, "Updates", "ForceAuto", "1")')
edit('Lib/Updates.ahk','43200000','600000')
edit('Lib/Updates.ahk','"Check for updates every 12 hours"','"Always Check & Force new updates"')
edit('Lib/Updates.ahk','ConfigFile, "Updates", "AutoCheck"','ConfigFile, "Updates", "ForceAuto"')
edit('Lib/Updates.ahk','selected ? "Auto-check enabled" : "Auto-check disabled"','selected ? "Automatic updates on · Every 10 minutes" : "Automatic updates off"')
s=read('Lib/Updates.ahk').replace('    if MsgBox("Install this update? Meso Control will restart automatically. Your settings and recordings will be kept.", "Install Meso Control update", "YesNo Default2 Icon?") != "Yes"\n        return\n','');write('Lib/Updates.ahk',s)
edit('Lib/Updates.ahk','    if IsObject(Queue.Active) || Queue.Count() || HasEffects()','    global SettingsGui, PendingAltEnterRestores\n    if GuiHwndSafe(SettingsGui) || SequenceBusy(now) || IsSet(PendingAltEnterRestores) && PendingAltEnterRestores.Count\n        return false\n    if IsObject(Queue.Active) || HasEffects()')
edit('Lib/Updates.ahk','    if !Updates.Pid && Updates.Requested && Updates.Ready && UpdateCanInstall(now) {\n        Queue.Paused := true','    if Updates.AutoCheck && Updates.Ready\n        Updates.Requested := true\n    if !Updates.Pid && Updates.Requested && Updates.Ready && UpdateCanInstall(now) {')
edit('Lib/Updates.ahk','            SaveAppSettings()\n            SavePending()','            SaveAppSettings()\n            SavePending()\n            SaveUpdateSession()')
edit('Lib/Updates.ahk','" -RendererPid " OutputPid (OutputEnabled ? " -ResumeOutput" : "")','" -RendererPid 0 -KeepRenderer" (OutputEnabled ? " -ResumeOutput" : "")')
edit('Lib/Updates.ahk','            Updates.Applying := true\n            CloseStreamOutput()','            Updates.Applying := true')
write('Lib/Updates.ahk',read('Lib/Updates.ahk')+r'''
SaveUpdateSession() {
    global Queue, AppGui, Slots, Clock, OutputEnabled, OutputPid, Guides, VisualHits, RuntimeDir
    WinGetPos(&x, &y, &w, &h, "ahk_id " AppGui.Hwnd)
    visible := DllCall("user32\IsWindowVisible", "Ptr", AppGui.Hwnd, "Int")
    nl := Chr(10)
    text := "[Session]" nl "SavedAt=" NowMs() nl "Paused=" (Queue.Paused ? 1 : 0) nl "Completed=" Queue.Completed nl "X=" x nl "Y=" y nl "Visible=" visible nl "Output=" (OutputEnabled ? 1 : 0) nl "Guides=" (Guides ? 1 : 0) nl
    text .= "[Clock]" nl "Phase=" Clock.Phase nl "Generation=" Clock.Generation nl
    text .= "[Slots]" nl "Phase=" Slots.Phase nl "Locked=" Slots.Locked nl "Id=" Slots.Id nl
    for i, value in Slots.Values
        text .= "Value" i "=" value nl
    text .= "[VisualHits]" nl
    for action, count in VisualHits
        text .= action "=" count nl
    WriteAtomic(A_ScriptDir "\.updates\session.ini", text)
    seen := ""
    for id, tick in Queue.Seen
        seen .= Line(id, tick)
    WriteAtomic(RuntimeDir "\update-seen.state", seen)
}
RestoreUpdateSession() {
    global Queue, AppGui, Slots, Clock, OutputEnabled, OutputPid, Guides, VisualHits, RuntimeDir, OutputCheck, GuideCheck, OutputReloadUntil
    path := A_ScriptDir "\.updates\session.ini"
    if !FileExist(path)
        return false
    try {
        age := NowMs() - Integer(IniRead(path, "Session", "SavedAt", "0"))
        if age < 0 || age > 600000
            return false
        Queue.Paused := IniRead(path, "Session", "Paused", "0") = "1"
        Queue.Completed := Integer(IniRead(path, "Session", "Completed", "0"))
        Guides := IniRead(path, "Session", "Guides", "0") = "1"
        OutputEnabled := IniRead(path, "Session", "Output", "0") = "1"
        OutputPid := OutputEnabled ? ExistingStreamOutputPid() : 0
        if IsSet(OutputCheck)
            OutputCheck.Value := OutputEnabled
        if IsSet(GuideCheck)
            GuideCheck.Enabled := OutputEnabled
        if OutputPid {
            renderer := StreamOutputWindow(OutputPid)
            OutputReloadUntil := NowMs()+5000
            if renderer
                SetTimer((*) => PostMessage(0x8004, 0, 0,, "ahk_id " renderer), -800)
        }
        Clock.Phase := IniRead(path, "Clock", "Phase", "idle") = "ready" ? "ready" : "idle"
        Clock.Generation := Integer(IniRead(path, "Clock", "Generation", "0"))
        Slots.Phase := "idle"
        Slots.Locked := Integer(IniRead(path, "Slots", "Locked", "0"))
        Slots.Id := IniRead(path, "Slots", "Id", "")
        loop 4
            Slots.Values[A_Index] := IniRead(path, "Slots", "Value" A_Index, "")
        for action in ["Lights Out", "Tunnel Vision", "Wide View"]
            VisualHits[action] := Integer(IniRead(path, "VisualHits", action, "0"))
        try {
            for row in StrSplit(FileRead(RuntimeDir "\update-seen.state", "UTF-8"), Chr(10)) {
                f := Fields(row)
                if f.Length = 2 && IsNumber(f[2])
                    Queue.Seen[f[1]] := f[2]+0
            }
            FileDelete(RuntimeDir "\update-seen.state")
        }
        x := Integer(IniRead(path, "Session", "X", "0")), y := Integer(IniRead(path, "Session", "Y", "0"))
        WinMove(x, y,,, "ahk_id " AppGui.Hwnd)
        if IniRead(path, "Session", "Visible", "1") = "1"
            AppGui.Show("NA")
        else
            AppGui.Hide()
        return true
    } catch as err {
        LogEvent("Update session: " err.Message)
        return false
    } finally {
        try FileDelete(path)
    }
}
''')
edit('Meso_Control.ahk','RestoreOutputAfterUpdate := false','RestoreOutputAfterUpdate := false\nResumeUpdateSession := false')
edit('Meso_Control.ahk','    if argument = "--background"','    if argument = "--resume-session"\n        ResumeUpdateSession := true, RestartInTray := true\n    if argument = "--background"')
edit('Meso_Control.ahk','InitUpdates()\nSetTimer','InitUpdates()\nif ResumeUpdateSession\n    RestoreUpdateSession()\nSetTimer')
edit('Meso_Control.ahk','    global Closing, Refreshing, Queue, RuntimeDir, SharedLargeIcon, SharedSmallIcon','    global Closing, Refreshing, Queue, RuntimeDir, SharedLargeIcon, SharedSmallIcon, Updates')
edit('Meso_Control.ahk','    CloseStreamOutput()\n    try FileDelete(RuntimeDir "\\controller.info")','    if !IsSet(Updates) || !Updates.Applying\n        CloseStreamOutput()\n    try FileDelete(RuntimeDir "\\controller.info")')
edit('Lib/GitHubUpdateTools.ps1','    [switch]$ResumeOutput','    [switch]$KeepRenderer,\n    [switch]$ResumeOutput')
edit('Lib/GitHubUpdateTools.ps1',"""$args = '"' + $script + '"'""","""$args = '"' + $script + '"'\n    if ($KeepRenderer) { $args += ' --resume-session' }""")
edit('Lib/GitHubUpdateTools.ps1','            WaitProcess $RendererPid','            if (!$KeepRenderer) { WaitProcess $RendererPid }')
edit('Meso_Stream_Output.ahk','OnExit(OutputExit)','OnMessage(0x8004, (*) => Reload())\nOnExit(OutputExit)')
edit('Meso_Control.ahk','    OutputManagementBusy := true\n    try {','''    OutputManagementBusy := true
    try {
        global OutputReloadUntil
        if IsSet(OutputReloadUntil) && OutputReloadUntil {
            candidate := ExistingStreamOutputPid()
            if candidate && candidate != OutputPid && ProcessExist(candidate) {
                OutputPid := candidate
                OutputReloadUntil := 0
            } else if NowMs() < OutputReloadUntil
                return
            else {
                OutputReloadUntil := 0
                if !ProcessExist(OutputPid)
                    OutputPid := 0
            }
        }''')
p='Meso_Stream_Output.ahk';s=read(p);a=s.index('DrawActive(c, now) {');b=s.index('\nDrawTimer(',a)
s=s[:a]+'''DrawActive(c, now) {
    global State
    items := []
    for row in State.ActiveItems
        if now < row[3]+0
            items.Push(row)
    if !items.Length
        return
    c.RoundRect(823, 498, 1074, 144, 24, 0xFF170D24, 0xFF8151B4, 2)
    if items.Length = 1 && items[1][2] = "COOLDOWN" {
        c.TextNoWrap("COOLDOWN", 847, 505, 1026, 40, 29, 0xFFE3C9FF, true)
        c.TextNoWrap(TimeText(Max(0, items[1][3]+0-now)), 847, 547, 1026, 82, 57, 0xFFFFFFFF, true)
        return
    }
    bonus := false
    for item in items
        if item.Length >= 6 && item[6] = "1"
            bonus := true
    c.TextNoWrap(bonus ? "2× BONUS ACTIVE" : items.Length>1 ? "ACTIVE PUNISHMENTS" : "ACTIVE PUNISHMENT", 849, 504, 1022, 32, bonus ? 23 : 19, bonus ? 0xFFA4FFDB : 0xFFC4A2E5, true)
    rows := Min(items.Length, 3)
    loop rows {
        item := items[A_Index]
        y := items.Length=1 ? 545 : 540+(A_Index-1)*29
        note := CompactEffectNote(item[4])
        isWaiting := note="Focus game" || note="Queued"
        detail := isWaiting ? note : InStr(note,"Solve puzzle") ? "Solve to continue" : Format("{:.1f}s", Max(0, item[3]+0-now)/1000)
        c.TextNoWrap(SubStr(item[2],1,50), 855, y, 1008, items.Length=1 ? 42 : 29, items.Length=1 ? 31 : 23, 0xFFFFFFFF, true)
        if items.Length=1
            c.TextNoWrap(note!="" && !isWaiting ? note " · " detail : detail, 855, 593, 1008, 28, 20, 0xFFD2ACFF, true)
        else
            c.TextNoWrap(detail, 1690, y, 168, 29, 17, 0xFFD2ACFF, true, 2)
    }
    if items.Length>3
        c.TextNoWrap("+" (items.Length-3) " more", 855, 623, 1008, 18, 12, 0xFFC4A2E5, true)
}
'''+s[b:];write(p,s)
print('Automatic updates, session recovery and centered active panel prepared')
