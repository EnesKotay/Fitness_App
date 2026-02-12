# Backend baslatma: 8080 portunu kullanan eski islemi kapatir, sonra Quarkus dev modunu baslatir.
# Kullanim: .\run-backend.ps1   veya  PowerShell'de: & .\run-backend.ps1

$port = 8080
$connections = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($connections) {
    $pids = $connections.OwningProcess | Sort-Object -Unique
    foreach ($pid in $pids) {
        Write-Host "Port $port kullanan islem (PID $pid) kapatiliyor..."
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
}
Set-Location $PSScriptRoot
& .\mvnw.cmd quarkus:dev -DskipTests
