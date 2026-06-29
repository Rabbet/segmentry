defmodule Segmentry.HttpTest do
  use ExUnit.Case, async: false

  alias Segmentry.Analytics.{Track, Identify, Context}
  alias Segmentry.Http

  @event %Track{userId: "u", event: "Sign Up", properties: %{plan: "pro"}}

  setup do
    handler_id = make_ref()

    :telemetry.attach_many(
      handler_id,
      [
        [:segmentry, :send, :start],
        [:segmentry, :send, :stop],
        [:segmentry, :batch, :start],
        [:segmentry, :batch, :stop]
      ],
      &__MODULE__.forward_telemetry/4,
      self()
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    :ok
  end

  # Public so it can be captured as a remote function (`&__MODULE__.forward/4`),
  # which keeps `:telemetry` from warning about local/anonymous handlers.
  def forward_telemetry(event, measurements, metadata, pid) do
    send(pid, {:telemetry, event, measurements, metadata})
  end

  describe "client/1" do
    test "produces a Req.Request with base_url, basic auth, and JSON content-type" do
      client = Http.client("write-key")
      assert %Req.Request{} = client
      assert client.options[:base_url] == Segmentry.Config.api_url()
      assert client.options[:auth] == {:basic, "write-key:"}
      assert client.options[:max_retries] == Segmentry.Config.retry_attempts()
    end

    test "uses the no-op adapter when send_to_http is false" do
      previous = Application.get_env(:segmentry, :send_to_http)

      try do
        Application.put_env(:segmentry, :send_to_http, false)
        client = Http.client("k")
        assert client.adapter == (&Segmentry.Http.Noop.call/1)
      after
        Application.put_env(:segmentry, :send_to_http, previous)
      end
    end
  end

  describe "client/2" do
    test "merges req_options on top of defaults" do
      client = Http.client("k", receive_timeout: 1_234)
      assert client.options[:receive_timeout] == 1_234
    end

    test "lets req_options override base_url" do
      client = Http.client("k", base_url: "https://example.test/")
      assert client.options[:base_url] == "https://example.test/"
    end
  end

  describe "send/2 single event" do
    test "returns :ok and emits start/stop telemetry on 200" do
      client = Http.client("k", plug: stub(200))

      assert :ok = Http.send(client, @event)

      assert_received {:req, %Plug.Conn{} = conn, _raw}
      assert conn.method == "POST"
      assert conn.request_path =~ ~r{/track$}
      assert ["Basic " <> _] = Plug.Conn.get_req_header(conn, "authorization")

      assert_received {:telemetry, [:segmentry, :send, :start], %{system_time: _},
                       %{event: %Track{}}}

      assert_received {:telemetry, [:segmentry, :send, :stop], %{duration: _},
                       %{event: %Track{}, status: :ok, result: {:ok, %Req.Response{status: 200}}}}
    end

    test "returns :error on 400" do
      client = Http.client("k", plug: stub(400))
      assert :error = Http.send(client, @event)
      assert_received {:telemetry, [:segmentry, :send, :stop], _, %{status: :error}}
    end

    test "returns :error on transport error" do
      client = Http.client("k", plug: error_stub(:econnrefused), retry: false)
      assert :error = Http.send(client, @event)
    end

    test "returns :error on unexpected status (e.g. 500 after retries exhausted)" do
      client = Http.client("k", plug: stub(500))
      assert :error = Http.send(client, @event)
    end

    test "retries on 500 up to max_retries" do
      client = Http.client("k", plug: stub(500))
      assert :error = Http.send(client, @event)

      attempts = drain_messages(:req, 0)
      assert attempts == Segmentry.Config.retry_attempts() + 1
    end

    test "stops retrying once the response is OK" do
      counter = :counters.new(1, [])
      name = unique_stub_name()

      Req.Test.stub(name, fn conn ->
        :counters.add(counter, 1, 1)
        status = if :counters.get(counter, 1) == 1, do: 500, else: 200
        Plug.Conn.send_resp(conn, status, "")
      end)

      client = Http.client("k", plug: {Req.Test, name})
      assert :ok = Http.send(client, @event)
      assert :counters.get(counter, 1) == 2
    end

    test "delegates to batch when given a list" do
      client = Http.client("k", plug: stub(200))
      assert :ok = Http.send(client, [@event, @event])
      assert_received {:req, conn, _raw}
      assert conn.request_path =~ ~r{/batch$}
    end
  end

  describe "batch/4" do
    test "200 → :ok and posts to /batch" do
      client = Http.client("k", plug: stub(200))
      assert :ok = Http.batch(client, [@event])

      assert_received {:req, conn, raw}
      assert conn.request_path =~ ~r{/batch$}
      assert is_list(decode(raw).batch)

      assert_received {:telemetry, [:segmentry, :batch, :start], _, %{events: [%Track{}]}}
      assert_received {:telemetry, [:segmentry, :batch, :stop], _, %{status: :ok}}
    end

    test "400 → :error" do
      client = Http.client("k", plug: stub(400))
      assert :error = Http.batch(client, [@event])
      assert_received {:telemetry, [:segmentry, :batch, :stop], _, %{status: :error}}
    end

    test "transport error → :error" do
      client = Http.client("k", plug: error_stub(:econnrefused), retry: false)
      assert :error = Http.batch(client, [@event])
    end

    test "unexpected status (501) → :error" do
      client = Http.client("k", plug: stub(501))
      assert :error = Http.batch(client, [@event])
    end

    test "context and integrations are attached when supplied" do
      client = Http.client("k", plug: stub(200))
      ctx = %{ip: "1.2.3.4"}
      integrations = %{All: false, Mixpanel: true}

      assert :ok = Http.batch(client, [@event], ctx, integrations)
      assert_received {:req, _conn, raw}

      body = decode(raw)
      assert body.context == %{ip: "1.2.3.4"}
      assert body.integrations == %{All: false, Mixpanel: true}
    end

    test "context and integrations are omitted when nil" do
      client = Http.client("k", plug: stub(200))
      assert :ok = Http.batch(client, [@event])
      assert_received {:req, _conn, raw}

      body = decode(raw)
      refute Map.has_key?(body, :context)
      refute Map.has_key?(body, :integrations)
    end
  end

  describe "prepare_events" do
    test "fills in a default context when one is missing" do
      client = Http.client("k", plug: stub(200))
      :ok = Http.send(client, %Identify{userId: "u", traits: %{}})

      assert_received {:req, _conn, raw}
      assert decode(raw).context.library.name == "Elixir client for Segment, built on Req"
    end

    test "passes through a Segmentry.Analytics.Context struct" do
      client = Http.client("k", plug: stub(200))
      ctx = Context.new(%{ip: "9.9.9.9"})
      :ok = Http.send(client, %Track{userId: "u", event: "e", context: ctx})

      assert_received {:req, _conn, raw}
      assert decode(raw).context.ip == "9.9.9.9"
    end

    test "passes through a plain map context" do
      client = Http.client("k", plug: stub(200))
      :ok = Http.send(client, %Track{userId: "u", event: "e", context: %{ip: "8.8.8.8"}})

      assert_received {:req, _conn, raw}
      assert decode(raw).context == %{ip: "8.8.8.8"}
    end

    test "always sets sentAt" do
      client = Http.client("k", plug: stub(200))
      :ok = Http.send(client, @event)

      assert_received {:req, _conn, raw}
      assert decode(raw).sentAt
    end

    test "drops nil values and empty maps" do
      client = Http.client("k", plug: stub(200))
      :ok = Http.send(client, %Track{userId: "u", event: "e"})

      assert_received {:req, _conn, raw}
      decoded = decode(raw)
      refute Map.has_key?(decoded, :anonymousId)
      refute Map.has_key?(decoded, :integrations)
      refute Map.has_key?(decoded, :properties)
    end
  end

  # Registers a Req.Test stub that forwards each request to the test process as
  # `{:req, %Plug.Conn{}, raw_body}` and replies with `status`. Returns the
  # `{Req.Test, name}` tuple to pass as the client's `:plug` option.
  defp stub(status, resp_body \\ "") do
    name = unique_stub_name()
    test = self()

    Req.Test.stub(name, fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      send(test, {:req, conn, raw})
      Plug.Conn.send_resp(conn, status, resp_body)
    end)

    {Req.Test, name}
  end

  # Like `stub/2`, but simulates a transport-level failure (e.g. `:econnrefused`).
  defp error_stub(reason) do
    name = unique_stub_name()
    test = self()

    Req.Test.stub(name, fn conn ->
      send(test, {:req, conn, nil})
      Req.Test.transport_error(conn, reason)
    end)

    {Req.Test, name}
  end

  defp unique_stub_name, do: :"stub_#{System.unique_integer([:positive])}"

  defp decode(raw) when is_binary(raw), do: Jason.decode!(raw, keys: :atoms)

  defp drain_messages(tag, n) do
    receive do
      {^tag, _, _} -> drain_messages(tag, n + 1)
    after
      50 -> n
    end
  end
end
