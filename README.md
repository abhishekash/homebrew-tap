# Agenturm Homebrew tap

Install Agenturm with Homebrew:

```sh
brew install abhishekash/tap/agenturm
```

The formula installs the published Rust 0.3.11 bundle. It supports Apple
Silicon Macs running macOS 13 or later and Linux (glibc 2.39+) on x86_64 or aarch64. Intel
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

## Build from source

```sh
brew install abhishekash/tap/agenturm-source
```

This alternative builds the immutable Rust 0.3.11 source archive with the
locked Cargo dependencies. It links macOS system SQLite on Mac and
Homebrew SQLite on Linux. Homebrew installs Rust and pkgconf for the build. Python is not required. The source formula and
the binary formula install the same commands; uninstall one before installing
the other. Use `brew upgrade agenturm-source` to update the source installation.

CI checks binary installs and source builds on Apple Silicon, Linux x86_64,
and Linux ARM64. Source checks include functional discovery and collection,
shared SQLite linkage, style, strict new-formula audit, livecheck, bottle
reinstallation, and repeat post-install checksum regeneration.

## Homebrew core submission

`core-candidate/agenturm.rb` is the source formula under its proposed core name.
Agenturm is currently distributed through this tap. `brew install agenturm`
without first adding the tap is available only after Homebrew core accepts
the formula. See the [Homebrew acceptance policy](https://docs.brew.sh/Package-Acceptance-Policy)
for the public-interest criteria. Homebrew also requires human review of
AI-assisted submissions and human-written responses to maintainer feedback.

The **Homebrew core readiness** workflow (on candidate PRs or manual dispatch) stages the
candidate in a real `homebrew/core` checkout and runs strict new-formula
audit. It reports core acceptance failures separately from tap validation.
