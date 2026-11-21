#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#Include ..\Lib\Core.ahk
#Include ..\Lib\RoundModel.ahk
#Include ..\Lib\ChatPolicy.ahk
#Include ..\Lib\MacroCodec.ahk
Checks := 0
try {
    rounds := RoundCycle("auto", 5, 15)
    rounds.Tick(1000)
    Assert(rounds.Remaining = 5 && rounds.Phase = "running", "Auto round starts with five")
    loop 4
        rounds.Complete(2000 + A_Index)
    Assert(!rounds.Cooling(2100) && rounds.Remaining = 1, "No early cooldown")
    rounds.Complete(3000)
    Assert(rounds.Cooling(17999) && rounds.CooldownUntil = 18000, "Cooldown is fifteen seconds")
    rounds.Tick(18000)
    Assert(rounds.Phase = "running" && rounds.Remaining = 5, "Next auto round starts on deadline")
    loop 5
        rounds.Complete(19000)
    rounds.Bonus(20000, 5)
    Assert(!rounds.Cooling(20000) && rounds.Remaining = 5, "Skip starts a full round")
    rounds.Bonus(20001, 5)
    Assert(rounds.Remaining = 10, "Bonus adds spins without losing active round")
    standard := RoundCycle("normal", 5, 15)
    standard.Tick(0, true)
    standard.Complete(0)
    Assert(!standard.Cooling(0) && standard.Phase = "idle", "Standard mode unchanged")
    batch := RoundCycle("batch", 3, 2)
    batch.Tick(0, false)
    Assert(batch.Phase = "idle", "Batch mode waits for work")
    batch.Tick(1000, true)
    Assert(batch.Remaining = 3, "Configured batch used")
    q := SpinQueue(8)
    Assert(q.AcceptBatch("one", 5, 1000, "ViewerOne") = 1 && q.Count() = 5, "Batch accepted")
    Assert(q.AcceptBatch("one", 5, 1000, "ViewerOne") = 2 && q.Count() = 5, "Retry deduplicated")
    Assert(q.AcceptBatch("two", 5, 1000, "ViewerTwo") = -2 && q.Count() = 5, "Capacity is all-or-nothing")
    job := q.Take(2000)
    Assert(job.Viewer = "ViewerOne" && q.Count() = 4, "Viewer preserved")
    Assert(!q.Take(2000), "One active spin only")
    q.Finish()
    Assert(IsObject(q.Take(2001)), "Next spin available after completion")
    stress := SpinQueue(2000)
    loop 200
        Assert(stress.AcceptBatch("burst" A_Index, 5, 0, "Viewer" A_Index) = 1, "Burst enqueue")
    loop 1000 {
        item := stress.Take(A_Index)
        Assert(IsObject(item), "No lost queued spin")
        Assert(!stress.Take(A_Index), "No overlapping spin")
        stress.Finish()
    }
    Assert(stress.Count() = 0 && stress.Completed = 1000, "Queue stress drained")
    policy := ChatPolicy()
    Assert(policy.Accept("1", "viewer", "jump", 1000, 1000, 500) = 1, "Valid chat command")
    Assert(policy.Accept("2", "viewer", "shoot", 1010, 1010, 500) = 0, "Viewer rate limit")
    Assert(policy.Take(1050).Token = "jump", "Typed command resolved")
    for command in ["alt f4", "{LWin}r", "cmd.exe", "!play enter", "ctrl+r", "!play w`n!play d", "{a down}"] {
        policy.Reset()
        Assert(policy.Accept(NewId(), "v", command, 2000, 2000, 500) = 0, "Unsafe chat rejected")
    }
    policy.Reset()
    policy.BannedInputs := ["w"]
    Assert(policy.Accept("b", "v", "forward", 2000, 2000, 500) = 0, "Alias cannot bypass input ban")
    policy.BannedInputs := []
    policy.BannedText := ["jump"]
    Assert(policy.Accept("c", "v", "jump", 2000, 2000, 500) = 0, "Text ban enforced")
    policy.BannedText := []
    Assert(policy.Accept("d", "v", "jump", 100, 2000, 500) = 0, "Stale chat rejected")
    Assert(policy.Accept("e", "v", "jump", 2100, 2100, 500) = 1, "Fresh command accepted")
    Assert(!policy.Take(34101), "Expired input never executes")
    events := ParseMacroText("MESOSEQ1`r`n0|down|w|0|0`r`n100|move||12|-4`r`n150|up|w|0|0`r`n`r`n")
    Assert(events.Length = 3, "Recording handles CRLF and trailing blank lines")
    Assert(events[2].X = 12 && events[2].Y = -4, "Mouse delta retained")
    Assert(ParseMacroText("MESOSEQ1`n100|down|w|0|0`n50|up|w|0|0").Length = 0, "Bad timing rejected")
    Assert(ParseMacroText("MESOSEQ1`n0|down|{LWin}r|0|0").Length = 0, "Invalid macro key rejected")
    balanced := BalanceRecordedEvents([{At: 0, Kind: "up", Key: "w", X: 0, Y: 0}, {At: 50, Kind: "down", Key: "w", X: 0, Y: 0}])
    Assert(balanced.Length = 2 && balanced[1].Kind = "down" && balanced[2].Kind = "up", "Missing key release repaired")
    MsgBox(Checks " checks passed. No gameplay input was sent.", "Meso checks")
    ExitApp(0)
} catch as err {
    MsgBox(err.Message "`n" err.File ":" err.Line, "Meso check failed", "Iconx")
    ExitApp(1)
}

Assert(condition, message) {
    global Checks
    Checks += 1
    if !condition
        throw Error(message)
}
