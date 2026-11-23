CompactEffectNote(note) {
    if InStr(note, "Waiting for Destiny") || InStr(note, "Waiting for a permitted") || note = "Waiting for game focus"
        return "Focus game"
    if InStr(note, "Waiting for ")
        return "Queued"
    if note = "Active" || note = "Input blocked"
        return ""
    return SubStr(note, 1, 48)
}

ActiveEffectLabel(name) {
    return SubStr(name, 1, 50)
}
