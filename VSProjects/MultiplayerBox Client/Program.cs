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

internal sealed class AppShell
{
    private readonly Network _network;
    private readonly string[] _tabs =
    {
        "Главная",
        "Инспектор",
        "Настройки",
        "Создать/Join"
    };

    private int _selectedTab;

    public AppShell(Network network)
    {
        _network = network;
    }

    public async Task RunAsync()
    {
        while (true)
        {
            Render();

            var key = Console.ReadKey(true).Key;

            if (key == ConsoleKey.LeftArrow)
            {
                _selectedTab = (_selectedTab - 1 + _tabs.Length) % _tabs.Length;
                continue;
            }

            if (key == ConsoleKey.RightArrow)
            {
                _selectedTab = (_selectedTab + 1) % _tabs.Length;
                continue;
            }

            if (key == ConsoleKey.D1 || key == ConsoleKey.NumPad1)
            {
                _selectedTab = 0;
                continue;
            }

            if (key == ConsoleKey.D2 || key == ConsoleKey.NumPad2)
            {
                _selectedTab = 1;
                continue;
            }

            if (key == ConsoleKey.D3 || key == ConsoleKey.NumPad3)
            {
                _selectedTab = 2;
                continue;
            }

            if (key == ConsoleKey.D4 || key == ConsoleKey.NumPad4)
            {
                _selectedTab = 3;
                continue;
            }

            if (key == ConsoleKey.Escape)
            {
                if (_selectedTab == 0)
                {
                    break;
                }

                _selectedTab = 0;
                continue;
            }

            if (key == ConsoleKey.F5)
            {
                continue;
            }

            if (_selectedTab == 1 && key == ConsoleKey.C)
            {
                ConsoleUi.ClearLogs();
                continue;
            }

            if (key == ConsoleKey.Enter)
            {
                switch (_selectedTab)
                {
                    case 0:
                        await OpenConnectionAsync();
                        break;
                    case 1:
                        await RefreshInspectorAsync();
                        break;
                    case 2:
                        await OpenSettingsAsync();
                        break;
                    case 3:
                        await OpenConnectionAsync();
                        break;
                }
            }
        }
    }

    private void Render()
    {
        Console.Clear();

        var subtitle =
            $"Theme: {ConsoleUi.CurrentThemeName} | Port: {_network.Port} | " +
            $"State: {GetStateText()}";

        ConsoleUi.DrawHeader("MultiplayerBox Client", subtitle);
        Console.WriteLine();

        ConsoleUi.DrawTabs(_tabs, _selectedTab);
        Console.WriteLine();

        switch (_selectedTab)
        {
            case 0:
                RenderHomeTab();
                break;
            case 1:
                RenderInspectorTab();
                break;
            case 2:
                RenderSettingsTab();
                break;
            case 3:
                RenderConnectionTab();
                break;
        }

        Console.WriteLine();
        ConsoleUi.WriteDim("← → tabs | 1-4 jump | Enter action | Esc back | F5 redraw | C clear logs in inspector");
    }

    private void RenderHomeTab()
    {
        ConsoleUi.DrawPanel("Стартовая панель", new[]
        {
            $"Client ID: {OrDash(_network.Client.ClientId)}",
            $"Connected: {BoolText(_network.IsClientConnected)}",
            $"Hosting: {BoolText(_network.IsHosting)}",
            $"Current host: {OrDash(_network.CurrentHostIp)}",
            $"Current room: {OrDash(_network.CurrentRoomCode)}",
            $"Packets in/out: {_network.IncomingPackets} / {_network.OutgoingPackets}"
        });

        Console.WriteLine();

        ConsoleUi.DrawPanel("Быстрые действия", new[]
        {
            "Enter на этой вкладке открывает меню подключения",
            "На вкладке Настройки можно сменить тему, порт и IP по умолчанию",
            "На вкладке Инспектор есть живые логи и состояние сети"
        });
    }

