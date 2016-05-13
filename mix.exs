defmodule Channels.Mixfile do
  use Mix.Project

  def project do
    [app: :channels,
     description: "An application to manage AMQP consumers and publishers.",
     version: "0.0.1",
     elixir: "~> 1.2",
     package: package,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     docs: [extras: ["README.md"]]]
  end

  def application do
    [applications: [:logger],
     mod: {Channels, []}]
  end

  defp deps do
    [{:amqp, "0.1.4", only: [:dev, :test]},
     {:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.11", only: :dev}]
  end

  defp package do
    %{mantainers: ["Jaime Cabot"],
      licenses: ["Apache 2"],
      links: %{"GitHub" => "https://github.com/jcabotc/channels"}}
  end
end
