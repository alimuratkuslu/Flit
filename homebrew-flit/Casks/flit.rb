cask "flit" do
  version "1.0.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/alimuratkuslu/Flit/releases/download/v#{version}/Flit-#{version}.dmg"
  name "Flit"
  desc "Instantly switch to any running app with Option+Number shortcuts"
  homepage "https://github.com/alimuratkuslu/Flit"

  depends_on macos: ">= :ventura"

  app "Flit.app"

  postflight do
    # Grant Accessibility permission prompt on first launch
    system_command "/usr/bin/open", args: ["-a", "Flit"]
  end

  livecheck do
    url :homepage
    strategy :github_latest
  end
end