    private void RenderInspectorTab()
    {
        var inspectorLines = new List<string>
        {
            $"Mode: {GetStateText()}",
            $"Client ID: {OrDash(_network.Client.ClientId)}",
            $"Host IP: {OrDash(_network.CurrentHostIp)}",
            $"Room code: {OrDash(_network.CurrentRoomCode)}",
            $"Port: {_network.Port}",
            $"Default host IP: {_network.DefaultHostIp}",
            $"Auto refresh rooms: {BoolText(_network.AutoRefreshRooms)}",
            $"Refresh interval: {_network.RefreshIntervalMs} ms",
            $"Connected: {BoolText(_network.IsClientConnected)}",
            $"Hosting: {BoolText(_network.IsHosting)}",
            $"Rooms cached: {_network.CachedRooms.Count}",
            $"Packets in/out: {_network.IncomingPackets} / {_network.OutgoingPackets}"
        };

        ConsoleUi.DrawPanel("Афигенный инспектор", inspectorLines);
        Console.WriteLine();

        var addresses = _network.LocalAddresses
            .Select(x => $"• {x}")
            .ToList();

        if (addresses.Count == 0)
        {
            addresses.Add("No active IPv4 addresses");
        }

        ConsoleUi.DrawPanel("Local IPv4", addresses);
        Console.WriteLine();

        var logs = ConsoleUi.GetRecentLogs(10)
            .Select(x => $"{x.Time:HH:mm:ss} [{x.Source}] {x.Message}")
            .ToList();

        if (logs.Count == 0)
        {
            logs.Add("No logs yet");
        }

        ConsoleUi.DrawPanel("Recent logs", logs);
    }

    private void RenderSettingsTab()
    {
        ConsoleUi.DrawPanel("Настройки", new[]
        {
            $"Theme: {ConsoleUi.CurrentThemeName}",
            $"Port: {_network.Port}",
            $"Default host IP: {_network.DefaultHostIp}",
            $"Auto refresh rooms: {BoolText(_network.AutoRefreshRooms)}",
            $"Refresh interval: {_network.RefreshIntervalMs} ms",
            $"Timestamps in logs: {BoolText(ConsoleUi.ShowTimestamps)}"
        });

        Console.WriteLine();

        ConsoleUi.DrawPanel("Управление", new[]
        {
            "Enter — открыть редактор настроек",
            "В редакторе можно сменить тему, порт, IP по умолчанию и интервал обновления",
            "Логи можно очищать на вкладке инспектора"
        });
    }

    private void RenderConnectionTab()
    {
        ConsoleUi.DrawPanel("Создать / Присоединиться", new[]
        {
            "Enter — открыть меню подключения",
            $"Default host IP: {OrDash(_network.DefaultHostIp)}",
            $"Port: {_network.Port}",
            $"Current room: {OrDash(_network.CurrentRoomCode)}",
            $"Hosting: {BoolText(_network.IsHosting)}",
            $"Connected: {BoolText(_network.IsClientConnected)}"
        });

        Console.WriteLine();

        ConsoleUi.DrawPanel("Доступные сценарии", new[]
        {
            "Host room — запускает локальный хост и создаёт комнату",
            "Join room — подключается к хосту, обновляет список комнат и даёт выбрать",
            "Disconnect — полностью отключает клиент и хост"
        });
    }

    private async Task RefreshInspectorAsync()
    {
        if (_selectedTab != 1)
        {
            return;
        }

        if (_network.AutoRefreshRooms && _network.IsClientConnected)
        {
            try
            {
                await _network.RefreshRoomsAsync();
            }
            catch (Exception ex)
            {
                ConsoleUi.Log("INSPECTOR", ex.Message, ConsoleColor.Red);
            }
        }
    }

