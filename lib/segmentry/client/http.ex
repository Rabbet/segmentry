defmodule Segmentry.Http.Stub do
  @moduledoc """
  `Req` adapter used when `:send_to_http` is set to `false`. Logs the request at
  `:debug` level and replies with `200 OK` without making any network call.
  """
  require Logger

  def call(request) do
    Logger.debug("[Segmentry] HTTP API called with #{inspect(request)}")
    {request, %Req.Response{status: 200, body: ""}}
  end
end

defmodule Segmentry.Http do
  @moduledoc """
  Underlying implementation for making calls to the Segment HTTP API, built on `Req`.

  ## Configuration

      config :segmentry,
        send_to_http: true,
        retry_attempts: 3,
        retry_expiry: 10_000,
        retry_start: 100

  * `:retry_attempts` — number of times to retry against the Segment API. Default `3`.
  * `:retry_expiry` — maximum delay (ms) between retries. Default `10_000`.
  * `:retry_start` — base delay (ms) for the first retry. Default `100`.
  * `:send_to_http` — if `false`, swaps in a stub plug that logs at `:debug` and replies `200`. Default `true`.
  * `:req_options` — keyword list merged into every `Req` client. Useful for `:plug` (see `Req.Test`)
    or to override `:receive_timeout`.
  """
  @type client :: Req.Request.t()

  require Logger

  @doc "Build a `Req` client for the given Segment write key."
  @spec client(String.t()) :: client()
  def client(api_key), do: client(api_key, [])

  @doc "Build a `Req` client and merge in the supplied `Req` options (used to inject test stubs)."
  @spec client(String.t(), keyword()) :: client()
  def client(api_key, req_options) when is_list(req_options) do
    [
      base_url: Segmentry.Config.api_url(),
      auth: {:basic, "#{api_key}:"},
      retry: :transient,
      max_retries: Segmentry.Config.retry_attempts(),
      retry_delay: &retry_delay/1,
      receive_timeout: 30_000
    ]
    |> Keyword.merge(default_req_options())
    |> Keyword.merge(req_options)
    |> Req.new()
  end

  defp default_req_options do
    base = Segmentry.Config.req_options()

    if Segmentry.Config.send_to_http() do
      base
    else
      Keyword.put_new(base, :adapter, &Segmentry.Http.Stub.call/1)
    end
  end

  defp retry_delay(n) do
    min(Segmentry.Config.retry_start() * trunc(:math.pow(2, n)), Segmentry.Config.retry_expiry())
  end

  @doc "Send a single Segment event (or a list of events as a batch)."
  @spec send(client(), list(Segmentry.segment_event())) :: :ok | :error
  def send(client, events) when is_list(events), do: batch(client, events)

  @spec send(client(), Segmentry.segment_event()) :: :ok | :error
  def send(client, event) do
    :telemetry.span([:segmentry, :send], %{event: event}, fn ->
      result = post(client, event.type, prepare_events(event))

      case process_send_post_result(result) do
        :ok -> {:ok, %{event: event, status: :ok, result: result}}
        :error -> {:error, %{event: event, status: :error, error: result, result: result}}
      end
    end)
  end

  defp process_send_post_result(result) do
    case result do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: 400}} ->
        Logger.error("[Segmentry] Call Failed. JSON too large or invalid")
        :error

      {:error, err} ->
        Logger.error(
          "[Segmentry] Call Failed after #{Segmentry.Config.retry_attempts()} retries. #{inspect(err)}"
        )

        :error

      err ->
        Logger.error("[Segmentry] Call Failed #{inspect(err)}")
        :error
    end
  end

  @doc """
  Send a list of Segment events as a batch.

  Optional `context` and `integrations` maps are applied to the entire batch — see
  [Segment's docs](https://segment.com/docs/sources/server/http/#batch).
  """
  @spec batch(client(), list(Segmentry.segment_event()), map() | nil, map() | nil) ::
          :ok | :error
  def batch(client, events, context \\ nil, integrations \\ nil) do
    :telemetry.span([:segmentry, :batch], %{events: events}, fn ->
      data =
        %{batch: prepare_events(events)}
        |> add_if(:context, context)
        |> add_if(:integrations, integrations)

      result = post(client, "batch", data)

      case process_batch_post_result(result, events) do
        :ok -> {:ok, %{events: events, status: :ok, result: result}}
        :error -> {:error, %{events: events, status: :error, error: result, result: result}}
      end
    end)
  end

  defp process_batch_post_result(result, events) do
    case result do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: 400}} ->
        Logger.error(
          "[Segmentry] Batch call of #{length(events)} events failed. JSON too large or invalid"
        )

        :error

      {:error, err} ->
        Logger.error(
          "[Segmentry] Batch call of #{length(events)} events failed after #{Segmentry.Config.retry_attempts()} retries. #{inspect(err)}"
        )

        :error

      err ->
        Logger.error("[Segmentry] Batch call of #{length(events)} events failed #{inspect(err)}")
        :error
    end
  end

  defp post(client, url, data) do
    case Req.post(client, url: url, json: data) do
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, error}
    end
  end

  defp prepare_events(items) when is_list(items), do: Enum.map(items, &prepare_events/1)

  defp prepare_events(item) do
    Map.from_struct(item)
    |> prep_context()
    |> add_sent_at()
    |> drop_nils()
  end

  defp drop_nils(map) do
    map
    |> Enum.filter(fn
      {_, %{} = item} when map_size(item) == 0 -> false
      {_, nil} -> false
      {_, _} -> true
    end)
    |> Enum.into(%{})
  end

  defp prep_context(%{context: nil} = map),
    do: %{map | context: map_content(Segmentry.Analytics.Context.new())}

  defp prep_context(%{context: context} = map),
    do: %{map | context: map_content(context)}

  defp prep_context(map),
    do: Map.put_new(map, :context, map_content(Segmentry.Analytics.Context.new()))

  defp map_content(%Segmentry.Analytics.Context{} = context), do: Map.from_struct(context)
  defp map_content(context) when is_map(context), do: context

  defp add_sent_at(%{sentAt: nil} = map), do: Map.put(map, :sentAt, DateTime.utc_now())
  defp add_sent_at(map), do: Map.put_new(map, :sentAt, DateTime.utc_now())

  defp add_if(map, _key, nil), do: map
  defp add_if(map, key, value), do: Map.put_new(map, key, value)
end
