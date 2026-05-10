using System;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace NetBackend.Shared
{
    public enum PacketType
    {
        CreateRoom,
        JoinRoom,
        RoomJoined,
        LeaveRoom,
        RequestRooms,
        RoomsList,
        Message,
        System,
        Error
    }

    public sealed class NetworkPacket
    {
        public PacketType Type { get; set; }
        public string? RoomId { get; set; }
        public string? ClientId { get; set; }
        public string? Payload { get; set; }
        public string[]? DataList { get; set; }
    }

    public static class PacketCodec
    {
        private static readonly JsonSerializerOptions Options = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

        public static async Task WriteAsync(Stream stream, NetworkPacket packet, CancellationToken ct = default)
        {
            var json = JsonSerializer.Serialize(packet, Options) + "\n";
            var bytes = Encoding.UTF8.GetBytes(json);
            await stream.WriteAsync(bytes.AsMemory(0, bytes.Length), ct);
            await stream.FlushAsync(ct);
        }

        public static async Task<NetworkPacket?> ReadAsync(StreamReader reader, CancellationToken ct = default)
        {
            var line = await reader.ReadLineAsync();
            return line == null ? null : JsonSerializer.Deserialize<NetworkPacket>(line, Options);
        }
    }
}