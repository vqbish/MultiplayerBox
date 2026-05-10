using NetBackend.Shared;
using System;
using System.Collections.Concurrent;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace NetBackend.Server
{
    public sealed class NetHost
    {
        private TcpListener? _listener;
        private readonly ConcurrentDictionary<string, Room> _rooms = new();
        private readonly ConcurrentDictionary<Guid, ClientSession> _sessions = new();

        public event Action<string>? OnLog;
        public event Action<string, string>? OnRoomCreated; // RoomId, CreatorId
        public event Action<string, string, string>? OnMessageBroadcasted; // RoomId, ClientId, Payload

        /// <summary>
        /// Запускает сервер на указанном порту. Доступен глобально при пробросе портов.
        /// </summary>
        public async Task StartAsync(int port, CancellationToken ct = default)
        {
            // IPAddress.Any позволяет принимать подключения с любых интерфейсов (включая внешние)
            _listener = new TcpListener(IPAddress.Any, port);
            _listener.Start();

            OnLog?.Invoke($"[Host] Запущен на порту {port}. Ожидание подключений...");

            while (!ct.IsCancellationRequested)
            {
                try
                {
                    var client = await _listener.AcceptTcpClientAsync(ct);
                    _ = Task.Run(() => HandleClientAsync(client, ct), ct);
                }
                catch (OperationCanceledException) { break; }
                catch (Exception ex) { OnLog?.Invoke($"[Host Error] {ex.Message}"); }
            }

            _listener.Stop();
        }

        public string[] GetActiveRooms() => _rooms.Keys.ToArray();

        private async Task HandleClientAsync(TcpClient tcpClient, CancellationToken ct)
        {
            var session = new ClientSession(tcpClient);
            _sessions[session.Id] = session;
            OnLog?.Invoke($"[Host] Клиент подключился: {session.Id}");

            using var stream = session.Stream;
            using var reader = new StreamReader(stream, Encoding.UTF8, false, 1024, true);

            try
            {
                while (!ct.IsCancellationRequested && tcpClient.Connected)
                {
                    var packet = await PacketCodec.ReadAsync(reader, ct);
                    if (packet == null) break;

                    await ProcessPacketAsync(session, packet, ct);
                }
            }
            catch { /* Игнорируем разрывы соединений */ }
            finally
            {
                await RemoveSessionAsync(session, ct);
                tcpClient.Close();
                _sessions.TryRemove(session.Id, out _);
                OnLog?.Invoke($"[Host] Клиент отключился: {session.Id}");
            }
        }

        private async Task ProcessPacketAsync(ClientSession session, NetworkPacket packet, CancellationToken ct)
        {
            switch (packet.Type)
            {
                case PacketType.RequestRooms:
                    await session.SendAsync(new NetworkPacket { Type = PacketType.RoomsList, DataList = GetActiveRooms() }, ct);
                    break;

                case PacketType.CreateRoom:
                    var roomId = GenerateRoomCode();
                    var newRoom = new Room(roomId);
                    _rooms[roomId] = newRoom;

                    session.ClientId = packet.ClientId ?? "Unknown";
                    newRoom.Add(session);

                    await session.SendAsync(new NetworkPacket { Type = PacketType.RoomJoined, RoomId = roomId }, ct);
                    OnRoomCreated?.Invoke(roomId, session.ClientId);
                    break;

                case PacketType.JoinRoom:
                    var targetRoom = packet.RoomId?.ToUpperInvariant();
                    if (targetRoom != null && _rooms.TryGetValue(targetRoom, out var room))
                    {
                        session.ClientId = packet.ClientId ?? "Unknown";
                        room.Add(session);
                        await session.SendAsync(new NetworkPacket { Type = PacketType.RoomJoined, RoomId = targetRoom }, ct);
                    }
                    else
                    {
                        await session.SendAsync(new NetworkPacket { Type = PacketType.Error, Payload = "Room not found" }, ct);
                    }
                    break;

                case PacketType.Message:
                    if (session.RoomId != null && _rooms.TryGetValue(session.RoomId, out var currentRoom))
                    {
                        await currentRoom.BroadcastAsync(new NetworkPacket
                        {
                            Type = PacketType.Message,
                            RoomId = session.RoomId,
                            ClientId = session.ClientId,
                            Payload = packet.Payload
                        }, ct);
                        OnMessageBroadcasted?.Invoke(session.RoomId, session.ClientId!, packet.Payload!);
                    }
                    break;

                case PacketType.LeaveRoom:
                    await RemoveSessionAsync(session, ct);
                    break;
            }
        }

        private async Task RemoveSessionAsync(ClientSession session, CancellationToken ct)
        {
            if (session.RoomId == null || !_rooms.TryGetValue(session.RoomId, out var room)) return;

            room.Remove(session);
            if (room.IsEmpty) _rooms.TryRemove(session.RoomId, out _);
        }

        private static string GenerateRoomCode()
        {
            const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            Span<char> code = stackalloc char[6];
            for (int i = 0; i < code.Length; i++) code[i] = chars[Random.Shared.Next(chars.Length)];
            return new string(code);
        }
    }

    internal sealed class ClientSession
    {
        public Guid Id { get; } = Guid.NewGuid();
        public TcpClient TcpClient { get; }
        public string? ClientId { get; set; }
        public string? RoomId { get; set; }
        public NetworkStream Stream => TcpClient.GetStream();

        public ClientSession(TcpClient tcpClient) => TcpClient = tcpClient;
        public Task SendAsync(NetworkPacket packet, CancellationToken ct = default) => PacketCodec.WriteAsync(Stream, packet, ct);
    }

    internal sealed class Room
    {
        private readonly ConcurrentDictionary<Guid, ClientSession> _clients = new();
        public string RoomId { get; }
        public bool IsEmpty => _clients.IsEmpty;

        public Room(string roomId) => RoomId = roomId;

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

        public async Task BroadcastAsync(NetworkPacket packet, CancellationToken ct = default)
        {
            foreach (var client in _clients.Values)
            {
                try { await client.SendAsync(packet, ct); } catch { /* Ignore disconnected */ }
            }
        }
    }
}