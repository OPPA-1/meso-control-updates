exec((__import__('pathlib').Path('Tests/Prepare612Core.py').read_text()).split("edit('Lib/Sensitivity.ahk'")[0])
edit('Tests/Feature600Tests.ahk','    TestFeature611()','    TestFeature611()\n    TestFeature612()')
edit('Tests/Feature600Tests.ahk','ScareDefinition(name).Duration < 1000','ScareDefinition(name).Duration <= 1000')
write('Tests/Feature600Tests.ahk',read('Tests/Feature600Tests.ahk')+r'''
TestFeature612() {
    global RuntimeDir, ConfigFile, HorrorEvents, Sonion, ScareQueue, ActiveScare
    Check(SlidingPuzzleGrid("bad")="3x3" && SlidingPuzzleGrid("4x4")="4x4", "Puzzle defaults to fixed 3x3")
    for n in [3,4] {
        loop 30 {
            board := PuzzleShuffle(n), seen := Map(), inversions := 0, blank := 0
            for i,tile in board {
                seen[tile] := true
                if !tile
                    blank := i
                if tile
                    for j,other in board
                        if j>i && other && tile>other
                            inversions++
            }
            Check(seen.Count=n*n && seen.Has(0) && !PuzzleSolved(board), "Puzzle has every tile and one gap")
            solvable := Mod(n,2) ? !Mod(inversions,2) : Mod(inversions+n-(blank-1)//n,2)=1
            Check(solvable, "Every 3x3 and 4x4 layout is solvable")
            for neighbor in PuzzleNeighbors(blank,n)
                Check(PuzzleAdjacent(blank,neighbor,n), "Puzzle moves only adjacent tiles")
        }
    }
    Check(!PuzzleAdjacent(3,4,3) && !PuzzleAdjacent(4,5,4), "Puzzle cannot wrap across rows")
    Check(PuzzleSolved([1,2,3,4,5,6,7,8,0]), "Solved puzzle is recognized")
    Check(!SensitivityStatusFields("").Length && !SensitivityStatusFields("ready|1").Length && !SensitivityStatusFields("ready|x|2").Length, "Empty and partial sensitivity status is safe")
    path := RuntimeDir "\pending-raw.state"
    item := {Phase:"running", SensitivityPid:ProcessExist(), SensitivityFile:path, SensitivityCheck:0, SensitivityReady:false, SensitivityStartup:NowMs()+8000, End:NowMs()+8000, Sensitivity:3.0}
    loop 5 {
        item.SensitivityCheck := 0
        WriteAtomic(path,"")
        CheckSensitivityWorker(item,NowMs())
        Check(!item.SensitivityReady,"Sensitivity tolerates empty status while its worker starts")
    }
    start := NowMs()
    WriteAtomic(path,"ready|" start "|" (start+1000))
    item.SensitivityCheck := 0
    CheckSensitivityWorker(item,start)
    Check(item.SensitivityReady && item.End=start+1000 && InStr(item.Note,"High"),"Sensitivity starts only after worker acknowledgement")
    WriteAtomic(path,"restored")
    item.SensitivityCheck := 0
    CheckSensitivityWorker(item,start+100)
    Check(item.End=start+100,"Restoration ends the sensitivity effect")
    Check(ScareDefinition("scare1").Fps=50/3 && ScareDefinition("scare1").Duration=840,"FNAF 1 uses its original frame rate and duration")
    Check(ScareDefinition("scare2").Frames=1 && FileExist(A_ScriptDir "\..\Ui\omni.png"),"Omni replaces the second visual with its linked audio slot")
    Check(!FileExist(A_ScriptDir "\..\Ui\scare2.png"),"FNAF 2 visual is removed")
    IniWrite(26,ConfigFile,"Audio","ScareVolume")
    IniWrite(82,ConfigFile,"Audio","ScareOutputVolume")
    Check(ScareVolume()=26 && ScareVolume(true)=82,"Local and output audio sliders are independent")
    IniWrite(0,ConfigFile,"Audio","ScareVolume")
    Check(ScareVolume()=0 && ScareVolume(true)=82,"Local mute preserves output audio")
    Check(CompactEffectNote("Waiting for Destiny 2 - click back into the game")="Focus game","Waiting overlay has a short status")
    savedSonion := Sonion, savedHorror := HorrorEvents, savedQueue := ScareQueue, savedScare := ActiveScare
    try {
        Sonion := 0, HorrorEvents := [], ScareQueue := [], ActiveScare := 0
        Check(!SequenceBusy(1000),"Alt Enter is eligible without a sequence")
        HorrorEvents := [{Due:50000}]
        Check(SequenceBusy(1000),"Queued Tung excludes Alt Enter")
        HorrorEvents := [], Sonion := {Phase:"ringing"}
        Check(SequenceBusy(1000),"Sonion ringing excludes Alt Enter")
        Sonion := {Phase:"accepted"}
        Check(SequenceBusy(1000),"Delayed Jeff excludes Alt Enter")
        Sonion := 0, ScareQueue := [{Due:50000}]
        Check(SequenceBusy(1000),"Queued scares exclude Alt Enter")
    } finally {
        Sonion := savedSonion, HorrorEvents := savedHorror, ScareQueue := savedQueue, ActiveScare := savedScare
    }
    source := FileRead(A_ScriptDir "\..\Lib\Updates.ahk","UTF-8")
    Check(InStr(source,'"ForceAuto", "1"') && InStr(source,"600000") && InStr(source,"SaveUpdateSession()"),"Auto updates default on with ten minute checks and session persistence")
    source := FileRead(A_ScriptDir "\..\Lib\Sonion.ahk","UTF-8")
    Check(InStr(source,"UpdateInteractionPointer(call, firstPhone)") && InStr(source,"CloseInteractionPointer(call)"),"Sonion owns a visible software pointer")
}
''')
s=read('Tests/Feature610Assets.ps1').replace('$db -ge -11 -and $db -le -6 -and $peak -lt 0.951','$db -ge -4 -and $db -le -2 -and $peak -lt 0.991')
s=s.replace('@(@{N=1;W=384;H=288;Frames=14;Seconds=0.560}, @{N=2;W=384;H=384;Frames=15;Seconds=0.303})','@(@{N=1;W=384;H=288;Frames=14;Seconds=0.840})')
s=s.replace("Check-Wave (Embedded 'SonionScream')",'''$omni = [Drawing.Bitmap]::FromFile((Join-Path $Root 'Ui/omni.png'))
try {
    Check ($omni.Width -eq 1227 -and $omni.Height -eq 1281) 'Omni dimensions'
    Check ($omni.GetPixel(0,0).A -eq 0) 'Omni white background is transparent'
} finally { $omni.Dispose() }
Check (!(Test-Path (Join-Path $Root 'Ui/scare2.png'))) 'FNAF 2 visual is removed'
Check-Wave (Embedded 'ScareAudio2') 0.303 'Omni linked 4124 audio'
Check-Wave (Embedded 'SonionScream')''')
write('Tests/Feature610Assets.ps1',s)
write('Tests/Puzzle612Tests.ahk',r'''
#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Include ..\Lib\Core.ahk
#Include ..\Lib\PuzzleModel.ahk
OnError((err, mode) => (FileAppend(err.Message " (" err.File ":" err.Line ")" Chr(10), "*"), ExitApp(1)))
RuntimeDir := A_Temp "\MesoPuzzle612-" NewId()
DirCreate(RuntimeDir)
status := RuntimeDir "\puzzle.state"
game := Gui("-DPIScale","Puzzle test game")
game.BackColor := "56367D"
game.SetFont("s30 cFFFFFF","Segoe UI")
game.AddText("x40 y60 w700 h200","LIVE PUZZLE TEST")
game.Show("x20 y30 w900 h620")
pid := 0
try {
    WinActivate("ahk_id " game.Hwnd)
    cmd := Chr(34) A_AhkPath Chr(34) " " Chr(34) A_ScriptDir "\..\Meso_Sliding_Puzzle.ahk" Chr(34) " " game.Hwnd " 3 " ProcessExist() " " Chr(34) status Chr(34)
    Run(cmd,,, &pid)
    deadline := NowMs()+7500, f := [], text := ""
    while NowMs()<deadline {
        Sleep(50)
        text := ""
        try text := Trim(FileRead(status,"UTF-8"),Chr(13) Chr(10))
        f := Fields(text)
        if f.Length>=5 && (f[3]="ready" || f[3]="error" || f[3]="stopped")
            break
    }
    if f.Length<5 || f[3]!="ready"
        throw Error("Puzzle did not become ready: " text)
    hwnd := Integer(f[5])
    if !WinActive("ahk_id " hwnd)
        throw Error("Puzzle must own foreground so game raw input is suspended")
    board := Fields(Trim(FileRead(status ".board","UTF-8"),Chr(13) Chr(10)))
    blank := 0
    for i,tile in board
        if tile="0"
            blank := i
    move := PuzzleNeighbors(blank,3)[1]
    WinGetClientPos(&x,&y,&w,&h,"ahk_id " hwnd)
    col := Mod(move-1,3), row := (move-1)//3
    mx := x+Round((col+.5)*w/3), my := y+46+Round((row+.5)*(h-46)/3)
    DllCall("user32\SetCursorPos","Int",mx,"Int",my)
    PostMessage(0x201,1,0,,"ahk_id " hwnd)
    Sleep(250)
    f := Fields(Trim(FileRead(status,"UTF-8"),Chr(13) Chr(10)))
    if f.Length<5 || f[3]!="ready" || f[4]!="1"
        throw Error("An adjacent tile must slide into the gap")
    WriteAtomic(status ".cancel","cancel")
    deadline := NowMs()+2500
    while ProcessExist(pid) && NowMs()<deadline
        Sleep(30)
    if ProcessExist(pid)
        throw Error("Puzzle failed to cancel and release input")
    if !WinActive("ahk_id " game.Hwnd)
        throw Error("Puzzle cancellation did not return game focus")
    FileAppend("PASS live puzzle startup, legal slide, focus ownership and cancellation" Chr(10),"*")
} finally {
    if pid && ProcessExist(pid)
        ProcessClose(pid)
    game.Destroy()
    try DirDelete(RuntimeDir,true)
}
ExitApp()
''')
print('6.1.2 regression tests prepared')
