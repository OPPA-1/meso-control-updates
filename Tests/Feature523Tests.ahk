#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#Include ..\Lib\Core.ahk
#Include ..\Lib\ChatPolicy.ahk
#Include ..\Lib\OutputState.ahk
count := 0
try {
    policy := ChatPolicy()
    Check(policy.RepeatEnabled, "Chat repetition is enabled by default")
    Check(policy.Accept("test-523", "viewer", "lookup", 2000, 2000, 1000) = 1, "Lookup accepted")
    item := policy.Take(2010)
    Check(item.Repeat && item.Hold && item.Duration = 2000, "Repeated movement lasts two seconds")
    policy.RepeatEnabled := false
    policy.Reset()
    Check(policy.Accept("test-524", "viewer", "shoot", 3000, 3000, 2500) = 1, "Disabled repeat accepted")
    Check(!policy.Take(3010).Repeat, "Repetition toggle is retained")
    data := Line("meta", 1, ProcessExist(), 1000)
    data .= Line("status", 0, false, false)
    data .= Line("wheel", "idle", "", 0, 0, "", 0, 0)
    data .= Line("slots", "idle", "", 0, 0, 0, 0, 0, "", "", "", "")
    data .= Line("timer", "idle", 0, 0, 0)
    data .= Line("active", "", 0, "", 0)
    state := ParseOutputState(data)
    Check(state.Wheel[2] = "idle", "Stream output protocol remains compatible")
    Check(FileExist(A_ScriptDir "\..\Ui\tung_damage.png") != "", "Tung silhouette file included")
    source := FileRead(A_ScriptDir "\..\Lib\Effects.ahk", "UTF-8")
    Check(InStr(source, "I'm a chud. I'm a chud. I'm a chud."), "New Send Chat message included")
    stream := FileRead(A_ScriptDir "\..\Meso_Stream_Output.ahk", "UTF-8")
    Check(!InStr(stream, "PaintStreamMirror(dc)"), "Stream output remains a wheel and reel overlay")
    Check(InStr(stream, "sourceWidth * 2.5"), "Screen damage scale increased")
    Check(InStr(stream, "Until: now + 60000"), "Each screen damage patch lasts sixty seconds")
    FileAppend("PASS " count " Meso 5.2.3 checks`n", "*")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message "`n", "*")
    ExitApp(1)
}
Check(condition, name) {
    global count
    count += 1
    if !condition
        throw Error(name)
}
