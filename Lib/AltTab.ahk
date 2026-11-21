TrackActiveWindow()
{
    global RecentWindows, LastActiveHwnd, AltTabGui, AltTabActive

    if AltTabActive
        return

    Hwnd := WinExist("A")

    if !Hwnd
        return

    if Hwnd = GuiHwndSafe(AltTabGui)
        return

    if !IsValidAltTabWindow(Hwnd)
        return

    if Hwnd = LastActiveHwnd
        return

    LastActiveHwnd := Hwnd
    ExistingIndex := 0

    for Index, ExistingHwnd in RecentWindows
    {
        if ExistingHwnd = Hwnd
        {
            ExistingIndex := Index
            break
        }
    }

    if ExistingIndex
        RecentWindows.RemoveAt(ExistingIndex)

    RecentWindows.InsertAt(1, Hwnd)

    while RecentWindows.Length > 50
        RecentWindows.Pop()
}

AltTabRelease()
{
    global AltTabActive, AltTabBuilding

    if !AltTabActive
        return

    if AltTabBuilding
        return

    AltTabCommit()
}

AltTabFailsafe()
{
    global AltTabGui, AltTabActive, AltTabBuilding

    if !IsObject(AltTabGui)
        return

    if AltTabBuilding
        return

    LeftAltDown := GetKeyState("LAlt", "P")
    RightAltDown := GetKeyState("RAlt", "P")

    if LeftAltDown || RightAltDown
        return

    try AltTabGui.Hide()

    if AltTabActive
        AltTabCommit()
    else
        CloseAltTabGui()
}

AltTabCycle(Direction)
{
    global AltTabActive, AltTabWindows, AltTabIndex

    LeftAltDown := GetKeyState("LAlt", "P")
    RightAltDown := GetKeyState("RAlt", "P")

    if !LeftAltDown && !RightAltDown
        return

    if !AltTabActive
    {
        AltTabWindows := GetAltTabWindows()

        if AltTabWindows.Length < 2
            return

        AltTabActive := true

        if Direction > 0
            AltTabIndex := 2
        else
            AltTabIndex := AltTabWindows.Length

        BuildAltTabGui()
        SetHighlightImmediate(AltTabIndex)
        return
    }

    AltTabIndex += Direction

    if AltTabIndex > AltTabWindows.Length
        AltTabIndex := 1

    if AltTabIndex < 1
        AltTabIndex := AltTabWindows.Length

    SetHighlightTarget(AltTabIndex)

    CloseAltTabGroupBubble()
}

AltTabCommit()
{
    global AltTabActive, AltTabWindows, AltTabIndex

    if !AltTabActive
    {
        CloseAltTabGui()
        return
    }

    if AltTabIndex < 1 || AltTabIndex > AltTabWindows.Length
    {
        CloseAltTabGui()
        return
    }

    ActivateAltTabWindow(AltTabWindows[AltTabIndex])
}

ActivateAltTabWindow(SelectedWindow)
{
    global AltTabGui, LastActiveHwnd

    if IsObject(AltTabGui)
        try AltTabGui.Hide()

    CloseAltTabGui()

    Sleep(10)

    if WinExist("ahk_id " . SelectedWindow)
    {
        try
        {
            if WinGetMinMax("ahk_id " . SelectedWindow) = -1
                WinRestore("ahk_id " . SelectedWindow)

            WinActivate("ahk_id " . SelectedWindow)
        }
    }

    LastActiveHwnd := 0
}

CloseAltTabGui()
{
    global AltTabActive, AltTabBuilding, AltTabGui, AltTabWindows, AltTabGroups, AltTabIndex
    global AltTabGroupGui, AltTabGroupIndex, AltTabGroupThumbnails
    global AltTabGroupCells, AltTabGroupHoverIndex, AltTabGroupBorders
    global HighlightBorders, AltTabCellPositions
    global HighlightCurrentX, HighlightCurrentY, HighlightTargetX, HighlightTargetY
    global LastAltTabMouseX, LastAltTabMouseY
    global AltTabPreviewThumbnail, AltTabPreviewIndex, AltTabPreviewHwnd
    global AltTabPreviewGui, AltTabPreviewCloseGui, AltTabPreviewCloseRect
    global AltTabBaseGuiWidth, AltTabBaseGuiHeight, AltTabGuiX, AltTabGuiY

    CloseAltTabPreview(false)
    CloseAltTabGroupBubble()

    if IsObject(AltTabGui)
    {
        try AltTabGui.Hide()
        try AltTabGui.Destroy()
    }

    AltTabGui := 0
    AltTabWindows := []
    AltTabGroups := []
    AltTabIndex := 0

    AltTabGroupGui := 0
    AltTabGroupIndex := 0
    AltTabGroupThumbnails := []
    AltTabGroupCells := []
    AltTabGroupHoverIndex := 0
    AltTabGroupBorders := []

    HighlightBorders := []
    AltTabCellPositions := []

    HighlightCurrentX := 0
    HighlightCurrentY := 0
    HighlightTargetX := 0
    HighlightTargetY := 0

    LastAltTabMouseX := -99999
    LastAltTabMouseY := -99999

    AltTabPreviewThumbnail := 0
    AltTabPreviewIndex := 0
    AltTabPreviewHwnd := 0
    AltTabPreviewGui := 0
    AltTabPreviewCloseGui := 0
    AltTabPreviewCloseRect := 0
    AltTabBaseGuiWidth := 0
    AltTabBaseGuiHeight := 0
    AltTabGuiX := 0
    AltTabGuiY := 0

    AltTabBuilding := false
    AltTabActive := false
}

