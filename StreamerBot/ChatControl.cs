using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

public class CPHInline
{
    public bool Execute()
    {
        string viewer = "";
        if (!CPH.TryGetArg("userName", out viewer) || string.IsNullOrWhiteSpace(viewer))
            if (!CPH.TryGetArg("userLogin", out viewer) || string.IsNullOrWhiteSpace(viewer))
                CPH.TryGetArg("user", out viewer);

        string message = "";
        if (!CPH.TryGetArg("message", out message) || string.IsNullOrWhiteSpace(message))
        {
            CPH.LogWarn("Meso relay: no Twitch message received. Check the Chat Message trigger.");
            return false;
        }

        viewer = (viewer ?? "").Trim().ToLowerInvariant();
        message = Regex.Replace(message.Trim().ToLowerInvariant(), @"\s+", " ");
        if (!Regex.IsMatch(viewer, "^[a-z0-9_]{1,25}$"))
        {
            CPH.LogWarn("Meso relay: viewer argument missing.");
            return false;
        }
        if (!Regex.IsMatch(message, "^![a-z][a-z0-9_]{0,19} [a-z0-9][a-z0-9_-]{0,23}$"))
            return true;

        string baseFolder = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        if (string.IsNullOrWhiteSpace(baseFolder))
        {
            CPH.LogWarn("Meso relay: local application folder unavailable.");
            return false;
        }

        string temp = "";
        try
        {
            string folder = Path.Combine(baseFolder, "MesoControl", "ChatBridge", "Inbox");
            Directory.CreateDirectory(folder);
            if (Directory.GetFiles(folder, "*.msg").Length > 300)
            {
                CPH.LogWarn("Meso relay: inbox full.");
                return false;
            }
            string id = "c" + Guid.NewGuid().ToString("N");
            temp = Path.Combine(folder, id + ".tmp");
            string destination = Path.Combine(folder, id + ".msg");
            File.WriteAllText(temp, "mesochat2|" + id + "|" + viewer + "|" + message, new UTF8Encoding(false));
            File.Move(temp, destination);
            CPH.LogInfo("Meso relay queued: @" + viewer + " " + message);
            return true;
        }
        catch (Exception ex)
        {
            CPH.LogWarn("Meso relay failed: " + ex.Message);
            if (temp.Length > 0)
                try { File.Delete(temp); } catch { }
            return false;
        }
    }
}
