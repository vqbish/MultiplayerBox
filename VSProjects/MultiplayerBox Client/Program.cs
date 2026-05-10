using System.Text.Json;
using System.Runtime.Versioning;
using GoreBoxRegistryLinker;

[assembly: SupportedOSPlatform("windows")]

namespace MultiplayerBoxClient;

internal static class Program
{
    private static readonly RegistryMonitor RegistryMonitor = new();
    private static readonly Network Network = new();
    private static AppShell? Shell;

    private static async Task Main()
    {
        Console.Title = "MultiplayerBox Client";
        Console.CursorVisible = false;

        Shell = new AppShell(Network);

        RegistryMonitor.OnLog += message => ConsoleUi.Log("REGISTRY", message, ConsoleColor.DarkGray);
        RegistryMonitor.OnMessageReceived += message => _ = HandleModMessageAsync(message);

        Network.Client.OnConnected += () =>
        {
            Network.MarkClientConnected();
            ConsoleUi.Log("NETWORK", "Connected", ConsoleColor.Green);
        };

        Network.Client.OnDisconnected += () =>
        {
            Network.MarkClientDisconnected();
            ConsoleUi.Log("NETWORK", "Disconnected", ConsoleColor.DarkYellow);
        };

        Network.Client.OnError += message => ConsoleUi.Log("NETWORK", message, ConsoleColor.Red);
        Network.Client.OnMessageReceived += HandleNetworkMessage;

        RegistryMonitor.Start();

        try
        {
            await Shell.RunAsync();
        }
        finally
        {
            RegistryMonitor.Dispose();
            await Network.StopAsync();
            Console.ResetColor();
            Console.Clear();
            Console.CursorVisible = true;
        }
    }

    private static async Task HandleModMessageAsync(string payload)
    {
        if (IsPacketType(payload, "PING"))
        {
            SendPong();
            return;
        }

        try
        {
            await Network.Client.SendPayloadAsync(payload);
            Network.MarkOutgoingPacket();
            ConsoleUi.Log("MOD", "Packet sent to room", ConsoleColor.Cyan);
        }
        catch (Exception ex)
        {
            ConsoleUi.Log("MOD", ex.Message, ConsoleColor.Red);
        }
    }

    private static void HandleNetworkMessage(string clientId, string payload)
    {
        if (clientId == Network.Client.ClientId)
        {
            return;
        }

        Network.MarkIncomingPacket();
        RegistryMonitor.SendPayload(payload, clientId);
        ConsoleUi.Log("NETWORK", $"Packet received from {clientId}", ConsoleColor.Cyan);
    }

    private static void SendPong()
    {
        RegistryMonitor.SendData(new Dictionary<string, string>
        {
            ["type"] = "PONG",
            ["message"] = "Client is alive"
        });
    }