GetAltTabWindows()
{
    global RecentWindows, AltTabGroups

    OrderedWindows := []
    CurrentHwnd := WinExist("A")

    if CurrentHwnd && IsValidAltTabWindow(CurrentHwnd)
        OrderedWindows.Push(CurrentHwnd)

    for _, Hwnd in RecentWindows
    {
        if !WinExist("ahk_id " . Hwnd)
            continue

        if !IsValidAltTabWindow(Hwnd)
            continue

        if !ArrayContains(OrderedWindows, Hwnd)
            OrderedWindows.Push(Hwnd)
    }

    for Hwnd in WinGetList()
    {
        if !IsValidAltTabWindow(Hwnd)
            continue

        if !ArrayContains(OrderedWindows, Hwnd)
            OrderedWindows.Push(Hwnd)
    }

    Groups := []
    GroupMap := Map()

    for _, Hwnd in OrderedWindows
    {
        Key := GetAltTabGroupKey(Hwnd)

        if GroupMap.Has(Key)
        {
            GroupMap[Key].Windows.Push(Hwnd)
            continue
        }

        Group := {
            Key: Key,
            Representative: Hwnd,
            Windows: [Hwnd]
        }

        Groups.Push(Group)
        GroupMap[Key] := Group
    }

    AltTabGroups := Groups

    Representatives := []

    for _, Group in Groups
        Representatives.Push(Group.Representative)

    return Representatives
}

GetAltTabGroupKey(Hwnd)
{
    global AppGui

    if IsObject(AppGui)
    {
        if Hwnd = AppGui.Hwnd
            return "MESO_ALTTAB|" . Hwnd
    }

    ExePath := GetWindowExe(Hwnd)

    if ExePath != ""
        return "EXE|" . StrLower(ExePath)

    try
    {
        ClassName := WinGetClass("ahk_id " . Hwnd)

        if ClassName != ""
            return "CLASS|" . StrLower(ClassName)
    }

    return "HWND|" . Hwnd
}

IsValidAltTabWindow(Hwnd)
{
    global AppGui, AltTabGui, AltTabPreviewGui, AltTabPreviewCloseGui, AltTabGroupGui, SettingsGui, RecorderGui
    if !Hwnd
        return false
    for g in [AltTabGui, AltTabPreviewGui, AltTabPreviewCloseGui, AltTabGroupGui, SettingsGui, RecorderGui]
        if Hwnd = GuiHwndSafe(g)
            return false
    try {
        title := WinGetTitle("ahk_id " Hwnd)
        if title = "Meso Stream Output" || title = "Meso Visual Effect"
            return false
        style := WinGetStyle("ahk_id " Hwnd)
        ex := WinGetExStyle("ahk_id " Hwnd)
        cls := WinGetClass("ahk_id " Hwnd)
        return (style & 0x10000000) && (!(ex & 0x80) || (ex & 0x40000)) && Trim(title) != "" && cls != "Progman" && cls != "WorkerW" && cls != "Shell_TrayWnd"
    }
    return false
}

ArrayContains(ArrayToCheck, Hwnd)
{
    for _, ExistingHwnd in ArrayToCheck
    {
        if ExistingHwnd = Hwnd
            return true
    }

    return false
}

