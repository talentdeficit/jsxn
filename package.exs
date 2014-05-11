defmodule JSXN.Mixfile do
use Mix.Project

  def project do
    [
      app: :jsxn,
      version: "0.2.1",
      description: "jsx but with maps",
      package: package,
      deps: deps
    ]
  end

  defp package do
    [
      files: [
        "LICENSE",
        "package.exs",
        "README.md",
        "rebar.config",
        "src"
      ],
      contributors: ["alisdair sullivan"],
      links: [{"github", "https://github.com/talentdeficit/jsxn"}]
    ]
  end
  
  defp deps do
    [{:jsx, "~> 2.0"}]
  end
end