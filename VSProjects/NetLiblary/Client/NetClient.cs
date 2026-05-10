using System.Net.Sockets;
using System.Text;
using NetBackend.Shared;

namespace NetBackend.Client;

public sealed class NetClient : IDisposable
{
    private readonly SemaphoreSlim _sendLock = new(1, 1);

    private TcpClient? _client;
    private NetworkStream? _stream;
    private CancellationTokenSource? _cts;
    private bool _disconnectRaised;
    private TaskCompletionSource<string[]>? _roomsRequest;
    private TaskCompletionSource<string>? _roomJoinRequest;

    public string? CurrentRoomId { get; private set; }
    public string ClientId { get; private set; } = $"Client_{Guid.NewGuid():N}"[..11];
    public bool IsConnected => _client?.Connected == true && _stream != null;

    public event Action? OnConnected;
    public event Action? OnDisconnected;
    public event Action<string, string>? OnMessageReceived;
    public event Action<string>? OnError;

    public async Task ConnectAsync(string host, int port, CancellationToken ct = default)
    {
        if (IsConnected)
        {
            await DisconnectAsync();
        }

        _client = new TcpClient
        {
            NoDelay = true
        };

        await _client.ConnectAsync(host, port, ct);

        _stream = _client.GetStream();
        _cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        _disconnectRaised = false;

        _ = Task.Run(() => ReceiveLoopAsync(_cts.Token), CancellationToken.None);
        OnConnected?.Invoke();
    }

    public void SetClientId(string id)
    {
        if (!string.IsNullOrWhiteSpace(id))
        {
            ClientId = id.Trim();
        }
    }

    public async Task<string[]> GetRoomsAsync(CancellationToken ct = default)
    {
        EnsureConnected();

        var request = CreateRoomsRequest();
        await SendRawAsync(new NetworkPacket { Type = PacketType.RequestRooms }, ct);

        try
        {
            return await request.Task.WaitAsync(TimeSpan.FromSeconds(5), ct);
        }
        finally
        {
            if (ReferenceEquals(_roomsRequest, request))
            {
                _roomsRequest = null;
            }
        }
    }

    public async Task<string> CreateRoomAsync(CancellationToken ct = default)
    {
        EnsureConnected();

        var request = CreateRoomRequest();
        await SendRawAsync(new NetworkPacket { Type = PacketType.CreateRoom, ClientId = ClientId }, ct);

        try
        {
            return await request.Task.WaitAsync(TimeSpan.FromSeconds(5), ct);
        }
        finally
        {
            if (ReferenceEquals(_roomJoinRequest, request))
            {
                _roomJoinRequest = null;
            }
        }
    }

    public async Task JoinRoomAsync(string roomId, CancellationToken ct = default)
    {
        EnsureConnected();

        if (string.IsNullOrWhiteSpace(roomId))
        {
            throw new ArgumentException("Room id is empty.", nameof(roomId));
        }

        var request = CreateRoomRequest();
        await SendRawAsync(new NetworkPacket
        {
            Type = PacketType.JoinRoom,
            ClientId = ClientId,
            RoomId = roomId.Trim().ToUpperInvariant()
        }, ct);

        try
        {
            await request.Task.WaitAsync(TimeSpan.FromSeconds(5), ct);
        }
        finally
        {
            if (ReferenceEquals(_roomJoinRequest, request))
            {
                _roomJoinRequest = null;
            }
        }
    }

    public async Task SendPayloadAsync(string payload, CancellationToken ct = default)
    {
        EnsureConnected();

        if (CurrentRoomId == null)
        {
            throw new InvalidOperationException("Client is not in a room.");
        }

        await SendRawAsync(new NetworkPacket
        {
            Type = PacketType.Message,
            RoomId = CurrentRoomId,
            ClientId = ClientId,
            Payload = payload
        }, ct);
    }

    public async Task DisconnectAsync()
    {
        if (_client == null)
        {
            return;
        }

        try
        {
            if (_stream != null && CurrentRoomId != null)
            {
                await SendRawAsync(new NetworkPacket
                {
                    Type = PacketType.LeaveRoom,
                    RoomId = CurrentRoomId,
                    ClientId = ClientId
                });
            }
        }
        catch
        {
        }

        CloseConnection();
        RaiseDisconnected();
    }

    public void Dispose()
    {
        CloseConnection();
        _sendLock.Dispose();
    }

    private async Task ReceiveLoopAsync(CancellationToken ct)
    {
        try
        {
            using var reader = new StreamReader(_stream!, Encoding.UTF8, false, 4096, true);

            while (!ct.IsCancellationRequested)
            {
                var packet = await PacketCodec.ReadAsync(reader, ct);

                if (packet == null)
                {
                    break;
                }

                HandlePacket(packet);
            }
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            OnError?.Invoke(ex.Message);
        }
        finally
        {
            CloseConnection();
            RaiseDisconnected();
        }
    }

    private void HandlePacket(NetworkPacket packet)
    {
        switch (packet.Type)
        {
            case PacketType.RoomsList:
                _roomsRequest?.TrySetResult(packet.DataList ?? Array.Empty<string>());
                break;

            case PacketType.RoomJoined:
                CurrentRoomId = packet.RoomId;
                _roomJoinRequest?.TrySetResult(packet.RoomId ?? "");
                break;

            case PacketType.Message:
                if (!string.IsNullOrEmpty(packet.ClientId) && packet.Payload != null)
                {
                    OnMessageReceived?.Invoke(packet.ClientId, packet.Payload);
                }
                break;

            case PacketType.Error:
                var message = packet.Payload ?? "Unknown network error";
                OnError?.Invoke(message);
                _roomsRequest?.TrySetException(new InvalidOperationException(message));
                _roomJoinRequest?.TrySetException(new InvalidOperationException(message));
                break;
        }
    }

    private async Task SendRawAsync(NetworkPacket packet, CancellationToken ct = default)
    {
        EnsureConnected();

        await _sendLock.WaitAsync(ct);

        try
        {
            await PacketCodec.WriteAsync(_stream!, packet, ct);
        }
        finally
        {
            _sendLock.Release();
        }
    }

    private TaskCompletionSource<string[]> CreateRoomsRequest()
    {
        _roomsRequest = new TaskCompletionSource<string[]>(TaskCreationOptions.RunContinuationsAsynchronously);
        return _roomsRequest;
    }

    private TaskCompletionSource<string> CreateRoomRequest()
    {
        _roomJoinRequest = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);
        return _roomJoinRequest;
    }

    private void EnsureConnected()
    {
        if (!IsConnected)
        {
            throw new InvalidOperationException("Client is not connected to server.");
        }
    }

    private void CloseConnection()
    {
        _cts?.Cancel();
        _cts?.Dispose();
        _cts = null;

        _stream?.Dispose();
        _stream = null;

        _client?.Close();
        _client = null;

        CurrentRoomId = null;
    }

    private void RaiseDisconnected()
    {
        if (_disconnectRaised)
        {
            return;
        }

        _disconnectRaised = true;
        OnDisconnected?.Invoke();
    }
}
