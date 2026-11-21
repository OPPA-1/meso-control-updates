#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
root := A_ScriptDir "\.."
paths := ["Lib\Editor.ahk", "Lib\Effects.ahk", "Meso_Visual_Effect.ahk", "Meso_Stream_Output.ahk", "Tests\VisualEffectSmokeTests.ahk"]
contents := Map()
for p in paths {
    full := root "\" p
    if !FileExist(full)
        throw Error("Missing feature file: " p)
    contents[p] := FileRead(full, "UTF-8")
}
checks := [
    ["Lib\Editor.ahk", "Invert Screen"],
    ["Lib\Editor.ahk", "Drunk Vision"],
    ["Lib\Editor.ahk", "Feature522"],
    ["Lib\Effects.ahk", "case ""Drunk Vision"""],
    ["Lib\Effects.ahk", """mirror"""],
    ["Meso_Visual_Effect.ahk", "1000.0 / 60.0"],
    ["Meso_Visual_Effect.ahk", "MagSetWindowSource"],
    ["Meso_Visual_Effect.ahk", "MagSetWindowTransform"],
    ["Meso_Stream_Output.ahk", "SmallTungLastPosition"],
    ["Meso_Stream_Output.ahk", "ScreenDamage.Until := Max(ScreenDamage.Until, now + 60000)"],
    ["Meso_Stream_Output.ahk", "ProcessScreenDamage(clockNow)"],
    ["Tests\VisualEffectSmokeTests.ahk", "RunVisualCheck(""mirror"""],
    ["Tests\VisualEffectSmokeTests.ahk", "RunVisualCheck(""drunk"""]
]
for item in checks {
    if !InStr(contents[item[1]], item[2])
        throw Error("Missing feature: " item[2])
}
MsgBox(checks.Length " feature checks passed. No game input was sent.", "Meso 5.2.2")
