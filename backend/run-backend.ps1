# Backend baslatma: 8080 portunu kullanan eski islemi kapatir, sonra Quarkus dev modunu baslatir.
# Kullanim: .\run-backend.ps1   veya  PowerShell'de: & .\run-backend.ps1

$port = 8080
$connections = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($connections) {
    $procIds = $connections.OwningProcess | Sort-Object -Unique
    foreach ($procId in $procIds) {
        Write-Host "Port $port kullanan islem (PID $procId) kapatiliyor..."
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
}

Set-Location $PSScriptRoot

# GEMINI_API_KEY istege bagli; tanimli degilse AI (coach/beslenme) istekleri 503 doner.
& .\mvnw.cmd quarkus:dev -DskipTests
