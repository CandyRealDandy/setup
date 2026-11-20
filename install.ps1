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
  $private = "repos/$owner/dotfiles/contents/setup/install.ps1"

  # Set-SessionConfigHome <%APPDATA%> <home folder>: on a fresh machine (no gh login in %APPDATA%\GitHub CLI,
  # no XDG_CONFIG_HOME), XDG_CONFIG_HOME for this window, so gh's login below goes straight into ~/.config/gh,
  # where the dotfiles keep it (the setup sets it for good). A machine with a login there keeps reading it,
  # until the setup copies it over.
  function Set-SessionConfigHome([string]$appData, [string]$userProfile) {
    if ($env:XDG_CONFIG_HOME -or (Test-Path -LiteralPath (Join-Path $appData 'GitHub CLI'))) { return }
    $env:XDG_CONFIG_HOME = (Join-Path $userProfile '.config').Replace('\', '/')
  }

  # Word-for-word copies of install.ps1's functions (this file is fetched alone, so it can't load them); the
  # dotfiles' setup/tests/install-functions.test.ps1 tests them and checks the copies stay the same.

  function Update-SessionPath {
    # winget installs don't reach this session's PATH by themselves.
    $env:Path = [Environment]::ExpandEnvironmentVariables(
      [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
      [Environment]::GetEnvironmentVariable('Path', 'User'))
  }

  # Get-OwnerFile <owner> <api path>: a file from a GitHub repo, fetched with gh as <owner>, with \n line ends;
  # $null, saying why, when it can't be. Fetched with <owner>'s own token (gh auth token --user), never by
  # switching gh's active account, which another program (a work session, say) may be using meanwhile.
  function Get-OwnerFile([string]$owner, [string]$path) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Write-Host 'setup: gh is not installed'; return $null }
    $token = gh auth token --hostname github.com --user $owner 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $token) {
      Write-Host "setup: gh has no login for $owner; log in (gh auth login --hostname github.com --web), then run this again"
      return $null
    }
    $saved = $env:GH_TOKEN
    try {
      $env:GH_TOKEN = $token
      $lines = gh api $path -H 'Accept: application/vnd.github.raw'
      $ok = $LASTEXITCODE -eq 0
    } finally { $env:GH_TOKEN = $saved }
    if (-not $ok) { Write-Host "setup: downloading $path as $owner failed"; return $null }
    return (($lines -join "`n") + "`n")
  }

  # Test-WingetDone <exit code>: whether winget succeeded, or said the tool is there already or up to date
  # (winget's own return codes, doc/windows/package-manager/winget/returnCodes.md in microsoft/winget-cli):
  # a tool installed but not on this window's PATH yet is asked for again, and that answer mustn't stop setup.
  function Test-WingetDone([int]$code) {
    return $code -in @(
      0,
      -1978335135, # 0x8A150061 APPINSTALLER_CLI_ERROR_PACKAGE_ALREADY_INSTALLED
      -1978334963, # 0x8A15010D APPINSTALLER_CLI_ERROR_INSTALL_ALREADY_INSTALLED (another version)
      -1978334962, # 0x8A15010E APPINSTALLER_CLI_ERROR_INSTALL_DOWNGRADE (a higher version)
      -1978335189, # 0x8A15002B APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
      -1978335153  # 0x8A15004F APPINSTALLER_CLI_ERROR_UPGRADE_VERSION_NOT_NEWER
    )
  }

  # gh's output is read as UTF-8 (Windows PowerShell 5.1 would use the console's old code page), and the
  # console's encoding put back at the end.
  $encoding = [Console]::OutputEncoding
  [Console]::OutputEncoding = [Text.Encoding]::UTF8
  try {
    Set-SessionConfigHome $env:APPDATA $env:USERPROFILE

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
      Write-Host "Installing GitHub's command line tool (gh)..."
      winget install --id GitHub.cli --exact --accept-source-agreements --accept-package-agreements
      if (-not (Test-WingetDone $LASTEXITCODE)) { Write-Host "setup: installing gh failed ($LASTEXITCODE)"; return }
      Update-SessionPath
    }

    # No login for the owner yet: log in. That makes the owner gh's active account, so the account that was
    # active before (a work one, say) is switched back to at once; the owner is used only by its own token.
    gh auth token --hostname github.com --user $owner *> $null
    if ($LASTEXITCODE -ne 0) {
      $previous = gh api user --jq .login 2>$null
      Write-Host "Log in to GitHub as ${owner}: gh opens the browser."
      gh auth login --hostname github.com --git-protocol ssh --web --scopes admin:public_key --skip-ssh-key
      if ($LASTEXITCODE -ne 0) { Write-Host 'setup: GitHub login failed'; return }
      if ($previous -and $previous -ne $owner) { gh auth switch --hostname github.com --user $previous *> $null }
    }

    $script = Get-OwnerFile $owner $private
    if ($null -eq $script) { return }
    Invoke-Expression $script
  } finally {
    [Console]::OutputEncoding = $encoding
  }
}
