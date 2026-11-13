Option Explicit
Dim fso, sh, root, bridge, inbox, replies, viewer, mode, arg, requestId, tempPath, readyPath, replyPath, handle, reply, bits, rx, started, manual, attempt, message, logPath
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
root = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%")
If Len(root) = 0 Or InStr(root, "%") > 0 Then root = sh.ExpandEnvironmentStrings("%APPDATA%")
If Len(root) = 0 Or InStr(root, "%") > 0 Then WScript.Quit 4
root = fso.BuildPath(root, "MesoControl")
bridge = fso.BuildPath(root, "WheelBridge")
inbox = fso.BuildPath(bridge, "Inbox")
replies = fso.BuildPath(bridge, "Replies")
manual = (WScript.Arguments.Count = 0)
mode = "spin"
viewer = ""
If WScript.Arguments.Count > 0 Then
    arg = CStr(WScript.Arguments(0))
    If arg = "--preview" Then
        mode = "preview"
        If WScript.Arguments.Count > 1 Then viewer = CStr(WScript.Arguments(1))
    ElseIf arg = "--skip" Then
        mode = "skip"
        If WScript.Arguments.Count > 1 Then viewer = CStr(WScript.Arguments(1))
    ElseIf arg = "--double" Then
        mode = "double"
        If WScript.Arguments.Count > 1 Then viewer = CStr(WScript.Arguments(1))
    ElseIf arg = "--direct" Then
        If WScript.Arguments.Count < 2 Then WScript.Quit 2
        arg = CStr(WScript.Arguments(1))
        Set rx = New RegExp
        rx.Pattern = "^[1-5]$"
        If Not rx.Test(arg) Then WScript.Quit 2
        mode = "direct" & arg
        If WScript.Arguments.Count > 2 Then viewer = CStr(WScript.Arguments(2))
    Else
        viewer = arg
    End If
End If
Set rx = New RegExp
rx.Pattern = "^[A-Za-z0-9_]{1,25}$"
If Len(viewer) > 0 And Not rx.Test(viewer) Then viewer = ""
If Len(viewer) = 0 Then viewer = "-"
On Error Resume Next
If Not fso.FolderExists(root) Then fso.CreateFolder root
If Not fso.FolderExists(bridge) Then fso.CreateFolder bridge
If Not fso.FolderExists(inbox) Then fso.CreateFolder inbox
If Not fso.FolderExists(replies) Then fso.CreateFolder replies
If Err.Number <> 0 Then
    message = "Cannot open wheel relay folder: " & Err.Description
    Done 4, message
End If
If fso.GetFolder(inbox).Files.Count > 300 Then Done 5, "Wheel relay is busy"
Randomize
requestId = "w" & Replace(fso.GetTempName(), ".tmp", "") & "_" & Hex(CLng(Rnd * 2000000000))
tempPath = fso.BuildPath(inbox, requestId & ".tmp")
readyPath = fso.BuildPath(inbox, requestId & ".req")
replyPath = fso.BuildPath(replies, requestId & ".ack")
Set handle = fso.CreateTextFile(tempPath, False, False)
If Err.Number <> 0 Then Done 6, "Cannot create wheel request: " & Err.Description
handle.Write "mesowheel2|" & mode & "|" & viewer
handle.Close
If Err.Number <> 0 Then Done 7, "Cannot write wheel request: " & Err.Description
fso.MoveFile tempPath, readyPath
If Err.Number <> 0 Then Done 8, "Cannot queue wheel request: " & Err.Description
For attempt = 1 To 35
    WScript.Sleep 100
    If fso.FileExists(replyPath) Then
        Set handle = fso.OpenTextFile(replyPath, 1, False, 0)
        reply = Trim(handle.ReadAll)
        handle.Close
        fso.DeleteFile replyPath, True
        If Left(reply, 7) = "QUEUED|" Then Done 0, "Meso Control: " & Mid(reply, 8)
        bits = Split(reply, "|")
        If UBound(bits) >= 1 Then
            Done 12, "Meso Control: " & bits(1)
        Else
            Done 12, "Meso Control: " & reply
        End If
    End If
Next
Done 9, "Meso Control did not respond. Start the app and enable Wheel Controller."

Sub Done(exitCode, msg)
    On Error Resume Next
    If exitCode <> 0 Then
        logPath = fso.BuildPath(bridge, "WheelRelay_errors.log")
        Set handle = fso.OpenTextFile(logPath, 8, True)
        handle.WriteLine Now() & " " & msg
        handle.Close
    End If
    If manual Then WScript.Echo msg
    WScript.Quit exitCode
End Sub
