# Krita Dark uninstaller. Double-click UNINSTALL.bat.
try {
  while (Get-Process krita -ErrorAction SilentlyContinue) {
    Write-Host 'Krita is still open. Close it, then press Enter here.' -ForegroundColor Yellow
    Read-Host | Out-Null
  }
  $data = Join-Path $env:APPDATA 'krita'
  $rc   = Join-Path $env:LOCALAPPDATA 'kritarc'
  $bak  = "$rc.backup-before-krita-dark"
  Remove-Item "$data\color-schemes\PhotoshopDark.colors", "$data\pykrita\dark_icons.desktop" -Force -ErrorAction SilentlyContinue
  Remove-Item "$data\dark_icons.json" -Force -ErrorAction SilentlyContinue
  Remove-Item "$data\pykrita\dark_icons" -Recurse -Force -ErrorAction SilentlyContinue
  if (Test-Path $bak) { Copy-Item $bak $rc -Force; Remove-Item $bak; Write-Host 'Your old settings were restored.' }
  Write-Host 'DONE. Krita Dark removed.' -ForegroundColor Green
} catch { Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red }
