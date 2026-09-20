@echo off
setlocal EnableExtensions
title Ollama to opencode config sync

rem ============================================================
rem  sync-ollama-models.bat
rem  One-click sync: mirror all local Ollama models into the
rem  provider.ollama.models section of the opencode config file.
rem   - Models present in Ollama but missing in config  -> added
rem   - Models deleted from Ollama but still in config  -> removed
rem   - A timestamped backup is saved before each update
rem  Requirements: curl, PowerShell 5+, running Ollama service.
rem
rem  Filtering: REQUIRE_TOOLS=1 (default) only syncs models that
rem  support tool calling. Set REQUIRE_TOOLS=0 to sync all models.
rem ============================================================

set "OLLAMA_URL=http://localhost:11434"
set "CONFIG=%USERPROFILE%\.config\opencode\opencode.jsonc"
set "REQUIRE_TOOLS=1"

set "PS_CONF=%CONFIG%"
set "PS_URL=%OLLAMA_URL%"
set "PS_TOOLS=%REQUIRE_TOOLS%"

rem ---- preflight -------------------------------------------------
if not exist "%CONFIG%" (
  echo [ERROR] Config file not found: %CONFIG%
  exit /b 1
)

curl -s -o NUL --max-time 5 "%OLLAMA_URL%/" >NUL 2>&1
if errorlevel 1 (
  echo [ERROR] Ollama service is not reachable at %OLLAMA_URL%
  exit /b 1
)

rem ---- run sync (single PowerShell pass, no temp files) --------
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$q=[char]34;$bt=[System.IO.File]::ReadAllBytes($env:PS_CONF);$bom=$false;if($bt.Length -ge 3){if(($bt[0] -eq 239)-and($bt[1] -eq 187)-and($bt[2] -eq 191)){$bom=$true}};$raw=[System.IO.File]::ReadAllText($env:PS_CONF,[System.Text.Encoding]::UTF8);$ki=$raw.IndexOf($q+'models'+$q);if($ki -lt 0){Write-Host 'models key not found; abort';exit 1};$ob=$raw.IndexOf('{',$ki);$i=$ob;$d=0;$cb=-1;$ins=$false;while($i -lt $raw.Length){$c=$raw[$i];if($c -eq $q){$ins=-not $ins}elseif(-not $ins){if($c -eq '{'){$d=$d+1}elseif($c -eq '}'){$d=$d-1;if($d -eq 0){$cb=$i;break}}};$i=$i+1};if($cb -lt 0){Write-Host 'models block is not closed; abort';exit 1};$block=$raw.Substring($ob,$cb-$ob+1);$existing=@();$re=$q+'([^'+$q+']+)'+$q+'[ \t]*:[ \t]*\{';foreach($m in [regex]::Matches($block,$re)){if($m.Groups[1].Value){$existing+=$m.Groups[1].Value}};$sorted=@((Invoke-RestMethod ($env:PS_URL+'/api/tags') -TimeoutSec 6).models|ForEach-Object{$_.name}|Sort-Object -Unique);if($env:PS_TOOLS -eq '1'){$all=@((Invoke-RestMethod ($env:PS_URL+'/api/tags') -TimeoutSec 6).models);$kept=@($all|Where-Object{$_.capabilities -contains 'tools'}|ForEach-Object{$_.name}|Sort-Object -Unique);$dropped=@($sorted|Where-Object{$_ -notin $kept});$sorted=$kept;if($dropped.Count -gt 0){Write-Host ('Skipped (no tools): '+($dropped -join ', '))}};if($sorted.Count -eq 0){Write-Host 'api/tags returned no models; abort';exit 1};$toAdd=@($sorted|Where-Object{$_ -notin $existing});$toRemove=@($existing|Where-Object{$_ -notin $sorted});Write-Host ('Ollama models : '+$sorted.Count);Write-Host ('Config models : '+(@($existing|Select-Object -Unique).Count));if($toRemove.Count -gt 0){Write-Host ('To remove: '+($toRemove -join ', '))};if($toAdd.Count -gt 0){Write-Host ('To add: '+($toAdd -join ', '))};if(($toAdd.Count+$toRemove.Count) -eq 0){Write-Host 'No change needed';exit 0};$stamp=Get-Date -Format 'yyyyMMdd-HHmmss';Copy-Item -LiteralPath $env:PS_CONF -Destination ($env:PS_CONF+'.'+$stamp+'.bak') -ErrorAction Stop;$nl=[string][char]13+[string][char]10;$sb=New-Object System.Text.StringBuilder;[void]$sb.Append('{'+$nl);$cnt=$sorted.Count;for($j=0;$j -lt $cnt;$j++){$n=$sorted[$j];$cm=',';if($j -eq $cnt-1){$cm=''};[void]$sb.Append('        '+$q+$n+$q+': {'+$nl);[void]$sb.Append('          '+$q+'name'+$q+': '+$q+$n+$q+$nl);[void]$sb.Append('        }'+$cm+$nl)};[void]$sb.Append('      }');$newRaw=$raw.Substring(0,$ob)+$sb.ToString()+$raw.Substring($cb+1);[System.IO.File]::WriteAllText($env:PS_CONF,$newRaw,(New-Object System.Text.UTF8Encoding($bom)));Write-Host ('Config updated to '+$cnt+' models')"

if errorlevel 1 (
  echo [ERROR] Sync failed with exit code %ERRORLEVEL%
  exit /b 1
)

echo [OK] Done. Config now mirrors Ollama models.
pause