defmodule NosProtocol.MixProject do
  use Mix.Project

  def project do
    [
      app: :nosprotocol,
      version: "0.1.0",
      elixir: "~> 1.9",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: "Nostale network library.",
      package: package(),

      # Docs
      name: "NosProtocol"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:recase, "~> 0.4"}
    ]
  end

  defp package do
    [
      files: ["lib", "priv", "mix.exs", "README.md"],
      maintainers: ["Shikanime Deva"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/deva-hub/NosProtocol"}
    ]
  end
end
