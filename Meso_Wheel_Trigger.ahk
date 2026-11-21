#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#NoTrayIcon
first := A_Args.Length ? A_Args[1] : ""
mode := first = "--skip" ? "skip" : (first = "--preview" || (first = "preview" && A_Args.Length >= 2)) ? "preview" : "spin"
viewer := mode != "spin" ? (A_Args.Length >= 2 ? A_Args[2] : "") : first
if !RegExMatch(viewer, "^[A-Za-z0-9_]{1,25}$")
    viewer := ""
script := A_ScriptDir (mode = "skip" ? "\Meso_Cooldown_Trigger.vbs" : "\Meso_Wheel_Trigger.vbs")
args := mode = "preview" ? " --preview" : ""
args .= " " Chr(34) viewer Chr(34)
command := Chr(34) A_WinDir "\System32\wscript.exe" Chr(34) " //B //NoLogo " Chr(34) script Chr(34) args
try ExitApp(RunWait(command, A_ScriptDir, "Hide"))
catch
    ExitApp(10)
