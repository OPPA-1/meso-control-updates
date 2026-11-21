from pathlib import Path
r=Path.cwd()
def read(p): return (r/p).read_text(encoding='utf-8-sig')
def write(p,s):
 q=r/p; old=q.read_bytes() if q.exists() else b''; nl='\r\n' if b'\r\n' in old else '\n'
 q.parent.mkdir(parents=True,exist_ok=True)
 q.write_bytes((b'\xef\xbb\xbf' if old.startswith(b'\xef\xbb\xbf') else b'')+s.replace('\r\n','\n').replace('\n',nl).encode())
def edit(p,a,b):
 s=read(p)
 assert a in s,(p,a[:100])
 write(p,s.replace(a,b))
edit('Lib/Sensitivity.ahk','if fields[1] = "ready" && fields.Length = 3 && !item.SensitivityReady {','if fields.Length = 3 && fields[1] = "ready" && IsNumber(fields[2]) && IsNumber(fields[3]) && fields[3] >= fields[2] && !item.SensitivityReady {')
edit('Lib/Sensitivity.ahk','} else if fields[1] = "restored" {','} else if fields.Length = 1 && fields[1] = "restored" {')
edit('Lib/Sensitivity.ahk','fields := StrSplit(state, "|")','fields := SensitivityStatusFields(state)')
write('Lib/Sensitivity.ahk',read('Lib/Sensitivity.ahk')+'''
SensitivityStatusFields(state) {
    state := Trim(state, Chr(13) Chr(10) " " Chr(0xFEFF))
    fields := StrSplit(state, "|")
    if !fields.Length
        return []
    if fields[1] = "ready" && (fields.Length != 3 || !IsNumber(fields[2]) || !IsNumber(fields[3]))
        return []
    return fields
}
''')
write('Lib/AltEnter.ahk',read('Lib/AltEnter.ahk')+'''
SequenceBusy(now := 0) {
    global Sonion, HorrorEvents, ScareQueue, ActiveScare
    if !now
        now := NowMs()
    if IsSet(Sonion) && IsObject(Sonion)
        return true
    if IsSet(ScareQueue) && ScareQueue.Length || IsSet(ActiveScare) && IsObject(ActiveScare)
        return true
    if IsSet(HorrorEvents)
        for event in HorrorEvents
            if now < event.Due + 100000
                return true
    return false
}

CancelSequenceAltEnter() {
    global ActiveEffects
    if !IsSet(ActiveEffects)
        return
    for item in ActiveEffects.Clone()
        if item.P.Action = "Alt+Enter"
            WithEffect(item, FinishEffect, "Sequence starting")
}
''')
write('Lib/EffectLabels.ahk','''CompactEffectNote(note) {
    if InStr(note, "Waiting for Destiny") || InStr(note, "Waiting for a permitted") || note = "Waiting for game focus"
        return "Focus game"
    if InStr(note, "Waiting for ")
        return "Queued"
    if note = "Active" || note = "Input blocked"
        return ""
    return SubStr(note, 1, 48)
}
''')
edit('Meso_Control.ahk','if p.Action = "Chat Control" && !ChatEnabled','if p.Action = "Alt+Enter" && SequenceBusy()\n            continue\n        if p.Action = "Chat Control" && !ChatEnabled')
edit('Lib/Effects.ahk','    p := Effect.P\n    for other in ActiveEffects {','    p := Effect.P\n    if p.Action = "Alt+Enter" && SequenceBusy(now) {\n        Effect.Note := "Waiting for sequence"\n        return false\n    }\n    for other in ActiveEffects {')
edit('Lib/Editor.ahk','{Name: "Jumpscare", Enabled: true, Duration: 1,','{Name: "Sliding Puzzle", Enabled: true, Duration: 1, Weight: 2, Action: "Sliding Puzzle", Keys: "", Value: 0, Grid: "3x3", Vary: false},\n        {Name: "Jumpscare", Enabled: true, Duration: 1,')
edit('Lib/Editor.ahk','return ["Jumpscare",','return ["Sliding Puzzle", "Jumpscare",')
edit('Lib/Editor.ahk','Grid: PunishmentGrid(IniRead(path, section, "Grid", "2x3"))','Grid: action = "Sliding Puzzle" ? SlidingPuzzleGrid(IniRead(path, section, "Grid", "3x3")) : PunishmentGrid(IniRead(path, section, "Grid", "2x3"))')
edit('Lib/Editor.ahk','    if needsSave {','    if IniRead(path, "Meta", "Feature612", "0") != "1" {\n        if !exists.Has("Sliding Puzzle") && result.Length < 200\n            for p in defaults\n                if p.Action = "Sliding Puzzle"\n                    result.Push(p.Clone())\n        needsSave := true\n    }\n    if needsSave {')
edit('Lib/Editor.ahk','IniWrite("1", staged, "Meta", "Feature610")','IniWrite("1", staged, "Meta", "Feature610")\n        IniWrite("1", staged, "Meta", "Feature612")')
edit('Lib/Editor.ahk','    for i, size in PunishmentGridChoices()','    EditorGrid.Delete()\n    EditorGrid.Add(p.Action = "Sliding Puzzle" ? ["3x3", "4x4"] : PunishmentGridChoices())\n    for i, size in (p.Action = "Sliding Puzzle" ? ["3x3", "4x4"] : PunishmentGridChoices())')
edit('Lib/Editor.ahk','"Screen Shuffle", "Grid",','"Screen Shuffle", "Grid", "Sliding Puzzle", "Grid",')
edit('Lib/Editor.ahk','|Screen Shuffle|Change Mouse Sensitivity|','|Screen Shuffle|Sliding Puzzle|Change Mouse Sensitivity|')
edit('Lib/Editor.ahk','action = "Screen Shuffle" || action = "Change Mouse Sensitivity" ?','action = "Screen Shuffle" || action = "Sliding Puzzle" || action = "Change Mouse Sensitivity" ?')
edit('Lib/Editor.ahk','EditorGrid.Visible := action = "Screen Shuffle"','''EditorGrid.Visible := action = "Screen Shuffle" || action = "Sliding Puzzle"
    choices := action = "Sliding Puzzle" ? ["3x3", "4x4"] : PunishmentGridChoices()
    if EditorGrid.Visible && EditorGrid.Text != "" && !(action = "Sliding Puzzle" ? RegExMatch(EditorGrid.Text, "^[34]x[34]$") : RegExMatch(EditorGrid.Text, "^[2-5]x[2-6]$")) {
        EditorGrid.Delete()
        EditorGrid.Add(choices)
        EditorGrid.Choose(1)
    }''')
