class Agenturm < Formula
  desc "Terminal cockpit for AI coding agent sessions"
  homepage "https://www.agenturm.dev"
  url "https://github.com/abhishekash/agenturm/releases/download/rust-v0.3.15/agenturm-0.3.15-linux-x86_64.tar.gz"
  version "0.3.15"
  sha256 "85c1cb64013425b8a44ad6d25b5974e50310f19051e31ce1bf2cfc3c8c22b6e3"
  license "MIT"

  on_macos do
    depends_on arch: :arm64
    depends_on macos: :ventura

    on_arm do
      url "https://github.com/abhishekash/agenturm/releases/download/rust-v0.3.15/agenturm-0.3.15-macos-aarch64.tar.gz"
      sha256 "2b763273999765a6893a0779971d2601c98bd9855e22760fe075d36e7f7e7aed"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/abhishekash/agenturm/releases/download/rust-v0.3.15/agenturm-0.3.15-linux-aarch64.tar.gz"
      sha256 "231c2e89a406a56089ddeb56fa00d6f997d6cf7980a44d234a14cc7461ce8568"
    end
  end

  def install
    bundle = Dir["agenturm-0.3.15-*"]
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

    assert_match "agenturm 0.3.15", shell_output("#{bin}/agenturm --version")

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
