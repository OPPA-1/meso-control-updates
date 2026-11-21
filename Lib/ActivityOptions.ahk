

SlotProfileSafe(name) {
    name := Trim(String(name))
    if name = ""
        return "Default"
    name := SubStr(RTrim(RegExReplace(name, '[\\/:*?"<>|]', '_'), " ."), 1, 48)
    return name = "" ? "Default" : name
}

SlotOptionsPath(profile := "") {
    global CurrentActivityProfile, ProfilesDir
    if profile = ""
        profile := CurrentActivityProfile
    profile := SlotProfileSafe(profile)
    return profile = "Default" ? A_ScriptDir "\Slots_Options.ini" : ProfilesDir "\slots_" profile ".ini"
}

LoadActivityProfileNames() {
    global ProfilesDir
    names := ["Default"]
    if DirExist(ProfilesDir) {
        loop files ProfilesDir "\slots_*.ini" {
            name := RegExReplace(A_LoopFileName, '^slots_(.*)\.ini$', '$1')
            if name != "" && name != "Default"
                names.Push(name)
        }
    }
    return names
}

RefreshActivityProfileDrop() {
    global ActivityProfileDrop, CurrentActivityProfile
    if !IsSet(ActivityProfileDrop) || !IsObject(ActivityProfileDrop)
        return
    names := LoadActivityProfileNames()
    ActivityProfileDrop.Delete()
    ActivityProfileDrop.Add(names)
    idx := 1
    for i, n in names
        if n = CurrentActivityProfile
            idx := i
    ActivityProfileDrop.Choose(idx)
}

SetActivityProfile(name) {
    global CurrentActivityProfile, SlotOptionRecords
    name := SlotProfileSafe(name)
    CurrentActivityProfile := name
    SlotOptionRecords := LoadSlotOptionRecords()
    SaveAppSettings()
    RefreshActivityProfileDrop()
    ActivityRefreshOptions()
}

ActivityProfileChanged(*) {
    global ActivityProfileDrop
    SetActivityProfile(ActivityProfileDrop.Text)
}

NewActivityProfile(*) {
    global SlotOptionRecords
    ib := InputBox('Enter a profile name.', 'New activity profile', 'w280 h120')
    if ib.Result != 'OK'
        return
    name := SlotProfileSafe(ib.Value)
    if name = ""
        return
    existing := Map()
    for item in LoadActivityProfileNames()
        existing[item] := true
    if existing.Has(name) {
        SetActivityProfile(name)
        return
    }
    SaveSlotOptionRecords(name, SlotOptionRecords)
    SetActivityProfile(name)
}

DeleteActivityProfile(*) {
    global CurrentActivityProfile
    if CurrentActivityProfile = 'Default' {
        MsgBox('The Default profile cannot be deleted.', 'Activity profiles')
        return
    }
    if MsgBox('Delete profile "' CurrentActivityProfile '"?', 'Activity profiles', 'YesNo Icon?') != 'Yes'
        return
    path := SlotOptionsPath(CurrentActivityProfile)
    try FileDelete(path)
    SetActivityProfile('Default')
}

SlotOptionKey(reel, category, group, name) {
    return reel Chr(31) category Chr(31) group Chr(31) name
}

EncodeSlotField(text) {
    text := StrReplace(String(text), "%", "%25")
    text := StrReplace(text, "|", "%7C")
    text := StrReplace(text, "`r", "")
    return StrReplace(text, "`n", " ")
}

DecodeSlotField(text) {
    return StrReplace(StrReplace(text, "%7C", "|"), "%25", "%")
}

LoadSlotOptionRecords(profile := "") {
    path := SlotOptionsPath(profile)
    result := Map()
    countText := IniRead(path, "Options", "Count", "0")
    count := IsNumber(countText) ? Min(3000, Max(0, Integer(countText))) : 0
    loop count {
        raw := IniRead(path, "Options", "Item" A_Index, "")
        fields := StrSplit(raw, "|")
        if fields.Length != 7 || !IsNumber(fields[1]) || !IsNumber(fields[5])
            continue
        reel := Integer(fields[1])
        if reel < 1 || reel > 4
            continue
        category := DecodeSlotField(fields[2])
        group := DecodeSlotField(fields[3])
        name := DecodeSlotField(fields[4])
        if name = "" || StrLen(name) > 90
            continue
        weight := Float(fields[5])
        if weight < 0 || weight > 100
            continue
        rec := {Reel: reel, Category: category, Group: group, Name: name, Weight: weight, Enabled: fields[6] = "1", Custom: fields[7] = "1"}
        result[SlotOptionKey(reel, category, group, name)] := rec
    }
    return result
}

