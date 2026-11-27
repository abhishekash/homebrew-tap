class Agenturm < Formula
  desc "Terminal cockpit for AI coding agent sessions"
  homepage "https://www.agenturm.dev"
  url "https://github.com/abhishekash/agenturm/releases/download/rust-v0.3.10/agenturm-0.3.10-linux-x86_64.tar.gz"
  sha256 "40911d4dbc50f1effb914d7616e02416afa3468d7e6f0d52b9ba727d55db2041"
  version "0.3.10"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
    depends_on macos: :ventura

    on_arm do
      url "https://github.com/abhishekash/agenturm/releases/download/rust-v0.3.10/agenturm-0.3.10-macos-aarch64.tar.gz"
      sha256 "d02a389c2bef8db187037254d48c13ffd6bc507b8b17d93af000c29b96d71c1c"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/abhishekash/agenturm/releases/download/rust-v0.3.10/agenturm-0.3.10-linux-aarch64.tar.gz"
      sha256 "2e2bc311d8fb547132a7577b152d4296b71a14bec1a66e7c1e5578a327aa40d2"
    end
  end

  def install
    bundle = Dir["agenturm-0.3.10-*"]
    odie "Expected exactly one Agenturm release bundle" unless bundle.length == 1

    libexec.install bundle.first => "agenturm"
    bin.install_symlink libexec/"agenturm/bin/agenturm" => "agenturm"
  end

  test do
    require "json"

    assert_match "agenturm 0.3.10", shell_output("#{bin}/agenturm --version")

    mktemp do |tmp|
      home = Pathname(tmp)/"home"
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

      config = shell_output("#{bin}/agenturm discover --sessions-per-harness 1", env: { "HOME" => home.to_s })
      config_path = Pathname(tmp)/"sources.json"
      config_path.write(config)
      database = Pathname(tmp)/"history.sqlite"
      system({ "HOME" => home.to_s }, bin/"agenturm", "collect", "--config", config_path, "--db", database)
      rows = JSON.parse(shell_output("#{bin}/agenturm query --db #{database}"))["observations"]
      usage = rows.filter_map do |row|
        next unless row.dig("observation", "kind") == "usage"

        [row.dig("identity", "session_id"), row.dig("observation", "input_tokens"),
         row.dig("observation", "output_tokens")]
      end.sort
      assert_equal [["brew-codex", 7, 3], ["brew-pi", 8, 3]], usage
    end
  end
end
