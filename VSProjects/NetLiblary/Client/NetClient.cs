using System;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using NetBackend.Shared;

namespace NetBackend.Client
{
    public sealed class NetClient
    {
        private TcpClient? _client;
        private CancellationTokenSource? _cts;

        public string? CurrentRoomId { get; private set; }
        public string ClientId { get; private set; } = "Client_" + Guid.NewGuid().ToString()[..4];
        public bool IsConnected => _client?.Connected ?? false;

        // События
        public event Action? OnConnected;
        public event Action? OnDisconnected;
        public event Action<string, string>? OnMessageReceived; // ClientId, Payload
        public event Action<string>? OnError;

        // TCS для асинхронного ожидания ответов от сервера
        private TaskCompletionSource<string[]>? _tcsRoomList;
        private TaskCompletionSource<string>? _tcsRoomJoined;

        public async Task ConnectAsync(string host, int port, CancellationToken ct = default)
        {
            _client = new TcpClient();
            await _client.ConnectAsync(host, port, ct);

            _cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            _ = Task.Run(() => ReceiveLoopAsync(_cts.Token), _cts.Token);

            OnConnected?.Invoke();
        }

        public void SetClientId(string id) => ClientId = id;

        /// <summary>
        /// Запрашивает у сервера список всех активных комнат.
        /// </summary>
        public async Task<string[]> GetRoomsAsync(CancellationToken ct = default)
        {
            EnsureConnected();
            _tcsRoomList = new TaskCompletionSource<string[]>();

            await SendRawAsync(new NetworkPacket { Type = PacketType.RequestRooms }, ct);

            // Ждем ответа от ReceiveLoopAsync
            return await _tcsRoomList.Task.WaitAsync(TimeSpan.FromSeconds(5), ct);
        }

        public async Task<string> CreateRoomAsync(CancellationToken ct = default)
        {
            EnsureConnected();
            _tcsRoomJoined = new TaskCompletionSource<string>();

            await SendRawAsync(new NetworkPacket { Type = PacketType.CreateRoom, ClientId = ClientId }, ct);
            return await _tcsRoomJoined.Task.WaitAsync(TimeSpan.FromSeconds(5), ct);
        }

        public async Task JoinRoomAsync(string roomId, CancellationToken ct = default)
        {
            EnsureConnected();
            _tcsRoomJoined = new TaskCompletionSource<string>();

            await SendRawAsync(new NetworkPacket { Type = PacketType.JoinRoom, ClientId = ClientId, RoomId = roomId }, ct);
            await _tcsRoomJoined.Task.WaitAsync(TimeSpan.FromSeconds(5), ct);
        }

        public async Task SendPayloadAsync(string payload, CancellationToken ct = default)
        {
            EnsureConnected();
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
            if (!IsConnected) return;

            try { await SendRawAsync(new NetworkPacket { Type = PacketType.LeaveRoom, RoomId = CurrentRoomId }, default); } catch { }

            _cts?.Cancel();
            _client?.Close();
            CurrentRoomId = null;
            OnDisconnected?.Invoke();
        }

        private async Task ReceiveLoopAsync(CancellationToken ct)
        {
            try
            {
                using var stream = _client!.GetStream();
                using var reader = new StreamReader(stream, Encoding.UTF8, false, 1024, true);

                while (!ct.IsCancellationRequested)
                {
                    var packet = await PacketCodec.ReadAsync(reader, ct);
                    if (packet == null) break;

                    switch (packet.Type)
                    {
                        case PacketType.RoomsList:
                            _tcsRoomList?.TrySetResult(packet.DataList ?? Array.Empty<string>());
                            break;

                        case PacketType.RoomJoined:
                            CurrentRoomId = packet.RoomId;
                            _tcsRoomJoined?.TrySetResult(packet.RoomId!);
                            break;

                        case PacketType.Message:
                            if (packet.ClientId != null && packet.Payload != null)
                                OnMessageReceived?.Invoke(packet.ClientId, packet.Payload);
                            break;

                        case PacketType.Error:
                            OnError?.Invoke(packet.Payload ?? "Unknown error");
                            _tcsRoomJoined?.TrySetException(new Exception(packet.Payload));
                            break;
                    }
                }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                OnError?.Invoke(ex.Message);
            }
            finally
            {
                OnDisconnected?.Invoke();
            }
        }

        private Task SendRawAsync(NetworkPacket packet, CancellationToken ct) =>
            PacketCodec.WriteAsync(_client!.GetStream(), packet, ct);

        private void EnsureConnected()
        {
            if (!IsConnected) throw new InvalidOperationException("Клиент не подключен к серверу.");
        }
    }
}