SaveSlotOptionRecords(profile := "", records := "") {
    global SlotOptionRecords
    path := SlotOptionsPath(profile)
    if !IsObject(records)
        records := SlotOptionRecords
    try IniDelete(path, "Options")
    MesoIniWrite(records.Count, path, "Options", "Count")
    i := 0
    for k, rec in records {
        i++
        value := rec.Reel "|" EncodeSlotField(rec.Category) "|" EncodeSlotField(rec.Group) "|" EncodeSlotField(rec.Name) "|" rec.Weight "|" (rec.Enabled ? 1 : 0) "|" (rec.Custom ? 1 : 0)
        MesoIniWrite(value, path, "Options", "Item" i)
    }
}

DefaultSlotNames(reel, category := "", group := "") {
    global ActivityData, ActivityClasses
    switch reel {
        case 1:
            return GetMapKeys(ActivityData)
        case 2:
            return ActivityData.Has(category) ? GetMapKeys(ActivityData[category]) : []
        case 3:
            return ActivityData.Has(category) && ActivityData[category].Has(group) ? ActivityData[category][group].Clone() : []
        case 4:
            return ActivityClasses.Clone()
    }
    return []
}

GetSlotOptions(reel, category := "", group := "") {
    global SlotOptionRecords
    values := []
    seen := Map()
    for name in DefaultSlotNames(reel, category, group) {
        key := SlotOptionKey(reel, category, group, name)
        rec := SlotOptionRecords.Has(key) ? SlotOptionRecords[key].Clone() : {Reel: reel, Category: category, Group: group, Name: name, Enabled: true, Weight: 1.0, Custom: false}
        values.Push(rec)
        seen[StrLower(name)] := true
    }
    for key, rec in SlotOptionRecords {
        if rec.Reel = reel && rec.Category = category && rec.Group = group && rec.Custom && !seen.Has(StrLower(rec.Name)) {
            values.Push(rec.Clone())
            seen[StrLower(rec.Name)] := true
        }
    }
    return values
}

GetSlotChoices(reel, category := "", group := "") {
    result := []
    for rec in GetSlotOptions(reel, category, group) {
        if !rec.Enabled || rec.Weight <= 0
            continue
        if reel = 1 && !GetSlotChoices(2, rec.Name).Length
            continue
        if reel = 2 && !GetSlotChoices(3, category, rec.Name).Length
            continue
        result.Push(rec)
    }
    return result
}

SlotWeightedChoice(options) {
    index := WeightedPick(options)
    return index > 0 ? options[index].Name : ""
}

SlotOptionsToNames(options) {
    result := []
    for item in options
        result.Push(item.Name)
    return result
}

SlotOptionIsDefault(rec) {
    for name in DefaultSlotNames(rec.Reel, rec.Category, rec.Group)
        if StrLower(name) = StrLower(rec.Name)
            return true
    return false
}