BuildAltTabGui()
{
    global AltTabGui, AltTabWindows, AltTabGroups, AltTabBuilding
    global HighlightBorders, AltTabCellPositions
    global HighlightSize, BorderThickness
    global LastAltTabMouseX, LastAltTabMouseY
    global AltTabBaseGuiWidth, AltTabBaseGuiHeight, AltTabGuiX, AltTabGuiY
    global AltTabPreviewThumbnail, AltTabPreviewIndex

    AltTabBuilding := true

    Switcher := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    Switcher.BackColor := "12071C"
    Switcher.MarginX := 0
    Switcher.MarginY := 0

    AltTabGui := Switcher
    HighlightBorders := []
    AltTabCellPositions := []

    PrimaryMonitor := MonitorGetPrimary()

    MonitorGetWorkArea(
        PrimaryMonitor,
        &ScreenLeft,
        &ScreenTop,
        &ScreenRight,
        &ScreenBottom
    )

    CellWidth := 62
    CellHeight := 62
    IconSize := 40

    ScreenWidth := ScreenRight - ScreenLeft
    ScreenHeight := ScreenBottom - ScreenTop

    MaxColumns := Floor((ScreenWidth - 100) / CellWidth)

    if MaxColumns < 1
        MaxColumns := 1

    WindowCount := AltTabWindows.Length

    if WindowCount < MaxColumns
        Columns := WindowCount
    else
        Columns := MaxColumns

    Rows := Ceil(WindowCount / Columns)

    GuiWidth := (Columns * CellWidth) + 24
    GuiHeight := (Rows * CellHeight) + 24

    OuterBorder := 2

    Switcher.AddText(
        "x0 y0 w" . GuiWidth
        . " h" . OuterBorder
        . " Background7B2CFF",
        ""
    )

    Switcher.AddText(
        "x0 y" . (GuiHeight - OuterBorder)
        . " w" . GuiWidth
        . " h" . OuterBorder
        . " Background7B2CFF",
        ""
    )

    Switcher.AddText(
        "x0 y0 w" . OuterBorder
        . " h" . GuiHeight
        . " Background7B2CFF",
        ""
    )

    Switcher.AddText(
        "x" . (GuiWidth - OuterBorder)
        . " y0 w" . OuterBorder
        . " h" . GuiHeight
        . " Background7B2CFF",
        ""
    )

    for Index, Hwnd in AltTabWindows
    {
        Column := Mod(Index - 1, Columns)
        Row := Floor((Index - 1) / Columns)

        CellX := 12 + (Column * CellWidth)
        CellY := 12 + (Row * CellHeight)

        AltTabCellPositions.Push({
            x: CellX,
            y: CellY,
            w: CellWidth,
            h: CellHeight
        })

        IconX := CellX + 7
        IconY := CellY + 7

        UseRawImage := false
        IconSource := GetAltTabIconSource(Hwnd, &UseRawImage)
        IconAdded := false

        if IconSource != ""
        {
            try
            {
                PicOptions :=
                    "x" . IconX
                    . " y" . IconY
                    . " w" . IconSize
                    . " h" . IconSize
                    . " BackgroundTrans"

                if !UseRawImage
                    PicOptions .= " Icon1"

                Switcher.AddPicture(PicOptions, IconSource)
                IconAdded := true
            }
        }

        if !IconAdded
        {
            Switcher.SetFont("s18 cFFFFFF", "Segoe UI")

            FallbackOptions :=
                "x" . IconX
                . " y" . IconY
                . " w" . IconSize
                . " h" . IconSize
                . " Center BackgroundTrans"

            Switcher.AddText(FallbackOptions, "□")
        }

        if Index <= AltTabGroups.Length
        {
            WindowCountForApp := AltTabGroups[Index].Windows.Length

            if WindowCountForApp > 1
            {
                BadgeText :=
                    WindowCountForApp > 9
                    ? "9+"
                    : WindowCountForApp

                Switcher.SetFont("s7 Bold cFFFFFF", "Segoe UI")

                BadgeX := IconX + IconSize - 12
                BadgeY := IconY + IconSize - 12

                Switcher.AddText(
                    "x" . BadgeX
                    . " y" . BadgeY
                    . " w16 h16"
                    . " Center Background7B2CFF",
                    BadgeText
                )
            }
        }
    }

    TopBorderOptions :=
        "x0 y0 w" . HighlightSize
        . " h" . BorderThickness
        . " Background7B2CFF"

    BottomBorderOptions :=
        "x0 y0 w" . HighlightSize
        . " h" . BorderThickness
        . " Background7B2CFF"

    LeftBorderOptions :=
        "x0 y0 w" . BorderThickness
        . " h" . HighlightSize
        . " Background7B2CFF"

    RightBorderOptions :=
        "x0 y0 w" . BorderThickness
        . " h" . HighlightSize
        . " Background7B2CFF"

    TopBorder := Switcher.AddText(TopBorderOptions, "")
    BottomBorder := Switcher.AddText(BottomBorderOptions, "")
    LeftBorder := Switcher.AddText(LeftBorderOptions, "")
    RightBorder := Switcher.AddText(RightBorderOptions, "")

    HighlightBorders := [
        TopBorder,
        BottomBorder,
        LeftBorder,
        RightBorder
    ]

    GuiX := ScreenLeft + Floor((ScreenWidth - GuiWidth) / 2)
    GuiY := ScreenTop + Floor((ScreenHeight - GuiHeight) / 2)

    AltTabBaseGuiWidth := GuiWidth
    AltTabBaseGuiHeight := GuiHeight
    AltTabGuiX := GuiX
    AltTabGuiY := GuiY
    AltTabPreviewThumbnail := 0
    AltTabPreviewIndex := 0

    ShowOptions :=
        "NoActivate x" . GuiX
        . " y" . GuiY
        . " w" . GuiWidth
        . " h" . GuiHeight

    Switcher.Show(ShowOptions)

    CornerRadius := 16

    try WinSetRegion(
        "0-0 W" . GuiWidth
        . " H" . GuiHeight
        . " R" . CornerRadius
        . "-" . CornerRadius,
        "ahk_id " . Switcher.Hwnd
    )

    try
    {
        DwmCornerPreference := 2
        DllCall(
            "dwmapi\DwmSetWindowAttribute",
            "Ptr", Switcher.Hwnd,
            "UInt", 33,
            "Int*", DwmCornerPreference,
            "UInt", 4
        )
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&LastAltTabMouseX, &LastAltTabMouseY)

    AltTabBuilding := false
}

SetHighlightImmediate(Index)
{
    global AltTabCellPositions
    global HighlightCurrentX, HighlightCurrentY
    global HighlightTargetX, HighlightTargetY

    if Index < 1 || Index > AltTabCellPositions.Length
        return

    Pos := AltTabCellPositions[Index]

    HighlightCurrentX := Pos.x
    HighlightCurrentY := Pos.y
    HighlightTargetX := Pos.x
    HighlightTargetY := Pos.y

    MoveHighlightBorders(
        HighlightCurrentX,
        HighlightCurrentY
    )
}

SetHighlightTarget(Index)
{
    global AltTabCellPositions
    global HighlightTargetX, HighlightTargetY

    if Index < 1 || Index > AltTabCellPositions.Length
        return

    Pos := AltTabCellPositions[Index]

    HighlightTargetX := Pos.x
    HighlightTargetY := Pos.y
}

HighlightAnimationTick()
{
    global AltTabActive, AltTabBuilding, HighlightBorders
    global HighlightCurrentX, HighlightCurrentY
    global HighlightTargetX, HighlightTargetY
    global HighlightEase

    if !AltTabActive
        return

    if AltTabBuilding
        return

    if HighlightBorders.Length != 4
        return

    DeltaX := HighlightTargetX - HighlightCurrentX
    DeltaY := HighlightTargetY - HighlightCurrentY

    if Abs(DeltaX) < 0.4 && Abs(DeltaY) < 0.4
    {
        HighlightCurrentX := HighlightTargetX
        HighlightCurrentY := HighlightTargetY

        MoveHighlightBorders(
            HighlightCurrentX,
            HighlightCurrentY
        )

        return
    }

    HighlightCurrentX += DeltaX * HighlightEase
    HighlightCurrentY += DeltaY * HighlightEase

    MoveHighlightBorders(
        HighlightCurrentX,
        HighlightCurrentY
    )
}

MoveHighlightBorders(X, Y)
{
    global HighlightBorders, HighlightSize, BorderThickness

    if HighlightBorders.Length != 4
        return

    X := Round(X)
    Y := Round(Y)

    try HighlightBorders[1].Move(
        X,
        Y,
        HighlightSize,
        BorderThickness
    )

    try HighlightBorders[2].Move(
        X,
        Y + HighlightSize - BorderThickness,
        HighlightSize,
        BorderThickness
    )

    try HighlightBorders[3].Move(
        X,
        Y,
        BorderThickness,
        HighlightSize
    )

    try HighlightBorders[4].Move(
        X + HighlightSize - BorderThickness,
        Y,
        BorderThickness,
        HighlightSize
    )
}

