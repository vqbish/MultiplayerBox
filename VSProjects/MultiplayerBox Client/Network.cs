using System.Collections.Concurrent;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using NetBackend.Client;
using NetBackend.Server;

namespace MultiplayerBoxClient;

internal sealed class Network
{
    private const int DefaultPort = 8888;
    private static readonly TimeSpan OperationTimeout = TimeSpan.FromSeconds(6);

    private readonly NetHost _host = new();
    private readonly object _recentHostsSync = new();
    private readonly List<LanHostInfo> _recentHosts = new();

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

    public IReadOnlyList<LanHostInfo> RecentHosts
    {
        get
        {
            lock (_recentHostsSync)
            {
                return _recentHosts.ToArray();
            }
        }
    }

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

        await ConnectAsync(IPAddress.Loopback.ToString());
        _currentRoomCode = await RunWithTimeoutAsync(() => Client.CreateRoomAsync(), OperationTimeout, "Create room");
        _cachedRooms = Array.Empty<string>();
    }

    public async Task ConnectAsync(string host)
    {
        var normalizedHost = NormalizeHost(host);

        await RunWithTimeoutAsync(
            () => Client.ConnectAsync(normalizedHost, Port),
            OperationTimeout,
            $"Connect to {normalizedHost}:{Port}");

        _currentHostIp = normalizedHost;
        MarkClientConnected();
        RememberRecentHost(normalizedHost, null, null);
    }

    public async Task<IReadOnlyList<string>> RefreshRoomsAsync()
    {
        var rooms = await RunWithTimeoutAsync(
            () => Client.GetRoomsAsync(),
            OperationTimeout,
            "Get rooms");

        _cachedRooms = rooms.ToArray();
        return _cachedRooms;
    }

    public async Task JoinRoomAsync(string room)
    {
        await RunWithTimeoutAsync(
            () => Client.JoinRoomAsync(room),
            OperationTimeout,
            $"Join room {room}");

        _currentRoomCode = room;
    }

    public async Task<IReadOnlyList<LanHostInfo>> ScanLanHostsAsync()
    {
        var ownAddresses = GetLocalIPv4Addresses()
            .Select(x => x.ToString())
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var candidates = GetLanCandidates()
            .Where(x => !ownAddresses.Contains(x.Address.ToString()))
            .GroupBy(x => x.Address.ToString())
            .Select(g => g.First())
            .ToArray();

        if (candidates.Length == 0)
        {
            return Array.Empty<LanHostInfo>();
        }

        var results = new ConcurrentBag<LanHostInfo>();
        using var throttle = new SemaphoreSlim(48);

        var tasks = candidates.Select(async candidate =>
        {
            await throttle.WaitAsync();

            try
            {
                if (!await IsHostAliveAsync(candidate.Address, 220))
                {
                    return;
                }

                var name = await TryResolveNameAsync(candidate.Address, 220);
                var info = new LanHostInfo(candidate.Address.ToString(), name, candidate.InterfaceName);
                results.Add(info);
                RememberRecentHost(info.Ip, info.Name, info.InterfaceName);
            }
            finally
            {
                throttle.Release();
            }
        });

        await Task.WhenAll(tasks);

        return results
            .OrderBy(x => x.Ip, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public async Task StopAsync()
    {
        try
        {
            await RunWithTimeoutAsync(
                () => Client.DisconnectAsync(),
                TimeSpan.FromSeconds(3),
                "Disconnect");
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

    private void RememberRecentHost(string ip, string? name, string? interfaceName)
    {
        lock (_recentHostsSync)
        {
            var index = _recentHosts.FindIndex(x => string.Equals(x.Ip, ip, StringComparison.OrdinalIgnoreCase));
            var item = new LanHostInfo(ip, name, interfaceName);

            if (index >= 0)
            {
                _recentHosts[index] = item;
            }
            else
            {
                _recentHosts.Insert(0, item);
            }

            if (_recentHosts.Count > 64)
            {
                _recentHosts.RemoveRange(64, _recentHosts.Count - 64);
            }
        }
    }

    private static string NormalizeHost(string host)
    {
        var trimmed = host.Trim();

        if (string.IsNullOrWhiteSpace(trimmed))
        {
            throw new ArgumentException("Host is empty.", nameof(host));
        }

        return trimmed;
    }

    private static async Task<T> RunWithTimeoutAsync<T>(Func<Task<T>> action, TimeSpan timeout, string operationName)
    {
        var task = Task.Run(action);
        var completed = await Task.WhenAny(task, Task.Delay(timeout));

        if (completed != task)
        {
            throw new TimeoutException($"{operationName} timed out after {timeout.TotalSeconds:0}s.");
        }

        return await task;
    }

    private static async Task RunWithTimeoutAsync(Func<Task> action, TimeSpan timeout, string operationName)
    {
        var task = Task.Run(action);
        var completed = await Task.WhenAny(task, Task.Delay(timeout));

        if (completed != task)
        {
            throw new TimeoutException($"{operationName} timed out after {timeout.TotalSeconds:0}s.");
        }

        await task;
    }

    private static async Task<bool> IsHostAliveAsync(IPAddress address, int timeoutMs)
    {
        try
        {
            using var ping = new Ping();
            var reply = await ping.SendPingAsync(address, timeoutMs);
            return reply.Status == IPStatus.Success;
        }
        catch
        {
            return false;
        }
    }

    private static async Task<string?> TryResolveNameAsync(IPAddress address, int timeoutMs)
    {
        try
        {
            var task = Dns.GetHostEntryAsync(address);
            var completed = await Task.WhenAny(task, Task.Delay(timeoutMs));

            if (completed != task)
            {
                return null;
            }

            var entry = await task;
            return string.IsNullOrWhiteSpace(entry.HostName) ? null : entry.HostName;
        }
        catch
        {
            return null;
        }
    }

    private static IEnumerable<SubnetCandidate> GetLanCandidates()
    {
        foreach (var adapter in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (adapter.OperationalStatus != OperationalStatus.Up)
            {
                continue;
            }

            var properties = adapter.GetIPProperties();

            foreach (var address in properties.UnicastAddresses)
            {
                if (address.Address.AddressFamily != AddressFamily.InterNetwork)
                {
                    continue;
                }

                if (IPAddress.IsLoopback(address.Address))
                {
                    continue;
                }

                if (address.IPv4Mask == null)
                {
                    continue;
                }

                foreach (var candidate in EnumerateSubnet(address.Address, address.IPv4Mask, adapter.Name))
                {
                    yield return candidate;
                }
            }
        }
    }

    private static IEnumerable<SubnetCandidate> EnumerateSubnet(IPAddress ip, IPAddress mask, string interfaceName)
    {
        var ipValue = ToUInt32(ip);
        var maskValue = ToUInt32(mask);

        var network = ipValue & maskValue;
        var broadcast = network | ~maskValue;

        var hostCount = broadcast > network ? broadcast - network - 1 : 0;
        if (hostCount == 0)
        {
            yield break;
        }

        var limit = Math.Min(hostCount, 254u);

        for (var i = 1u; i <= limit; i++)
        {
            yield return new SubnetCandidate(FromUInt32(network + i), interfaceName);
        }
    }

    private static uint ToUInt32(IPAddress ip)
    {
        var bytes = ip.GetAddressBytes();

        if (BitConverter.IsLittleEndian)
        {
            Array.Reverse(bytes);
        }

        return BitConverter.ToUInt32(bytes, 0);
    }

    private static IPAddress FromUInt32(uint value)
    {
        var bytes = BitConverter.GetBytes(value);

        if (BitConverter.IsLittleEndian)
        {
            Array.Reverse(bytes);
        }

        return new IPAddress(bytes);
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

    private readonly record struct SubnetCandidate(IPAddress Address, string InterfaceName);
}

internal sealed record LanHostInfo(string Ip, string? Name, string? InterfaceName);