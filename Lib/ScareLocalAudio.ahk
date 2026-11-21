
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
    serial += 1
    alias := "mesolocalscare" serial
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
