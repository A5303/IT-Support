# Enhanced System Health Check Script v2.0
# Features: Logging, Email Alerts, Remote Support, GUI
# Created for IT Support Professional Portfolio

param(
    [string]$ComputerName = $env:COMPUTERNAME,
    [switch]$GUI,
    [switch]$SendEmail,
    [string]$LogPath = "C:\IT-Scripts\Logs"
)

# 1. AUTOMATIC LOG FILE CREATION
$LogFolder = $LogPath
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = "$LogFolder\HealthCheck-$($ComputerName)-$Timestamp.log"

# Create log directory if it doesn't exist
if (!(Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $LogEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Type] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Host $Message -ForegroundColor $(switch($Type) { "WARNING" { "Yellow" } "ERROR" { "Red" } "SUCCESS" { "Green" } default { "White" } })
}

# Initialize log
Write-Log "=== SYSTEM HEALTH CHECK STARTED ===" "INFO"
Write-Log "Computer: $ComputerName" "INFO"
Write-Log "Generated on: $(Get-Date)" "INFO"

# Critical issues collection for email alerts
$CriticalIssues = @()

# 2. REMOTE COMPUTER SUPPORT
function Get-RemoteSystemInfo {
    param([string]$TargetComputer)
    
    try {
        if ($TargetComputer -ne $env:COMPUTERNAME) {
            Write-Log "Connecting to remote computer: $TargetComputer" "INFO"
            # Test connection first
            if (-not (Test-Connection -ComputerName $TargetComputer -Count 1 -Quiet)) {
                Write-Log "Cannot reach remote computer: $TargetComputer" "ERROR"
                return $null
            }
        }
        return $true
    }
    catch {
        Write-Log "Remote connection failed: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Test remote connectivity if different computer
if ($ComputerName -ne $env:COMPUTERNAME) {
    $RemoteAccess = Get-RemoteSystemInfo -TargetComputer $ComputerName
    if (-not $RemoteAccess) {
        Write-Log "Switching to local computer analysis" "WARNING"
        $ComputerName = $env:COMPUTERNAME
    }
}

# System Analysis Functions
function Get-SystemHealth {
    Write-Log "--- BASIC SYSTEM INFORMATION ---" "INFO"
    
    try {
        $OS = Get-WmiObject Win32_OperatingSystem -ComputerName $ComputerName
        $ComputerSystem = Get-WmiObject Win32_ComputerSystem -ComputerName $ComputerName
        
        Write-Log "Computer Name: $($env:COMPUTERNAME)" "INFO"
        Write-Log "Logged in User: $($env:USERNAME)" "INFO"
        Write-Log "OS Version: $($OS.Caption)" "INFO"
        Write-Log "System Model: $($ComputerSystem.Model)" "INFO"

        # Uptime
        $lastBoot = $OS.LastBootUpTime
        $uptime = (Get-Date) - $lastBoot
        $UptimeString = "$($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
        Write-Log "System Uptime: $UptimeString" "INFO"
        
        return $OS, $ComputerSystem, $UptimeString
    }
    catch {
        Write-Log "Failed to get system information: $($_.Exception.Message)" "ERROR"
        return $null, $null, "Unknown"
    }
}

function Get-MemoryAnalysis {
    Write-Log "--- MEMORY USAGE ---" "INFO"
    
    try {
        $memory = Get-WmiObject Win32_OperatingSystem -ComputerName $ComputerName
        $totalMemory = [math]::Round($memory.TotalVisibleMemorySize/1MB, 2)
        $freeMemory = [math]::Round($memory.FreePhysicalMemory/1MB, 2)
        $usedMemory = $totalMemory - $freeMemory
        $memoryPercent = [math]::Round(($usedMemory/$totalMemory)*100, 2)

        Write-Log "Total RAM: $totalMemory GB" "INFO"
        Write-Log "Used RAM: $usedMemory GB ($memoryPercent%)" "INFO"
        Write-Log "Available RAM: $freeMemory GB" "INFO"

        # Check for critical memory usage
        if ($memoryPercent -gt 85) {
            $CriticalIssues += "CRITICAL: Memory usage at $memoryPercent% - System may experience slowdowns"
            Write-Log "Memory usage critical: $memoryPercent%" "WARNING"
        }
        elseif ($memoryPercent -gt 70) {
            Write-Log "Memory usage high: $memoryPercent%" "WARNING"
        }
        
        return $totalMemory, $usedMemory, $freeMemory, $memoryPercent
    }
    catch {
        Write-Log "Failed to get memory information: $($_.Exception.Message)" "ERROR"
        return 0, 0, 0, 0
    }
}

function Get-DiskAnalysis {
    Write-Log "--- DISK SPACE ANALYSIS ---" "INFO"
    
    try {
        $disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" -ComputerName $ComputerName
        $DiskReport = @()

        foreach ($disk in $disks) {
            $drive = $disk.DeviceID
            $freeSpace = [math]::Round($disk.FreeSpace/1GB, 2)
            $totalSpace = [math]::Round($disk.Size/1GB, 2)
            $usedSpace = $totalSpace - $freeSpace
            $percentFree = [math]::Round(($freeSpace/$totalSpace)*100, 2)

            $status = "Drive $drive : $usedSpace GB used, $freeSpace GB free ($percentFree% free)"
            
            if ($percentFree -lt 10) {
                Write-Log "$status" "ERROR"
                $CriticalIssues += "CRITICAL: Drive $drive low on space - $percentFree% free"
            }
            elseif ($percentFree -lt 20) {
                Write-Log "$status" "WARNING"
            }
            else {
                Write-Log "$status" "INFO"
            }
            
            $DiskReport += @{
                Drive = $drive
                FreeSpace = $freeSpace
                TotalSpace = $totalSpace
                PercentFree = $percentFree
            }
        }
        
        return $DiskReport
    }
    catch {
        Write-Log "Failed to get disk information: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

function Get-NetworkAnalysis {
    Write-Log "--- NETWORK ADAPTERS (Active) ---" "INFO"
    
    try {
        $networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        $NetworkReport = @()

        if ($networkAdapters) {
            foreach ($adapter in $networkAdapters) {
                $ipAddress = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
                
                $adapterInfo = "Adapter: $($adapter.Name) | Status: $($adapter.Status)"
                if ($ipAddress) {
                    $adapterInfo += " | IP: $($ipAddress.IPAddress) | Speed: $($adapter.LinkSpeed)"
                }
                
                Write-Log $adapterInfo "INFO"
                
                # Check for APIPA address (169.254.x.x)
                if ($ipAddress -and $ipAddress.IPAddress -like "169.254.*") {
                    $CriticalIssues += "NETWORK: Adapter $($adapter.Name) has APIPA address - No DHCP server contact"
                    Write-Log "Adapter $($adapter.Name) has APIPA address - Network configuration issue" "WARNING"
                }
                
                $NetworkReport += @{
                    Name = $adapter.Name
                    Status = $adapter.Status
                    IPAddress = if ($ipAddress) { $ipAddress.IPAddress } else { "No IP" }
                    Speed = $adapter.LinkSpeed
                }
            }
        } else {
            Write-Log "No active network adapters found" "WARNING"
        }
        
        return $NetworkReport
    }
    catch {
        Write-Log "Failed to get network information: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

# 3. EMAIL ALERTS FOR CRITICAL ISSUES
function Send-HealthAlert {
    param([array]$Issues, [string]$Computer)
    
    if ($Issues.Count -eq 0) {
        Write-Log "No critical issues found - Email alert not sent" "INFO"
        return
    }
    
    $EmailBody = @"
SYSTEM HEALTH ALERT - $Computer

Critical Issues Found:
$($Issues -join "`n")

Report Time: $(Get-Date)
Log File: $LogFile

Please review the system immediately.

-- Automated Health Check System
"@

    Write-Log "Preparing email alert for $($Issues.Count) critical issues" "WARNING"
    
    # Email configuration - UPDATE THESE WITH YOUR SETTINGS
    $EmailParams = @{
        From = "healthcheck@yourcompany.com"
        To = "admin@yourcompany.com"
        Subject = "SYSTEM ALERT: Critical Issues on $Computer"
        Body = $EmailBody
        SmtpServer = "smtp.yourcompany.com"
        Port = 587
        Credential = (Get-Credential -Message "Enter SMTP credentials" -UserName "healthcheck@yourcompany.com")
    }
    
    try {
        if ($SendEmail) {
            Send-MailMessage @EmailParams -UseSsl
            Write-Log "Email alert sent successfully" "SUCCESS"
        } else {
            Write-Log "Email alert prepared but not sent (use -SendEmail to enable)" "INFO"
            Write-Log "Email would be sent to: $($EmailParams.To)" "INFO"
        }
    }
    catch {
        Write-Log "Failed to send email: $($_.Exception.Message)" "ERROR"
    }
}

# 4. GRAPHICAL INTERFACE
function Show-GraphicalInterface {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "System Health Check"
    $Form.Size = New-Object System.Drawing.Size(600, 500)
    $Form.StartPosition = "CenterScreen"

    # Results TextBox
    $TextBox = New-Object System.Windows.Forms.TextBox
    $TextBox.Location = New-Object System.Drawing.Point(10, 10)
    $TextBox.Size = New-Object System.Drawing.Size(565, 400)
    $TextBox.Multiline = $true
    $TextBox.ScrollBars = "Vertical"
    $TextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $Form.Controls.Add($TextBox)

    # Run Button
    $RunButton = New-Object System.Windows.Forms.Button
    $RunButton.Location = New-Object System.Drawing.Point(10, 420)
    $RunButton.Size = New-Object System.Drawing.Size(100, 30)
    $RunButton.Text = "Run Health Check"
    $RunButton.Add_Click({
        $TextBox.Text = "Running health check...`r`n"
        
        # Run all checks
        $OS, $ComputerSystem, $Uptime = Get-SystemHealth
        $TotalMem, $UsedMem, $FreeMem, $MemPercent = Get-MemoryAnalysis
        $Disks = Get-DiskAnalysis
        $Network = Get-NetworkAnalysis
        
        # Display results
        $Results = @"
=== SYSTEM HEALTH CHECK RESULTS ===
Computer: $ComputerName
Time: $(Get-Date)

SYSTEM INFORMATION:
- OS: $($OS.Caption)
- Model: $($ComputerSystem.Model)  
- Uptime: $Uptime

MEMORY:
- Total: $TotalMem GB
- Used: $UsedMem GB ($MemPercent%)
- Available: $FreeMem GB

DISK SPACE:
$($Disks | ForEach-Object { "- Drive $($_.Drive): $($_.PercentFree)% free ($($_.FreeSpace) GB)" } -join "`r`n")

NETWORK:
$($Network | ForEach-Object { "- $($_.Name): $($_.IPAddress) ($($_.Status))" } -join "`r`n")

CRITICAL ISSUES: $($CriticalIssues.Count)
$($CriticalIssues -join "`r`n")

Log File: $LogFile
"@
        $TextBox.Text = $Results
    })
    $Form.Controls.Add($RunButton)

    # Exit Button
    $ExitButton = New-Object System.Windows.Forms.Button
    $ExitButton.Location = New-Object System.Drawing.Point(120, 420)
    $ExitButton.Size = New-Object System.Drawing.Size(100, 30)
    $ExitButton.Text = "Exit"
    $ExitButton.Add_Click({ $Form.Close() })
    $Form.Controls.Add($ExitButton)

    $Form.ShowDialog() | Out-Null
}

# MAIN EXECUTION
Write-Log "Starting comprehensive health check..." "INFO"

# Run all health checks
$OS, $ComputerSystem, $Uptime = Get-SystemHealth
$TotalMem, $UsedMem, $FreeMem, $MemPercent = Get-MemoryAnalysis
$Disks = Get-DiskAnalysis
$Network = Get-NetworkAnalysis

# Show GUI or console output
if ($GUI) {
    Write-Log "Launching graphical interface..." "INFO"
    Show-GraphicalInterface
} else {
    # Console output
    Write-Host "`n=== HEALTH CHECK COMPLETE ===" -ForegroundColor Green
    Write-Host "Critical Issues Found: $($CriticalIssues.Count)" -ForegroundColor $(if ($CriticalIssues.Count -gt 0) { "Red" } else { "Green" })
    Write-Host "Log File: $LogFile" -ForegroundColor Cyan
    
    if ($CriticalIssues.Count -gt 0) {
        Write-Host "`nCRITICAL ISSUES:" -ForegroundColor Red
        $CriticalIssues | ForEach-Object { Write-Host "  • $_" -ForegroundColor Red }
    }
}

# Send email alerts if requested or if critical issues found
if ($SendEmail -or $CriticalIssues.Count -gt 0) {
    Send-HealthAlert -Issues $CriticalIssues -Computer $ComputerName
}

Write-Log "=== SYSTEM HEALTH CHECK COMPLETED ===" "SUCCESS"
Write-Log "Log file saved: $LogFile" "INFO"