defmodule Segmentry.Http.Noop do
  @moduledoc """
  No-op `Req` adapter used when `:send_to_http` is set to `false`. Logs the
  request at `:debug` level and replies with `200 OK` without making any network
  call.
  """
  require Logger

  def call(request) do
    Logger.debug("[Segmentry] HTTP API called with #{inspect(request)}")
    {request, %Req.Response{status: 200, body: ""}}
  end
end
