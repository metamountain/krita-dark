# Krita Dark installer. Double-click INSTALL.bat - nothing else to do.
$ErrorActionPreference = 'Stop'
function Say($t, $c = 'White') { Write-Host $t -ForegroundColor $c }
try {
  $here = Split-Path -Parent $MyInvocation.MyCommand.Path
  if (-not (Test-Path "$here\color-schemes\PhotoshopDark.colors") -or -not (Test-Path "$here\pykrita\dark_icons")) {
    throw "Files are missing. Unzip the WHOLE zip first (right-click > Extract All), then run INSTALL.bat from the unzipped folder."
  }
  # 1. Krita must be closed, otherwise it overwrites our settings on exit.
  while (Get-Process krita -ErrorAction SilentlyContinue) {
    Say 'Krita is still open. Close Krita (save your work!), then press Enter here.' Yellow
    Read-Host | Out-Null
  }
  # 2. Is Krita there at all?
  $data = Join-Path $env:APPDATA 'krita'
  $rc   = Join-Path $env:LOCALAPPDATA 'kritarc'
  if (-not (Test-Path $data) -and -not (Test-Path $rc)) {
    Say 'Warning: no Krita settings found. Start Krita once, close it, then run this again. Installing anyway.' Yellow
  }
  # 3. Backup the settings file (never touched without a copy).
  if (Test-Path $rc) {
    $bak = "$rc.backup-before-krita-dark"
    if (-not (Test-Path $bak)) { Copy-Item $rc $bak }
    Say "Backup of your settings: $bak"
  }
  # 4. Copy files.
  New-Item -ItemType Directory -Force "$data\color-schemes", "$data\pykrita" | Out-Null
  Copy-Item "$here\color-schemes\*.colors" "$data\color-schemes\" -Force
  Copy-Item "$here\pykrita\*" "$data\pykrita\" -Recurse -Force
  # 5. Enable plugin + select theme.
  $lines = New-Object 'System.Collections.Generic.List[string]'
  if (Test-Path $rc) { Get-Content $rc | ForEach-Object { $lines.Add($_) } }
  function Set-Key($section, $key, $value) {
    $i = $lines.IndexOf("[$section]")
    if ($i -lt 0) { $lines.Add(''); $lines.Add("[$section]"); $lines.Add("$key=$value"); return }
    for ($j = $i + 1; $j -lt $lines.Count -and $lines[$j] -notmatch '^\['; $j++) {
      if ($lines[$j] -like "$key=*") { $lines[$j] = "$key=$value"; return }
    }
    $lines.Insert($i + 1, "$key=$value")
  }
  Set-Key 'python' 'enable_dark_icons' 'true'
  Set-Key 'theme' 'Theme' 'Photoshop Dark'
  Set-Content $rc $lines -Encoding UTF8
  # 6. Verify.
  $ok = (Test-Path "$data\color-schemes\PhotoshopDark.colors") -and (Test-Path "$data\pykrita\dark_icons\__init__.py") -and (Test-Path "$data\pykrita\dark_icons.desktop") -and ((Get-Content $rc) -contains 'enable_dark_icons=true')
  if (-not $ok) { throw 'Verification failed - something was not copied.' }
  Say ''
  Say 'DONE. Everything installed. Now start Krita.' Green
  Say 'If something looks wrong: run UNINSTALL.bat, it restores everything.'
} catch {
  Say ''
  Say "FAILED: $($_.Exception.Message)" Red
  Say 'Nothing is broken - your settings backup is next to kritarc. Send this message in a GitHub issue.'
}