AltTabMouseTick()
{
    global AltTabActive, AltTabBuilding, AltTabIndex
    global LastAltTabMouseX, LastAltTabMouseY
    global AltTabGroups, AltTabGroupIndex

    if !AltTabActive || AltTabBuilding
        return

    CoordMode("Mouse", "Screen")
    MouseGetPos(&MouseX, &MouseY)

    if MouseX = LastAltTabMouseX && MouseY = LastAltTabMouseY
        return

    LastAltTabMouseX := MouseX
    LastAltTabMouseY := MouseY

    if AltTabGroupHitTest(&GroupMemberIndex, &GroupMemberHwnd)
    {
        SetAltTabGroupHover(GroupMemberIndex)
        return
    }

    if AltTabMouseHitTest(&HoveredIndex)
    {
        if HoveredIndex != AltTabIndex
        {
            AltTabIndex := HoveredIndex
            SetHighlightTarget(HoveredIndex)

            if AltTabGroupIndex != HoveredIndex
                CloseAltTabGroupBubble()
        }

        if (HoveredIndex <= AltTabGroups.Length
            && AltTabGroups[HoveredIndex].Windows.Length > 1)
        {
            ShowAltTabGroupBubble(HoveredIndex)
        }
        else
        {
            CloseAltTabGroupBubble()
        }

        return
    }

}

AltTabMouseClick()
{
    global AltTabActive, AltTabIndex, AltTabPreviewHwnd

    if !AltTabActive
        return

    if AltTabPreviewHitTest(&PreviewCloseHit)
    {
        if PreviewCloseHit
        {
            CloseAltTabTargetWindow(AltTabPreviewHwnd)
            return
        }

        if AltTabPreviewHwnd
        {
            ActivateAltTabWindow(AltTabPreviewHwnd)
            return
        }
    }

    if AltTabGroupCloseHitTest(&GroupCloseIndex, &GroupCloseHwnd)
    {
        CloseAltTabTargetWindow(GroupCloseHwnd)
        return
    }

    if AltTabGroupHitTest(&GroupMemberIndex, &GroupMemberHwnd)
    {
        ActivateAltTabWindow(GroupMemberHwnd)
        return
    }

    if AltTabMouseHitTest(&ClickedIndex)
    {
        AltTabIndex := ClickedIndex
        SetHighlightImmediate(ClickedIndex)
        AltTabCommit()
        return
    }

    CloseAltTabGui()
}

CloseAltTabTargetWindow(Hwnd)
{
    global CustomAltTabFeatureEnabled
    global AltTabActive, AltTabWindows, AltTabIndex

    if !Hwnd
        return

    OldIndex := AltTabIndex

    if WinExist("ahk_id " . Hwnd)
    {
        try WinClose("ahk_id " . Hwnd)
    }

    Sleep(90)

    LeftAltDown := GetKeyState("LAlt", "P")
    RightAltDown := GetKeyState("RAlt", "P")

    if CustomAltTabFeatureEnabled && (LeftAltDown || RightAltDown)
    {
        CloseAltTabGui()

        AltTabWindows := GetAltTabWindows()

        if AltTabWindows.Length = 0
            return

        AltTabActive := true

        if OldIndex < 1
            OldIndex := 1

        if OldIndex > AltTabWindows.Length
            OldIndex := AltTabWindows.Length

        AltTabIndex := OldIndex

        BuildAltTabGui()
        SetHighlightImmediate(AltTabIndex)
        return
    }

    CloseAltTabGui()
}

