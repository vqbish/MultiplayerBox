using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using NetBackend.Client;
using NetBackend.Server;

namespace MultiplayerBoxClient;

internal sealed class Network
{
    private const int Port = 8888;

    private readonly NetHost _host = new();
    private CancellationTokenSource? _hostCts;
    private Task? _hostTask;

    public NetClient Client { get; } = new();

    public async Task StartAsync()
    {
        Console.Clear();
        Console.WriteLine("=== MultiplayerBox ===");
        Console.WriteLine("1. Host room");
        Console.WriteLine("2. Join room");
        Console.Write("> ");

        var key = Console.ReadKey(true).Key;

        if (key is ConsoleKey.D1 or ConsoleKey.NumPad1)
        {
            await RunHostModeAsync();
            return;
        }

        if (key is ConsoleKey.D2 or ConsoleKey.NumPad2)
        {
            await RunClientModeAsync();
        }
    }

    public async Task StopAsync()
    {
        await Client.DisconnectAsync();

        if (_hostCts == null)
        {
            return;
        }

        _hostCts.Cancel();

        if (_hostTask != null)
        {
            try
            {
                await _hostTask.WaitAsync(TimeSpan.FromSeconds(2));
            }
            catch
            {
            }
        }

        _hostCts.Dispose();
        _hostCts = null;
        _hostTask = null;
    }

    private async Task RunHostModeAsync()
    {
        _host.OnLog += message => Console.WriteLine($"[HOST] {message}");
        _host.OnRoomCreated += (roomId, clientId) => Console.WriteLine($"[HOST] Room {roomId} created by {clientId}");
        _host.OnRoomJoined += (roomId, clientId) => Console.WriteLine($"[HOST] {clientId} joined {roomId}");
        _host.OnMessageBroadcasted += (roomId, clientId, _) => Console.WriteLine($"[HOST] Message from {clientId} in {roomId}");

        _hostCts = new CancellationTokenSource();
        _hostTask = _host.StartAsync(Port, _hostCts.Token);

        await Client.ConnectAsync(IPAddress.Loopback.ToString(), Port);

        var roomCode = await Client.CreateRoomAsync();
        Console.WriteLine();
        Console.WriteLine($"Room code: {roomCode}");
        Console.WriteLine($"Port: {Port}");

        foreach (var address in GetLocalIPv4Addresses())
        {
            Console.WriteLine($"- {address}");
        }

        Console.WriteLine();
        Console.WriteLine("Press any key to stop host.");
        Console.ReadKey(true);

        await StopAsync();
    }

    private async Task RunClientModeAsync()
    {
        Console.WriteLine();
        Console.Write("Host IP: ");

        var host = Console.ReadLine();

        if (string.IsNullOrWhiteSpace(host))
        {
            host = IPAddress.Loopback.ToString();
        }

        await Client.ConnectAsync(host.Trim(), Port);

        var rooms = await Client.GetRoomsAsync();

        if (rooms.Length == 0)
        {
            Console.WriteLine("No active rooms found.");
            Console.WriteLine("Press any key to exit.");
            Console.ReadKey(true);
            return;
        }

        var room = SelectRoom(rooms);
        await Client.JoinRoomAsync(room);

        Console.WriteLine();
        Console.WriteLine($"Joined room: {room}");
        Console.WriteLine("Press any key to disconnect.");
        Console.ReadKey(true);

        await StopAsync();
    }

    private static string SelectRoom(IReadOnlyList<string> rooms)
    {
        var selectedIndex = 0;

        while (true)
        {
            Console.Clear();
            Console.WriteLine("Select room with arrows and Enter:");
            Console.WriteLine();

            for (var i = 0; i < rooms.Count; i++)
            {
                if (i == selectedIndex)
                {
                    Console.ForegroundColor = ConsoleColor.Black;
                    Console.BackgroundColor = ConsoleColor.Gray;
                    Console.WriteLine($"> {rooms[i]} <");
                    Console.ResetColor();
                    continue;
                }

                Console.WriteLine($"  {rooms[i]}");
            }

            var key = Console.ReadKey(true).Key;

            selectedIndex = key switch
            {
                ConsoleKey.UpArrow => Math.Max(0, selectedIndex - 1),
                ConsoleKey.DownArrow => Math.Min(rooms.Count - 1, selectedIndex + 1),
                _ => selectedIndex
            };

            if (key == ConsoleKey.Enter)
            {
                return rooms[selectedIndex];
            }
        }
    }

    private static IEnumerable<IPAddress> GetLocalIPv4Addresses()
    {
        return NetworkInterface.GetAllNetworkInterfaces()
            .Where(adapter => adapter.OperationalStatus == OperationalStatus.Up)
            .SelectMany(adapter => adapter.GetIPProperties().UnicastAddresses)
            .Select(address => address.Address)
            .Where(address => address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(address))
            .Distinct();
    }
}
