using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Runtime.Versioning;
using Microsoft.Win32;

[assembly: SupportedOSPlatform("windows")]

namespace GoreBoxRegistryLinker;

public sealed class RegistryMonitor : IDisposable
{
    private const string SubKeyPath = @"Software\F2Games\GoreBox";
    private const string ValuePrefix = "ModPrefsMultiplayerBoxHandshake";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = false
    };

    private readonly TimeSpan _lookupInterval = TimeSpan.FromSeconds(2);
    private readonly TimeSpan _pollInterval = TimeSpan.FromMilliseconds(50);

    private string? _valueName;
    private string _lastValue = "";
    private volatile bool _isRunning;
    private Thread? _workerThread;

    public event Action<string>? OnMessageReceived;
    public event Action<string>? OnLog;

    public void Start()
    {
        if (_isRunning)
        {
            return;
        }

        _isRunning = true;
        _workerThread = new Thread(PollingLoop)
        {
            IsBackground = true,
            Name = "GoreBoxRegistryMonitor"
        };
        _workerThread.Start();
    }

    public void Stop()
    {
        if (!_isRunning)
        {
            return;
        }

        _isRunning = false;

        if (_workerThread is { IsAlive: true } && Thread.CurrentThread != _workerThread)
        {
            _workerThread.Join();
        }
    }

    public void SendData(IReadOnlyDictionary<string, string> data)
    {
        var dataObject = new JsonObject();

        foreach (var item in data)
        {
            dataObject[item.Key] = item.Value;
        }

        var payload = new JsonObject
        {
            ["Type"] = "POST",
            ["Time"] = GetUnixTimeMs(),
            ["data"] = dataObject,
            ["from"] = "CLIENT"
        };

        WritePayload(payload.ToJsonString(JsonOptions));
    }

    public void SendPayload(string payload, string? senderId = null)
    {
        try
        {
            if (JsonNode.Parse(payload) is not JsonObject root)
            {
                OnLog?.Invoke("[REGISTRY] Invalid packet");
                return;
            }

            root["Time"] = GetUnixTimeMs();
            root["from"] = "CLIENT";

            if (!string.IsNullOrWhiteSpace(senderId) && root["data"] is JsonObject data)
            {
                data["Sender"] = senderId;
            }

            WritePayload(root.ToJsonString(JsonOptions));
        }
        catch (Exception ex)
        {
            OnLog?.Invoke($"[REGISTRY] Packet write err: {ex.Message}");
        }
    }

    public void Dispose()
    {
        Stop();
    }

    private void PollingLoop()
    {
        try
        {
            OnLog?.Invoke("[REGISTRY] Waiting for GoreBox PlayerPrefs key");
            WaitForValueName();

            if (_valueName == null)
            {
                return;
            }

            OnLog?.Invoke($"[REGISTRY] Monitoring {_valueName}");
            _lastValue = ReadRegistryValue(_valueName);

            while (_isRunning)
            {
                var currentValue = ReadRegistryValue(_valueName);

                if (currentValue != _lastValue)
                {
                    _lastValue = currentValue;

                    if (!string.IsNullOrWhiteSpace(currentValue) && !IsClientMessage(currentValue))
                    {
                        OnMessageReceived?.Invoke(currentValue);
                    }
                }

                Thread.Sleep(_pollInterval);
            }
        }
        catch (Exception ex)
        {
            OnLog?.Invoke($"[REGISTRY] WD err: {ex.Message}");
        }
    }

    private void WaitForValueName()
    {
        while (_isRunning && _valueName == null)
        {
            _valueName = FindValueName();

            if (_valueName == null)
            {
                Thread.Sleep(_lookupInterval);
            }
        }
    }

    private void WritePayload(string payload)
    {
        if (_valueName == null)
        {
            OnLog?.Invoke("[REGISTRY] GoreBox PlayerPrefs err");
            return;
        }

        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(SubKeyPath, true) ?? Registry.CurrentUser.CreateSubKey(SubKeyPath, true);
            if (key == null)
            {
                OnLog?.Invoke("[REGISTRY] Failed to open/create registry key");
                return;
            }

            key.SetValue(_valueName, payload, RegistryValueKind.String);
        }
        catch (UnauthorizedAccessException ex)
        {
            OnLog?.Invoke($"[REGISTRY] Access denied: {ex.Message}");
        }
        catch (Exception ex)
        {
            OnLog?.Invoke($"[REGISTRY] Packet write failed: {ex.Message}");
        }
    }
    private static string? FindValueName()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(SubKeyPath);
            return key?.GetValueNames().FirstOrDefault(name => name.StartsWith(ValuePrefix, StringComparison.Ordinal));
        }
        catch
        {
            return null;
        }
    }

    private static string ReadRegistryValue(string valueName)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(SubKeyPath);
            var rawValue = key?.GetValue(valueName);

            return rawValue switch
            {
                byte[] bytes => Encoding.UTF8.GetString(bytes).TrimEnd('\0'),
                null => "",
                _ => rawValue.ToString() ?? ""
            };
        }
        catch
        {
            return "";
        }
    }

    private static bool IsClientMessage(string payload)
    {
        try
        {
            var sender = JsonNode.Parse(payload)?["from"]?.ToString();
            return string.Equals(sender, "CLIENT", StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return payload.Contains("\"from\":\"CLIENT\"", StringComparison.OrdinalIgnoreCase);
        }
    }

    private static string GetUnixTimeMs()
    {
        return DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString();
    }
}
