using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using NetBackend.Client;
using NetBackend.Server;

namespace MultiplayerBoxClient;

internal sealed class Network
{
    private const int DefaultPort = 8888;

    private readonly NetHost _host = new();
    private CancellationTokenSource? _hostCts;
    private Task? _hostTask;
    private bool _hostEventsAttached;
    private bool _clientConnected;
    private string? _currentHostIp;
    private string? _currentRoomCode;
    private IReadOnlyList<string> _cachedRooms = Array.Empty<string>();

    public NetClient Client { get; } = new();

    public int Port { get; set; } = DefaultPort;
    public string DefaultHostIp { get; set; } = IPAddress.Loopback.ToString();
    public bool AutoRefreshRooms { get; set; } = true;
    public int RefreshIntervalMs { get; set; } = 1500;

    public bool IsHosting => _hostCts != null && !_hostCts.IsCancellationRequested;
    public bool IsClientConnected => _clientConnected;

    public string? CurrentHostIp => _currentHostIp;
    public string? CurrentRoomCode => _currentRoomCode;

    public IReadOnlyList<string> CachedRooms => _cachedRooms;

    public int IncomingPackets { get; private set; }
    public int OutgoingPackets { get; private set; }

    public IReadOnlyList<IPAddress> LocalAddresses => GetLocalIPv4Addresses().ToArray();

    public void MarkClientConnected()
    {
        _clientConnected = true;
    }

    public void MarkClientDisconnected()
    {
        _clientConnected = false;
    }

    public void MarkIncomingPacket()
    {
        IncomingPackets++;
    }

    public void MarkOutgoingPacket()
    {
        OutgoingPackets++;
    }

    public async Task StartHostedRoomAsync()
    {
        await StopAsync();
        AttachHostEventsOnce();

        _hostCts = new CancellationTokenSource();
        _hostTask = _host.StartAsync(Port, _hostCts.Token);

        await Task.Delay(150);

        _currentHostIp = IPAddress.Loopback.ToString();
        await Client.ConnectAsync(IPAddress.Loopback.ToString(), Port);
        MarkClientConnected();

        _currentRoomCode = await Client.CreateRoomAsync();
        _cachedRooms = Array.Empty<string>();
    }

    public async Task ConnectAsync(string host)
    {
        _currentHostIp = host.Trim();
        await Client.ConnectAsync(_currentHostIp, Port);
    }

    public async Task<IReadOnlyList<string>> RefreshRoomsAsync()
    {
        var rooms = await Client.GetRoomsAsync();
        _cachedRooms = rooms.ToArray();
        return _cachedRooms;
    }

    public async Task JoinRoomAsync(string room)
    {
        await Client.JoinRoomAsync(room);
        _currentRoomCode = room;
    }

    public async Task StopAsync()
    {
        try
        {
            await Client.DisconnectAsync();
        }
        catch
        {
        }

        MarkClientDisconnected();

        if (_hostCts == null)
        {
            _currentHostIp = null;
            _currentRoomCode = null;
            _cachedRooms = Array.Empty<string>();
            return;
        }

        try
        {
            _hostCts.Cancel();
        }
        catch
        {
        }

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
        _currentHostIp = null;
        _currentRoomCode = null;
        _cachedRooms = Array.Empty<string>();
    }

    private void AttachHostEventsOnce()
    {
        if (_hostEventsAttached)
        {
            return;
        }

        _hostEventsAttached = true;

        _host.OnLog += message => ConsoleUi.Log("HOST", message, ConsoleColor.DarkGray);
        _host.OnRoomCreated += (roomId, clientId) => ConsoleUi.Log("HOST", $"Room {roomId} created by {clientId}", ConsoleColor.Green);
        _host.OnRoomJoined += (roomId, clientId) => ConsoleUi.Log("HOST", $"{clientId} joined {roomId}", ConsoleColor.Cyan);
        _host.OnMessageBroadcasted += (roomId, clientId, _) => ConsoleUi.Log("HOST", $"Message from {clientId} in {roomId}", ConsoleColor.DarkCyan);
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