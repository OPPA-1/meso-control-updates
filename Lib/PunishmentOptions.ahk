IsNew600Action(action) {
    return InStr("|Turn M&K Off|Alt+Enter|Wide View|Change Mouse Sensitivity|", "|" action "|") > 0
}

PunishmentVaries(p) {
    return p.HasOwnProp("Vary") ? p.Vary : p.Action = "Change Mouse Sensitivity"
}

PunishmentGridChoices() {
    return ["2x3", "3x4", "4x5", "5x6"]
}

PunishmentGrid(value) {
    return RegExMatch(value, "^[2-5]x[2-6]$") ? value : "2x3"
}

PunishmentValueRange(action) {
    switch action {
        case "Lights Out": return {Min: 100, Max: 240, Default: 210, Label: "100 to 240"}
        case "Tunnel Vision": return {Min: 1.1, Max: 4.0, Default: 2.0, Label: "1.1x to 4.0x"}
        case "Wide View": return {Min: 0.25, Max: 0.95, Default: 0.75, Label: "0.25x to 0.95x"}
        case "Change Mouse Sensitivity": return {Min: 0.1, Max: 5.0, Default: 0.5, Label: "0.1x to 5.0x"}
    }
    return 0
}

FixedPunishmentValue(p) {
    limits := PunishmentValueRange(p.Action)
    if !IsObject(limits)
        return p.Value
    return Max(limits.Min, Min(limits.Max, p.Value > 0 ? p.Value : limits.Default))
}

VisualStrength(p, hit) {
    switch p.Action {
        case "Lights Out": return hit ? Min(240, 155 + (hit - 1) * 22) : FixedPunishmentValue(p)
        case "Tunnel Vision": return hit ? Min(4.0, 1.5 + (hit - 1) * 0.35) : FixedPunishmentValue(p)
        case "Wide View": return hit ? Max(0.25, 0.8 - (hit - 1) * 0.10) : FixedPunishmentValue(p)
        case "Screen Shuffle":
            options := PunishmentGridChoices()
            return PunishmentVaries(p) ? options[Random(1, options.Length)] : p.HasOwnProp("Grid") ? p.Grid : "2x3"
        default: return p.Value > 0 ? p.Value : 210
    }
}
