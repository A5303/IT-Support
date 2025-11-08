Simple System Health Check Script
Shows basic system information for troubleshooting

Write-Host "=== System Health Check ===" -ForegroundColor Green

Computer Name
Write-Host "Computer Name: " -NoNewline
Write-Host $env:COMPUTERNAME -ForegroundColor Yellow

OS Information
Write-Host "OS Version: " -NoNewline
Write-Host (Get-WmiObject Win32_OperatingSystem).Caption -ForegroundColor Yellow

Uptime
$lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$uptime = (Get-Date) - $lastBoot
Write-Host "System Uptime: " -NoNewline
Write-Host "$($uptime.Days) days, $($uptime.Hours) hours" -ForegroundColor Yellow

Write-Host "`nBasic system check complete!" -ForegroundColor Green
Write-Host "Use this for initial troubleshooting of performance issues." -ForegroundColor Cyan
