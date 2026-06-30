defmodule Segmentry.Analytics.Types do
  @moduledoc false
  def common_fields do
    [
      :anonymousId,
      :context,
      :integrations,
      :timestamp,
      :userId,
      :version
    ]
  end
end

defmodule Segmentry.Analytics.Track do
  @moduledoc """
  A [`track`](https://segment.com/docs/connections/spec/track/) event — records
  an action a user performed, named by `event`, with optional `properties`.
  """
  @method "track"

  defstruct Segmentry.Analytics.Types.common_fields() ++
              [
                :event,
                :properties,
                type: @method
              ]

  @type t :: %__MODULE__{}

  def new(attrs), do: struct(__MODULE__, attrs)
end

defmodule Segmentry.Analytics.Identify do
  @moduledoc """
  An [`identify`](https://segment.com/docs/connections/spec/identify/) event —
  ties a user to their `traits` (name, email, plan, etc.).
  """
  @method "identify"

  defstruct Segmentry.Analytics.Types.common_fields() ++
              [
                :traits,
                type: @method
              ]

  @type t :: %__MODULE__{}

  def new(attrs), do: struct(__MODULE__, attrs)
end

defmodule Segmentry.Analytics.Alias do
  @moduledoc """
  An [`alias`](https://segment.com/docs/connections/spec/alias/) event — merges
  two user identities by associating `userId` with a `previousId`.
  """
  @method "alias"

  defstruct Segmentry.Analytics.Types.common_fields() ++
              [
                :previousId,
                type: @method
              ]

  @type t :: %__MODULE__{}

  def new(attrs), do: struct(__MODULE__, attrs)
end

defmodule Segmentry.Analytics.Page do
  @moduledoc """
  A [`page`](https://segment.com/docs/connections/spec/page/) event — records a
  web page view, named by `name`, with optional `properties`.
  """
  @method "page"

  defstruct Segmentry.Analytics.Types.common_fields() ++
              [
                :name,
                :properties,
                type: @method
              ]

  @type t :: %__MODULE__{}

  def new(attrs), do: struct(__MODULE__, attrs)
end

defmodule Segmentry.Analytics.Screen do
  @moduledoc """
  A [`screen`](https://segment.com/docs/connections/spec/screen/) event — the
  mobile equivalent of `Segmentry.Analytics.Page`, recording a screen view.
  """
  @method "screen"

  defstruct Segmentry.Analytics.Types.common_fields() ++
              [
                :name,
                :properties,
                type: @method
              ]

  @type t :: %__MODULE__{}

  def new(attrs), do: struct(__MODULE__, attrs)
end

defmodule Segmentry.Analytics.Group do
  @moduledoc """
  A [`group`](https://segment.com/docs/connections/spec/group/) event —
  associates a user with a `groupId` (account/organization) and its `traits`.
  """
  @method "group"

  defstruct Segmentry.Analytics.Types.common_fields() ++
              [
                :groupId,
                :traits,
                type: @method
              ]

  @type t :: %__MODULE__{}

  def new(attrs), do: struct(__MODULE__, attrs)
end

defmodule Segmentry.Analytics.Context do
  @moduledoc """
  Shared [context](https://segment.com/docs/connections/spec/common/#context)
  attached to an event — library info, IP, locale, app, device, and so on.

  Use `new/0` or `new/1` to build one; both populate `library` with Segmentry's
  name and version automatically.
  """
  @library_name Mix.Project.get().project()[:description]
  @library_version Mix.Project.get().project()[:version]

  defstruct [
    :active,
    :app,
    :campaign,
    :device,
    :ip,
    :library,
    :locale,
    :location,
    :network,
    :os,
    :page,
    :referrer,
    :screen,
    :timezone,
    :groupId,
    :traits,
    :userAgent
  ]

  @type t :: %__MODULE__{}

  def update(context = %__MODULE__{}) do
    %{context | library: %{name: @library_name, version: @library_version}}
  end

  def new, do: update(%__MODULE__{})

  def new(attrs) do
    struct(__MODULE__, attrs)
    |> update()
  end
end
