ScoreNumber(value, fallback := 0) {
    value := Trim(String(value))
    if !RegExMatch(value, "^\d{1,4}$")
        return fallback
    return Integer(value)
}