ShowAltTabGroupBubble(GroupIndex)
{
    global AltTabGui, AltTabGroups, AltTabBuilding
    global AltTabGroupGui, AltTabGroupIndex, AltTabGroupThumbnails
    global AltTabGroupCells, AltTabGroupHoverIndex, AltTabGroupBorders
    global AltTabBaseGuiWidth, AltTabGuiX, AltTabGuiY
    global AltTabGroupGap, AltTabGroupPadding, AltTabGroupBorder, AltTabGroupRadius
    global AltTabGroupCardWidth, AltTabGroupCardHeight
    global AltTabGroupIconSize, AltTabGroupCloseSize, AltTabGroupCardGap

    if !IsObject(AltTabGui)
        return

    if GroupIndex < 1 || GroupIndex > AltTabGroups.Length
        return

    Group := AltTabGroups[GroupIndex]

    if Group.Windows.Length < 2
    {
        CloseAltTabGroupBubble()
        return
    }

    if AltTabGroupIndex = GroupIndex && IsObject(AltTabGroupGui)
        return

    CloseAltTabGroupBubble()

    AltTabBuilding := true

    PrimaryMonitor := MonitorGetPrimary()

    MonitorGetWorkArea(
        PrimaryMonitor,
        &ScreenLeft,
        &ScreenTop,
        &ScreenRight,
        &ScreenBottom
    )

    ScreenWidth := ScreenRight - ScreenLeft

    CardW := AltTabGroupCardWidth
    CardH := AltTabGroupCardHeight

    MaxColumns :=
        Floor(
            (ScreenWidth - 40 - (AltTabGroupPadding * 2) + AltTabGroupCardGap)
            / (CardW + AltTabGroupCardGap)
        )

    if MaxColumns < 1
        MaxColumns := 1

    WindowCount := Group.Windows.Length
    Columns := Min(WindowCount, MaxColumns)
    Rows := Ceil(WindowCount / Columns)

    BubbleWidth :=
        (Columns * CardW)
        + ((Columns - 1) * AltTabGroupCardGap)
        + (AltTabGroupPadding * 2)

    BubbleHeight :=
        (Rows * CardH)
        + ((Rows - 1) * AltTabGroupCardGap)
        + (AltTabGroupPadding * 2)

    BubbleX :=
        AltTabGuiX
        + Floor((AltTabBaseGuiWidth - BubbleWidth) / 2)

    BubbleY :=
        AltTabGuiY
        - AltTabGroupGap
        - BubbleHeight

    if BubbleX < ScreenLeft + 8
        BubbleX := ScreenLeft + 8

    if BubbleX + BubbleWidth > ScreenRight - 8
        BubbleX := ScreenRight - BubbleWidth - 8

    if BubbleY < ScreenTop + 8
        BubbleY := ScreenTop + 8

    GroupGui := Gui(
        "+AlwaysOnTop -Caption +ToolWindow +E0x20 +Owner"
        . AltTabGui.Hwnd
    )

    GroupGui.BackColor := "0D0614"
    GroupGui.MarginX := 0
    GroupGui.MarginY := 0

    AltTabGroupGui := GroupGui
    AltTabGroupIndex := GroupIndex
    AltTabGroupThumbnails := []
    AltTabGroupCells := []
    AltTabGroupHoverIndex := 0
    AltTabGroupBorders := []

    B := AltTabGroupBorder

    GroupGui.AddText(
        "x0 y0 w" . BubbleWidth
        . " h" . B
        . " Background7B2CFF",
        ""
    )

    GroupGui.AddText(
        "x0 y" . (BubbleHeight - B)
        . " w" . BubbleWidth
        . " h" . B
        . " Background7B2CFF",
        ""
    )

    GroupGui.AddText(
        "x0 y0 w" . B
        . " h" . BubbleHeight
        . " Background7B2CFF",
        ""
    )

    GroupGui.AddText(
        "x" . (BubbleWidth - B)
        . " y0 w" . B
        . " h" . BubbleHeight
        . " Background7B2CFF",
        ""
    )

    for MemberIndex, Hwnd in Group.Windows
    {
        Col := Mod(MemberIndex - 1, Columns)
        Row := Floor((MemberIndex - 1) / Columns)

        CellX :=
            AltTabGroupPadding
            + (Col * (CardW + AltTabGroupCardGap))

        CellY :=
            AltTabGroupPadding
            + (Row * (CardH + AltTabGroupCardGap))

        CloseX := CellX + CardW - AltTabGroupCloseSize - 7
        CloseY := CellY + CardH - AltTabGroupCloseSize - 6

        AltTabGroupCells.Push({
            x: CellX,
            y: CellY,
            w: CardW,
            h: CardH,
            hwnd: Hwnd,
            closeX: CloseX,
            closeY: CloseY,
            closeW: AltTabGroupCloseSize,
            closeH: AltTabGroupCloseSize
        })

        GroupGui.AddText(
            "x" . CellX
            . " y" . CellY
            . " w" . CardW
            . " h" . CardH
            . " Background1A0D29",
            ""
        )

        UseRawImage := false
        IconSource := GetAltTabIconSource(Hwnd, &UseRawImage)

        IconX := CellX + 13
        IconY := CellY + 15

        IconAdded := false

        if IconSource != ""
        {
            try
            {
                PicOptions :=
                    "x" . IconX
                    . " y" . IconY
                    . " w" . AltTabGroupIconSize
                    . " h" . AltTabGroupIconSize
                    . " BackgroundTrans"

                if !UseRawImage
                    PicOptions .= " Icon1"

                GroupGui.AddPicture(PicOptions, IconSource)
                IconAdded := true
            }
        }

        if !IconAdded
        {
            GroupGui.SetFont("s18 cFFFFFF", "Segoe UI")

            GroupGui.AddText(
                "x" . IconX
                . " y" . IconY
                . " w" . AltTabGroupIconSize
                . " h" . AltTabGroupIconSize
                . " Center BackgroundTrans",
                "□"
            )
        }

        Title := ""

        try Title := WinGetTitle("ahk_id " . Hwnd)

        if Trim(Title) = ""
            Title := "Window " . MemberIndex

        if StrLen(Title) > 28
            Title := SubStr(Title, 1, 25) . "..."

        GroupGui.SetFont("s9 cFFFFFF", "Segoe UI")

        GroupGui.AddText(
            "x" . (IconX + AltTabGroupIconSize + 10)
            . " y" . (CellY + 21)
            . " w" . (CardW - AltTabGroupIconSize - 52)
            . " h32"
            . " Left BackgroundTrans",
            Title
        )

        GroupGui.SetFont("s12 Bold c7B2CFF", "Segoe UI")

        GroupGui.AddText(
            "x" . CloseX
            . " y" . (CloseY - 3)
            . " w" . AltTabGroupCloseSize
            . " h" . (AltTabGroupCloseSize + 3)
            . " Center BackgroundTrans",
            "×"
        )
    }

    HB := 3

    GroupTop := GroupGui.AddText(
        "x0 y0 w" . CardW
        . " h" . HB
        . " Background7B2CFF",
        ""
    )

    GroupBottom := GroupGui.AddText(
        "x0 y0 w" . CardW
        . " h" . HB
        . " Background7B2CFF",
        ""
    )

    GroupLeft := GroupGui.AddText(
        "x0 y0 w" . HB
        . " h" . CardH
        . " Background7B2CFF",
        ""
    )

    GroupRight := GroupGui.AddText(
        "x0 y0 w" . HB
        . " h" . CardH
        . " Background7B2CFF",
        ""
    )

    AltTabGroupBorders := [
        GroupTop,
        GroupBottom,
        GroupLeft,
        GroupRight
    ]

    for _, Border in AltTabGroupBorders
        try Border.Move(-1000, -1000)

    GroupGui.Show(
        "NoActivate"
        . " x" . BubbleX
        . " y" . BubbleY
        . " w" . BubbleWidth
        . " h" . BubbleHeight
    )

    try WinSetRegion(
        "0-0 W" . BubbleWidth
        . " H" . BubbleHeight
        . " R" . AltTabGroupRadius
        . "-" . AltTabGroupRadius,
        "ahk_id " . GroupGui.Hwnd
    )

    AltTabBuilding := false
}

