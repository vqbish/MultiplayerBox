using NetBackend.Client;
using NetBackend.Server;
using System;
using System.Threading.Tasks;

public class Network
{
    public NetClient Client = new();
    private NetHost _host = new();

    public async Task Start()
    {
        Console.Clear();
        Console.WriteLine("=== СЕТЕВОЕ МЕНЮ ===");
        Console.WriteLine("1. Создать сервер (Host)");
        Console.WriteLine("2. Подключиться к серверу (Client)");

        var key = Console.ReadKey(true).Key;

        if (key == ConsoleKey.D1 || key == ConsoleKey.NumPad1)
        {
            await RunHostMode();
        }
        else if (key == ConsoleKey.D2 || key == ConsoleKey.NumPad2)
        {
            await RunClientMode();
        }
    }

    private async Task RunHostMode()
    {
        Console.WriteLine("\n[HOST] Запуск сервера...");
        _host.OnLog += (m) => Console.WriteLine($"[SERVER LOG]: {m}");

        _ = _host.StartAsync(8888);

        await Client.ConnectAsync("127.0.0.1", 8888);
        string roomCode = await Client.CreateRoomAsync();

        Console.WriteLine($"[HOST] Сервер запущен. Комната: {roomCode}");
        Console.WriteLine("Нажмите любую клавишу для выхода...");
        Console.ReadKey();
    }

    private async Task RunClientMode()
    {
        Console.Write("\nВведите IP сервера (по умолчанию 127.0.0.1): ");
        string ip = Console.ReadLine();
        if (string.IsNullOrEmpty(ip)) ip = "127.0.0.1";

        try
        {
            await Client.ConnectAsync(ip, 8888);
            Console.WriteLine("Подключено! Получение списка комнат...");

            string[] rooms = await Client.GetRoomsAsync();

            if (rooms.Length == 0)
            {
                Console.WriteLine("Активных комнат не найдено. Нажмите любую клавишу...");
                Console.ReadKey();
                return;
            }

            int selectedIndex = 0;
            bool roomSelected = false;

            while (!roomSelected)
            {
                Console.Clear();
                Console.WriteLine("=== ВЫБЕРИТЕ КОМНАТУ (Стрелки для выбора, Enter для входа) ===");

                for (int i = 0; i < rooms.Length; i++)
                {
                    if (i == selectedIndex)
                    {
                        Console.BackgroundColor = ConsoleColor.Gray;
                        Console.ForegroundColor = ConsoleColor.Black;
                        Console.WriteLine($"> Room: {rooms[i]} <");
                        Console.ResetColor();
                    }
                    else
                    {
                        Console.WriteLine($"  Room: {rooms[i]}  ");
                    }
                }

                var key = Console.ReadKey(true).Key;
                if (key == ConsoleKey.UpArrow) selectedIndex = Math.Max(0, selectedIndex - 1);
                else if (key == ConsoleKey.DownArrow) selectedIndex = Math.Min(rooms.Length - 1, selectedIndex + 1);
                else if (key == ConsoleKey.Enter) roomSelected = true;
            }

            string selectedRoom = rooms[selectedIndex];
            await Client.JoinRoomAsync(selectedRoom);
            Console.WriteLine($"\nВы вошли в комнату: {selectedRoom}");
            Console.WriteLine("Нажмите любую клавишу для выхода...");
            Console.ReadKey();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Ошибка: {ex.Message}");
            Console.ReadKey();
        }
    }
}