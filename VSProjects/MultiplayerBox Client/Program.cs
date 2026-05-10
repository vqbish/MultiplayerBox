using System;
using System.Collections.Generic;
using GoreBoxRegistryLinker;
using NetBackend;

namespace GoreBoxClient
{
    class Program
    {
        private static RegistryMonitor _monitor;
        public static Network network = new Network();

        static async Task Main(string[] args)
        {
            Console.Title = "MultiplayerBox Client";
            _monitor = new RegistryMonitor();

            _monitor.OnLog += HandleLog;
            _monitor.OnMessageReceived += HandleMODMessageReceived;

            network.Client.OnMessageReceived += HandleNETWOTKMessageReceived;

            _monitor.Start();

            await network.Start();
        }

        private static void HandleNETWOTKMessageReceived(string clientID, string payload)
        {
            if (clientID == network.Client.ClientId) return;

            Console.WriteLine($"[NETWORK] Получено от {clientID}: {payload}");
        }

        private static void HandleLog(string message)
        {
            Console.ForegroundColor = ConsoleColor.Gray;
            Console.WriteLine($"{DateTime.Now:HH:mm:ss} | {message}");
            Console.ResetColor();
        }

        private static async void HandleMODMessageReceived(string jsonContent)
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine($"\n[{DateTime.Now:HH:mm:ss}] ПОЛУЧЕН ПАКЕТ:");
            Console.ResetColor();

            Console.WriteLine(jsonContent);
            Console.WriteLine(new string('-', 40));

            if (jsonContent.Contains("\"PING\""))
            {
                SendPong();
                return;
            }

            try
            {
                await network.Client.SendPayloadAsync(jsonContent);
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"Ошибка при рассылке пакета лобби: {ex.Message}");
                Console.ResetColor();
            }
        }

        private static void SendPong()
        {
            var data = new Dictionary<string, string>
            {
                { "type", "PONG" },
                { "message", "Client is alive" }
            };
            _monitor.SendData(data);
        }
    }
}