#Requires AutoHotkey v2.0
#SingleInstance Off
#Include ..\Lib\Core.ahk
pass := 0
try {
    q := SpinQueue()
    loop 10000
        Check(q.Accept("id" A_Index, true, 1000) = 1, "Burst accept")
    Check(q.Count() = 10000, "Burst count")
    Check(q.Accept("id1", true, 1001) = 2, "Duplicate dedup")
    Check(q.Accept("overflow", true, 1001) = -2, "Queue bound")
    loop 10000 {
        item := q.Take(1000 + A_Index * 11000)
        Check(item.Id = "id" A_Index, "FIFO ordering")
        Check(!IsObject(q.Take(1001 + A_Index * 11000)), "No overlapping spin")
        q.Finish()
    }
    Check(q.Count() = 0 && q.Completed = 10000, "Drained")
    q.Accept("A", true, 0)
    q.Take(0)
    q.Accept("B", true, 10)
    q.Finish()
    q.Accept("C", true, 11)
    Check(q.Take(12).Id = "B", "Arrival at completion cannot overtake")
    c := ActivityClock()
    c.Prep(60000, 1000)
    Check(c.Remaining(17000) = 44000, "Delayed frames do not stretch prep")
    Check(c.Tax(120000, 17000) = 0, "No tax during prep")
    c.Tick(62000)
    Check(c.Phase = "ready", "Prep completion")
    Check(c.Start(300000, 65000), "Start activity")
    Check(c.Remaining(166000) = 199000, "Wall clock not frame decrement")
    Check(c.Tax(120000, 166000) = 120000, "Two-minute tax")
    Check(c.Remaining(166000) = 79000, "Tax remaining")
    Check(c.Tax(120000, 170000) = 75000 && c.Phase = "time", "Clamp at zero")
    c.Prep(5000, 171000)
    c.Tick(173001)
    Check(c.Phase = "prep", "Old TIME cleanup cannot erase new prep")
    oldGeneration := c.Generation
    c.Prep(0, 174000)
    c.Start(300000, 174000)
    Check(c.Tax(120000, 174500, oldGeneration) = 0, "Tax cannot target a replacement timer")
    Check(ParseTime("1:30:00") = 5400000, "Hours")
    Check(ParseTime("05:00") = 300000, "Minutes")
    Check(ParseTime("60:60") = -1, "Invalid time")
    Check(Unpack(Pack("A|B%25`nC")) = "A|B%25`nC", "IPC escape roundtrip")
    p := [{Weight: 5}, {Weight: 2}, {Weight: 1}]
    Check(WeightedPick(p, 4.99) = 1 && WeightedPick(p, 5) = 2 && WeightedPick(p, 7) = 3, "Weighted edges")
    FileAppend("PASS " pass " checks`n", "*")
    MsgBox("Passed " pass " model checks. No game input was sent.", "Meso tests")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL " err.Message "`n", "*")
    MsgBox(err.Message, "Meso test failed")
    ExitApp(1)
}
Check(ok, name) {
    global pass
    if !ok
        throw Error(name)
    pass += 1
}
