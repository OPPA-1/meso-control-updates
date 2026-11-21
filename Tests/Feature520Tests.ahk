#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#Include ..\Lib\Core.ahk
#Include ..\Lib\ChatPolicy.ahk
count := 0
try {
    chat := ChatPolicy()
    Check(chat.Mode = "queue", "Queue mode default")
    Check(chat.HoldEnabled["forward"], "Movement default hold")
    Check(chat.HoldEnabled["aim"] && chat.HoldEnabled["shoot"] && chat.HoldEnabled["interact"], "Interactive command holds")
    Check(chat.HoldMs["forward"] = 2000, "Default hold duration")
    Check(ChatHoldDuration(1000000) = 10000 && ChatHoldDuration(12) = 50, "Duration limits")
    Check(chat.Accept("test1", "alice", "forward", 1200, 1200, 1000) = 1, "Accept held movement")
    item := chat.Take(1210)
    Check(item.Hold && item.Duration = 2000, "Held movement duration")
    chat.Reset()
    chat.Mode := "anytime"
    Check(chat.Accept("test2", "alice", "shoot", 2000, 2000, 1500) = 1, "Anytime command accepted")
    Check(chat.Accept("test3", "bob", "aim", 2080, 2080, 1500) = 1, "Overlapping commands accepted")
    Check(chat.Pending.Length = 2, "Two pending actions")
    Check(chat.Take(2100).Token = "shoot" && chat.Take(2100).Token = "aim", "Independent commands")
    Check(DefaultChatHold("lookleft") && !DefaultChatHold("jump"), "Camera movement hold")
    Check(ChatCommandNameValid("customdash"), "Custom commands supported")
    MsgBox(count " feature tests passed. No gameplay input sent.", "Meso 5.2.0")
    ExitApp(0)
} catch as err {
    MsgBox(err.Message, "Meso 5.2.0 tests", "Iconx")
    ExitApp(1)
}
Check(condition, message) {
    global count
    count += 1
    if !condition
        throw Error(message)
}
