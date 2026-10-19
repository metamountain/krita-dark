# Asks how dark the icons and brush presets should be. Double-click SETTINGS.bat.
$f = Join-Path $env:APPDATA 'krita\dark_icons.json'
$default = @{ icon_dim = 120; preset_dim = 150 }
$cfg = @{ icon_dim = $default.icon_dim; preset_dim = $default.preset_dim }
if (Test-Path $f) { try { (Get-Content $f -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $cfg[$_.Name] = [int]$_.Value } } catch {} }

Write-Host ''
Write-Host '=== Krita Dark - how dark should it be? ===' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Type a number from 0 to 255:'
Write-Host '    0   = original, not darkened at all'
Write-Host '    255 = completely black (invisible)'
Write-Host '    Higher number = darker.'
Write-Host ''
Write-Host "Icons         (toolbar, toolbox, dockers)  standard: $($default.icon_dim)   - good range 90-160"
Write-Host "Brush presets (the brush thumbnails)       standard: $($default.preset_dim)   - good range 100-200"
Write-Host ''
Write-Host 'Enter = keep the current value.   D = back to the standard values.'
Write-Host ''

function Ask($label, $key) {
  while ($true) {
    $a = (Read-Host "$label - now $($cfg[$key])").Trim()
    if ($a -eq '') { return }
    if ($a -eq 'd' -or $a -eq 'D') { $cfg[$key] = $default[$key]; return }
    $n = 0
    if ([int]::TryParse($a, [ref]$n) -and $n -ge 0 -and $n -le 255) { $cfg[$key] = $n; return }
    Write-Host 'Please type a number from 0 to 255 (or D for standard).' -ForegroundColor Yellow
  }
}
Ask 'Icon darkness' 'icon_dim'
Ask 'Brush preset darkness' 'preset_dim'
$cfg | ConvertTo-Json | Set-Content $f -Encoding UTF8
Write-Host ''
Write-Host "Saved: icons $($cfg.icon_dim), brush presets $($cfg.preset_dim). Restart Krita to see it." -ForegroundColor Green
