ScreenFilterBounds(mode, x, y, w, h) {
    width := mode = "split" ? w//2 : w
    return {X: x, Y: y, W: width, H: h, SourceX: mode = "split" ? x+w-width : x, SourceY: y}
}

ScreenFilterCall(interfacePtr, index, args*) {
    callArgs := [index, interfacePtr]
    callArgs.Push(args*)
    callArgs.Push("Int")
    return ComCall(callArgs*)
}

ScreenFilterCheck(result, operation) {
    if result < 0
        throw Error(operation " failed (" Format("0x{:08X}", result & 0xFFFFFFFF) ")")
}

ScreenFilterGuid(value) {
    guid := Buffer(16, 0)
    ScreenFilterCheck(DllCall("ole32\CLSIDFromString", "WStr", value, "Ptr", guid, "Int"), "Composition GUID")
    return guid
}

ScreenFilterRelease(&value) {
    if value {
        ptr := value, value := 0
        try ScreenFilterCall(ptr, 2)
    }
}
