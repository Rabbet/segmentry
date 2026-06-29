defmodule Segmentry.Analytics.BatcherTest do
  use ExUnit.Case, async: false

  alias Segmentry.Analytics.{Batcher, Track}

  setup do
    parent = self()

    adapter = fn req ->
      send(parent, {:req, req})
      {req, %Req.Response{status: 200}}
    end

    on_exit(fn ->
      case Process.whereis(Batcher) do
        nil -> :ok
        pid -> Process.exit(pid, :kill)
      end
    end)

    {:ok, adapter: adapter}
  end

  defp start_batcher(adapter, opts \\ []) do
    {:ok, pid} = Batcher.start_link("k", [adapter: adapter] ++ opts)
    pid
  end

  test "starts and registers under the module name", %{adapter: adapter} do
    pid = start_batcher(adapter)
    assert Process.whereis(Batcher) == pid
  end

  test "call/1 enqueues an event without making an HTTP request", %{adapter: adapter} do
    start_batcher(adapter)
    :ok = Batcher.call(%Track{userId: "u", event: "e"})
    refute_received {:req, _}
  end

  test "flush/0 sends queued events as a batch", %{adapter: adapter} do
    start_batcher(adapter)
    :ok = Batcher.call(%Track{userId: "u", event: "e1"})
    :ok = Batcher.call(%Track{userId: "u", event: "e2"})
    :ok = Batcher.flush()

    assert_receive {:req, req}, 200
    body = Jason.decode!(IO.iodata_to_binary(req.body))
    assert length(body["batch"]) == 2
  end

  test "flush/0 with empty queue is a no-op", %{adapter: adapter} do
    start_batcher(adapter)
    :ok = Batcher.flush()
    refute_received {:req, _}
  end

  test "periodic flush sends events without manual flush" do
    parent = self()

    adapter = fn req ->
      send(parent, {:req, req})
      {req, %Req.Response{status: 200}}
    end

    start_batcher(adapter)
    :ok = Batcher.call(%Track{userId: "u", event: "tick"})
    assert_receive {:req, _}, 500
  end

  test "honors max_batch_size by splitting the queue", %{adapter: adapter} do
    previous = Application.get_env(:segmentry, :max_batch_size)

    try do
      Application.put_env(:segmentry, :max_batch_size, 2)
      start_batcher(adapter)

      for n <- 1..3 do
        :ok = Batcher.call(%Track{userId: "u", event: "e#{n}"})
      end

      :ok = Batcher.flush()
      assert_receive {:req, req}, 200
      body = Jason.decode!(IO.iodata_to_binary(req.body))
      assert length(body["batch"]) == 3

      send(Batcher, :process_batch)
      refute_receive {:req, _}, 100
    after
      Application.put_env(:segmentry, :max_batch_size, previous)
    end
  end

  test "tick processes only max_batch_size events at a time" do
    parent = self()

    adapter = fn req ->
      send(parent, {:req, req})
      {req, %Req.Response{status: 200}}
    end

    previous = Application.get_env(:segmentry, :max_batch_size)
    previous_every = Application.get_env(:segmentry, :batch_every_ms)

    try do
      Application.put_env(:segmentry, :max_batch_size, 2)
      Application.put_env(:segmentry, :batch_every_ms, 30_000)

      start_batcher(adapter)

      for n <- 1..3 do
        :ok = Batcher.call(%Track{userId: "u", event: "e#{n}"})
      end

      send(Batcher, :process_batch)

      assert_receive {:req, req1}, 200
      body1 = Jason.decode!(IO.iodata_to_binary(req1.body))
      assert length(body1["batch"]) == 2

      send(Batcher, :process_batch)

      assert_receive {:req, req2}, 200
      body2 = Jason.decode!(IO.iodata_to_binary(req2.body))
      assert length(body2["batch"]) == 1
    after
      Application.put_env(:segmentry, :max_batch_size, previous)
      Application.put_env(:segmentry, :batch_every_ms, previous_every)
    end
  end

  test "ignores spurious :ssl_closed messages", %{adapter: adapter} do
    pid = start_batcher(adapter)
    send(pid, {:ssl_closed, :ignored})
    assert Process.alive?(pid)
  end

  test "start_link/1 uses default Req options", %{adapter: adapter} do
    Application.put_env(:segmentry, :req_options, adapter: adapter)

    try do
      {:ok, _pid} = Batcher.start_link("k")
      :ok = Batcher.call(%Track{userId: "u", event: "ping"})
      :ok = Batcher.flush()
      assert_receive {:req, _}, 200
    after
      Application.delete_env(:segmentry, :req_options)
    end
  end
end
