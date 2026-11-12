# ============================================================================
#  3105 - pairing em um clique (Windows)
#
#  Gera o pairing record do iPhone conectado e empurra direto para dentro do
#  app 3105, sem passar por Files, iCloud ou Telegram.
#
#  Uso:  duplo clique em PAREAR-3105.bat  (ou clique direito -> Executar)
#
#  Requisitos:
#    - Windows 10/11
#    - Python 3 instalado (https://python.org)  -> marque "Add to PATH"
#    - iTunes ou o app "Apple Devices" da Microsoft Store (driver do iPhone)
#    - iPhone conectado, desbloqueado e com passcode ativo
#
#  O que este script faz, em ordem:
#    1. instala/atualiza o pymobiledevice3
#    2. faz o handshake "Confiar neste computador"
#    3. exporta o pairing record
#    4. empurra o arquivo para o Documents do 3105 via AFC
#    5. se o passo 4 falhar, mostra um codigo base64 para colar no app
# ============================================================================

$ErrorActionPreference = 'Stop'
$AppBundleId   = 'com.apple.mobile.MobileHouseArrest'
$PairingName   = 'airlift_pairing.plist'

function Write-Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "    $text" -ForegroundColor Green }
function Write-Warn2($text){ Write-Host "    $text" -ForegroundColor Yellow }
function Fail($text) {
    Write-Host "`n[ERRO] $text" -ForegroundColor Red
    Write-Host "`nPressione Enter para fechar..."
    Read-Host | Out-Null
    exit 1
}

Write-Host "=============================================="
Write-Host " 3105 - pareamento do iPhone"
Write-Host "=============================================="

# ---------------------------------------------------------------- Python
Write-Step "Procurando o Python"
$python = $null
foreach ($candidate in @('python', 'py')) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) {
        try {
            $version = & $candidate --version 2>&1
            if ($version -match 'Python 3') { $python = $candidate; break }
        } catch { }
    }
}
if (-not $python) {
    Fail "Python 3 nao encontrado. Instale de https://python.org e marque 'Add Python to PATH'."
}
Write-Ok "usando $python ($(& $python --version 2>&1))"

# ---------------------------------------------------------------- pymobiledevice3
Write-Step "Instalando/atualizando pymobiledevice3 (pode levar um minuto)"
& $python -m pip install --upgrade --quiet pymobiledevice3
if ($LASTEXITCODE -ne 0) {
    Fail "Falha ao instalar o pymobiledevice3. Sem internet ou pip bloqueado?"
}
& $python -m pymobiledevice3 version *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "pymobiledevice3 instalou mas nao executa. Reinstale o Python com 'Add to PATH'."
}
Write-Ok "pymobiledevice3 pronto"

# ---------------------------------------------------------------- device
Write-Step "Procurando o iPhone pelo cabo"
$devices = & $python -m pymobiledevice3 usbmux list 2>&1
if ($LASTEXITCODE -ne 0 -or -not ($devices -match 'Identifier')) {
    Write-Warn2 "lista de dispositivos: $devices"
    Fail "Nenhum iPhone detectado. Confira o cabo, desbloqueie a tela e instale iTunes/Apple Devices."
}
Write-Ok "iPhone detectado"

# ---------------------------------------------------------------- pair
Write-Step "Pareando (aceite 'Confiar neste computador' no iPhone)"
& $python -m pymobiledevice3 lockdown pair
if ($LASTEXITCODE -ne 0) {
    Write-Warn2 "o pareamento retornou codigo $LASTEXITCODE - pode ja estar pareado, seguindo"
} else {
    Write-Ok "pareado"
}

# ---------------------------------------------------------------- save record
Write-Step "Exportando o pairing record"
$tempFile = Join-Path $env:TEMP $PairingName
if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
& $python -m pymobiledevice3 lockdown save-pair-record $tempFile
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tempFile)) {
    Fail "Nao consegui exportar o pairing record."
}
$size = (Get-Item $tempFile).Length
if ($size -lt 500) {
    Fail "O pairing record saiu com $size bytes. Desbloqueie o iPhone, aceite 'Confiar' e rode de novo."
}
Write-Ok "pairing record: $size bytes"

# ---------------------------------------------------------------- push into app
Write-Step "Enviando o pairing para dentro do app 3105"
$pushed = $false
& $python -m pymobiledevice3 apps push $AppBundleId $tempFile $PairingName --documents
if ($LASTEXITCODE -eq 0) {
    $pushed = $true
    Write-Ok "arquivo entregue em On My iPhone/3105/$PairingName"
} else {
    Write-Warn2 "o envio automatico falhou (app 3105 instalado?)"
}

# ---------------------------------------------------------------- fallback
if (-not $pushed) {
    Write-Step "Plano B: codigo para colar no app"
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($tempFile))
    Write-Host "`n1. Copie o bloco abaixo inteiro" -ForegroundColor Yellow
    Write-Host "2. No 3105: Aim -> ROTA DE ACESSO -> Colar codigo -> Importar`n" -ForegroundColor Yellow
    Set-Clipboard -Value $b64
    Write-Host "   (o codigo ja foi copiado para a area de transferencia)" -ForegroundColor Green
    Write-Host "`n$b64`n"
}

# ---------------------------------------------------------------- done
Write-Host "`n=============================================="
if ($pushed) {
    Write-Host " PRONTO. Abra o 3105: o pairing ja aparece ativo." -ForegroundColor Green
} else {
    Write-Host " Cole o codigo no app e toque em Importar." -ForegroundColor Green
}
Write-Host " Depois: ligue o LocalDevVPN e toque em Testar." -ForegroundColor Green
Write-Host "=============================================="
Write-Host "`nPressione Enter para fechar..."
Read-Host | Out-Null
