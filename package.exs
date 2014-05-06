defmodule JSXN.Mixfile do
use Mix.Project

  def project do
    [
      app: :jsxn,
      version: "0.1.0",
      description: "jsx but with maps",
      package: package
    ]
  end

  defp package do
    [
      files: [
        "LICENSE",
        "package.exs",
        "README.md",
        "rebar.config"
        "src"
      ],
      contributors: ["alisdair sullivan"],
      links: [{"github", "https://github.com/talentdeficit/jsxn"}]
    ]
  end
end