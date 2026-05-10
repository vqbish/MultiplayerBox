using System.Text;
using System.Text.Json;

namespace NetBackend.Shared;

public enum PacketType
{
    CreateRoom,
    JoinRoom,
    RoomJoined,
    LeaveRoom,
    RequestRooms,
    RoomsList,
    Message,
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
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public static async Task WriteAsync(Stream stream, NetworkPacket packet, CancellationToken ct = default)
    {
        var json = JsonSerializer.Serialize(packet, Options);
        var bytes = Encoding.UTF8.GetBytes(json + "\n");

        await stream.WriteAsync(bytes, ct);
        await stream.FlushAsync(ct);
    }

    public static async Task<NetworkPacket?> ReadAsync(StreamReader reader, CancellationToken ct = default)
    {
        var line = await reader.ReadLineAsync(ct);
        return string.IsNullOrWhiteSpace(line)
            ? null
            : JsonSerializer.Deserialize<NetworkPacket>(line, Options);
    }
}
