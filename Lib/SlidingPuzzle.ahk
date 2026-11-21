
StartSlidingPuzzle(item, now) {
    global RuntimeDir
    item.PuzzleFile := RuntimeDir "\puzzle-" NewId() ".state"
    item.PuzzleReady := false
    item.PuzzlePid := 0
    item.PuzzleUntil := now + 8000
    grid := PunishmentVaries(item.P) ? Random(3, 4) : SlidingPuzzleGrid(item.P.HasOwnProp("Grid") ? item.P.Grid : "3x3") = "4x4" ? 4 : 3
    cmd := UpdateQuote(A_AhkPath) " " UpdateQuote(A_ScriptDir "\Meso_Sliding_Puzzle.ahk") " " item.Target " " grid " " ProcessExist() " " UpdateQuote(item.PuzzleFile)
    ClearHeldGameBindings()
    pid := 0
    Run(cmd, A_ScriptDir, "Hide", &pid)
    item.PuzzlePid := pid
    item.End := now + 1000
    item.Note := "Preparing puzzle"
}
AdvanceSlidingPuzzle(item, now) {
    if !item.HasOwnProp("PuzzlePid")
        return
    state := ""
    try state := Trim(FileRead(item.PuzzleFile, "UTF-8"), Chr(13) Chr(10))
    packet := Fields(state)
    if packet.Length >= 5 && packet[1] = item.PuzzlePid {
        switch packet[3] {
            case "ready":
                item.PuzzleReady := true
                item.Note := "Solve puzzle · " packet[4] " moves"
            case "solved":
                FinishEffect("Puzzle solved")
                return
            case "stopped", "error":
                FinishEffect(packet[4])
                return
        }
    }
    if !ProcessExist(item.PuzzlePid) {
        FinishEffect(item.PuzzleReady ? "Puzzle interrupted" : "Puzzle could not start; see input log")
        return
    }
    if !item.PuzzleReady && now >= item.PuzzleUntil {
        FinishEffect("Puzzle startup timed out")
        return
    }
    item.End := now + 1000
}
StopSlidingPuzzle(item) {
    if item.HasOwnProp("PuzzleFile")
        try WriteAtomic(item.PuzzleFile ".cancel", "cancel")
}
