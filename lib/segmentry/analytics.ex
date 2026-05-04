defmodule Segmentry.Analytics do
  @moduledoc """
  The `Segmentry.Analytics` module is the easiest way to send Segment events. It exposes
  convenience functions for `track`, `identify`, `screen`, `alias`, `group`, and `page` calls.

  Functions delegate to the configured service implementation, which can be changed with:

      config :segmentry, sender_impl: Segmentry.Analytics.Batcher

  By default `Segmentry.Analytics.Batcher` is used to send events in a batch periodically.
  """
  alias Segmentry.Analytics.{Track, Identify, Screen, Context, Alias, Group, Page}

  @type segment_id :: String.t() | integer()

  @doc "Send any Segment event struct (`Track`, `Identify`, `Screen`, `Alias`, `Group`, `Page`)."
  @spec send(Segmentry.segment_event()) :: :ok
  def send(%{__struct__: mod} = event)
      when mod in [Track, Identify, Screen, Alias, Group, Page] do
    call(event)
  end

  @spec track(Segmentry.Analytics.Track.t()) :: :ok
  def track(t = %Track{}), do: call(t)

  @spec track(segment_id(), String.t(), map(), Segmentry.Analytics.Context.t()) :: :ok
  def track(user_id, event_name, properties \\ %{}, context \\ Context.new()) do
    %Track{userId: user_id, event: event_name, properties: properties, context: context}
    |> call()
  end

  @spec identify(Segmentry.Analytics.Identify.t()) :: :ok
  def identify(i = %Identify{}), do: call(i)

  @spec identify(segment_id(), map(), Segmentry.Analytics.Context.t()) :: :ok
  def identify(user_id, traits \\ %{}, context \\ Context.new()) do
    %Identify{userId: user_id, traits: traits, context: context}
    |> call()
  end

  @spec screen(Segmentry.Analytics.Screen.t()) :: :ok
  def screen(s = %Screen{}), do: call(s)

  @spec screen(segment_id(), String.t(), map(), Segmentry.Analytics.Context.t()) :: :ok
  def screen(user_id, screen_name \\ "", properties \\ %{}, context \\ Context.new()) do
    %Screen{userId: user_id, name: screen_name, properties: properties, context: context}
    |> call()
  end

  @spec alias(Segmentry.Analytics.Alias.t()) :: :ok
  def alias(a = %Alias{}), do: call(a)

  @spec alias(segment_id(), segment_id(), Segmentry.Analytics.Context.t()) :: :ok
  def alias(user_id, previous_id, context \\ Context.new()) do
    %Alias{userId: user_id, previousId: previous_id, context: context}
    |> call()
  end

  @spec group(Segmentry.Analytics.Group.t()) :: :ok
  def group(g = %Group{}), do: call(g)

  @spec group(segment_id(), segment_id(), map(), Segmentry.Analytics.Context.t()) :: :ok
  def group(user_id, group_id, traits \\ %{}, context \\ Context.new()) do
    %Group{userId: user_id, groupId: group_id, traits: traits, context: context}
    |> call()
  end

  @spec page(Segmentry.Analytics.Page.t()) :: :ok
  def page(p = %Page{}), do: call(p)

  @spec page(segment_id(), String.t(), map(), Segmentry.Analytics.Context.t()) :: :ok
  def page(user_id, page_name \\ "", properties \\ %{}, context \\ Context.new()) do
    %Page{userId: user_id, name: page_name, properties: properties, context: context}
    |> call()
  end

  @spec call(Segmentry.segment_event()) :: :ok
  def call(event) do
    Segmentry.Config.service().call(event)
  end
end