CloseAltTabGroupBubble()
{
    global AltTabBuilding
    global AltTabGroupGui, AltTabGroupIndex, AltTabGroupThumbnails
    global AltTabGroupCells, AltTabGroupHoverIndex, AltTabGroupBorders

    for _, Thumbnail in AltTabGroupThumbnails
    {
        if Thumbnail
        {
            try DllCall(
                "dwmapi\DwmUnregisterThumbnail",
                "Ptr", Thumbnail
            )
        }
    }

    AltTabGroupThumbnails := []

    if IsObject(AltTabGroupGui)
    {
        try AltTabGroupGui.Hide()
        try AltTabGroupGui.Destroy()
    }

    AltTabGroupGui := 0
    AltTabGroupIndex := 0
    AltTabGroupCells := []
    AltTabGroupHoverIndex := 0
    AltTabGroupBorders := []

    AltTabBuilding := false
}

AltTabGroupHitTest(&MemberIndex, &MemberHwnd)
{
    global AltTabGroupGui, AltTabGroupCells

    MemberIndex := 0
    MemberHwnd := 0

    if !IsObject(AltTabGroupGui)
        return false

    try
    {
        WinGetPos(
            &BubbleX,
            &BubbleY,
            ,
            ,
            "ahk_id " . AltTabGroupGui.Hwnd
        )
    }
    catch
    {
        return false
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&MouseX, &MouseY)

    LocalX := MouseX - BubbleX
    LocalY := MouseY - BubbleY

    for Index, Cell in AltTabGroupCells
    {
        if (LocalX >= Cell.x
            && LocalX < Cell.x + Cell.w
            && LocalY >= Cell.y
            && LocalY < Cell.y + Cell.h)
        {
            MemberIndex := Index
            MemberHwnd := Cell.hwnd
            return true
        }
    }

    return false
}

AltTabGroupCloseHitTest(&MemberIndex, &MemberHwnd)
{
    global AltTabGroupGui, AltTabGroupCells

    MemberIndex := 0
    MemberHwnd := 0

    if !IsObject(AltTabGroupGui)
        return false

    try
    {
        WinGetPos(
            &BubbleX,
            &BubbleY,
            ,
            ,
            "ahk_id " . AltTabGroupGui.Hwnd
        )
    }
    catch
    {
        return false
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&MouseX, &MouseY)

    LocalX := MouseX - BubbleX
    LocalY := MouseY - BubbleY

    for Index, Cell in AltTabGroupCells
    {
        if (LocalX >= Cell.closeX
            && LocalX < Cell.closeX + Cell.closeW
            && LocalY >= Cell.closeY
            && LocalY < Cell.closeY + Cell.closeH)
        {
            MemberIndex := Index
            MemberHwnd := Cell.hwnd
            return true
        }
    }

    return false
}

SetAltTabGroupHover(MemberIndex)
{
    global AltTabGroupCells, AltTabGroupHoverIndex, AltTabGroupBorders

    if MemberIndex < 1 || MemberIndex > AltTabGroupCells.Length
        return

    if AltTabGroupBorders.Length != 4
        return

    if AltTabGroupHoverIndex = MemberIndex
        return

    AltTabGroupHoverIndex := MemberIndex
    Cell := AltTabGroupCells[MemberIndex]

    HB := 3

    try AltTabGroupBorders[1].Move(
        Cell.x,
        Cell.y,
        Cell.w,
        HB
    )

    try AltTabGroupBorders[2].Move(
        Cell.x,
        Cell.y + Cell.h - HB,
        Cell.w,
        HB
    )

    try AltTabGroupBorders[3].Move(
        Cell.x,
        Cell.y,
        HB,
        Cell.h
    )

    try AltTabGroupBorders[4].Move(
        Cell.x + Cell.w - HB,
        Cell.y,
        HB,
        Cell.h
    )
}

AltTabMousePreview()
{
    global AltTabActive, AltTabIndex
    global AltTabPreviewHwnd

    if !AltTabActive
        return

    if AltTabGroupCloseHitTest(&DummyCloseIndex, &DummyCloseHwnd)
        return

    if AltTabGroupHitTest(&GroupMemberIndex, &GroupMemberHwnd)
    {
        if AltTabPreviewHwnd = GroupMemberHwnd
        {
            CloseAltTabPreview(true)
            return
        }

        ShowAltTabPreviewWindow(GroupMemberHwnd, 0)
        return
    }

    if !AltTabMouseHitTest(&PreviewIndex)
        return

    AltTabIndex := PreviewIndex
    SetHighlightImmediate(PreviewIndex)

    SourceHwnd := 0

    try SourceHwnd := AltTabWindows[PreviewIndex]

    if !SourceHwnd
        return

    if AltTabPreviewHwnd = SourceHwnd
    {
        CloseAltTabPreview(true)
        return
    }

    ShowAltTabPreviewWindow(SourceHwnd, PreviewIndex)
}

ShowAltTabPreview(Index)
{
    global AltTabWindows

    if Index < 1 || Index > AltTabWindows.Length
        return

    ShowAltTabPreviewWindow(AltTabWindows[Index], Index)
}

