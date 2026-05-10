using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using Microsoft.Win32;

namespace GoreBoxRegistryLinker
{
    public class RegistryMonitor : IDisposable
    {
        private const string SubKeyPath = @"Software\F2Games\GoreBox";
        private const string ValuePrefix = "ModPrefsMultiplayerBoxHandshake";

        private string _realValueName;
        private string _lastValue;
        private bool _isRunning;
        private Thread _workerThread;

        // Событие, на которое будет подписываться основной код
        public event Action<string> OnMessageReceived;
        public event Action<string> OnLog;

        public RegistryMonitor() { }

        public void Start()
        {
            if (_isRunning) return;
            _isRunning = true;

            _workerThread = new Thread(PollingLoop) { IsBackground = true };
            _workerThread.Start();
        }

        public void Stop()
        {
            _isRunning = false;
            _workerThread?.Join();
        }

        private void PollingLoop()
        {
            OnLog?.Invoke("[SERVICE] Ожидание инициализации ключа...");

            while (_isRunning && _realValueName == null)
            {
                _realValueName = FindFullValueName(SubKeyPath, ValuePrefix);
                if (_realValueName == null) Thread.Sleep(2000);
            }

            if (_realValueName != null)
                OnLog?.Invoke($"[FOUND] Мониторинг запущен на ключе: {_realValueName}");

            _lastValue = GetRegistryString(SubKeyPath, _realValueName);

            while (_isRunning)
            {
                string currentValue = GetRegistryString(SubKeyPath, _realValueName);

                if (currentValue != _lastValue)
                {
                    if (!currentValue.Contains("\"from\":\"CLIENT\""))
                    {
                        OnMessageReceived?.Invoke(currentValue);
                    }
                    _lastValue = currentValue;
                }

                Thread.Sleep(100);
            }
        }

        public void SendData(Dictionary<string, string> data)
        {
            if (_realValueName == null) return;

            try
            {
                string dataContent = string.Join(",", data.Select(x => $"\"{x.Key}\":\"{x.Value}\""));
                string timeMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString();

                string fullJson = "{" +
                    $"\"Type\":\"POST\"," +
                    $"\"Time\":\"{timeMs}\"," +
                    $"\"data\":{{{dataContent}}}," +
                    $"\"from\":\"CLIENT\"" +
                "}";

                using (RegistryKey key = Registry.CurrentUser.CreateSubKey(SubKeyPath))
                {
                    key?.SetValue(_realValueName, fullJson, RegistryValueKind.String);
                }
            }
            catch (Exception ex)
            {
                OnLog?.Invoke($"[ERROR] Ошибка отправки: {ex.Message}");
            }
        }

        private string FindFullValueName(string path, string prefix)
        {
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(path))
                {
                    return key?.GetValueNames().FirstOrDefault(n => n.StartsWith(prefix));
                }
            }
            catch { return null; }
        }

        private string GetRegistryString(string keyPath, string name)
        {
            if (string.IsNullOrEmpty(name)) return "";
            try
            {
                using (RegistryKey key = Registry.CurrentUser.OpenSubKey(keyPath))
                {
                    object rawValue = key?.GetValue(name);
                    if (rawValue == null) return "";

                    if (rawValue is byte[] bytes)
                        return Encoding.UTF8.GetString(bytes).TrimEnd('\0');

                    return rawValue.ToString();
                }
            }
            catch { return ""; }
        }

        public void Dispose() => Stop();
    }
}