    private static bool IsPacketType(string payload, string expectedType)
    {
        try
        {
            using var document = JsonDocument.Parse(payload);

            return TryReadPacketType(document.RootElement, out var packetType)
                   && string.Equals(packetType, expectedType, StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    private static bool TryReadPacketType(JsonElement element, out string? packetType)
    {
        packetType = null;

        if (element.ValueKind == JsonValueKind.Object && element.TryGetProperty("data", out var data))
        {
            if (TryReadStringProperty(data, "type", out packetType) || TryReadStringProperty(data, "Type", out packetType))
            {
                return true;
            }
        }

        if (TryReadStringProperty(element, "type", out packetType) || TryReadStringProperty(element, "Type", out packetType))
        {
            return true;
        }

        return false;
    }

    private static bool TryReadStringProperty(JsonElement element, string propertyName, out string? value)
    {
        value = null;

        if (element.ValueKind != JsonValueKind.Object || !element.TryGetProperty(propertyName, out var property))
        {
            return false;
        }

        if (property.ValueKind != JsonValueKind.String)
        {
            return false;
        }

        value = property.GetString();
        return value != null;
    }
}

internal enum ConsoleTheme
{
    Neon,
    Dark,
    Classic
}

internal static class ConsoleUi
{
    private static readonly object Sync = new();
    private static readonly List<LogEntry> Logs = new();
    private const int MaxLogs = 200;

    private static ConsoleTheme _theme = ConsoleTheme.Neon;

    public static string CurrentThemeName => _theme.ToString();
    public static bool ShowTimestamps { get; set; } = true;

    public static void SetTheme(ConsoleTheme theme)
    {
        _theme = theme;
    }

    public static int ShowMainMenu()
    {
        var items = new[]
        {
            "Host room",
            "Join room",
            "Exit"
        };

        return ShowSelectableMenu(
            "MultiplayerBox",
            "Choose how to connect",
            items,
            "↑ ↓  Enter  Esc"
        ) ?? 2;
    }

    public static int? ShowSelectableMenu(string title, string subtitle, IReadOnlyList<string> items, string footer)
    {
        var selected = 0;

        while (true)
        {
            Console.Clear();
            DrawHeader(title, subtitle);
            Console.WriteLine();

            for (var i = 0; i < items.Count; i++)
            {
                if (i == selected)
                {
                    var oldForeground = Console.ForegroundColor;
                    var oldBackground = Console.BackgroundColor;

                    Console.ForegroundColor = GetHighlightTextColor();
                    Console.BackgroundColor = GetHighlightBackgroundColor();
                    Console.WriteLine($"  ▶ {items[i]}");
                    Console.ForegroundColor = oldForeground;
                    Console.BackgroundColor = oldBackground;
                }
                else
                {
                    Console.WriteLine($"    {items[i]}");
                }
            }

            Console.WriteLine();
            WriteDim(footer);

            var key = Console.ReadKey(true).Key;

            if (key == ConsoleKey.UpArrow)
            {
                selected = Math.Max(0, selected - 1);
                continue;
            }

            if (key == ConsoleKey.DownArrow)
            {
                selected = Math.Min(items.Count - 1, selected + 1);
                continue;
            }

            if (key == ConsoleKey.Enter)
            {
                return selected;
            }

            if (key == ConsoleKey.Escape)
            {
                return null;
            }

            if (key >= ConsoleKey.D1 && key <= ConsoleKey.D9)
            {
                var index = (int)key - (int)ConsoleKey.D1;
                if (index >= 0 && index < items.Count)
                {
                    return index;
                }
            }

            if (key >= ConsoleKey.NumPad1 && key <= ConsoleKey.NumPad9)
            {
                var index = (int)key - (int)ConsoleKey.NumPad1;
                if (index >= 0 && index < items.Count)
                {
                    return index;
                }
            }
        }
    }

    public static string Prompt(string label, string? defaultValue = null)
    {
        Console.Write($"{label}");
        if (!string.IsNullOrWhiteSpace(defaultValue))
        {
            Console.Write($" [{defaultValue}]");
        }

        Console.Write(": ");
        var value = Console.ReadLine();

        if (string.IsNullOrWhiteSpace(value))
        {
            return defaultValue ?? string.Empty;
        }

        return value.Trim();
    }

    public static void Pause(string message = "Press any key to continue...")
    {
        WriteDim(message);
        Console.ReadKey(true);
    }

    public static void Log(string source, string message, ConsoleColor color)
    {
        lock (Sync)
        {
            Logs.Add(new LogEntry(DateTime.Now, source, message, color));

            if (Logs.Count > MaxLogs)
            {
                Logs.RemoveRange(0, Logs.Count - MaxLogs);
            }

            var oldColor = Console.ForegroundColor;
            Console.ForegroundColor = color;

            if (ShowTimestamps)
            {
                Console.WriteLine($"{DateTime.Now:HH:mm:ss} [{source}] {message}");
            }
            else
            {
                Console.WriteLine($"[{source}] {message}");
            }

            Console.ForegroundColor = oldColor;
        }
    }

    public static IReadOnlyList<LogEntry> GetRecentLogs(int count)
    {
        lock (Sync)
        {
            if (count <= 0 || Logs.Count == 0)
            {
                return Array.Empty<LogEntry>();
            }

            return Logs.TakeLast(count).ToArray();
        }
    }

    public static void ClearLogs()
    {
        lock (Sync)
        {
            Logs.Clear();
        }
    }

    public static void DrawHeader(string title, string subtitle = "")
    {
        var width = Math.Max(48, Math.Max(title.Length + 8, subtitle.Length + 8));
        var line = new string('═', width - 2);

        Console.WriteLine($"╔{line}╗");
        Console.Write("║ ");
        Console.ForegroundColor = GetAccentColor();
        Console.Write(title);
        Console.ResetColor();
        Console.WriteLine(new string(' ', width - 4 - title.Length) + "║");

        if (!string.IsNullOrWhiteSpace(subtitle))
        {
            Console.Write("║ ");
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.Write(subtitle);
            Console.ResetColor();
            Console.WriteLine(new string(' ', width - 4 - subtitle.Length) + "║");
        }
        else
        {
            Console.WriteLine($"║{new string(' ', width - 2)}║");
        }

        Console.WriteLine($"╚{line}╝");
    }

    public static void DrawTabs(IReadOnlyList<string> tabs, int selectedIndex)
    {
        for (var i = 0; i < tabs.Count; i++)
        {
            if (i > 0)
            {
                Console.Write(" ");
            }

            if (i == selectedIndex)
            {
                var oldForeground = Console.ForegroundColor;
                var oldBackground = Console.BackgroundColor;

                Console.ForegroundColor = GetHighlightTextColor();
                Console.BackgroundColor = GetHighlightBackgroundColor();
                Console.Write($"[{tabs[i]}]");
                Console.ForegroundColor = oldForeground;
                Console.BackgroundColor = oldBackground;
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.DarkGray;
                Console.Write($" {tabs[i]} ");
                Console.ResetColor();
            }
        }

        Console.WriteLine();
    }

    public static void DrawPanel(string title, IEnumerable<string> lines)
    {
        var list = lines.ToList();
        var maxLine = Math.Max(title.Length, list.Count == 0 ? 0 : list.Max(x => x.Length));
        var width = Math.Max(48, maxLine + 8);
        var line = new string('═', width - 2);

        Console.WriteLine($"╔{line}╗");
        Console.Write("║ ");
        Console.ForegroundColor = GetAccentColor();
        Console.Write(title);
        Console.ResetColor();
        Console.WriteLine(new string(' ', width - 4 - title.Length) + "║");
        Console.WriteLine($"╠{new string('═', width - 2)}╣");

        if (list.Count == 0)
        {
            Console.WriteLine($"║ {PadRightSafe("No data", width - 4)} ║");
        }
        else
        {
            foreach (var entry in list)
            {
                Console.WriteLine($"║ {PadRightSafe(entry, width - 4)} ║");
            }
        }

        Console.WriteLine($"╚{line}╝");
    }

    public static void WriteDim(string text)
    {
        var oldColor = Console.ForegroundColor;
        Console.ForegroundColor = ConsoleColor.DarkGray;
        Console.WriteLine(text);
        Console.ForegroundColor = oldColor;
    }

    private static string PadRightSafe(string text, int width)
    {
        if (text.Length >= width)
        {
            return text[..width];
        }

        return text.PadRight(width);
    }

    private static ConsoleColor GetAccentColor()
    {
        return _theme switch
        {
            ConsoleTheme.Neon => ConsoleColor.Cyan,
            ConsoleTheme.Dark => ConsoleColor.White,
            ConsoleTheme.Classic => ConsoleColor.Green,
            _ => ConsoleColor.Cyan
        };
    }

    private static ConsoleColor GetHighlightTextColor()
    {
        return _theme switch
        {
            ConsoleTheme.Classic => ConsoleColor.Black,
            _ => ConsoleColor.Black
        };
    }

    private static ConsoleColor GetHighlightBackgroundColor()
    {
        return _theme switch
        {
            ConsoleTheme.Neon => ConsoleColor.Gray,
            ConsoleTheme.Dark => ConsoleColor.Gray,
            ConsoleTheme.Classic => ConsoleColor.White,
            _ => ConsoleColor.Gray
        };
    }
}

internal readonly record struct LogEntry(DateTime Time, string Source, string Message, ConsoleColor Color);