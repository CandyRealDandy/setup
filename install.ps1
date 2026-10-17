# Windows: sets up this machine from CandyRealDandy's dotfiles. The setup itself
# lives in a private repo, so this only installs GitHub's command line tool
# (gh), logs in to GitHub in the browser, then runs that setup. In PowerShell:
#
#   irm https://raw.githubusercontent.com/CandyRealDandy/setup/main/install.ps1 | iex
#
# One script block, ending with `return`, never `exit`: under `irm | iex` this
# runs in your own PowerShell, and `exit` would close the window.

& {
  $owner = 'CandyRealDandy'
  $private = 'repos/CandyRealDandy/dotfiles/contents/setup/install.ps1'

  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "Installing GitHub's command line tool (gh)..."
    winget install --id GitHub.cli --exact --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Host 'setup: installing gh failed'; return }
    $env:Path = [Environment]::ExpandEnvironmentVariables(
      [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
      [Environment]::GetEnvironmentVariable('Path', 'User'))
  }

  $previous = gh api user --jq .login 2>$null
  if ($previous -ne $owner) {
    gh auth switch --hostname github.com --user $owner *> $null
    if ($LASTEXITCODE -ne 0) {
      Write-Host "Log in to GitHub as ${owner}: gh opens the browser."
      gh auth login --hostname github.com --git-protocol ssh --web --scopes admin:public_key --skip-ssh-key
      if ($LASTEXITCODE -ne 0) { Write-Host 'setup: GitHub login failed'; return }
    }
    $login = gh api user --jq .login 2>$null
    if ($login -ne $owner) {
      Write-Host "setup: gh is logged in to GitHub as $login, not ${owner}: log in as $owner (gh auth login), then run this again"
      return
    }
  }

  $script = (gh api $private -H 'Accept: application/vnd.github.raw') -join "`n"
  $downloaded = $LASTEXITCODE -eq 0 -and $script
  # gh back to the account that was active (e.g. work, on a work machine).
  if ($previous -and $previous -ne $owner) { gh auth switch --hostname github.com --user $previous *> $null }
  if (-not $downloaded) {
    Write-Host "setup: couldn't download the setup from the private dotfiles repo as $owner"; return
  }
  Invoke-Expression $script
}
