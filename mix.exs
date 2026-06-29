defmodule Segmentry.MixProject do
  use Mix.Project

  @source_url "https://github.com/Rabbet/segmentry"
  @version "0.3.0"

  def project do
    [
      app: :segmentry,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: "Elixir client for Segment, built on Req",
      dialyzer: [plt_add_deps: :app_tree],
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.6"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.2"},
      {:plug, "~> 1.16", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Rabbet"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "Segmentry",
      api_reference: false,
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
