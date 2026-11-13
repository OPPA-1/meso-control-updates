DefaultChatBindings() {
    return Map("forward", "w", "back", "s", "left", "a", "right", "d", "jump", "Space", "crouch", "LControl", "sprint", "LShift", "shoot", "LButton", "aim", "RButton", "reload", "r", "interact", "e", "super", "f", "melee", "c", "grenade", "q", "weapon1", "1", "weapon2", "2", "weapon3", "3", "lookleft", "mouse-left", "lookright", "mouse-right", "lookup", "mouse-up", "lookdown", "mouse-down")
}

AllowedChatKey(key) {
    key := StrLower(Trim(key))
    if RegExMatch(key, "^(vk[0-9a-f]{2}sc[0-9a-f]{3}|f(?:[1-9]|1[0-9]|2[0-4])|numpad[a-z0-9]+)$")
        return true
    if RegExMatch(key, "^[a-z0-9]$")
        return true
    return InStr("|space|lcontrol|rcontrol|lshift|rshift|lbutton|rbutton|mbutton|xbutton1|xbutton2|wheelup|wheeldown|wheelleft|wheelright|tab|enter|backspace|delete|insert|home|end|pgup|pgdn|capslock|lalt|ralt|up|down|left|right|mouse-left|mouse-right|mouse-up|mouse-down|", "|" key "|") > 0
}

DefaultChatHold(name) {
    return InStr("|forward|back|left|right|sprint|crouch|shoot|aim|interact|lookleft|lookright|lookup|lookdown|", "|" name "|") > 0
}

ChatHoldDuration(value) {
    if !IsNumber(value)
        return 2000
    return Max(50, Min(10000, Round(Float(value))))
}

ChatCommandNameValid(name) {
    return RegExMatch(StrLower(Trim(name)), "^[a-z0-9][a-z0-9_-]{0,23}$") > 0
}

ChatToken(message) {
    token := StrLower(Trim(message))
    return ChatCommandNameValid(token) ? token : ""
}

ChatRelayAction(message) {
    message := StrLower(Trim(message))
    token := ChatToken(message)
    if token != ""
        return token
    if RegExMatch(message, "^![a-z][a-z0-9_]{0,19}\s+([a-z0-9][a-z0-9_-]{0,23})$", &matched)
        return matched[1]
    return ""
}

ChatAlias(token) {
    aliases := Map("w", "forward", "s", "back", "a", "left", "d", "right", "space", "jump", "ctrl", "crouch", "control", "crouch", "shift", "sprint", "fire", "shoot", "ads", "aim", "air-move", "airmove")
    return aliases.Has(token) ? aliases[token] : token
}

class ChatPolicy {
    __New() {
        this.Bindings := DefaultChatBindings()
        this.BannedText := []
        this.BannedInputs := []
        this.MaxPending := 30
        this.HoldEnabled := Map()
        this.HoldMs := Map()
        this.Mode := "queue"
        this.RepeatEnabled := true
        for name, key in this.Bindings {
            this.HoldEnabled[name] := DefaultChatHold(name)
            this.HoldMs[name] := 2000
        }
        this.Reset()
    }
    Reset() {
        this.Pending := []
        this.ViewerNext := Map()
        this.Seen := Map()
        this.NextGlobal := 0
        this.LastReason := "Waiting for chat"
    }
    Reject(reason) {
        this.LastReason := reason
        return 0
    }
    Accept(id, viewer, message, sent, now, started) {
        if viewer = "" || id = ""
            return this.Reject("Invalid message")
        if this.Seen.Has(id)
            return this.Reject("Already received")
        if sent < started || sent > now + 100 || now - sent > 1200
            return this.Reject("Message expired")
        raw := StrLower(Trim(message))
        for banned in this.BannedText
            if banned != "" && InStr(raw, banned)
                return this.Reject("Blocked phrase")
        token := ChatToken(raw)
        if token = ""
            return this.Reject("Invalid command")
        if !this.Bindings.Has(token)
            token := ChatAlias(token)
        if !this.Bindings.Has(token)
            return this.Reject("Unknown command")
        key := this.Bindings[token]
        if !AllowedChatKey(key)
            return this.Reject("Invalid input")
        for banned in this.BannedInputs {
            blocked := StrLower(Trim(banned))
            if blocked = token || blocked = StrLower(key) || blocked = raw || ChatToken(blocked) = token
                return this.Reject("Blocked input")
        }
        if now < this.NextGlobal || (this.ViewerNext.Has(viewer) && now < this.ViewerNext[viewer])
            return this.Reject("Cooldown")
        if this.Pending.Length >= this.MaxPending
            return this.Reject("Queue full")
        this.Seen[id] := now
        this.ViewerNext[viewer] := now + 750
        this.NextGlobal := now + (this.Mode = "anytime" ? 0 : 100)
        hold := this.HoldEnabled.Has(token) && this.HoldEnabled[token]
        duration := hold ? ChatHoldDuration(this.HoldMs.Has(token) ? this.HoldMs[token] : 2000) : 90
        this.Pending.Push({Token: token, Key: key, Viewer: viewer, Duration: duration, Hold: hold, Repeat: this.RepeatEnabled, Expires: now + 32000})
        this.LastReason := this.Mode = "anytime" ? "Accepted" : "Queued"
        if this.Seen.Count > 1024 {
            expired := []
            for keyId, tick in this.Seen
                if now - tick > 5000
                    expired.Push(keyId)
            for keyId in expired
                this.Seen.Delete(keyId)
            expired := []
            for viewerName, tick in this.ViewerNext
                if now > tick
                    expired.Push(viewerName)
            for viewerName in expired
                this.ViewerNext.Delete(viewerName)
        }
        return 1
    }
    Take(now) {
        while this.Pending.Length {
            item := this.Pending.RemoveAt(1)
            if now < item.Expires
                return item
        }
        return 0
    }
}
