using System.Collections.Concurrent;
using System.Net;
using System.Net.Sockets;
using System.Text;
using NetBackend.Shared;

namespace NetBackend.Server;

public sealed class NetHost
{
    private readonly ConcurrentDictionary<string, Room> _rooms = new();
    private readonly ConcurrentDictionary<Guid, ClientSession> _sessions = new();

    private TcpListener? _listener;

    public event Action<string>? OnLog;
    public event Action<string, string>? OnRoomCreated;
    public event Action<string, string>? OnRoomJoined;
    public event Action<string, string, string>? OnMessageBroadcasted;

    public async Task StartAsync(int port, CancellationToken ct = default)
    {
        if (_listener != null)
        {
            throw new InvalidOperationException("Host is already running.");
        }

        _listener = new TcpListener(IPAddress.Any, port);
        _listener.Start();

        OnLog?.Invoke($"Host started on 0.0.0.0:{port}");

        try
        {
            while (!ct.IsCancellationRequested)
            {
                var client = await _listener.AcceptTcpClientAsync(ct);
                _ = Task.Run(() => HandleClientAsync(client, ct), CancellationToken.None);
            }
        }
        catch (OperationCanceledException)
        {
        }
        finally
        {
            _listener.Stop();
            _listener = null;
            OnLog?.Invoke("Host stopped");
        }
    }

    public string[] GetActiveRooms()
    {
        return _rooms.Keys.Order().ToArray();
    }

    private async Task HandleClientAsync(TcpClient tcpClient, CancellationToken ct)
    {
        tcpClient.NoDelay = true;

        var session = new ClientSession(tcpClient);
        _sessions[session.Id] = session;
        OnLog?.Invoke($"Client connected: {session.Id}");

        try
        {
            using var stream = session.Stream;
            using var reader = new StreamReader(stream, Encoding.UTF8, false, 4096, true);

            while (!ct.IsCancellationRequested && tcpClient.Connected)
            {
                var packet = await PacketCodec.ReadAsync(reader, ct);

                if (packet == null)
                {
                    break;
                }

                await ProcessPacketAsync(session, packet, ct);
            }
        }
        catch (Exception ex) when (ex is IOException or SocketException or OperationCanceledException)
        {
        }
        finally
        {
            RemoveSessionFromRoom(session);
            _sessions.TryRemove(session.Id, out _);
            session.Dispose();
            tcpClient.Close();
            OnLog?.Invoke($"Client disconnected: {session.Id}");
        }
    }

    private async Task ProcessPacketAsync(ClientSession session, NetworkPacket packet, CancellationToken ct)
    {
        switch (packet.Type)
        {
            case PacketType.RequestRooms:
                await session.SendAsync(new NetworkPacket
                {
                    Type = PacketType.RoomsList,
                    DataList = GetActiveRooms()
                }, ct);
                break;

            case PacketType.CreateRoom:
                await CreateRoomAsync(session, packet, ct);
                break;

            case PacketType.JoinRoom:
                await JoinRoomAsync(session, packet, ct);
                break;

            case PacketType.Message:
                await BroadcastMessageAsync(session, packet, ct);
                break;

            case PacketType.LeaveRoom:
                RemoveSessionFromRoom(session);
                break;
        }
    }

    private async Task CreateRoomAsync(ClientSession session, NetworkPacket packet, CancellationToken ct)
    {
        RemoveSessionFromRoom(session);

        var roomId = GenerateRoomCode();
        var room = new Room(roomId);

        _rooms[roomId] = room;
        session.ClientId = NormalizeClientId(packet.ClientId);
        room.Add(session);

        await session.SendAsync(new NetworkPacket
        {
            Type = PacketType.RoomJoined,
            RoomId = roomId
        }, ct);

        OnRoomCreated?.Invoke(roomId, session.ClientId);
    }

