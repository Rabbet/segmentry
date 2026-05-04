defmodule Segmentry.ReqStub do
  @moduledoc false

  @doc """
  Builds a `Req` adapter that forwards every request to `pid` as
  `{:req, %Req.Request{}}` and replies with `response`. Useful for tests that
  need to assert on request shape without going through `Req.Test` ownership.
  """
  def adapter(pid, %Req.Response{} = response) do
    fn req ->
      send(pid, {:req, req})
      {req, response}
    end
  end

  @doc """
  Adapter that simulates a transport error.
  """
  def error_adapter(pid, exception) do
    fn req ->
      send(pid, {:req, req})
      {req, exception}
    end
  end

  @doc """
  Attaches a telemetry handler that forwards events to `pid` as
  `{:telemetry, name, measurements, metadata}`. Returns a 0-arity function
  the test can use to detach.
  """
  def attach_telemetry(pid, events) do
    handler_id = make_ref()
    :telemetry.attach_many(handler_id, events, &__MODULE__.forward/4, pid)
    fn -> :telemetry.detach(handler_id) end
  end

  def forward(name, measurements, metadata, pid) do
    send(pid, {:telemetry, name, measurements, metadata})
  end
end
