# Enhanced System Health Check Script
# Created for IT Support Learning Portfolio

Write-Host "=== COMPREHENSIVE SYSTEM HEALTH CHECK ===" -ForegroundColor Green
Write-Host "Generated on: $(Get-Date)" -ForegroundColor Gray
Write-Host "Location: IT-Scripts Folder" -ForegroundColor Gray
Write-Host ""

# 1. BASIC SYSTEM INFORMATION
Write-Host "--- BASIC SYSTEM INFORMATION ---" -ForegroundColor Cyan
Write-Host "Computer Name: " -NoNewline
Write-Host $env:COMPUTERNAME -ForegroundColor Yellow
Write-Host "Logged in User: " -NoNewline
Write-Host $env:USERNAME -ForegroundColor Yellow
Write-Host "OS Version: " -NoNewline
Write-Host (Get-WmiObject Win32_OperatingSystem).Caption -ForegroundColor Yellow
Write-Host "System Model: " -NoNewline
Write-Host (Get-WmiObject Win32_ComputerSystem).Model -ForegroundColor Yellow

# Uptime Calculation
$lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$uptime = (Get-Date) - $lastBoot
Write-Host "System Uptime: " -NoNewline
Write-Host "$($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes" -ForegroundColor Yellow

Write-Host ""

# 2. MEMORY USAGE STATISTICS
Write-Host "--- MEMORY USAGE ---" -ForegroundColor Cyan
$memory = Get-WmiObject Win32_OperatingSystem
$totalMemory = [math]::Round($memory.TotalVisibleMemorySize/1MB, 2)
$freeMemory = [math]::Round($memory.FreePhysicalMemory/1MB, 2)
$usedMemory = $totalMemory - $freeMemory
$memoryPercent = [math]::Round(($usedMemory/$totalMemory)*100, 2)

Write-Host "Total RAM: " -NoNewline
Write-Host "$totalMemory GB" -ForegroundColor Yellow
Write-Host "Used RAM: " -NoNewline
Write-Host "$usedMemory GB ($memoryPercent%)" -ForegroundColor $(if ($memoryPercent -gt 85) { "Red" } else { "Yellow" })
Write-Host "Available RAM: " -NoNewline
Write-Host "$freeMemory GB" -ForegroundColor Yellow

Write-Host ""

# 3. DISK SPACE ANALYSIS
Write-Host "--- DISK SPACE ANALYSIS ---" -ForegroundColor Cyan
$disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"

foreach ($disk in $disks) {
    $drive = $disk.DeviceID
    $freeSpace = [math]::Round($disk.FreeSpace/1GB, 2)
    $totalSpace = [math]::Round($disk.Size/1GB, 2)
    $usedSpace = $totalSpace - $freeSpace
    $percentFree = [math]::Round(($freeSpace/$totalSpace)*100, 2)
    
    # Color coding for warnings
    $spaceColor = if ($percentFree -lt 10) { "Red" } elseif ($percentFree -lt 20) { "Yellow" } else { "Green" }
    
    Write-Host "Drive $drive : " -NoNewline
    Write-Host "$usedSpace GB used, $freeSpace GB free ($percentFree% free)" -ForegroundColor $spaceColor
}

Write-Host ""

# 4. NETWORK ADAPTER INFORMATION
Write-Host "--- NETWORK ADAPTERS (Active) ---" -ForegroundColor Cyan
$networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }

if ($networkAdapters) {
    foreach ($adapter in $networkAdapters) {
        $ipAddress = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        
        Write-Host "Adapter: " -NoNewline
        Write-Host $adapter.Name -ForegroundColor Yellow
        Write-Host "  Status: " -NoNewline
        Write-Host $adapter.Status -ForegroundColor Green
        if ($ipAddress) {
            Write-Host "  IP Address: " -NoNewline
            Write-Host $($ipAddress.IPAddress) -ForegroundColor White
        }
        Write-Host "  Speed: " -NoNewline
        Write-Host "$($adapter.LinkSpeed)" -ForegroundColor White
    }
} else {
    Write-Host "No active network adapters found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== HEALTH CHECK COMPLETE ===" -ForegroundColor Green
Write-Host "Use this information for systematic troubleshooting" -ForegroundColor Cyan
Write-Host "Script location: IT-Scripts Folder" -ForegroundColor Gray