ShowAltTabPreviewWindow(SourceHwnd, MainIndex := 0)
{
    global AltTabGui
    global AltTabPreviewThumbnail, AltTabPreviewIndex, AltTabPreviewHwnd
    global AltTabPreviewGui, AltTabPreviewCloseGui, AltTabPreviewCloseRect
    global AltTabBaseGuiWidth, AltTabBaseGuiHeight, AltTabGuiX, AltTabGuiY
    global AltTabPreviewGap, AltTabPreviewPadding, AltTabPreviewBorder
    global AltTabPreviewRadius, AltTabPreviewMaxWidth, AltTabPreviewMaxHeight

    if !IsObject(AltTabGui)
        return

    if !SourceHwnd || !WinExist("ahk_id " . SourceHwnd)
        return

    CloseAltTabPreview(false)

    PreviewGui := Gui(
        "+AlwaysOnTop -Caption +ToolWindow +E0x20 +Owner"
        . AltTabGui.Hwnd
    )

    PreviewGui.BackColor := "0D0614"
    PreviewGui.MarginX := 0
    PreviewGui.MarginY := 0

    AltTabPreviewGui := PreviewGui

    Thumbnail := 0
    Result := -1

    Loop 3
    {
        Thumbnail := 0

        try Result := DllCall(
            "dwmapi\DwmRegisterThumbnail",
            "Ptr", PreviewGui.Hwnd,
            "Ptr", SourceHwnd,
            "Ptr*", &Thumbnail,
            "Int"
        )
        catch
            Result := -1

        if Result = 0 && Thumbnail
            break

        Sleep(15)
    }

    if Result != 0 || !Thumbnail
    {
        try PreviewGui.Destroy()
        AltTabPreviewGui := 0
        return
    }

    SourceWidth := 0
    SourceHeight := 0
    SourceSize := Buffer(8, 0)

    try QueryResult := DllCall(
        "dwmapi\DwmQueryThumbnailSourceSize",
        "Ptr", Thumbnail,
        "Ptr", SourceSize.Ptr,
        "Int"
    )
    catch
        QueryResult := -1

    if QueryResult = 0
    {
        SourceWidth := NumGet(SourceSize, 0, "Int")
        SourceHeight := NumGet(SourceSize, 4, "Int")
    }

    if SourceWidth <= 0 || SourceHeight <= 0
    {
        try WinGetPos(, , &SourceWidth, &SourceHeight, "ahk_id " . SourceHwnd)
    }

    if SourceWidth <= 0 || SourceHeight <= 0
    {
        try DllCall("dwmapi\DwmUnregisterThumbnail", "Ptr", Thumbnail)
        try PreviewGui.Destroy()
        AltTabPreviewGui := 0
        return
    }

    PrimaryMonitor := MonitorGetPrimary()

    MonitorGetWorkArea(
        PrimaryMonitor,
        &ScreenLeft,
        &ScreenTop,
        &ScreenRight,
        &ScreenBottom
    )

    MaxInnerWidth := AltTabPreviewMaxWidth
    MaxInnerHeight := AltTabPreviewMaxHeight

    Scale := Min(
        MaxInnerWidth / SourceWidth,
        MaxInnerHeight / SourceHeight,
        1
    )

    PreviewWidth := Max(1, Round(SourceWidth * Scale))
    PreviewHeight := Max(1, Round(SourceHeight * Scale))

    BubbleWidth := PreviewWidth + (AltTabPreviewPadding * 2)
    BubbleHeight := PreviewHeight + (AltTabPreviewPadding * 2)

    BubbleX :=
        AltTabGuiX
        + Floor((AltTabBaseGuiWidth - BubbleWidth) / 2)

    BubbleY :=
        AltTabGuiY
        + AltTabBaseGuiHeight
        + AltTabPreviewGap

    if BubbleX < ScreenLeft + 8
        BubbleX := ScreenLeft + 8

    if BubbleX + BubbleWidth > ScreenRight - 8
        BubbleX := ScreenRight - BubbleWidth - 8

    if BubbleY + BubbleHeight > ScreenBottom - 8
    {
        AboveY :=
            AltTabGuiY
            - AltTabPreviewGap
            - BubbleHeight

        if AboveY >= ScreenTop + 8
            BubbleY := AboveY
    }

    B := AltTabPreviewBorder

    PreviewGui.AddText(
        "x0 y0 w" . BubbleWidth
        . " h" . B
        . " Background7B2CFF",
        ""
    )

    PreviewGui.AddText(
        "x0 y" . (BubbleHeight - B)
        . " w" . BubbleWidth
        . " h" . B
        . " Background7B2CFF",
        ""
    )

    PreviewGui.AddText(
        "x0 y0 w" . B
        . " h" . BubbleHeight
        . " Background7B2CFF",
        ""
    )

    PreviewGui.AddText(
        "x" . (BubbleWidth - B)
        . " y0 w" . B
        . " h" . BubbleHeight
        . " Background7B2CFF",
        ""
    )

    CloseW := 24
    CloseH := 24

    CloseX :=
        AltTabPreviewPadding
        + PreviewWidth
        - CloseW
        - 5

    CloseY :=
        AltTabPreviewPadding
        + PreviewHeight
        - CloseH
        - 5

    AltTabPreviewCloseRect := {
        x: CloseX,
        y: CloseY,
        w: CloseW,
        h: CloseH
    }

    PreviewGui.Show(
        "NoActivate"
        . " x" . BubbleX
        . " y" . BubbleY
        . " w" . BubbleWidth
        . " h" . BubbleHeight
    )

    try WinSetRegion(
        "0-0 W" . BubbleWidth
        . " H" . BubbleHeight
        . " R" . AltTabPreviewRadius
        . "-" . AltTabPreviewRadius,
        "ahk_id " . PreviewGui.Hwnd
    )

    try DllCall("user32\UpdateWindow", "Ptr", PreviewGui.Hwnd)
    Sleep(10)

    CloseGui := Gui(
        "+AlwaysOnTop -Caption +ToolWindow +E0x20 +Owner"
        . PreviewGui.Hwnd
    )

    CloseGui.BackColor := "010101"
    CloseGui.MarginX := 0
    CloseGui.MarginY := 0

    CloseGui.SetFont("s14 Bold c7B2CFF", "Segoe UI")
    CloseGui.AddText(
        "x0 y-2 w" . CloseW
        . " h" . CloseH
        . " Center BackgroundTrans",
        "×"
    )

    CloseScreenX := BubbleX + CloseX
    CloseScreenY := BubbleY + CloseY

    CloseGui.Show(
        "NoActivate"
        . " x" . CloseScreenX
        . " y" . CloseScreenY
        . " w" . CloseW
        . " h" . CloseH
    )

    try WinSetTransColor(
        "010101",
        "ahk_id " . CloseGui.Hwnd
    )

    AltTabPreviewCloseGui := CloseGui

    Props := Buffer(48, 0)

    DWM_TNP_RECTDESTINATION := 0x1
    DWM_TNP_OPACITY := 0x4
    DWM_TNP_VISIBLE := 0x8

    Flags :=
        DWM_TNP_RECTDESTINATION
        | DWM_TNP_OPACITY
        | DWM_TNP_VISIBLE

    NumPut("UInt", Flags, Props, 0)

    DestLeft := AltTabPreviewPadding
    DestTop := AltTabPreviewPadding
    DestRight := DestLeft + PreviewWidth
    DestBottom := DestTop + PreviewHeight

    NumPut("Int", DestLeft, Props, 4)
    NumPut("Int", DestTop, Props, 8)
    NumPut("Int", DestRight, Props, 12)
    NumPut("Int", DestBottom, Props, 16)

    NumPut("UChar", 255, Props, 36)
    NumPut("Int", 1, Props, 40)
    NumPut("Int", 0, Props, 44)

    UpdateResult := -1

    Loop 3
    {
        try UpdateResult := DllCall(
            "dwmapi\DwmUpdateThumbnailProperties",
            "Ptr", Thumbnail,
            "Ptr", Props.Ptr,
            "Int"
        )
        catch
            UpdateResult := -1

        if UpdateResult = 0
            break

        Sleep(15)
    }

    if UpdateResult != 0
    {
        try DllCall(
            "dwmapi\DwmUnregisterThumbnail",
            "Ptr", Thumbnail
        )

        if IsObject(AltTabPreviewCloseGui)
        {
            try AltTabPreviewCloseGui.Hide()
            try AltTabPreviewCloseGui.Destroy()
        }

        AltTabPreviewCloseGui := 0

        try PreviewGui.Hide()
        try PreviewGui.Destroy()

        AltTabPreviewGui := 0
        AltTabPreviewCloseRect := 0
        return
    }

    AltTabPreviewThumbnail := Thumbnail
    AltTabPreviewIndex := MainIndex
    AltTabPreviewHwnd := SourceHwnd
}

