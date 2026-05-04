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
  @moduledoc false
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
  @moduledoc false
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
  @moduledoc false
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
  @moduledoc false
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
  @moduledoc false
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
  @moduledoc false
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
  @moduledoc false
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
