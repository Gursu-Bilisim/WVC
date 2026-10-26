<#
.SYNOPSIS
  wvc-tani.sh betigini adb ile bagli Android cihazlarda root olarak calistirir
  ve raporu bilgisayara ceker.

.DESCRIPTION
  wvc-tani.sh bu betikle ayni klasorde durmalidir. Satir sonlari LF'ye
  cevrilerek cihaza gonderilir. Cihazda root yoneticisinin "Shell"
  (com.android.shell) uygulamasina root izni vermis olmasi gerekir.

.PARAMETER Adb
  adb.exe yolu. Bos birakilirsa PATH icinde aranir.
  Ornek: -Adb '<adb.exe yolu>'

.PARAMETER Serial
  Yalniz bu cihaz. Bos birakilirsa yetkili butun cihazlar sirayla islenir.

.PARAMETER OutDir
  Raporlarin kaydedilecegi klasor. Varsayilan: betigin yanindaki wvc-raporlar.

.EXAMPLE
  .\wvc-tani.ps1
.EXAMPLE
  .\wvc-tani.ps1 -Serial 1a2b3c4d -OutDir '<rapor klasoru>'
#>
param(
    [string]$Adb = "",
    [string]$Serial = "",
    [string]$OutDir = ""
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sh = Join-Path $here "wvc-tani.sh"
if (-not (Test-Path $sh)) {
    Write-Error "wvc-tani.sh bu betikle ayni klasorde olmali: $here"
    exit 1
}

if (-not $OutDir) { $OutDir = Join-Path $here "wvc-raporlar" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if (-not $Adb) {
    # Sirayla: WVC'nin bir ve iki ust dizini, oralardaki platform-tools, sonra PATH.
    $cands = @(
        "..\..\adb.exe",
        "..\adb.exe",
        "..\..\platform-tools\adb.exe",
        "..\platform-tools\adb.exe"
    ) | ForEach-Object { Join-Path $here $_ }
    $near = $cands | Where-Object { Test-Path $_ } | Select-Object -First 1
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($near) {
        $Adb = (Resolve-Path $near).Path
    } elseif ($cmd) {
        $Adb = $cmd.Source
    } else {
        Write-Error "adb bulunamadi. -Adb '<adb.exe yolu>' parametresiyle verin."
        exit 1
    }
}
Write-Host "adb: $Adb"

# Windows satir sonlarini temizle; cihazdaki sh CRLF ile calismaz.
$tmp = Join-Path $env:TEMP "wvc-tani.sh"
$text = [IO.File]::ReadAllText($sh) -replace "`r`n", "`n"
[IO.File]::WriteAllText($tmp, $text, (New-Object Text.UTF8Encoding($false)))

if ($Serial) {
    $serials = @($Serial)
} else {
    $serials = @(& $Adb devices |
        Select-Object -Skip 1 |
        Where-Object { $_ -match "`tdevice$" } |
        ForEach-Object { ($_ -split "`t")[0] })
}

if ($serials.Count -eq 0) {
    Write-Error "Yetkili bagli cihaz yok. 'adb devices' ciktisini kontrol edin."
    exit 1
}

$ok = 0
foreach ($s in $serials) {
    Write-Host "== $s"

    & $Adb -s $s push $tmp /data/local/tmp/wvc-tani.sh 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "${s}: betik cihaza gonderilemedi."
        continue
    }

    $res = (& $Adb -s $s shell "su -c 'sh /data/local/tmp/wvc-tani.sh'" 2>&1) | Out-String
    $m = [regex]::Match($res, "Yazildi: (\S+)")
    if (-not $m.Success) {
        Write-Warning "${s}: rapor olusmadi. Root izni verilmemis olabilir. Cihaz ciktisi:"
        Write-Host $res
        continue
    }

    $remote = $m.Groups[1].Value
    & $Adb -s $s pull $remote $OutDir 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "${s}: rapor cekilemedi: $remote"
        continue
    }

    $local = Join-Path $OutDir (Split-Path $remote -Leaf)
    Write-Host ("   rapor: " + $local)

    # Raporun isaret ettigi ek dosyalar (overlay XML'leri)
    foreach ($e in [regex]::Matches((Get-Content -Raw $local), "Ek: (\S+)")) {
        $r = $e.Groups[1].Value
        & $Adb -s $s pull $r $OutDir 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host ("   ek:    " + (Join-Path $OutDir (Split-Path $r -Leaf)))
        } else {
            Write-Warning "${s}: ek dosya cekilemedi: $r"
        }
    }
    $ok++
}

Write-Host "Tamamlanan cihaz: $ok / $($serials.Count)"
if ($ok -ne $serials.Count) { exit 2 }
