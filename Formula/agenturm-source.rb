require "json"

class AgenturmSource < Formula
  desc "Terminal cockpit for AI coding agent sessions"
  homepage "https://www.agenturm.dev"
  url "https://github.com/abhishekash/agenturm/archive/refs/tags/rust-v0.3.11.tar.gz"
  version "0.3.11"
  sha256 "68e4e579fef6f162eb2d6b45a5ad724a541acfaf63a843bbd97d8c1f868f03e1"
  license "MIT"

  livecheck do
    url :stable
    regex(/^rust-v(\d+(?:\.\d+)+)$/i)
    strategy :github_latest
  end

  on_macos do
    depends_on arch: :arm64
    depends_on macos: :ventura
  end

  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on "sqlite"

  deny_network_access!

  post_install_steps do
    run "agenturm-regenerate-catalog",
        base:           :libexec,
        writable_paths: ["agenturm-plugins.json"],
        writable_base:  :prefix
  end

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    ENV["MACOSX_DEPLOYMENT_TARGET"] = "13.0" if OS.mac?
    ENV["LIBSQLITE3_SYS_USE_PKG_CONFIG"] = "1"

    adapters = %w[codex pi claude kiro opencode]
    binaries = %w[agenturm agenturm-plugin-host]
    binaries += %w[agenturm-connector agenturm-storage-service] if OS.linux?
    binaries += adapters.map { |adapter| "agenturm-#{adapter}-harness" }

    build_args = ["build", "--release", "--locked", "--offline"]
    binaries.each { |binary| build_args.push("--bin", binary) }
    system "cargo", *build_args

    binaries.each { |binary| bin.install "target/release/#{binary}" }

    generator = <<~'SH'
      #!/bin/sh
      set -eu
      script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
      prefix=${script_dir%/libexec}
      if command -v shasum >/dev/null 2>&1; then
        sha256_of() { shasum -a 256 -- "$1" | awk '{print $1}'; }
      elif command -v sha256sum >/dev/null 2>&1; then
        sha256_of() { sha256sum -- "$1" | awk '{print $1}'; }
      else
        echo "shasum or sha256sum is required to refresh the adapter catalog" >&2
        exit 1
      fi
      emit() {
        adapter=$1
        discovery=$2
        digest=$(sha256_of "$prefix/bin/agenturm-$adapter-harness")
        printf '%s{"plugin_id":"example.rust-%s-harness","adapter":"bin/agenturm-%s-harness","sha256":"%s","protocol":1,"features":["source-adapter/1","configured-root/1"],"observation_format":"agenturm-observations/1","discovery":{%s}}' \
          "$separator" "$adapter" "$adapter" "$digest" "$discovery"
        separator=$(printf ',\n')
      }
      separator=
      {
        printf '{"version":1,"plugins":[\n'
        emit codex '"namespace":"codex","root_env":"CODEX_HOME","default_root":".codex/sessions","env_suffix":"sessions","shape":"codex_jsonl_tree"'
        emit pi '"namespace":"pi","root_env":"PI_CODING_AGENT_DIR","default_root":".pi/agent/sessions","env_suffix":"sessions","shape":"jsonl_tree"'
        emit claude '"namespace":"claude","root_env":"CLAUDE_CONFIG_DIR","default_root":".claude/projects","env_suffix":"projects","shape":"jsonl_tree"'
        emit kiro '"namespace":"kiro","root_env":"KIRO_HOME","default_root":".kiro/sessions","env_suffix":"sessions","shape":"kiro_jsonl_tree"'
        emit opencode '"namespace":"opencode","root_env":"OPENCODE_DB","default_root":".local/share/opencode/opencode.db","macos_default_root":"Library/Application Support/opencode/opencode.db","fallback_base_env":"XDG_DATA_HOME","fallback_suffix":"opencode/opencode.db","shape":"sqlite_file"'
        printf '\n]}\n'
      } > "$prefix/agenturm-plugins.json"
    SH

    libexec.mkpath
    (libexec/"agenturm-regenerate-catalog").write(generator)
    (libexec/"agenturm-regenerate-catalog").chmod(0755)
    system libexec/"agenturm-regenerate-catalog"
  end

  test do
    assert_match "agenturm 0.3.11", shell_output("#{bin}/agenturm --version")
    sqlite_linkage = shell_output("#{OS.mac? ? "otool -L" : "ldd"} #{bin}/agenturm")
    expected_sqlite = OS.mac? ? "libsqlite3.dylib" : "libsqlite3.so"
    assert_match expected_sqlite, sqlite_linkage

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
      next if row.dig("observation", "kind") != "usage"

      [row.dig("identity", "session_id"), row.dig("observation", "input_tokens"),
       row.dig("observation", "output_tokens")]
    end.sort
    assert_equal [["brew-codex", 7, 3], ["brew-pi", 8, 3]], usage
  end
end
