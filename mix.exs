defmodule Arango.Mixfile do
  use Mix.Project

  def project do
    [
      app: :arango,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:connection, "~> 1.0"},
      {:credo, "~> 0.8", only: [:dev, :test]},
      {:ex_doc, "~> 0.16", only: :dev},
      {:velocy_pack, "~> 0.0"},
      {:velocy_stream, "~> 0.0"},
    ]
  end
end
