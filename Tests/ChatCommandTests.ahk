#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#Include ..\Lib\Core.ahk
#Include ..\Lib\ChatPolicy.ahk
Checked := 0
try {
    policy := ChatPolicy()
    Check(policy.Bindings.Count = 21, "Twenty-one default chat controls")
    Check(ChatToken("jump") = "jump", "Command action accepted")
    Check(ChatToken("  SHOOT  ") = "shoot", "Action normalized")
    Check(ChatToken("!chat jump") = "", "Prefix is owned by Streamer.bot")
    Check(ChatRelayAction("!chat jump") = "jump", "Legacy full chat message normalized")
    Check(ChatRelayAction("!do jump") = "jump", "Legacy command independent of app prefix")
    Check(ChatRelayAction("!chat jump shoot") = "", "Multiple actions rejected")
    Check(policy.Accept("one", "viewer", "jump", 1100, 1100, 1000) = 1, "Valid jump queued")
    Check(policy.Take(1110).Token = "jump", "Valid token dequeued")
    Check(policy.Accept("two", "viewer", "shoot", 1200, 1200, 1000) = 0, "Viewer cooldown works")
    policy.Reset()
    Check(policy.Accept("three", "viewer", "w", 2000, 2000, 1500) = 1, "W alias works")
    Check(policy.Take(2010).Token = "forward", "W resolves to forward")
    policy.Reset()
    policy.Bindings["dance"] := "q"
    Check(policy.Accept("six", "viewer", "dance", 3500, 3500, 3000) = 1, "Custom command accepted")
    policy.Reset()
    policy.BannedInputs := ["q"]
    Check(policy.Accept("seven", "viewer", "dance", 3900, 3900, 3500) = 0, "Blocked custom key rejected")
    policy.BannedInputs := []
    policy.BannedText := ["dance"]
    Check(policy.Accept("eight", "viewer", "dance", 4000, 4000, 3500) = 0, "Banned phrase rejected")
    policy.BannedText := []
    for invalid in ["!chat jump", "alt f4", "cmd.exe", "{Win}", "jump|shoot", "jump`nforward", "", "  "] {
        policy.Reset()
        Check(policy.Accept("invalid" A_Index, "viewer", invalid, 4300, 4300, 4000) = 0, "Unsafe chat rejected")
    }
    Check(!AllowedChatKey("LWin"), "Win key prohibited")
    Check(!AllowedChatKey("LAlt"), "Alt key prohibited")
    Check(!AllowedChatKey("Enter"), "Enter key prohibited")
    Check(AllowedChatKey("mouse-left"), "Mouse motion allowed")
    policy.Reset()
    Check(policy.Accept("expired", "viewer", "jump", 10, 2000, 1000) = 0 && policy.LastReason = "Message expired", "Expired message reason")
    policy.Reset()
    Check(policy.Accept("unknown", "viewer", "unknown", 4000, 4000, 3000) = 0 && policy.LastReason = "Unknown command", "Unknown command reason")
    policy.Reset()
    Check(policy.Accept("valid", "viewer", "jump", 4000, 4000, 3000) = 1 && policy.LastReason = "Queued", "Queued reason")
    Check(policy.Accept("valid", "viewer", "jump", 4100, 4100, 3000) = 0 && policy.LastReason = "Already received", "Duplicate reason")
    MsgBox(Checked " chat policy tests passed. No game inputs were sent.", "Meso chat tests")
    ExitApp(0)
} catch as err {
    MsgBox(err.Message "`n" err.File ":" err.Line, "Meso chat tests failed", "Iconx")
    ExitApp(1)
}
Check(condition, message) {
    global Checked
    Checked += 1
    if !condition
        throw Error(message)
}
