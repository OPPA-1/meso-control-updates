HideVisualCursor(owner) {
    global RuntimeDir
    folder := RuntimeDir "\cursor-owners"
    DirCreate(folder)
    owner.CursorLease := folder "\" ProcessExist() "-" NewId() ".owner"
    WriteAtomic(owner.CursorLease, "hidden")
    if DllCall("Magnification\MagShowSystemCursor", "Int", false, "Int") {
        owner.CursorRefresh := NowMs()
        return true
    }
    try FileDelete(owner.CursorLease)
    owner.DeleteProp("CursorLease")
    return false
}

MaintainVisualCursor(owner) {
    if owner.HasOwnProp("CursorLease") && NowMs()-owner.CursorRefresh >= 250 {
        DllCall("Magnification\MagShowSystemCursor", "Int", false, "Int")
        owner.CursorRefresh := NowMs()
    }
}

RestoreVisualCursor(owner) {
    global RuntimeDir
    if !owner.HasOwnProp("CursorLease")
        return false
    try FileDelete(owner.CursorLease)
    owner.DeleteProp("CursorLease")
    ; MagShowSystemCursor has no reference count, so workers keep their own ownership.
    active := false
    loop files RuntimeDir "\cursor-owners\*.owner", "F" {
        if RegExMatch(A_LoopFileName, "^(\d+)-", &m) && ProcessExist(m[1])
            active := true
        else
            try FileDelete(A_LoopFileFullPath)
    }
    if active
        return false
    return DllCall("Magnification\MagShowSystemCursor", "Int", true, "Int") != 0
}
