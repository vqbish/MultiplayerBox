using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace GoreBoxModBridgeWeb
{
    public sealed class ModWebBridge : IDisposable
    {
        private readonly string modName;
        public readonly string baseUrl;
        private readonly HttpClient client;

        private readonly HttpListener? listener;
        private readonly CancellationTokenSource cts = new();
        private Task? serverTask;
        private bool disposed;

        public bool IsListening { get; }
        public event Action<string, string>? OnResponseSuccess;
        public event Action<string, string>? OnResponseError;
        public event Action<JsonElement>? OnCustomEvent;

        public ModWebBridge(
            string modName,
            string host = "127.0.0.1",
            int port = 8765,
            int listenPort = 8766,
            bool enableListener = true)
        {
            this.modName = modName ?? throw new ArgumentNullException(nameof(modName));

            baseUrl = $"http://{host}:{port}/GoreBoxModding/{SanitizeForUrl(modName)}/";

            client = new HttpClient
            {
                Timeout = TimeSpan.FromSeconds(5),
                BaseAddress = new Uri(baseUrl)
            };

            if (enableListener)
            {
                try
                {
                    listener = new HttpListener();
                    listener.Prefixes.Add($"http://{host}:{listenPort}/");
                    listener.Start();

                    IsListening = true;
                    serverTask = Task.Run(() => ServerLoopAsync(cts.Token));

                    Console.WriteLine($"[DEBUG] Listening for Lua POSTs on http://{host}:{listenPort}/");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[DEBUG] Listener disabled: {ex.Message}");
                    listener = null;
                    IsListening = false;
                }
            }
            else
            {
                listener = null;
                IsListening = false;
            }
        }

        private async Task ServerLoopAsync(CancellationToken ct)
        {
            if (listener == null)
            {
                return;
            }

            try
            {
                while (!ct.IsCancellationRequested && listener.IsListening)
                {
                    HttpListenerContext ctx;

                    try
                    {
                        ctx = await listener.GetContextAsync().WaitAsync(ct);
                    }
                    catch (OperationCanceledException)
                    {
                        break;
                    }
                    catch (ObjectDisposedException)
                    {
                        break;
                    }
                    catch (HttpListenerException)
                    {
                        break;
                    }

                    _ = Task.Run(() => HandleContextAsync(ctx), CancellationToken.None);
                }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                Console.WriteLine($"[DEBUG] Listener loop error: {ex.Message}");
            }
        }

        private async Task HandleContextAsync(HttpListenerContext ctx)
        {
            try
            {
                if (!string.Equals(ctx.Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase))
                {
                    ctx.Response.StatusCode = 405;
                    await WriteTextAsync(ctx.Response, "Method Not Allowed");
                    return;
                }

                string body;
                using (var sr = new StreamReader(ctx.Request.InputStream, ctx.Request.ContentEncoding))
                {
                    body = await sr.ReadToEndAsync();
                }

                Console.WriteLine("[DEBUG] Received Lua POST: " + body);

                try
                {
                    using var doc = JsonDocument.Parse(body);
                    OnCustomEvent?.Invoke(doc.RootElement.Clone());
                }
                catch (Exception ex)
                {
                    Console.WriteLine("[DEBUG] Failed to parse Lua POST JSON: " + ex.Message);
                }

                ctx.Response.StatusCode = 200;
                await WriteTextAsync(ctx.Response, "ok");
            }
            catch (Exception ex)
            {
                try
                {
                    ctx.Response.StatusCode = 500;
                    await WriteTextAsync(ctx.Response, ex.Message);
                }
                catch
                {
                    // ignore
                }
            }
            finally
            {
                try
                {
                    ctx.Response.Close();
                }
                catch
                {
                    // ignore
                }
            }
        }

        private static async Task WriteTextAsync(HttpListenerResponse response, string text)
        {
            var buf = Encoding.UTF8.GetBytes(text);
            response.ContentType = "text/plain; charset=utf-8";
            response.ContentLength64 = buf.Length;
            await response.OutputStream.WriteAsync(buf, 0, buf.Length);
            await response.OutputStream.FlushAsync();
        }

        private static string SanitizeForUrl(string s)
        {
            if (string.IsNullOrWhiteSpace(s))
            {
                return "mod";
            }

            var sb = new StringBuilder(s.Length);

            foreach (var c in s)
            {
                if (char.IsLetterOrDigit(c) || c == '-' || c == '_')
                {
                    sb.Append(c);
                }
                else if (char.IsWhiteSpace(c))
                {
                    sb.Append('_');
                }
            }

            return sb.Length == 0 ? "mod" : sb.ToString();
        }

        public async Task SendGetAsync(string path)
        {
            EnsureNotDisposed();

            try
            {
                var response = await client.GetAsync(NormalizePath(path));
                var text = await response.Content.ReadAsStringAsync();

                OnResponseSuccess?.Invoke(path, text);
            }
            catch (Exception ex)
            {
                OnResponseError?.Invoke(path, ex.Message);
            }
        }

        public async Task SendPostAsync(string path, object payload)
        {
            EnsureNotDisposed();

            try
            {
                var json = JsonSerializer.Serialize(payload);
                using var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await client.PostAsync(NormalizePath(path), content);
                var text = await response.Content.ReadAsStringAsync();

                OnResponseSuccess?.Invoke(path, text);
            }
            catch (Exception ex)
            {
                OnResponseError?.Invoke(path, ex.Message);
            }
        }

        private static string NormalizePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                return string.Empty;
            }

            return path.TrimStart('/');
        }

        private void EnsureNotDisposed()
        {
            if (disposed)
            {
                throw new ObjectDisposedException(nameof(ModWebBridge));
            }
        }

        public void Dispose()
        {
            if (disposed)
            {
                return;
            }

            disposed = true;

            try
            {
                cts.Cancel();
            }
            catch
            {
            }

            try
            {
                listener?.Stop();
            }
            catch
            {
            }

            try
            {
                listener?.Close();
            }
            catch
            {
            }

            try
            {
                if (serverTask != null)
                {
                    serverTask.Wait(TimeSpan.FromSeconds(2));
                }
            }
            catch
            {
            }

            cts.Dispose();
            client.Dispose();
        }
    }
}