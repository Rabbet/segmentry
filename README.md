# Segmentry

<!-- MDOC !-->

[![hex.pm](https://img.shields.io/hexpm/v/segmentry.svg)](https://hex.pm/packages/segmentry)
[![hexdocs.pm](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/segmentry/)
[![hex.pm](https://img.shields.io/hexpm/l/segmentry.svg)](https://hex.pm/packages/segmentry)

A non-official Elixir client for [Segment](https://segment.com), built on [Req](https://hex.pm/packages/req).
Supports batched delivery with automatic retries.

This is a fork of [stueccles/analytics-elixir](https://github.com/stueccles/analytics-elixir) maintained by [Rabbet](https://github.com/Rabbet),
modernized to use Req in place of Tesla/hackney.

## Installation

Add `segmentry` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:segmentry, "~> 0.3"}
  ]
end
```

## Usage

Start the Segmentry agent with your write key from a Segment HTTP API Server Source.

```elixir
Segmentry.start_link("YOUR_WRITE_KEY")
```

There are two ways to call methods on the API. The basic way is via `Segmentry.Analytics`,
which delegates to the configured GenServer (`Segmentry.Analytics.Batcher` by default) so
events are queued and batched. The lower-level way is to use `Segmentry.Http.send/2` and
`Segmentry.Http.batch/2` directly with a client built via `Segmentry.Http.client/1` or
`Segmentry.Http.client/2`.

### Track

```elixir
Segmentry.Analytics.track(user_id, event, %{property1: "", property2: ""})
```

Or with the full struct:

```elixir
%Segmentry.Analytics.Track{userId: "abc", event: "Signed Up", properties: %{plan: "pro"}}
|> Segmentry.Analytics.track()
```

### Identify

```elixir
Segmentry.Analytics.identify(user_id, %{trait1: "", trait2: ""})
```

### Screen

```elixir
Segmentry.Analytics.screen(user_id, name)
```

### Alias

```elixir
Segmentry.Analytics.alias(user_id, previous_id)
```

### Group

```elixir
Segmentry.Analytics.group(user_id, group_id)
```

### Page

```elixir
Segmentry.Analytics.page(user_id, name)
```

### Setting Context

```elixir
context = Segmentry.Analytics.Context.new(%{active: false})
Segmentry.Analytics.track(user_id, event, %{property1: ""}, context)
```

## Configuration

- `config :segmentry, :sender_impl` — sender implementation. Defaults to `Segmentry.Analytics.Batcher`. Set to `Segmentry.Analytics.Sender` to send each event immediately (asynchronously).
- `config :segmentry, :max_batch_size` — maximum events per batch. Default `100`.
- `config :segmentry, :batch_every_ms` — interval (ms) between batches. Default `2000`.
- `config :segmentry, :retry_attempts` — retry count for failed requests. Default `3`.
- `config :segmentry, :retry_expiry` — maximum delay (ms) between retries. Default `10_000`.
- `config :segmentry, :retry_start` — base delay (ms) for the first retry. Default `100`.
- `config :segmentry, :send_to_http` — when `false`, replaces the HTTP client with a stub plug that logs at `:debug` and returns `200`. Useful for dev/test. Default `true`.
- `config :segmentry, :req_options` — keyword list merged into every `Req` client. Useful for injecting `Req.Test` plug stubs or overriding `:receive_timeout`.
- `config :segmentry, :api_url` — Segment-compatible endpoint. Defaults to `https://api.segment.io/v1/`. Override for Segment's EU instance or compatible APIs like [Rudderstack](https://rudderstack.com).

## Usage in Phoenix

Add a config variable for your write key (typically loaded from the environment):

```elixir
config :segmentry, write_key: System.get_env("SEGMENT_WRITE_KEY")
```

Then start Segmentry under your application supervisor (in `application.ex`):

```elixir
{Segmentry, Application.get_env(:segmentry, :write_key)}
```

## Testing with Req.Test

Because Segmentry uses `Req`, you can stub out HTTP using `Req.Test`:

```elixir
Req.Test.stub(MySegmentStub, fn conn ->
  Plug.Conn.send_resp(conn, 200, "")
end)

{:ok, _pid} = Segmentry.Analytics.Batcher.start_link("test-key", plug: {Req.Test, MySegmentStub})
```

## Telemetry

Segmentry wraps each Segment call in [`:telemetry.span/3`](https://hexdocs.pm/telemetry/telemetry.html#span/3).
You can attach to:

- `[:segmentry, :send, :start]`
- `[:segmentry, :send, :stop]`
- `[:segmentry, :send, :exception]`
- `[:segmentry, :batch, :start]`
- `[:segmentry, :batch, :stop]`
- `[:segmentry, :batch, :exception]`

Measurements (in `:native` time units):

- `system_time` on `:start` events
- `duration` on `:stop` and `:exception` events

Metadata:

- the original `event` or `events`
- `status` (`:ok` | `:error`) and the `Req` `result` on `:stop` events
- `error` matching `result` when it isn't `{:ok, response}`
- `kind`, `reason`, `stacktrace` on `:exception` events