BuildActivitySettings(gui) {
    global SlotReelDrop, SlotCategoryDrop, SlotGroupDrop, SlotCategoryLabel, SlotGroupLabel
    global SlotOptionsLV, SlotNameEdit, SlotWeightEdit, SlotEnabledCheck, SlotOptionVisibleRows, SlotSelectedIndex, SlotNoticeLabel
    global ActivityProfileDrop
    gui.SetFont("s11 Bold cF1E7F8", "Segoe UI")
    gui.AddText("x35 y131 w260 h26", "ACTIVITY REELS")
    gui.SetFont("s9 Norm cD4C7E5", "Segoe UI")
    gui.AddText("x441 y132 w50 h22", "Profile")
    ActivityProfileDrop := gui.AddDropDownList("x495 y127 w168", LoadActivityProfileNames())
    ActivityProfileDrop.OnEvent("Change", ActivityProfileChanged)
    apnew := gui.AddButton("x670 y126 w49 h28", "New")
    apnew.OnEvent("Click", NewActivityProfile)
    apdel := gui.AddButton("x724 y126 w52 h28", "Delete")
    apdel.OnEvent("Click", DeleteActivityProfile)
    gui.SetFont("s9 Norm cD4C7E5", "Segoe UI")
    gui.AddText("x35 y171 w71 h23", "Reel")
    SlotReelDrop := gui.AddDropDownList("x105 y166 w240 Choose1", ["1  ·  Type", "2  ·  Destination", "3  ·  Activity", "4  ·  Class"])
    SlotReelDrop.OnEvent("Change", ActivityReelChanged)
    SlotCategoryLabel := gui.AddText("x361 y171 w76 h23", "Type")
    SlotCategoryDrop := gui.AddDropDownList("x427 y166 w345", ["STRIKE"])
    SlotCategoryDrop.OnEvent("Change", ActivityCategoryChanged)
    SlotGroupLabel := gui.AddText("x35 y214 w90 h23", "Destination")
    SlotGroupDrop := gui.AddDropDownList("x130 y207 w641", ["EDZ"])
    SlotGroupDrop.OnEvent("Change", ActivityGroupChanged)
    SlotOptionsLV := gui.AddListView("x35 y246 w741 h204 -Multi NoSortHdr Background181323 cF5EBFF", ["On", "Option", "Weight"])
    SlotOptionsLV.ModifyCol(1, 68)
    SlotOptionsLV.ModifyCol(2, 527)
    SlotOptionsLV.ModifyCol(3, 123)
    DarkTable(SlotOptionsLV)
    SlotOptionsLV.OnEvent("ItemSelect", ActivityOptionSelected)
    gui.AddText("x35 y476 w81 h23", "Name")
    SlotNameEdit := gui.AddEdit("x119 y470 w412 h30 Background241B30 cFFFFFF")
    gui.AddText("x542 y476 w65 h23", "Weight")
    SlotWeightEdit := gui.AddEdit("x601 y470 w91 h30 Number Background241B30 cFFFFFF", "1")
    SlotEnabledCheck := gui.AddCheckbox("x702 y473 w80 h25", "On")
    SlotEnabledCheck.Value := 1
    for spec in [[35, "New", ActivityNewOption, 120], [168, "Save", ActivitySaveOption, 120], [301, "Add", ActivityAddOption, 120], [434, "Remove", ActivityRemoveOption, 120]] {
        button := gui.AddButton("x" spec[1] " y526 w" spec[4] " h35", spec[2])
        button.OnEvent("Click", spec[3])
    }
    SlotNoticeLabel := gui.AddText("x35 y585 w740 h25 cB5A5C9", "")
    SlotOptionVisibleRows := []
    SlotSelectedIndex := 0
    RefreshActivityProfileDrop()
    ActivityReelChanged()
}

ActivityReelChanged(*) {
    global SlotReelDrop, SlotCategoryDrop, SlotCategoryLabel, SlotGroupDrop, SlotGroupLabel
    reel := SlotReelDrop.Value
    hasCategory := reel = 2 || reel = 3
    hasGroup := reel = 3
    for control in [SlotCategoryDrop, SlotCategoryLabel]
        control.Opt(hasCategory ? "-Hidden" : "+Hidden")
    for control in [SlotGroupDrop, SlotGroupLabel]
        control.Opt(hasGroup ? "-Hidden" : "+Hidden")
    if hasCategory {
        names := SlotOptionsToNames(GetSlotOptions(1))
        SlotCategoryDrop.Delete()
        if names.Length {
            SlotCategoryDrop.Add(names)
            SlotCategoryDrop.Choose(1)
        }
    }
    ActivityCategoryChanged()
}

ActivityCategoryChanged(*) {
    global SlotReelDrop, SlotCategoryDrop, SlotGroupDrop
    if SlotReelDrop.Value = 3 {
        groups := SlotOptionsToNames(GetSlotOptions(2, SlotCategoryDrop.Text))
        SlotGroupDrop.Delete()
        if groups.Length {
            SlotGroupDrop.Add(groups)
            SlotGroupDrop.Choose(1)
        }
    }
    ActivityRefreshOptions()
}

ActivityGroupChanged(*) {
    ActivityRefreshOptions()
}

ActivityOptionContext() {
    global SlotReelDrop, SlotCategoryDrop, SlotGroupDrop
    reel := SlotReelDrop.Value
    category := reel = 2 || reel = 3 ? SlotCategoryDrop.Text : ""
    group := reel = 3 ? SlotGroupDrop.Text : ""
    return {Reel: reel, Category: category, Group: group}
}

ActivityRefreshOptions() {
    global SlotOptionsLV, SlotOptionVisibleRows, SlotSelectedIndex, SlotNameEdit, SlotWeightEdit, SlotEnabledCheck, SlotNoticeLabel
    if !IsSet(SlotOptionsLV) || !IsObject(SlotOptionsLV)
        return
    context := ActivityOptionContext()
    SlotOptionVisibleRows := GetSlotOptions(context.Reel, context.Category, context.Group)
    SlotOptionsLV.Opt("-Redraw")
    try {
        SlotOptionsLV.Delete()
        for rec in SlotOptionVisibleRows
            SlotOptionsLV.Add("", rec.Enabled ? "ON" : "OFF", rec.Name, rec.Weight)
    } finally SlotOptionsLV.Opt("+Redraw")
    SlotSelectedIndex := 0
    SlotNameEdit.Value := ""
    SlotNameEdit.Enabled := true
    SlotWeightEdit.Value := "1"
    SlotEnabledCheck.Value := 1
    SetText(SlotNoticeLabel, SlotOptionVisibleRows.Length " options")
}

