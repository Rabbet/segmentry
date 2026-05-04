defmodule Segmentry do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @type segment_event ::
          Segmentry.Analytics.Track.t()
          | Segmentry.Analytics.Identify.t()
          | Segmentry.Analytics.Screen.t()
          | Segmentry.Analytics.Alias.t()
          | Segmentry.Analytics.Group.t()
          | Segmentry.Analytics.Page.t()

  @doc """
  Start the configured GenServer for handling Segment events with the Segment HTTP Source API Write Key.

  By default if nothing is configured it will start `Segmentry.Analytics.Batcher`.
  """
  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(api_key) do
    Segmentry.Config.service().start_link(api_key)
  end

  @doc """
  Start the configured GenServer for handling Segment events with the Segment HTTP Source API Write Key
  and a keyword list of `Req` options that will be merged into the HTTP client. This is the seam used by
  tests to inject `Req.Test` plugs.
  """
  @spec start_link(String.t(), keyword()) :: GenServer.on_start()
  def start_link(api_key, req_options) do
    Segmentry.Config.service().start_link(api_key, req_options)
  end

  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(opts) do
    Segmentry.Config.service().child_spec(opts)
  end
end
