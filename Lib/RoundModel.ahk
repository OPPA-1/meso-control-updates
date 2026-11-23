class RoundCycle {
    BonusPunishment := false
    BonusChance := 20
    __New(mode := "normal", batch := 5, seconds := 15) {
        this.Configure(mode, batch, seconds)
    }
    Configure(mode, batch, seconds) {
        this.Mode := mode = "auto" || mode = "batch" ? mode : "normal"
        this.BatchSize := Max(1, Min(50, Integer(batch)))
        this.CooldownMs := Max(0, Min(3600000, Round(seconds * 1000)))
        this.Reset()
    }
    Reset() {
        this.Phase := "idle"
        this.Remaining := 0
        this.CooldownUntil := 0
        this.CooldownStart := 0
    }
    Tick(now, hasWork := false) {
        if this.Mode = "normal"
            return
        if this.Phase = "cooldown" && now >= this.CooldownUntil {
            this.Phase := "idle"
            this.CooldownUntil := 0
        }
        if this.Phase = "idle" && (this.Mode = "auto" || hasWork) {
            this.Remaining := this.BatchSize
            this.Phase := "running"
        }
    }
    Complete(now) {
        if this.Mode = "normal" || this.Phase != "running"
            return
        this.Remaining := Max(0, this.Remaining - 1)
        if this.Remaining = 0 {
            this.Phase := "cooldown"
            this.CooldownStart := now
            this.CooldownUntil := now + this.CooldownMs
        }
    }
    Bonus(now, count) {
        if this.Mode = "normal"
            return
        if this.Phase = "running"
            this.Remaining += count
        else {
            this.Remaining := count
            this.Phase := "running"
        }
        this.CooldownUntil := 0
        this.CooldownStart := 0
    }
    Cooling(now) {
        return this.Mode != "normal" && this.Phase = "cooldown" && now < this.CooldownUntil
    }
}

