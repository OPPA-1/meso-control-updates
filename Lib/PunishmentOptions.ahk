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

VisualStrength(p, hit) {
    switch p.Action {
        case "Lights Out": return hit ? Min(240, 155 + (hit - 1) * 22) : p.Value > 0 ? p.Value : 210
        case "Tunnel Vision": return hit ? Min(4.0, 1.5 + (hit - 1) * 0.35) : p.Value > 0 ? p.Value : 2.0
        case "Wide View": return hit ? Max(0.25, 0.8 - (hit - 1) * 0.10) : p.Value > 0 ? p.Value : 0.75
        case "Screen Shuffle":
            options := PunishmentGridChoices()
            return PunishmentVaries(p) ? options[Random(1, options.Length)] : p.HasOwnProp("Grid") ? p.Grid : "2x3"
        default: return p.Value > 0 ? p.Value : 210
    }
}