    private async Task OpenSettingsAsync()
    {
        var items = new[]
        {
            $"Theme: Neon",
            $"Theme: Dark",
            $"Theme: Classic",
            $"Edit port",
            $"Edit default host IP",
            $"Toggle auto refresh",
            $"Set refresh interval",
            $"Toggle timestamps in logs",
            $"Clear logs",
            "Back"
        };

        var index = ConsoleUi.ShowSelectableMenu(
            "Settings",
            "Theme, room and connection settings",
            items,
            "↑ ↓  Enter  Esc"
        );

        if (index == null)
        {
            return;
        }

        switch (index.Value)
        {
            case 0:
                ConsoleUi.SetTheme(ConsoleTheme.Neon);
                break;
            case 1:
                ConsoleUi.SetTheme(ConsoleTheme.Dark);
                break;
            case 2:
                ConsoleUi.SetTheme(ConsoleTheme.Classic);
                break;
            case 3:
                {
                    var value = ConsoleUi.Prompt("Port", _network.Port.ToString());
                    if (int.TryParse(value, out var port) && port is > 0 and < 65536)
                    {
                        _network.Port = port;
                    }
                    break;
                }
            case 4:
                {
                    var value = ConsoleUi.Prompt("Default host IP", _network.DefaultHostIp);
                    if (!string.IsNullOrWhiteSpace(value))
                    {
                        _network.DefaultHostIp = value.Trim();
                    }
                    break;
                }
            case 5:
                _network.AutoRefreshRooms = !_network.AutoRefreshRooms;
                break;
            case 6:
                {
                    var value = ConsoleUi.Prompt("Refresh interval in ms", _network.RefreshIntervalMs.ToString());
                    if (int.TryParse(value, out var ms) && ms >= 250)
                    {
                        _network.RefreshIntervalMs = ms;
                    }
                    break;
                }
            case 7:
                ConsoleUi.ShowTimestamps = !ConsoleUi.ShowTimestamps;
                break;
            case 8:
                ConsoleUi.ClearLogs();
                break;
        }
    }

    private async Task OpenConnectionAsync()
    {
        var items = new[]
        {
            "Host room",
            "Join room",
            "Disconnect",
            "Back"
        };

        var index = ConsoleUi.ShowSelectableMenu(
            "Connection",
            "Create a room or connect to an existing one",
            items,
            "↑ ↓  Enter  Esc"
        );

        if (index == null)
        {
            return;
        }

        switch (index.Value)
        {
            case 0:
                await StartHostSessionAsync();
                break;
            case 1:
                await StartJoinSessionAsync();
                break;
            case 2:
                await _network.StopAsync();
                break;
        }
    }

    private async Task StartHostSessionAsync()
    {
        try
        {
            await _network.StartHostedRoomAsync();
            ConsoleUi.Log("NETWORK", $"Hosted room created: {_network.CurrentRoomCode}", ConsoleColor.Green);
        }
        catch (Exception ex)
        {
            ConsoleUi.Log("HOST", ex.Message, ConsoleColor.Red);
            ConsoleUi.Pause();
        }
    }

    private async Task StartJoinSessionAsync()
    {
        await _network.StopAsync();

        var host = ConsoleUi.Prompt("Host IP", _network.DefaultHostIp);

        if (string.IsNullOrWhiteSpace(host))
        {
            return;
        }

        _network.DefaultHostIp = host.Trim();

        try
        {
            await _network.ConnectAsync(_network.DefaultHostIp);
        }
        catch (Exception ex)
        {
            ConsoleUi.Log("CLIENT", ex.Message, ConsoleColor.Red);
            ConsoleUi.Pause();
            return;
        }

        try
        {
            var rooms = await _network.RefreshRoomsAsync();

            if (rooms.Count == 0)
            {
                ConsoleUi.Log("CLIENT", "No active rooms found", ConsoleColor.DarkYellow);
                ConsoleUi.Pause();
                return;
            }

            var roomIndex = ConsoleUi.ShowSelectableMenu(
                "Available rooms",
                $"Connected to {_network.DefaultHostIp}:{_network.Port}",
                rooms,
                "↑ ↓  Enter  Esc"
            );

            if (roomIndex == null)
            {
                return;
            }

            var room = rooms[roomIndex.Value];
            await _network.JoinRoomAsync(room);

            ConsoleUi.Log("CLIENT", $"Joined room {room}", ConsoleColor.Green);
            ConsoleUi.Pause("Press any key to continue...");
        }
        catch (Exception ex)
        {
            ConsoleUi.Log("CLIENT", ex.Message, ConsoleColor.Red);
            ConsoleUi.Pause();
        }
    }

    private string GetStateText()
    {
        if (_network.IsHosting)
        {
            return "Hosting";
        }

        if (_network.IsClientConnected)
        {
            return "Connected";
        }

        return "Idle";
    }

    private static string OrDash(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? "-" : value;
    }

    private static string BoolText(bool value)
    {
        return value ? "Yes" : "No";
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