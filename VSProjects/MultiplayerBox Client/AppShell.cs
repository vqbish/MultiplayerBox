using System.Text.Json;

namespace MultiplayerBoxClient;

internal sealed class AppShell
{
    private readonly Network _network;
    private readonly string[] _tabs =
    {
        "Главная",
        "Инспектор",
        "Настройки",
        "Создать/Join",
        "Ping mod"
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
                    case 4:
                        SendPingToMod();
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
            "Enter на вкладке Создать/Join откроет picker подключения",
            "На вкладке Настройки можно сменить тему, порт и IP по умолчанию",
            "На вкладке Инспектор есть живые логи, локальные IP и recent hosts"
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

        var recentHosts = _network.RecentHosts
            .Take(10)
            .Select(FormatHostLine)
            .ToList();

        if (recentHosts.Count == 0)
        {
            recentHosts.Add("No discovered hosts yet");
        }

        ConsoleUi.DrawPanel("Recent LAN hosts", recentHosts);
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
            "Enter — открыть picker подключения",
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
            "LAN picker — сканирует подсеть и показывает IP + имена машин",
            "Manual IP — подключение по выбранному адресу с таймаутом",
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

    private async Task SendPingToMod()
    {
        await Program.Bridge.SendPostAsync("custom", new Dictionary<string, string>
        {
            ["type"] = "PING",
            ["message"] = "Client is alive"
        });

        return;
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
            "Join via LAN picker",
            "Join by IP",
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
                await StartJoinFromLanAsync();
                break;
            case 2:
                await StartJoinByIpAsync();
                break;
            case 3:
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

    private async Task StartJoinFromLanAsync()
    {
        Console.Clear();
        ConsoleUi.DrawHeader("LAN picker", "Scanning local network");
        Console.WriteLine();
        ConsoleUi.WriteDim("Scanning hosts...");
        Console.WriteLine();

        IReadOnlyList<LanHostInfo> hosts;

        try
        {
            hosts = await _network.ScanLanHostsAsync();
        }
        catch (Exception ex)
        {
            ConsoleUi.Log("LAN", ex.Message, ConsoleColor.Red);
            ConsoleUi.Pause();
            return;
        }

        if (hosts.Count == 0)
        {
            ConsoleUi.Log("LAN", "No active hosts found in local subnets", ConsoleColor.DarkYellow);
            ConsoleUi.Pause();
            return;
        }

        var items = hosts
            .Select(FormatHostLine)
            .ToArray();

        var selected = ConsoleUi.ShowSelectableMenu(
            "LAN picker",
            "Select a host by IP / name / interface",
            items,
            "↑ ↓  Enter  Esc"
        );

        if (selected == null)
        {
            return;
        }

        await ConnectThenPickRoomAsync(hosts[selected.Value].Ip);
    }

    private async Task StartJoinByIpAsync()
    {
        var host = ConsoleUi.Prompt("Host IP", _network.DefaultHostIp);

        if (string.IsNullOrWhiteSpace(host))
        {
            return;
        }

        await ConnectThenPickRoomAsync(host.Trim());
    }

    private async Task ConnectThenPickRoomAsync(string host)
    {
        try
        {
            await _network.ConnectAsync(host);
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
                $"Connected to {host}:{_network.Port}",
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

    private static string FormatHostLine(LanHostInfo host)
    {
        var name = string.IsNullOrWhiteSpace(host.Name) ? "-" : host.Name;
        var iface = string.IsNullOrWhiteSpace(host.InterfaceName) ? "-" : host.InterfaceName;

        return $"{host.Ip,-15}  {name,-30}  {iface}";
    }
}