    private async Task JoinRoomAsync(ClientSession session, NetworkPacket packet, CancellationToken ct)
    {
        var roomId = packet.RoomId?.Trim().ToUpperInvariant();

        if (roomId == null || !_rooms.TryGetValue(roomId, out var room))
        {
            await session.SendAsync(new NetworkPacket
            {
                Type = PacketType.Error,
                Payload = "Room not found"
            }, ct);
            return;
        }

        RemoveSessionFromRoom(session);

        session.ClientId = NormalizeClientId(packet.ClientId);
        room.Add(session);

        await session.SendAsync(new NetworkPacket
        {
            Type = PacketType.RoomJoined,
            RoomId = roomId
        }, ct);

        OnRoomJoined?.Invoke(roomId, session.ClientId);
    }

    private async Task BroadcastMessageAsync(ClientSession session, NetworkPacket packet, CancellationToken ct)
    {
        if (session.RoomId == null || packet.Payload == null)
        {
            return;
        }

        if (!_rooms.TryGetValue(session.RoomId, out var room))
        {
            return;
        }

        var message = new NetworkPacket
        {
            Type = PacketType.Message,
            RoomId = session.RoomId,
            ClientId = session.ClientId,
            Payload = packet.Payload
        };

        await room.BroadcastAsync(message, session.Id, ct);
        OnMessageBroadcasted?.Invoke(session.RoomId, session.ClientId, packet.Payload);
    }

    private void RemoveSessionFromRoom(ClientSession session)
    {
        if (session.RoomId == null)
        {
            return;
        }

        var roomId = session.RoomId;

        if (!_rooms.TryGetValue(roomId, out var room))
        {
            session.RoomId = null;
            return;
        }

        room.Remove(session);

        if (room.IsEmpty)
        {
            _rooms.TryRemove(roomId, out _);
        }
    }

    private static string NormalizeClientId(string? clientId)
    {
        return string.IsNullOrWhiteSpace(clientId)
            ? $"Client_{Guid.NewGuid():N}"[..11]
            : clientId.Trim();
    }

    private static string GenerateRoomCode()
    {
        const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        Span<char> code = stackalloc char[6];

        for (var i = 0; i < code.Length; i++)
        {
            code[i] = chars[Random.Shared.Next(chars.Length)];
        }

        return new string(code);
    }
}

internal sealed class ClientSession : IDisposable
{
    private readonly SemaphoreSlim _sendLock = new(1, 1);

    public Guid Id { get; } = Guid.NewGuid();
    public TcpClient TcpClient { get; }
    public NetworkStream Stream { get; }
    public string ClientId { get; set; } = "";
    public string? RoomId { get; set; }

    public ClientSession(TcpClient tcpClient)
    {
        TcpClient = tcpClient;
        Stream = tcpClient.GetStream();
    }

    public async Task SendAsync(NetworkPacket packet, CancellationToken ct = default)
    {
        await _sendLock.WaitAsync(ct);

        try
        {
            await PacketCodec.WriteAsync(Stream, packet, ct);
        }
        finally
        {
            _sendLock.Release();
        }
    }

    public void Dispose()
    {
        _sendLock.Dispose();
    }
}

internal sealed class Room
{
    private readonly ConcurrentDictionary<Guid, ClientSession> _clients = new();

    public string RoomId { get; }
    public bool IsEmpty => _clients.IsEmpty;

    public Room(string roomId)
    {
        RoomId = roomId;
    }

    public void Add(ClientSession client)
    {
        _clients[client.Id] = client;
        client.RoomId = RoomId;
    }

    public void Remove(ClientSession client)
    {
        _clients.TryRemove(client.Id, out _);
        client.RoomId = null;
    }

    public async Task BroadcastAsync(NetworkPacket packet, Guid excludedSessionId, CancellationToken ct = default)
    {
        foreach (var client in _clients.Values)
        {
            if (client.Id == excludedSessionId)
            {
                continue;
            }

            try
            {
                await client.SendAsync(packet, ct);
            }
            catch
            {
            }
        }
    }
}