edit('Lib/Editor.ahk','EditorValue.Visible := valueLabels.Has(action) && action != "Screen Shuffle"','EditorValue.Visible := valueLabels.Has(action) && action != "Screen Shuffle" && action != "Sliding Puzzle"')
edit('Lib/Editor.ahk','Grid: PunishmentGrid(EditorGrid.Text)','Grid: action = "Sliding Puzzle" ? SlidingPuzzleGrid(EditorGrid.Text) : PunishmentGrid(EditorGrid.Text)')
for p,prefix in [('Meso_Control.ahk',''),('Tests/Feature600Tests.ahk','..\\')]:
 inc='#Include '+prefix+'Lib\\Sensitivity.ahk'
 edit(p,inc,inc+'\n'+'\n'.join('#Include '+prefix+'Lib\\'+name+'.ahk' for name in ['SlidingPuzzle','PuzzleModel','InteractionPointer','ScareLocalAudio','EffectLabels']))
edit('Lib/Effects.ahk','} else if p.Action = "Alt+Enter" {','} else if p.Action = "Sliding Puzzle" {\n        try StartSlidingPuzzle(Effect, now)\n        catch as err {\n            BlockEffect(err.Message, now)\n            return false\n        }\n    } else if p.Action = "Alt+Enter" {')
edit('Lib/Effects.ahk','    ReleaseDueKeys(now)\n    CheckVisualWorker(now)','    if Effect.P.Action = "Sliding Puzzle" && !Effect.Preview && Effect.Phase = "running" {\n        AdvanceSlidingPuzzle(Effect, now)\n        return\n    }\n    ReleaseDueKeys(now)\n    CheckVisualWorker(now)')
edit('Lib/Effects.ahk','    try StopSensitivityWorker(Effect)','    try StopSlidingPuzzle(Effect)\n    try StopSensitivityWorker(Effect)')
edit('Lib/Effects.ahk','    if a = b\n        return','    if a = "Sliding Puzzle" || b = "Sliding Puzzle"\n        return true\n    if a = b\n        return')
edit('Lib/Sonion.ahk','    LayoutSonionPhones(call, now)\n    call.Next := now + 38','    UpdateInteractionPointer(call)\n    LayoutSonionPhones(call, now)\n    call.Next := now + 16')
edit('Lib/Sonion.ahk','CloseSonionWindows(call) {','CloseSonionWindows(call) {\n    CloseInteractionPointer(call)')
edit('Lib/Sonion.ahk','    index := call.Phones.Length + 1','    firstPhone := call.Phones.Length = 0\n    index := call.Phones.Length + 1')
edit('Lib/Sonion.ahk','    call.Panel := phone','    call.Panel := phone\n    UpdateInteractionPointer(call, firstPhone)')
edit('Lib/Sonion.ahk','    preview := IsObject(stage)','    CancelSequenceAltEnter()\n    preview := IsObject(stage)')
edit('Meso_Control.ahk','    HorrorEvents.Push({Id: NewId(), Due: due})','    CancelSequenceAltEnter()\n    HorrorEvents.Push({Id: NewId(), Due: due})')
edit('Lib/ScareAssets.ahk','Frames: 14, Fps: 25, W: 384, H: 288, Duration: 560','Frames: 14, Fps: 50/3, W: 384, H: 288, Duration: 840')
edit('Lib/ScareAssets.ahk','Frames: 15, Fps: 49.5, W: 384, H: 384, Duration: 303','Frames: 1, Fps: 1, W: 1227, H: 1281, Duration: 1000')
edit('Lib/ScareAssets.ahk','"-610.wav"','"-612.wav"')
edit('Lib/ScareAssets.ahk','"\\sonion-610-"','"\\sonion-612-"')
edit('Lib/ScareAssets.ahk','    if name = "scare1"','    if name = "1.wav" || name = "2.wav"\n        return A_ScriptDir "\\" name\n    if name = "scare1"')
edit('Lib/ScareMedia.ahk','    WinGetClientPos(&x, &y, &w, &h, "ahk_id " target)','''    monitor := DllCall("user32\\MonitorFromWindow", "Ptr", target, "UInt", 2, "Ptr")
    info := Buffer(40, 0)
    NumPut("UInt", 40, info)
    if !DllCall("user32\\GetMonitorInfoW", "Ptr", monitor, "Ptr", info)
        throw Error("Could not find the game monitor")
    x := NumGet(info, 4, "Int"), y := NumGet(info, 8, "Int")
    w := NumGet(info, 12, "Int") - x, h := NumGet(info, 16, "Int") - y''')
edit('Lib/ScareMedia.ahk','name = "jeff" ? "sonion_jeff.png" : name ".png"','name = "jeff" ? "sonion_jeff.png" : name = "scare2" ? "omni.png" : "scare1.png"')
edit('Lib/ScareMedia.ahk','        state.Sound := SpecialSound','        PlayLocalScare(name = "jeff" ? "321.wav" : name, def.Duration)\n        state.Sound := SpecialSound')
edit('Lib/ScareMedia.ahk','    ScareQueue := []\n    StopScareVisual','    ScareQueue := []\n    StopLocalScares()\n    StopScareVisual')
edit('Meso_Control.ahk','        AdvanceScares(now)','        AdvanceScares(now)\n        AdvanceLocalScares(now)')
edit('Meso_Control.ahk','item.Preview ? "" : item.Note, item.Start','item.Preview ? "" : CompactEffectNote(item.Note), item.Start')
edit('version.ini','6.1.1','6.1.2')
edit('Lib/Updates.ahk','"6.1.1"','"6.1.2"')
print('Core 6.1.2 source prepared')
