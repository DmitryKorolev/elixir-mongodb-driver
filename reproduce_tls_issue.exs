defmodule ReproduceTlsIssue do
  require Logger

  def run do
    uri = System.get_env("MONGODB_URI")

    unless uri do
      IO.puts("Error: MONGODB_URI environment variable is not set.")
      IO.puts("Usage: MONGODB_URI='mongodb+srv://...' mix run reproduce_tls_issue.exs")
      System.halt(1)
    end

    IO.puts("Target URI: #{uri}")

    # Start the application
    {:ok, _} = Application.ensure_all_started(:mongodb_driver)

    # 1. Attempt connection with default settings (should fail if cluster offers TLS 1.2 & 1.3 and issue is present)
    IO.puts("\n--- Test 1: Connecting with default SSL options ---")
    connect(uri)

    # 2. Attempt connection specifying TLS 1.2 ciphers but not setting TLS 1.2 explicitly
    IO.puts("\n--- Test 2: Connecting with TLS 1.2 ciphers (no version restriction) ---")
    # Using a cipher that is valid for TLS 1.2.
    # If the server supports TLS 1.3, the handshake might fail if we don't restrict the version
    # because the client might attempt TLS 1.3 but we haven't provided TLS 1.3 ciphers.
    ciphers = ['AES256-GCM-SHA384']
    connect(uri, ssl_opts: [ciphers: ciphers])
  end

  def connect(uri, extra_opts \\ []) do
    # We pass the URL and any extra options (like ssl_opts)
    # Note: start_link takes a keyword list. 'url' is one option.
    # extra_opts will override/merge with what's parsed from URL if handled by the driver,
    # but here we pass them as top-level options to Mongo.start_link.
    
    opts = [url: uri] ++ extra_opts
    
    # Set a short timeout for the reproduction script so it doesn't hang forever
    opts = opts ++ [connect_timeout: 5000]

    case Mongo.start_link(opts) do
      {:ok, conn} ->
        IO.puts("  Connection process started (PID: #{inspect(conn)}). Verifying connectivity...")
        
        # Try a ping command to verify actual connectivity and handshake completion
        case Mongo.command(conn, [ping: 1]) do
          {:ok, _} -> 
            IO.puts("  SUCCESS: Connected and pinged successfully.")
          {:error, reason} -> 
            IO.puts("  FAILURE: Ping failed.")
            IO.inspect(reason, label: "  Reason")
        end
        
        # Cleanup
        GenServer.stop(conn)
        
      {:error, reason} ->
        IO.puts("  FAILURE: Could not start connection process.")
        IO.inspect(reason, label: "  Reason")
    end
  end
end

ReproduceTlsIssue.run()
