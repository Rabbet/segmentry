defmodule Segmentry.Analytics.Batcher do
  @moduledoc """
  Default service implementation. Uses the
  [Segment Batch HTTP API](https://segment.com/docs/sources/server/http/#batch)
  to put events in a FIFO queue and send on a regular basis.

      config :segmentry,
        max_batch_size: 100,
        batch_every_ms: 5000

  * `:max_batch_size` — maximum batch size sent per request. Default `100`.
  * `:batch_every_ms` — interval (ms) between batch flushes. Default `2000`.

  Segment limits batch requests to 500KB and individual calls to 32KB. The library does not
  enforce this directly — keep `max_batch_size` low if your events are large. Segment also asks
  callers to limit themselves to under 50 requests/second; do not set `batch_every_ms` under 20ms.
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
    GenServer.start_link(__MODULE__, {client, :queue.new()}, name: __MODULE__)
  end

  @doc """
  Enqueue a Segment event for the next batch. Must be a `Track`, `Identify`, `Screen`,
  `Alias`, `Group`, or `Page` struct.
  """
  @spec call(Segmentry.segment_event()) :: :ok
  def call(%{__struct__: mod} = event)
      when mod in [Track, Identify, Screen, Alias, Group, Page] do
    enqueue(event)
  end

  @doc "Force the batcher to flush the queue immediately."
  @spec flush() :: :ok
  def flush, do: GenServer.call(__MODULE__, :flush)

  # GenServer Callbacks

  @impl true
  def init({client, queue}) do
    schedule_batch_send()
    {:ok, {client, queue}}
  end

  @impl true
  def handle_cast({:enqueue, event}, {client, queue}) do
    {:noreply, {client, :queue.in(event, queue)}}
  end

  @impl true
  def handle_call(:flush, _from, {client, queue}) do
    items = :queue.to_list(queue)
    if items != [], do: Segmentry.Http.batch(client, items)
    {:reply, :ok, {client, :queue.new()}}
  end

  @impl true
  def handle_info(:process_batch, {client, queue}) do
    length = :queue.len(queue)
    {items, queue} = extract_batch(queue, length)

    if items != [], do: Segmentry.Http.batch(client, items)

    schedule_batch_send()
    {:noreply, {client, queue}}
  end

  def handle_info({:ssl_closed, _msg}, state), do: {:noreply, state}

  defp schedule_batch_send do
    Process.send_after(self(), :process_batch, Segmentry.Config.batch_every_ms())
  end

  defp enqueue(event), do: GenServer.cast(__MODULE__, {:enqueue, event})

  defp extract_batch(queue, 0), do: {[], queue}

  defp extract_batch(queue, length) do
    take = min(length, Segmentry.Config.max_batch_size())
    :queue.split(take, queue) |> split_result()
  end

  defp split_result({q1, q2}), do: {:queue.to_list(q1), q2}
end
