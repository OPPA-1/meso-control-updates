SpecialAudioPath(name) {
    global RuntimeDir
    if name = "1.wav" || name = "2.wav"
        return A_ScriptDir "\" name
    if name = "scare1" || name = "scare2" {
        data := name = "scare1" ? ScareAudio1Data() : ScareAudio2Data()
        return DecodeScareAudio(RuntimeDir "\" name "-612.wav", data)
    }
    return SonionMediaFile(RuntimeDir, name)
}

DecodeScareAudio(path, data) {
    if FileExist(path)
        return path
    size := 0
    if !DllCall("crypt32\CryptStringToBinaryW", "WStr", data, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0)
        throw Error("Invalid jumpscare audio")
    bytes := Buffer(size)
    if !DllCall("crypt32\CryptStringToBinaryW", "WStr", data, "UInt", 0, "UInt", 1, "Ptr", bytes, "UInt*", &size, "Ptr", 0, "Ptr", 0)
        throw Error("Could not decode jumpscare audio")
    file := FileOpen(path, "w")
    try file.RawWrite(bytes, size)
    finally file.Close()
    return path
}

ScareDefinition(name) {
    switch name {
        case "scare1": return {Frames: 14, Fps: 50/3, W: 384, H: 288, Duration: 840}
        case "scare2": return {Frames: 1, Fps: 1, W: 1227, H: 1281, Duration: 1000}
        case "jeff": return {Frames: 1, Fps: 1, W: 760, H: 427, Duration: 3200}
    }
    throw Error("Unknown jumpscare")
}

DrawScareFrame(canvas, picture, definition, elapsed, w, h) {
    frame := Min(definition.Frames - 1, Max(0, Floor(elapsed * definition.Fps / 1000)))
    sx := Mod(frame, 4) * definition.W, sy := Floor(frame / 4) * definition.H
    scale := Min(w / definition.W, h / definition.H)
    dw := Round(definition.W * scale), dh := Round(definition.H * scale)
    DllCall("gdiplus\GdipDrawImageRectRectI", "Ptr", canvas.G, "Ptr", picture,
        "Int", (w - dw)//2, "Int", (h - dh)//2, "Int", dw, "Int", dh,
        "Int", sx, "Int", sy, "Int", definition.W, "Int", definition.H,
        "Int", 2, "Ptr", 0, "Ptr", 0, "Ptr", 0)
}

SonionUiAsset(name) {
    SplitPath(A_LineFile,, &scriptFolder)
    return scriptFolder "\..\Ui\" name
}

SonionMediaFile(dir, name) {
    if name = "ringring.mp3" {
        custom := SonionUiAsset(name)
        if FileExist(custom)
            return custom
        data := SonionRingtoneData()
    } else
        data := name = "321.wav" ? SonionScreamData() : SonionGlitchData()
    path := dir "\sonion-612-" name
    if FileExist(path)
        return path
    size := 0
    if !DllCall("crypt32\CryptStringToBinaryW", "WStr", data, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0, "Int")
        throw Error("Sonion audio size could not be read")
    bytes := Buffer(size)
    if !DllCall("crypt32\CryptStringToBinaryW", "WStr", data, "UInt", 0, "UInt", 1, "Ptr", bytes, "UInt*", &size, "Ptr", 0, "Ptr", 0, "Int")
        throw Error("Sonion audio could not be decoded")
    audio := FileOpen(path, "w")
    try audio.RawWrite(bytes, size)
    finally audio.Close()
    return path
}
