# Agenturm Homebrew tap

Install Agenturm with Homebrew:

```sh
brew install abhishekash/tap/agenturm
```

The formula installs the published Rust 0.3.11 bundle. It supports Apple
Silicon Macs running macOS 13 or later and Linux on x86_64 or aarch64. Intel
Macs are not supported. The full bundle stays together under Homebrew's
`libexec`, so the executable can find its plugin host, harnesses, and catalog.

The tap uses the public release archives and their verified SHA-256 values.
There is no Python or Rust toolchain requirement at install time or runtime.

## Update

```sh
brew update
brew upgrade agenturm
```

## Uninstall

```sh
brew uninstall agenturm
```
