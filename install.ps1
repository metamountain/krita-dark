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
  # 2b. Which Krita version? The plugin needs Krita 6 (PyQt6); older versions only get the color scheme.
  $major = $null
  $exe = Get-ChildItem "$env:ProgramFiles\Krita*\bin\krita.exe", "${env:ProgramFiles(x86)}\Krita*\bin\krita.exe", "$env:LOCALAPPDATA\Programs\Krita*\bin\krita.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($exe) { $major = [int]($exe.VersionInfo.ProductVersion -split '\.')[0] }
  $withPlugin = $true
  if ($major -and $major -lt 6) {
    $withPlugin = $false
    Say '' 
    Say "WARNING: you have Krita $major. The Dark Icons plugin needs Krita 6, so it will NOT be installed." Yellow
    Say 'Only the color scheme is installed. Icons stay bright, the title bar and brush presets are not changed.' Yellow
    Say 'Tip: Krita 6 is a free download from krita.org if you want the full effect.' Yellow
    Say ''
  } elseif (-not $major) {
    Say 'Could not detect your Krita version. This works with Krita 6 only (the color scheme also on older versions).' Yellow
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
  if ($withPlugin) { Copy-Item "$here\pykrita\*" "$data\pykrita\" -Recurse -Force }
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
  # top-level key (before the first [section]): canvas border = the area around the image
  $first = 0; while ($first -lt $lines.Count -and $lines[$first] -notmatch '^\[') { $first++ }
  $hit = $false
  for ($j = 0; $j -lt $first; $j++) { if ($lines[$j] -like 'canvasBorderColor=*') { $lines[$j] = 'canvasBorderColor=0,0,0'; $hit = $true } }
  if (-not $hit) { $lines.Insert(0, 'canvasBorderColor=0,0,0') }
  if ($withPlugin) { Set-Key 'python' 'enable_dark_icons' 'true' }
  Set-Key 'theme' 'Theme' 'Photoshop Dark'
  # standard darkness values; never overwrite what the user chose with SETTINGS.bat
  $cfgFile = Join-Path $data 'dark_icons.json'
  if ($withPlugin -and -not (Test-Path $cfgFile)) { '{ "icon_dim": 120, "preset_dim": 120 }' | Set-Content $cfgFile -Encoding UTF8 }
  Set-Content $rc $lines -Encoding UTF8
  # 6. Verify.
  $ok = (Test-Path "$data\color-schemes\PhotoshopDark.colors") -and (-not $withPlugin -or ((Test-Path "$data\pykrita\dark_icons\__init__.py") -and (Test-Path "$data\pykrita\dark_icons.desktop") -and ((Get-Content $rc) -contains 'enable_dark_icons=true')))
  if (-not $ok) { throw 'Verification failed - something was not copied.' }
  Say ''
  Say 'DONE. Everything installed. Now start Krita.' Green
  Say 'If something looks wrong: run UNINSTALL.bat, it restores everything.'
} catch {
  Say ''
  Say "FAILED: $($_.Exception.Message)" Red
  Say 'Nothing is broken - your settings backup is next to kritarc. Send this message in a GitHub issue.'
}
