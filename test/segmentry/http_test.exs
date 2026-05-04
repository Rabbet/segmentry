defmodule Segmentry.HttpTest do
  use ExUnit.Case, async: false

  alias Segmentry.Analytics.{Track, Identify, Context}
  alias Segmentry.{Http, ReqStub}

  @event %Track{userId: "u", event: "Sign Up", properties: %{plan: "pro"}}

  setup do
    detach =
      ReqStub.attach_telemetry(self(), [
        [:segmentry, :send, :start],
        [:segmentry, :send, :stop],
        [:segmentry, :batch, :start],
        [:segmentry, :batch, :stop]
      ])

    on_exit(detach)
    :ok
  end

  describe "client/1" do
    test "produces a Req.Request with base_url, basic auth, and JSON content-type" do
      client = Http.client("write-key")
      assert %Req.Request{} = client
      assert client.options[:base_url] == Segmentry.Config.api_url()
      assert client.options[:auth] == {:basic, "write-key:"}
      assert client.options[:max_retries] == Segmentry.Config.retry_attempts()
    end

    test "uses the stub adapter when send_to_http is false" do
      previous = Application.get_env(:segmentry, :send_to_http)

      try do
        Application.put_env(:segmentry, :send_to_http, false)
        client = Http.client("k")
        assert client.adapter == (&Segmentry.Http.Stub.call/1)
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
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 200}))

      assert :ok = Http.send(client, @event)

      assert_received {:req, %Req.Request{} = req}
      assert req.method == :post
      assert URI.to_string(req.url) =~ ~r{/track$}
      assert ["Basic " <> _] = Map.fetch!(req.headers, "authorization")

      assert_received {:telemetry, [:segmentry, :send, :start], %{system_time: _},
                       %{event: %Track{}}}

      assert_received {:telemetry, [:segmentry, :send, :stop], %{duration: _},
                       %{event: %Track{}, status: :ok, result: {:ok, %Req.Response{status: 200}}}}
    end

    test "returns :error on 400" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 400}))
      assert :error = Http.send(client, @event)
      assert_received {:telemetry, [:segmentry, :send, :stop], _, %{status: :error}}
    end

    test "returns :error on transport error" do
      adapter = ReqStub.error_adapter(self(), %RuntimeError{message: "boom"})
      client = Http.client("k", adapter: adapter, retry: false)
      assert :error = Http.send(client, @event)
    end

    test "returns :error on unexpected status (e.g. 500 after retries exhausted)" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 500}))
      assert :error = Http.send(client, @event)
    end

    test "retries on 500 up to max_retries" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 500}))
      assert :error = Http.send(client, @event)

      attempts = drain_messages(:req, 0)
      assert attempts == Segmentry.Config.retry_attempts() + 1
    end

    test "stops retrying once the response is OK" do
      counter = :counters.new(1, [])

      adapter = fn req ->
        :counters.add(counter, 1, 1)
        n = :counters.get(counter, 1)
        status = if n == 1, do: 500, else: 200
        {req, %Req.Response{status: status}}
      end

      client = Http.client("k", adapter: adapter)
      assert :ok = Http.send(client, @event)
      assert :counters.get(counter, 1) == 2
    end

    test "delegates to batch when given a list" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 200}))
      assert :ok = Http.send(client, [@event, @event])
      assert_received {:req, req}
      assert URI.to_string(req.url) =~ ~r{/batch$}
    end
  end

  describe "batch/4" do
    test "200 → :ok and posts to /batch" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 200}))
      assert :ok = Http.batch(client, [@event])

      assert_received {:req, req}
      assert URI.to_string(req.url) =~ ~r{/batch$}
      assert is_list(decode(req).batch)

      assert_received {:telemetry, [:segmentry, :batch, :start], _, %{events: [%Track{}]}}
      assert_received {:telemetry, [:segmentry, :batch, :stop], _, %{status: :ok}}
    end

    test "400 → :error" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 400}))
      assert :error = Http.batch(client, [@event])
      assert_received {:telemetry, [:segmentry, :batch, :stop], _, %{status: :error}}
    end

    test "transport error → :error" do
      adapter = ReqStub.error_adapter(self(), %RuntimeError{message: "kaboom"})
      client = Http.client("k", adapter: adapter, retry: false)
      assert :error = Http.batch(client, [@event])
    end

    test "unexpected status (501) → :error" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 501}))
      assert :error = Http.batch(client, [@event])
    end

    test "context and integrations are attached when supplied" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 200}))
      ctx = %{ip: "1.2.3.4"}
      integrations = %{All: false, Mixpanel: true}

      assert :ok = Http.batch(client, [@event], ctx, integrations)
      assert_received {:req, req}

      body = decode(req)
      assert body.context == %{ip: "1.2.3.4"}
      assert body.integrations == %{All: false, Mixpanel: true}
    end

    test "context and integrations are omitted when nil" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 200}))
      assert :ok = Http.batch(client, [@event])
      assert_received {:req, req}

      body = decode(req)
      refute Map.has_key?(body, :context)
      refute Map.has_key?(body, :integrations)
    end
  end

  describe "prepare_events" do
    test "fills in a default context when one is missing" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 200}))
      :ok = Http.send(client, %Identify{userId: "u", traits: %{}})

      assert_received {:req, req}
      assert decode(req).context.library.name == "Elixir client for Segment, built on Req"
    end

    test "passes through a Segmentry.Analytics.Context struct" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 200}))
      ctx = Context.new(%{ip: "9.9.9.9"})
      :ok = Http.send(client, %Track{userId: "u", event: "e", context: ctx})

      assert_received {:req, req}
      decoded = decode(req)
      assert decoded.context.ip == "9.9.9.9"
    end

    test "passes through a plain map context" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 200}))
      :ok = Http.send(client, %Track{userId: "u", event: "e", context: %{ip: "8.8.8.8"}})

      assert_received {:req, req}
      assert decode(req).context == %{ip: "8.8.8.8"}
    end

    test "always sets sentAt" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 200}))
      :ok = Http.send(client, @event)

      assert_received {:req, req}
      assert decode(req).sentAt
    end

    test "drops nil values and empty maps" do
      client = Http.client("k", adapter: ReqStub.adapter(self(), %Req.Response{status: 200}))
      :ok = Http.send(client, %Track{userId: "u", event: "e"})

      assert_received {:req, req}
      decoded = decode(req)
      refute Map.has_key?(decoded, :anonymousId)
      refute Map.has_key?(decoded, :integrations)
      refute Map.has_key?(decoded, :properties)
    end
  end

  describe "Req.Test integration" do
    test "works with a Req.Test plug stub" do
      stub_name = :"http_test_stub_#{System.unique_integer([:positive])}"

      Req.Test.stub(stub_name, fn conn ->
        Plug.Conn.send_resp(conn, 200, "")
      end)

      client = Http.client("k", plug: {Req.Test, stub_name})
      assert :ok = Http.send(client, @event)
    end
  end

  defp decode(%Req.Request{body: body}) when is_binary(body) or is_list(body) do
    body |> IO.iodata_to_binary() |> Jason.decode!(keys: :atoms)
  end

  defp drain_messages(tag, n) do
    receive do
      {^tag, _} -> drain_messages(tag, n + 1)
    after
      50 -> n
    end
  end
end
