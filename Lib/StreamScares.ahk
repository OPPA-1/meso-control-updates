SyncSpecialSounds(now) {
    global State, OutputSpecialSounds
    static serial := 0
    if !IsSet(OutputSpecialSounds)
        OutputSpecialSounds := Map()
    wanted := Map()
    for event in State.Sounds {
        if event.Until && now >= event.Until
            continue
        wanted[event.Id] := true
        if OutputSpecialSounds.Has(event.Id) {
            playing := OutputSpecialSounds[event.Id]
            if event.Name = "321.wav" || event.Name = "scare1" || event.Name = "scare2"
                Mci("setaudio " playing " volume to " ScareVolume(true)*10)
            if event.Repeat && MciStatus(playing, "mode") = "stopped"
                Mci("play " playing " from 0")
            continue
        }
        serial += 1
        alias := "mesospecial" serial
        try {
            path := SpecialAudioPath(event.Name)
            if Mci("open " Chr(34) path Chr(34) " alias " alias)
                throw Error("Could not open " event.Name)
            volume := event.Name = "321.wav" || event.Name = "scare1" || event.Name = "scare2" ? ScareVolume(true)*10 : 1000
            Mci("setaudio " alias " volume to " volume)
            status := Mci("play " alias " from 0" (event.Repeat ? " repeat" : ""))
            if status && event.Repeat
                status := Mci("play " alias " from 0")
            if status
                throw Error("Could not play " event.Name)
            OutputSpecialSounds[event.Id] := alias
        } catch as err {
            Mci("close " alias)
            LogEvent("Stream audio: " err.Message)
        }
    }
    for id, alias in OutputSpecialSounds.Clone() {
        if !wanted.Has(id) {
            Mci("close " alias)
            OutputSpecialSounds.Delete(id)
        }
    }
}

StopOutputSpecialSounds() {
    global OutputSpecialSounds
    if IsSet(OutputSpecialSounds) {
        for id, alias in OutputSpecialSounds
            Mci("close " alias)
        OutputSpecialSounds := Map()
    }
}
