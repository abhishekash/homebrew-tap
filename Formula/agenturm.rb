class Agenturm < Formula
  desc "Terminal cockpit for AI coding agent sessions"
  homepage "https://www.agenturm.dev"
  url "https://github.com/abhishekash/agenturm/releases/download/rust-v0.3.16/agenturm-0.3.16-linux-x86_64.tar.gz"
  version "0.3.16"
  sha256 "7892d72645e817ac00b64fcb086d0037093046c22aee844d61234ce3da2961f6"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
    depends_on macos: :ventura

    on_arm do
      url "https://github.com/abhishekash/agenturm/releases/download/rust-v0.3.16/agenturm-0.3.16-macos-aarch64.tar.gz"
      sha256 "a4f7ea0b73654057f5978775c2c04a2158ba8f739c3d053abf810bc0e9718091"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/abhishekash/agenturm/releases/download/rust-v0.3.16/agenturm-0.3.16-linux-aarch64.tar.gz"
      sha256 "04746b9150960b2921acc54158d2d192ec640782923fe4e735e25e9239febf68"
    end
  end

  def install
    bundle = Dir["agenturm-0.3.16-*"]
    if bundle.length == 1
      libexec.install bundle.first => "agenturm"
      app = libexec/"agenturm"
    else
      odie "Expected at most one Agenturm bundle root" if bundle.length > 1
      odie "Missing Agenturm plugin catalog" unless File.file?("agenturm-plugins.json")
      odie "Missing Agenturm binary directory" unless File.directory?("bin")

      libexec.install Dir["*"]
      app = libexec
    end
    bin.install_symlink app/"bin/agenturm" => "agenturm"
  end

  test do
    require "json"

    assert_match "agenturm 0.3.16", shell_output("#{bin}/agenturm --version")

    home = testpath/"home"
    codex = home/".codex/sessions/2026/11/20"
    pi = home/".pi/agent/sessions/project"
    codex.mkpath
    pi.mkpath
    (codex/"session.jsonl").write(<<~JSONL)
      {"type":"session_meta","payload":{"id":"brew-codex"}}
      {"type":"event_msg","timestamp":"2026-11-20T12:00:00Z","payload":{"type":"task_started","turn_id":"turn-1"}}
      {"type":"token_usage_record","timestamp":"2026-11-20T12:00:02Z","payload":{"type":"token_usage_record","turn_id":"turn-1","response_id":"response-1","usage":{"input_tokens":7,"output_tokens":3,"total_tokens":10}}}
    JSONL
    (pi/"session.jsonl").write(<<~JSONL)
      {"type":"session","id":"brew-pi"}
      {"type":"message","id":"assistant-1","timestamp":"2026-11-20T12:00:01Z","message":{"role":"assistant","stopReason":"stop","usage":{"input":8,"output":3},"content":[]}}
    JSONL

    ENV["HOME"] = home.to_s
    config = shell_output("#{bin}/agenturm discover --sessions-per-harness 1")
    config_path = testpath/"sources.json"
    config_path.write(config)
    database = testpath/"history.sqlite"
    system bin/"agenturm", "collect", "--config", config_path, "--db", database
    rows = JSON.parse(shell_output("#{bin}/agenturm query --db #{database}"))["observations"]
    usage = rows.filter_map do |row|
      if row.dig("observation", "kind") != "usage"
        next
      end

      [row.dig("identity", "session_id"), row.dig("observation", "input_tokens"),
       row.dig("observation", "output_tokens")]
    end
    assert_equal [["brew-codex", 7, 3], ["brew-pi", 8, 3]], usage.sort
  end
end
