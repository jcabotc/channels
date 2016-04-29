defmodule Channels.Mixfile do
  use Mix.Project

  def project do
    [app: :channels,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger],
     mod: {Channels, []}]
  end

  defp deps do
    [{:amqp, "0.1.4", only: :test}]
  end
end
