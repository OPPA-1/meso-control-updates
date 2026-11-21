#Requires AutoHotkey v2.0 64-bit
source := FileRead(A_ScriptDir "\..\Meso_Visual_Effect.ahk", "UTF-8")
if !InStr(source, "DCompInvoke(interfacePtr, index, args*)")
    throw Error("DirectComposition helper is missing")
if InStr(source, 'args*, "Int"')
    throw Error("Invalid variadic call syntax remains")
if !InStr(source, "return DllCall(callArgs*)")
    throw Error("Argument expansion fix is missing")
if !InStr(source, 'callArgs.Push("Int")')
    throw Error("Return type is missing")
expected := DllCall("kernel32\GetCurrentProcessId", "UInt")
functionPtr := DllCall("kernel32\GetProcAddress", "Ptr", DllCall("kernel32\GetModuleHandleW", "WStr", "kernel32.dll", "Ptr"), "AStr", "GetCurrentProcessId", "Ptr")
if !functionPtr
    throw Error("Windows function pointer unavailable")
callArgs := [functionPtr, "UInt"]
if DllCall(callArgs*) != expected
    throw Error("Variadic DllCall arguments are invalid")
FileAppend("PASS 5.2.7 variadic DllCall smoke test`n", "*")
