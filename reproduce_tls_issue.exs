Mix.install([
  {:mongodb_driver, path: "."}
])

defmodule ReproduceTlsIssue do
  require Logger

  def run do
    uri = System.get_env("MONGODB_URI")

    unless uri do
      IO.puts("Error: MONGODB_URI environment variable is not set.")
      IO.puts("Usage: MONGODB_URI='mongodb+srv://...' elixir reproduce_tls_issue.exs")
      System.halt(1)
    end

    IO.puts("Target URI: #{uri}")

    # 1. Attempt connection with default settings
    IO.puts("\n--- Test 1: Connecting with default SSL options ---")
    connect(uri)

    # 2. Attempt connection specifying TLS 1.2 ciphers but not setting TLS 1.2 explicitly
    IO.puts("\n--- Test 2: Connecting with TLS 1.2 ciphers (no version restriction) ---")
    ciphers = ['AES256-GCM-SHA384']
    connect(uri, ssl_opts: [ciphers: ciphers])
  end

  def connect(uri, extra_opts \\ []) do
    Process.flag(:trap_exit, true)
    
    opts = [url: uri] ++ extra_opts
    opts = opts ++ [connect_timeout: 5000]

    case Mongo.start_link(opts) do
      {:ok, conn} ->
        IO.puts("  Connection process started (PID: #{inspect(conn)}). Verifying connectivity...")
        try do
          case Mongo.command(conn, [ping: 1]) do
            {:ok, _} -> 
              IO.puts("  SUCCESS: Connected and pinged successfully.")
            {:error, reason} -> 
              IO.puts("  FAILURE: Ping failed.")
              IO.inspect(reason, label: "  Reason")
          end
        catch
          :exit, reason ->
            IO.puts("  FAILURE: Connection process crashed during ping.")
            IO.inspect(reason, label: "  Exit Reason")
        end
        
        try do
          GenServer.stop(conn)
        catch
          :exit, _ -> :ok
        end
        
      {:error, reason} ->
        IO.puts("  FAILURE: Could not start connection process.")
        IO.inspect(reason, label: "  Reason")
    end
    Process.flag(:trap_exit, false)
  end
end

ReproduceTlsIssue.run()