AltTabPreviewHitTest(&CloseHit)
{
    global AltTabPreviewGui, AltTabPreviewCloseGui, AltTabPreviewCloseRect

    CloseHit := false

    if !IsObject(AltTabPreviewGui)
        return false

    try
    {
        WinGetPos(
            &BubbleX,
            &BubbleY,
            &BubbleW,
            &BubbleH,
            "ahk_id " . AltTabPreviewGui.Hwnd
        )
    }
    catch
    {
        return false
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&MouseX, &MouseY)

    LocalX := MouseX - BubbleX
    LocalY := MouseY - BubbleY

    if (LocalX < 0
        || LocalY < 0
        || LocalX >= BubbleW
        || LocalY >= BubbleH)
    {
        return false
    }

    if IsObject(AltTabPreviewCloseRect)
    {
        R := AltTabPreviewCloseRect

        if (LocalX >= R.x
            && LocalX < R.x + R.w
            && LocalY >= R.y
            && LocalY < R.y + R.h)
        {
            CloseHit := true
        }
    }

    return true
}

CloseAltTabPreview(DestroyOnly := true)
{
    global AltTabPreviewThumbnail, AltTabPreviewIndex, AltTabPreviewHwnd
    global AltTabPreviewGui, AltTabPreviewCloseGui, AltTabPreviewCloseRect

    if AltTabPreviewThumbnail
    {
        try DllCall(
            "dwmapi\DwmUnregisterThumbnail",
            "Ptr", AltTabPreviewThumbnail
        )
    }

    AltTabPreviewThumbnail := 0
    AltTabPreviewIndex := 0
    AltTabPreviewHwnd := 0
    AltTabPreviewCloseRect := 0

    if IsObject(AltTabPreviewCloseGui)
    {
        try AltTabPreviewCloseGui.Hide()
        try AltTabPreviewCloseGui.Destroy()
    }

    AltTabPreviewCloseGui := 0

    if IsObject(AltTabPreviewGui)
    {
        try AltTabPreviewGui.Hide()
        try AltTabPreviewGui.Destroy()
    }

    AltTabPreviewGui := 0
}

AltTabMouseHitTest(&FoundIndex)
{
    global AltTabGui, AltTabCellPositions, HighlightSize

    FoundIndex := 0

    if !IsObject(AltTabGui)
        return false

    try
    {
        WinGetPos(&GuiX, &GuiY, , , "ahk_id " . AltTabGui.Hwnd)
    }
    catch
    {
        return false
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&MouseX, &MouseY)

    LocalX := MouseX - GuiX
    LocalY := MouseY - GuiY

    for Index, Pos in AltTabCellPositions
    {
        if (LocalX >= Pos.x
            && LocalX < Pos.x + Pos.w
            && LocalY >= Pos.y
            && LocalY < Pos.y + Pos.h)
        {
            FoundIndex := Index
            return true
        }
    }

    return false
}

GetAltTabIconSource(Hwnd, &UseRawImage)
{
    global AppGui, LogoPath

    UseRawImage := false

    if IsObject(AppGui)
    {
        if Hwnd = AppGui.Hwnd && FileExist(LogoPath)
        {
            UseRawImage := true
            return LogoPath
        }
    }

    return GetWindowExe(Hwnd)
}

GetWindowExe(Hwnd)
{
    try
    {
        PID := WinGetPID("ahk_id " . Hwnd)
        return ProcessGetPath(PID)
    }

    return ""
}
