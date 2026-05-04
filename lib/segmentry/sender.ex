defmodule Segmentry.Analytics.Sender do
  @moduledoc """
  Alternative service implementation that sends every event as it is called. The HTTP call
  is made in a `Task.start_link/1` so it does not block the GenServer; ordering is **not** guaranteed.

  `Segmentry.Analytics.Batcher` should be preferred in production, but use this module when events
  must be as real-time as possible.
  """
  use GenServer
  alias Segmentry.Analytics.{Track, Identify, Screen, Alias, Group, Page}

  @doc "Start the GenServer with a Segment HTTP Source API write key."
  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(api_key), do: start_link(api_key, [])

  @doc """
  Start the GenServer with a Segment HTTP Source API write key and a keyword list of `Req`
  options. Used in tests to inject a `Req.Test` plug stub.
  """
  @spec start_link(String.t(), keyword()) :: GenServer.on_start()
  def start_link(api_key, req_options) do
    client = Segmentry.Http.client(api_key, req_options)
    GenServer.start_link(__MODULE__, client, name: __MODULE__)
  end

  @doc """
  Send a Segment event immediately and asynchronously. Must be a `Track`, `Identify`,
  `Screen`, `Alias`, `Group`, or `Page` struct.
  """
  @spec call(Segmentry.segment_event()) :: :ok
  def call(%{__struct__: mod} = event)
      when mod in [Track, Identify, Screen, Alias, Group, Page] do
    GenServer.cast(__MODULE__, {:send, event})
  end

  # GenServer Callbacks

  @impl true
  def init(client), do: {:ok, client}

  @impl true
  def handle_cast({:send, event}, client) do
    parent = self()

    Task.start_link(fn ->
      result = Segmentry.Http.send(client, event)
      send(parent, {:sent, event, result})
    end)

    {:noreply, client}
  end

  @impl true
  def handle_info({:sent, _event, _result}, client), do: {:noreply, client}
end