ActivityOptionSelected(control, index, selected) {
    global SlotOptionVisibleRows, SlotSelectedIndex, SlotNameEdit, SlotWeightEdit, SlotEnabledCheck
    if !selected || index < 1 || index > SlotOptionVisibleRows.Length
        return
    SlotSelectedIndex := index
    rec := SlotOptionVisibleRows[index]
    SlotNameEdit.Value := rec.Name
    SlotNameEdit.Enabled := false
    SlotWeightEdit.Value := rec.Weight
    SlotEnabledCheck.Value := rec.Enabled
}

ActivityNewOption(*) {
    global SlotSelectedIndex, SlotOptionsLV, SlotNameEdit, SlotWeightEdit, SlotEnabledCheck
    SlotSelectedIndex := 0
    SlotOptionsLV.Modify(0, "-Select")
    SlotNameEdit.Enabled := true
    SlotNameEdit.Value := ""
    SlotWeightEdit.Value := "1"
    SlotEnabledCheck.Value := 1
    SlotNameEdit.Focus()
}

ActivityValidWeight() {
    global SlotWeightEdit
    value := Trim(SlotWeightEdit.Value)
    if !IsNumber(value) || Float(value) < 0 || Float(value) > 100 {
        MsgBox("Weight must be between 0 and 100.", "Activities")
        return -1
    }
    return Float(value)
}

ActivitySaveOption(*) {
    global SlotSelectedIndex, SlotOptionVisibleRows, SlotWeightEdit, SlotEnabledCheck, SlotOptionRecords
    if SlotSelectedIndex < 1 || SlotSelectedIndex > SlotOptionVisibleRows.Length
        return
    weight := ActivityValidWeight()
    if weight < 0
        return
    rec := SlotOptionVisibleRows[SlotSelectedIndex].Clone()
    rec.Weight := weight
    rec.Enabled := SlotEnabledCheck.Value = 1
    key := SlotOptionKey(rec.Reel, rec.Category, rec.Group, rec.Name)
    if !rec.Custom && rec.Enabled && rec.Weight = 1 {
        if SlotOptionRecords.Has(key)
            SlotOptionRecords.Delete(key)
    } else
        SlotOptionRecords[key] := rec
    SaveSlotOptionRecords()
    ActivityRefreshOptions()
}

ActivityAddOption(*) {
    global SlotNameEdit, SlotWeightEdit, SlotEnabledCheck, SlotOptionRecords
    context := ActivityOptionContext()
    name := Trim(SlotNameEdit.Value)
    if name = "" || StrLen(name) > 80 || InStr(name, "`n") || InStr(name, "`r") {
        MsgBox("Enter an option name (1–80 characters).", "Activities")
        return
    }
    for rec in GetSlotOptions(context.Reel, context.Category, context.Group) {
        if StrLower(rec.Name) = StrLower(name) {
            MsgBox("That option already exists. Select it to edit its weight.", "Activities")
            return
        }
    }
    weight := ActivityValidWeight()
    if weight < 0
        return
    rec := {Reel: context.Reel, Category: context.Category, Group: context.Group, Name: name, Enabled: SlotEnabledCheck.Value = 1, Weight: weight, Custom: true}
    SlotOptionRecords[SlotOptionKey(rec.Reel, rec.Category, rec.Group, rec.Name)] := rec
    SaveSlotOptionRecords()
    if context.Reel = 1 || context.Reel = 2
        ActivityReelChanged()
    else
        ActivityRefreshOptions()
}

ActivityRemoveOption(*) {
    global SlotSelectedIndex, SlotOptionVisibleRows, SlotOptionRecords
    if SlotSelectedIndex < 1 || SlotSelectedIndex > SlotOptionVisibleRows.Length
        return
    rec := SlotOptionVisibleRows[SlotSelectedIndex]
    if !rec.Custom {
        MsgBox("Built-in options can be turned off or given zero weight.", "Activities")
        return
    }
    if rec.Reel = 1 && GetSlotOptions(2, rec.Name).Length {
        MsgBox("Remove the destinations in this type first.", "Activities")
        return
    }
    if rec.Reel = 2 && GetSlotOptions(3, rec.Category, rec.Name).Length {
        MsgBox("Remove the activities in this destination first.", "Activities")
        return
    }
    key := SlotOptionKey(rec.Reel, rec.Category, rec.Group, rec.Name)
    if SlotOptionRecords.Has(key)
        SlotOptionRecords.Delete(key)
    SaveSlotOptionRecords()
    ActivityRefreshOptions()
}
