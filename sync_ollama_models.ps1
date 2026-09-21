$ErrorActionPreference = "Stop"
$OLLAMA_URL = "http://localhost:11434"
$CONFIG = Join-Path $HOME ".config\opencode\opencode.jsonc"
$REQUIRE_TOOLS = $true
$MIN_CONTEXT = 65536
$q = [char]34

# 前置檢查：設定檔存在
if (-not (Test-Path -LiteralPath $CONFIG)) {
    Write-Host "[ERROR] Config file not found: $CONFIG"
    exit 1
}

# 前置檢查：Ollama 服務可達
if (-not (Test-NetConnection -ComputerName localhost -Port 11434 -InformationLevel Quiet)) {
    Write-Host "[ERROR] Ollama service is not reachable at $OLLAMA_URL"
    Write-Host "[INFO] Please start Ollama service first: ollama serve"
    exit 1
}

# 讀取設定檔
$raw = [System.IO.File]::ReadAllText($CONFIG, [System.Text.Encoding]::UTF8)

# 尋找 models 區段
$modelsKeyIndex = $raw.IndexOf($q + "models" + $q)

if ($modelsKeyIndex -ge 0) {
    # 找到 models 區段：計算物件大括號邊界
    $objStart = $raw.IndexOf("{", $modelsKeyIndex)
    $braceCount = 0
    $objEnd = -1
    for ($i = $objStart; $i -lt $raw.Length; $i++) {
        $c = $raw[$i]
        if ($c -eq "{") { $braceCount++ }
        elseif ($c -eq "}") { $braceCount--; if ($braceCount -eq 0) { $objEnd = $i; break } }
    }
    if ($objEnd -lt 0) { Write-Host "[ERROR] models block not closed"; exit 1 }

    $modelsBlock = $raw.Substring($objStart, $objEnd - $objStart + 1)

    # 從設定檔抽出既有 model 名稱
    $existingModels = @()
    $re = $q + "([^" + $q + "]+)" + $q + "[ \t]*:[ \t]*\{"
    foreach ($m in [regex]::Matches($modelsBlock, $re)) {
        if ($m.Groups[1].Value) { $existingModels += $m.Groups[1].Value }
    }
    $existingModels = $existingModels | Sort-Object -Unique
} else {
    # 缺少 models 區段：嘗試自動建立
    $providerIdx = $raw.IndexOf($q + "provider" + $q)
    if ($providerIdx -ge 0) {
        Write-Host "[ERROR] provider key exists but models key not found; please add provider.ollama.models manually"
        exit 1
    }
    $objStart = -1; $objEnd = -1; $autoCreate = $true; $existingModels = @()
}

# 取得 Ollama models
try {
    $all = (Invoke-RestMethod ($OLLAMA_URL + "/api/tags") -TimeoutSec 10).models
} catch {
    Write-Host "[ERROR] Ollama unreachable: $_"; exit 1
}

# 依工具支援與 context 大小篩選
$kept = @(); $dt = @(); $dc = @()
foreach ($m in $all) {
    $okT = $true; $okC = $true
    if ($REQUIRE_TOOLS) {
        if (@($m.capabilities) -notcontains "tools") { $okT = $false; $dt += $m.name }
    }
    if ($MIN_CONTEXT) {
        $ctx = $m.details.context_length
        if ($null -eq $ctx -or $ctx -lt $MIN_CONTEXT) { $okC = $false; $dc += $m.name }
    }
    if ($okT -and $okC) { $kept += $m.name }
}
$sorted = $kept | Sort-Object -Unique

if ($dt.Count -gt 0) { Write-Host ("[INFO] Skipped (no tools): " + ($dt -join ", ")) }
if ($dc.Count -gt 0) { Write-Host ("[INFO] Skipped (small context): " + ($dc -join ", ")) }

$toAdd = $sorted | Where-Object { $_ -notin $existingModels }
$toRemove = $existingModels | Where-Object { $_ -notin $sorted }

Write-Host ("[INFO] Ollama models: " + $sorted.Count)
Write-Host ("[INFO] Config models: " + ($existingModels | Select-Object -Unique).Count)
if ($toRemove.Count -gt 0) { Write-Host ("[INFO] To remove: " + ($toRemove -join ", ")) }
if ($toAdd.Count -gt 0) { Write-Host ("[INFO] To add: " + ($toAdd -join ", ")) }
if ($sorted.Count -eq 0) { Write-Host "[ERROR] No model passed filters"; exit 1 }
if (($toAdd.Count + $toRemove.Count) -eq 0) { Write-Host "[INFO] No change needed"; exit 0 }

# 建立備份
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -LiteralPath $CONFIG -Destination ($CONFIG + "." + $stamp + ".bak") -ErrorAction Stop
Write-Host "[INFO] Backup saved: $CONFIG.$stamp.bak"

# 建立新的 models block（內含開頭 { 至結尾 }
$nl = [char]13 + [char]10
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("{" + $nl)
$cnt = $sorted.Count
for ($j = 0; $j -lt $cnt; $j++) {
    $n = $sorted[$j]
    $cm = if ($j -eq $cnt - 1) { "" } else { "," }
    [void]$sb.Append("        " + $q + $n + $q + ": {" + $nl)
    [void]$sb.Append("          " + $q + "name" + $q + ": " + $q + $n + $q + $nl)
    [void]$sb.Append("        }" + $cm + $nl)
}
[void]$sb.Append("      }")
$body = $sb.ToString()

if ($autoCreate) {
    # 在設定檔末端 } 之前插入完整 provider.ollama.models 結構
    $end = $raw.LastIndexOf("}")
    if ($end -lt 0) { Write-Host "[ERROR] config missing closing brace"; exit 1 }
    $before = $raw.Substring(0, $end).TrimEnd()
    $fragment = $before + "," + $nl + $nl + "  " + $q + "provider" + $q + ": {" + $nl + "    " + $q + "ollama" + $q + ": {" + $nl + "      " + $q + "options" + $q + ": {" + $nl + "        " + $q + "baseURL" + $q + ": " + $q + $OLLAMA_URL + "/v1" + $q + $nl + "      }," + $nl + "      " + $q + "models" + $q + ": " + $body + $nl + "    }" + $nl + "  }" + $nl
    $newRaw = $fragment + $raw.Substring($end)
} else {
    # 取代設定檔中的 models block
    $newRaw = $raw.Substring(0, $objStart) + $body + $raw.Substring($objEnd + 1)
}

[System.IO.File]::WriteAllText($CONFIG, $newRaw, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[OK] Done. Config now mirrors Ollama models."
Read-Host "Press Enter to exit"