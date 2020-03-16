defmodule NosProtocol.MixProject do
  @moduledoc false
  use Mix.Project

  @version "1.0.0"
  @repo_url "https://github.com/deva-hub/NosProtocol"

  def project do
    [
      app: :nosprotocol,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "NosTale network library.",
      package: package(),
      name: "NosProtocol",
      docs: docs()
    ]
  end

  defp deps do
    [
      {:ranch, "~> 1.7"},
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      noslib_dep()
    ]
  end

  defp noslib_dep do
    if path = System.get_env("NOSLIB_PATH") do
      {:noslib, path: path}
    else
      {:noslib, github: "deva-hub/noslib"}
    end
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      source_url: @repo_url
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md"],
      maintainers: ["Shikanime Deva"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end
end
