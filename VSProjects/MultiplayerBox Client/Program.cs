using System.Text.Json;
using System.Runtime.Versioning;
using GoreBoxRegistryLinker;

[assembly: SupportedOSPlatform("windows")]

namespace MultiplayerBoxClient;

internal static class Program
{
    private static readonly RegistryMonitor RegistryMonitor = new();
    private static readonly Network Network = new();

    private static async Task Main()
    {
        Console.Title = "MultiplayerBox Client";

        RegistryMonitor.OnLog += message => WriteLog("REGISTRY", message, ConsoleColor.Gray);
        RegistryMonitor.OnMessageReceived += message => _ = HandleModMessageAsync(message);

        Network.Client.OnConnected += () => WriteLog("NETWORK", "Connected", ConsoleColor.Green);
        Network.Client.OnDisconnected += () => WriteLog("NETWORK", "Disconnected", ConsoleColor.DarkYellow);
        Network.Client.OnError += message => WriteLog("NETWORK", message, ConsoleColor.Red);
        Network.Client.OnMessageReceived += HandleNetworkMessage;

        RegistryMonitor.Start(); 


        try
        {
            await Network.StartAsync();
        }
        finally
        {
            RegistryMonitor.Dispose();
            await Network.StopAsync();
        }
    }

    private static async Task HandleModMessageAsync(string payload)
    {
        if (IsPacketType(payload, "PING"))
        {
            SendPong();
            return;
        }

        try
        {
            await Network.Client.SendPayloadAsync(payload);
            WriteLog("MOD", "Packet sent to room", ConsoleColor.Cyan);
        }
        catch (Exception ex)
        {
            WriteLog("MOD", ex.Message, ConsoleColor.Red);
        }
    }

    private static void HandleNetworkMessage(string clientId, string payload)
    {
        if (clientId == Network.Client.ClientId)
        {
            return;
        }

        RegistryMonitor.SendPayload(payload, clientId);
        WriteLog("NETWORK", $"Packet received from {clientId}", ConsoleColor.Cyan);
    }

    private static void SendPong()
    {
        RegistryMonitor.SendData(new Dictionary<string, string>
        {
            ["type"] = "PONG",
            ["message"] = "Client is alive"
        });
    }

    private static bool IsPacketType(string payload, string expectedType)
    {
        try
        {
            using var document = JsonDocument.Parse(payload);

            return TryReadPacketType(document.RootElement, out var packetType)
                && string.Equals(packetType, expectedType, StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    private static bool TryReadPacketType(JsonElement element, out string? packetType)
    {
        packetType = null;

        if (element.ValueKind == JsonValueKind.Object && element.TryGetProperty("data", out var data))
        {
            if (TryReadStringProperty(data, "type", out packetType) || TryReadStringProperty(data, "Type", out packetType))
            {
                return true;
            }
        }

        if (TryReadStringProperty(element, "type", out packetType) || TryReadStringProperty(element, "Type", out packetType))
        {
            return true;
        }

        return false;
    }

    private static bool TryReadStringProperty(JsonElement element, string propertyName, out string? value)
    {
        value = null;

        if (element.ValueKind != JsonValueKind.Object || !element.TryGetProperty(propertyName, out var property))
        {
            return false;
        }

        if (property.ValueKind != JsonValueKind.String)
        {
            return false;
        }

        value = property.GetString();
        return value != null;
    }

    private static void WriteLog(string source, string message, ConsoleColor color)
    {
        var previousColor = Console.ForegroundColor;
        Console.ForegroundColor = color;
        Console.WriteLine($"{DateTime.Now:HH:mm:ss} [{source}] {message}");
        Console.ForegroundColor = previousColor;
    }
}
