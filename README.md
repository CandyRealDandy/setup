# setup

Sets up a machine from my dotfiles. The setup itself is private; this repo
only gets it started: it installs gh (GitHub's command line tool), logs in to
GitHub in the browser, then runs the private setup.

**macOS, Linux (Ubuntu 22.04+, Debian 12+, Arch) and WSL**, in a terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/CandyRealDandy/setup/main/install.sh | bash
```

**Windows**, in PowerShell:

```powershell
irm https://raw.githubusercontent.com/CandyRealDandy/setup/main/install.ps1 | iex
```

Options go to the private setup as they are, e.g.
`... | bash -s -- --profile work --yes`.
