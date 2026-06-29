defmodule Segmentry.Analytics.SenderTest do
  use ExUnit.Case, async: false

  alias Segmentry.Analytics.{Sender, Track}

  setup do
    on_exit(fn ->
      case Process.whereis(Sender) do
        nil -> :ok
        pid -> Process.exit(pid, :kill)
      end
    end)

    :ok
  end

  test "starts and registers under the module name" do
    parent = self()

    adapter = fn req ->
      send(parent, {:req, req})
      {req, %Req.Response{status: 200}}
    end

    {:ok, pid} = Sender.start_link("k", adapter: adapter)
    assert Process.whereis(Sender) == pid
  end

  test "call/1 sends each event immediately and asynchronously" do
    parent = self()

    adapter = fn req ->
      send(parent, {:req, req})
      {req, %Req.Response{status: 200}}
    end

    {:ok, _pid} = Sender.start_link("k", adapter: adapter)

    :ok = Sender.call(%Track{userId: "u", event: "first"})
    :ok = Sender.call(%Track{userId: "u", event: "second"})

    assert_receive {:req, _}, 200
    assert_receive {:req, _}, 200
  end

  test "single-event call uses /track endpoint, not /batch" do
    parent = self()

    adapter = fn req ->
      send(parent, {:req, req})
      {req, %Req.Response{status: 200}}
    end

    {:ok, _pid} = Sender.start_link("k", adapter: adapter)
    :ok = Sender.call(%Track{userId: "u", event: "one"})

    assert_receive {:req, req}, 200
    assert URI.to_string(req.url) =~ ~r{/track$}
  end

  test "start_link/1 uses default Req options" do
    parent = self()

    adapter = fn req ->
      send(parent, {:req, req})
      {req, %Req.Response{status: 200}}
    end

    Application.put_env(:segmentry, :req_options, adapter: adapter)

    try do
      {:ok, _pid} = Sender.start_link("k")
      :ok = Sender.call(%Track{userId: "u", event: "x"})
      assert_receive {:req, _}, 200
    after
      Application.delete_env(:segmentry, :req_options)
    end
  end
end
