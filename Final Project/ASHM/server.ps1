Add-Type -AssemblyName System.Web

$port = 8000
$prefix = "http://localhost:$port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)

# ==========================================
# EMAIL CONFIGURATION (SET YOUR GMAIL HERE)
# ==========================================
$script:SenderGmail = "" # <-- SET YOUR GMAIL ADDRESS HERE
$script:SenderGmailPassword = ""  # <-- SET YOUR APP PASSWORD HERE

$script:EmailConfig = @{
    RecipientEmail = ""
    EnableCPU      = $true
    EnableRAM      = $true
    EnableDisk     = $true
}

$script:Thresholds = @{
    CPU  = 85
    RAM  = 85
    Disk = 90
}

$script:LastAlertTime = @{}
$script:AlertCooldown = 300

try {
    $listener.Start()
    Write-Host "ASHM Server Running at $prefix" -ForegroundColor Green
}
catch {
    Write-Error "Failed to start: $_"
    Read-Host "Press Enter"
    exit 1
}

$script:dataCache = $null
$script:cacheTime = [DateTime]::MinValue
$script:cacheDuration = 1.5

function Get-Safe {
    param($v, $default = "N/A")
    if ($null -ne $v -and $v -ne "") { return $v } else { return $default }
}

function Send-EmailAlert {
    param($AlertType, $Message)
    
    if ([string]::IsNullOrEmpty($script:EmailConfig.RecipientEmail)) {
        Write-Host "No recipient email configured" -ForegroundColor Yellow
        return
    }
    
    $enabledAlerts = @($script:EmailConfig.EnableCPU, $script:EmailConfig.EnableRAM, $script:EmailConfig.EnableDisk)
    if (-not ($enabledAlerts -contains $true)) {
        Write-Host "All alerts disabled" -ForegroundColor Yellow
        return
    }
    
    if ($AlertType -eq "CPU" -and -not $script:EmailConfig.EnableCPU) { return }
    if ($AlertType -eq "RAM" -and -not $script:EmailConfig.EnableRAM) { return }
    if ($AlertType -eq "Disk" -and -not $script:EmailConfig.EnableDisk) { return }
    
    $now = Get-Date
    $alertKey = "$AlertType-Alert"
    if ($script:LastAlertTime.ContainsKey($alertKey)) {
        $timeSinceLastAlert = ($now - $script:LastAlertTime[$alertKey]).TotalSeconds
        if ($timeSinceLastAlert -lt $script:AlertCooldown) {
            return
        }
    }
    
    try {
        $SecurePassword = ConvertTo-SecureString $script:SenderGmailPassword -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential($script:SenderGmail, $SecurePassword)
        
        # Determine alert color and icon
        $alertColor = switch ($AlertType) {
            "CPU" { "#ef4444" }
            "RAM" { "#f59e0b" }
            "Disk" { "#eab308" }
            default { "#dc2626" }
        }
        
        $alertIcon = switch ($AlertType) {
            "CPU" { "" }
            "RAM" { "" }
            "Disk" { "" }
            default { "" }
        }
        
        $timestamp = Get-Date -Format 'MMMM dd, yyyy - HH:mm:ss'
        $computerName = $env:COMPUTERNAME
        $userName = $env:USERNAME
        
        # Get current system stats for context
        $stats = Get-CachedStats
        $cpuCurrent = $stats.cpu.usage
        $ramCurrent = $stats.ram.usage
        $diskCurrent = if ($stats.disks.Count -gt 0) { 
            ($stats.disks | Measure-Object -Property UsagePercent -Average).Average 
        }
        else { 0 }
        
        $htmlBody = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background-color: #f3f4f6;
        }
        .email-container {
            max-width: 600px;
            margin: 0 auto;
            background-color: #ffffff;
        }
        .header {
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
            padding: 40px 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            color: #ffffff;
            font-size: 28px;
            font-weight: 700;
        }
        .header p {
            margin: 10px 0 0 0;
            color: #94a3b8;
            font-size: 14px;
        }
        .alert-badge {
            background-color: $alertColor;
            color: #ffffff;
            padding: 30px;
            text-align: center;
            border-bottom: 4px solid rgba(0,0,0,0.1);
        }
        .alert-icon {
            font-size: 48px;
            margin-bottom: 10px;
        }
        .alert-title {
            margin: 0;
            font-size: 24px;
            font-weight: 700;
            color: #ffffff;
        }
        .alert-subtitle {
            margin: 5px 0 0 0;
            font-size: 14px;
            color: rgba(255,255,255,0.9);
        }
        .content {
            padding: 30px;
        }
        .info-box {
            background-color: #f8fafc;
            border-left: 4px solid $alertColor;
            padding: 20px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .info-box p {
            margin: 8px 0;
            color: #334155;
            font-size: 14px;
            line-height: 1.6;
        }
        .info-box strong {
            color: #0f172a;
            font-weight: 600;
        }
        .stats-grid {
            display: table;
            width: 100%;
            margin: 20px 0;
            border-collapse: collapse;
        }
        .stat-row {
            display: table-row;
        }
        .stat-cell {
            display: table-cell;
            padding: 15px;
            background-color: #f1f5f9;
            border: 1px solid #e2e8f0;
            text-align: center;
        }
        .stat-label {
            display: block;
            font-size: 12px;
            color: #64748b;
            text-transform: uppercase;
            font-weight: 600;
            margin-bottom: 5px;
        }
        .stat-value {
            display: block;
            font-size: 24px;
            color: #0f172a;
            font-weight: 700;
        }
        .message-box {
            background-color: #fef3c7;
            border: 1px solid #fbbf24;
            border-radius: 6px;
            padding: 15px;
            margin: 20px 0;
        }
        .message-box p {
            margin: 0;
            color: #92400e;
            font-size: 14px;
            line-height: 1.5;
        }
        .footer {
            background-color: #f8fafc;
            padding: 25px 30px;
            text-align: center;
            border-top: 1px solid #e2e8f0;
        }
        .footer p {
            margin: 5px 0;
            color: #64748b;
            font-size: 12px;
        }
        .divider {
            height: 1px;
            background-color: #e2e8f0;
            margin: 25px 0;
        }
        .btn {
            display: inline-block;
            padding: 12px 24px;
            background-color: $alertColor;
            color: #ffffff;
            text-decoration: none;
            border-radius: 6px;
            font-weight: 600;
            font-size: 14px;
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <div class="email-container">
        <!-- Header -->
        <div class="header">
            <h1>ASHM System Monitor</h1>
            <p>Automated System Health Monitor</p>
        </div>
        
        <!-- Alert Badge -->
        <div class="alert-badge">
            <div class="alert-icon">$alertIcon</div>
            <h2 class="alert-title">$AlertType Threshold Exceeded</h2>
            <p class="alert-subtitle">Critical Alert Triggered</p>
        </div>
        
        <!-- Content -->
        <div class="content">
            <h2 style="margin: 0 0 15px 0; color: #0f172a; font-size: 20px;">Alert Details</h2>
            
            <div class="info-box">
                <p><strong>Computer:</strong> $computerName</p>
                <p><strong>User:</strong> $userName</p>
                <p><strong>Time:</strong> $timestamp</p>
                <p><strong>Alert Type:</strong> $AlertType Usage Critical</p>
            </div>
            
            <div class="divider"></div>
            
            <h3 style="margin: 0 0 15px 0; color: #0f172a; font-size: 18px;">Current System Status</h3>
            
            <table class="stats-grid">
                <tr class="stat-row">
                    <td class="stat-cell">
                        <span class="stat-label">CPU Usage</span>
                        <span class="stat-value" style="color: $(if($cpuCurrent -ge 85){'#ef4444'}else{'#10b981'});">$([math]::Round($cpuCurrent, 1))%</span>
                    </td>
                    <td class="stat-cell">
                        <span class="stat-label">RAM Usage</span>
                        <span class="stat-value" style="color: $(if($ramCurrent -ge 85){'#ef4444'}else{'#10b981'});">$([math]::Round($ramCurrent, 1))%</span>
                    </td>
                    <td class="stat-cell">
                        <span class="stat-label">Disk Usage</span>
                        <span class="stat-value" style="color: $(if($diskCurrent -ge 90){'#ef4444'}else{'#10b981'});">$([math]::Round($diskCurrent, 1))%</span>
                    </td>
                </tr>
            </table>
            
            <div class="divider"></div>
            
            <h3 style="margin: 0 0 15px 0; color: #0f172a; font-size: 18px;">Issue Description</h3>
            
            <div class="info-box">
                <p>$Message</p>
            </div>
            
            <div class="message-box">
                <p><strong>Note:</strong> This alert will not repeat for the next 5 minutes to prevent notification spam. If the issue persists, you will receive another alert after the cooldown period.</p>
            </div>
            
            <div style="text-align: center; margin-top: 30px;">
                <p style="color: #64748b; font-size: 14px; margin-bottom: 10px;">Take immediate action to resolve this issue</p>
            </div>
        </div>
        
        <!-- Footer -->
        <div class="footer">
            <p><strong>Automated System Health Monitor (ASHM)</strong></p>
            <p>This is an automated alert from your system monitoring service.</p>
            <p style="margin-top: 15px; color: #94a3b8;">Generated automatically / Do not reply to this email</p>
        </div>
    </div>
</body>
</html>
"@
        
        $mailParams = @{
            SmtpServer = "smtp.gmail.com"
            Port       = 587
            From       = $script:SenderGmail
            To         = $script:EmailConfig.RecipientEmail
            Subject    = "ASHM ALERT: $AlertType Threshold Exceeded on $computerName"
            Body       = $htmlBody
            BodyAsHtml = $true
            Credential = $Credential
            UseSsl     = $true
        }
        
        Send-MailMessage @mailParams
        $script:LastAlertTime[$alertKey] = $now
        Write-Host "Email alert sent: $AlertType to $($script:EmailConfig.RecipientEmail)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to send email: $_" -ForegroundColor Red
    }
}

function Get-CachedStats {
    $now = Get-Date
    if ($script:dataCache -and ($now - $script:cacheTime).TotalSeconds -lt $script:cacheDuration) {
        return $script:dataCache
    }
    
    $script:dataCache = Get-SystemStats
    $script:cacheTime = $now
    return $script:dataCache
}

function Get-SystemStats {
    try {
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        
        $perfCPU = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop
        $perfRAM = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -ErrorAction Stop
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        
        $cpuUsage = [math]::Round($perfCPU.PercentProcessorTime, 2)
        
        $totalRAM = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        $availableRAM = [math]::Round($perfRAM.AvailableMBytes / 1024, 2)
        $usedRAM = [math]::Round($totalRAM - $availableRAM, 2)
        $ramUsage = if ($totalRAM -gt 0) { [math]::Round(($usedRAM / $totalRAM) * 100, 2) } else { 0 }
        
        $volumes = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
        $disks = @()
        $maxDiskUsage = 0
        foreach ($vol in $volumes) {
            $size = if ($vol.Size) { [math]::Round($vol.Size / 1GB, 2) } else { 0 }
            $free = if ($vol.FreeSpace) { [math]::Round($vol.FreeSpace / 1GB, 2) } else { 0 }
            $used = [math]::Round($size - $free, 2)
            $usage = if ($size -gt 0) { [math]::Round(($used / $size) * 100, 2) } else { 0 }
            
            if ($usage -gt $maxDiskUsage) { $maxDiskUsage = $usage }
            
            $disks += @{
                Drive        = $vol.DeviceID
                Size         = $size
                Used         = $used
                Free         = $free
                UsagePercent = $usage
                Status       = if ($usage -ge 90) { "CRITICAL" } elseif ($usage -ge 75) { "WARNING" } else { "HEALTHY" }
            }
        }
        
        $processes = Get-Process -ErrorAction Stop | 
        Sort-Object CPU -Descending | 
        Select-Object -First 10 |
        ForEach-Object {
            @{
                Name     = $_.ProcessName
                PID      = $_.Id
                CPU      = [math]::Round((Get-Safe $_.CPU 0), 2)
                MemoryMB = [math]::Round($_.WorkingSet64 / 1MB, 2)
            }
        }
        
        $overallStatus = "HEALTHY"
        $alerts = @()
        
        if ($cpuUsage -ge $script:Thresholds.CPU) {
            $overallStatus = "CRITICAL"
            $alerts += "CPU Critical: $cpuUsage%"
            Send-EmailAlert "CPU" "CPU usage has reached $cpuUsage%, exceeding the threshold of $($script:Thresholds.CPU)%"
        }
        elseif ($cpuUsage -ge 75) {
            if ($overallStatus -eq "HEALTHY") { $overallStatus = "WARNING" }
            $alerts += "CPU High: $cpuUsage%"
        }
        
        if ($ramUsage -ge $script:Thresholds.RAM) {
            $overallStatus = "CRITICAL"
            $alerts += "RAM Critical: $ramUsage%"
            Send-EmailAlert "RAM" "RAM usage has reached $ramUsage% ($usedRAM GB / $totalRAM GB), exceeding the threshold of $($script:Thresholds.RAM)%"
        }
        elseif ($ramUsage -ge 75) {
            if ($overallStatus -eq "HEALTHY") { $overallStatus = "WARNING" }
            $alerts += "RAM High: $ramUsage%"
        }
        
        if ($maxDiskUsage -ge $script:Thresholds.Disk) {
            $overallStatus = "CRITICAL"
            $alerts += "Disk Critical: $maxDiskUsage%"
            Send-EmailAlert "Disk" "Disk usage has reached $maxDiskUsage%, exceeding the threshold of $($script:Thresholds.Disk)%"
        }
        
        if ($alerts.Count -eq 0) { $alerts += "All systems operational" }
        
        return @{
            timestamp = $timestamp
            status    = $overallStatus
            alerts    = $alerts
            cpu       = @{ usage = $cpuUsage }
            ram       = @{
                total     = $totalRAM
                used      = $usedRAM
                available = $availableRAM
                usage     = $ramUsage
            }
            disks     = $disks
            processes = $processes
        }
    }
    catch {
        return @{
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            status    = "ERROR"
            alerts    = @("Failed to collect data")
            cpu       = @{ usage = 0 }
            ram       = @{ total = 0; used = 0; available = 0; usage = 0 }
            disks     = @()
            processes = @()
        }
    }
}

function Get-BatteryInfo {
    try {
        $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop | Select-Object -First 1
        
        if ($battery) {
            $designCapacity = $battery.DesignCapacity
            $fullChargeCapacity = $battery.FullChargeCapacity
            $currentCharge = $battery.EstimatedChargeRemaining
            
            if ($designCapacity -gt 0 -and $fullChargeCapacity -gt 0) {
                $health = [math]::Round(($fullChargeCapacity / $designCapacity) * 100, 2)
                
                return @{
                    present            = $true
                    designCapacity     = $designCapacity
                    fullChargeCapacity = $fullChargeCapacity
                    currentCharge      = $currentCharge
                    health             = $health
                    status             = $battery.Status
                    chemistry          = $battery.Chemistry
                }
            }
        }
        
        $portableBattery = Get-CimInstance -Namespace root/wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue
        $batteryStatus = Get-CimInstance -Namespace root/wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue
        
        if ($portableBattery -and $batteryStatus) {
            $design = $portableBattery.DesignedCapacity
            $full = $batteryStatus.FullChargedCapacity
            
            if ($design -gt 0 -and $full -gt 0) {
                $health = [math]::Round(($full / $design) * 100, 2)
                
                return @{
                    present            = $true
                    designCapacity     = $design
                    fullChargeCapacity = $full
                    currentCharge      = 0
                    health             = $health
                    status             = "Unknown"
                    chemistry          = "Unknown"
                }
            }
        }
        
        return @{ present = $false; message = "No battery detected or desktop PC" }
    }
    catch {
        return @{ present = $false; message = "Battery information unavailable" }
    }
}

function Get-FullSystemInfo {
    $ci = Get-ComputerInfo -ErrorAction SilentlyContinue
    $processor = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
    $video = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
    $network = Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | 
    Where-Object { $_.IPAddress -ne $null } | Select-Object -First 1
    $physicalmem = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
    
    $ramModules = @()
    foreach ($mem in $physicalmem) {
        $ramModules += @{
            Slot         = Get-Safe $mem.DeviceLocator
            Capacity     = [math]::Round($mem.Capacity / 1GB, 2)
            Speed        = Get-Safe $mem.Speed
            Manufacturer = Get-Safe $mem.Manufacturer
            PartNumber   = Get-Safe $mem.PartNumber
        }
    }
    
    $bootTime = Get-Safe $ci.OsLastBootUpTime
    $uptime = "N/A"
    if ($bootTime -ne "N/A") {
        try {
            $span = (Get-Date) - $bootTime
            $uptime = "$($span.Days)d $($span.Hours)h $($span.Minutes)m"
        }
        catch { }
    }
    
    return @{
        system     = @{
            manufacturer     = Get-Safe $ci.CsManufacturer
            model            = Get-Safe $ci.CsModel
            os               = Get-Safe $ci.OsName
            version          = Get-Safe $ci.OsVersion
            build            = Get-Safe $ci.OsBuildNumber
            biosManufacturer = Get-Safe $bios.Manufacturer
            biosSerial       = Get-Safe $bios.SerialNumber
            uptime           = $uptime
        }
        cpu        = @{
            name    = Get-Safe $processor.Name
            cores   = Get-Safe $processor.NumberOfCores
            threads = Get-Safe $processor.NumberOfLogicalProcessors
        }
        display    = @{
            gpu        = Get-Safe $video.Name
            vram       = [math]::Round((Get-Safe $video.AdapterRAM 0) / 1MB, 2)
            resolution = "$(Get-Safe $video.CurrentHorizontalResolution) x $(Get-Safe $video.CurrentVerticalResolution)"
        }
        network    = @{
            adapter = Get-Safe $network.Description
            ip      = if ($network -and $network.IPAddress) { $network.IPAddress[0] } else { "N/A" }
            mac     = Get-Safe $network.MACAddress
        }
        ramModules = $ramModules
    }
}

function Send-Response {
    param($response, $content, $contentType = "application/json", $statusCode = 200)
    
    try {
        $response.StatusCode = $statusCode
        $response.ContentType = "$contentType; charset=utf-8"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    catch {
        Write-Host "Response error: $_" -ForegroundColor Red
    }
    finally {
        try { $response.OutputStream.Close() } catch { }
        try { $response.Close() } catch { }
    }
}

function Serve-File {
    param($fileName)
    $filePath = Join-Path $PSScriptRoot $fileName
    if (Test-Path $filePath) {
        return Get-Content $filePath -Raw -Encoding UTF8
    }
    return $null
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $response.Headers.Add("Access-Control-Allow-Origin", "*")
        
        if ($request.HttpMethod -eq "OPTIONS") {
            Send-Response $response "" "text/plain" 204
            continue
        }
        
        $path = $request.Url.AbsolutePath
        
        switch -Regex ($path) {
            '^/$' {
                $html = Serve-File "index.html"
                if ($html) { Send-Response $response $html "text/html" }
                else { Send-Response $response "404 Not Found" "text/plain" 404 }
            }
            '^/api/quick-stats$' {
                $data = Get-CachedStats
                $json = $data | ConvertTo-Json -Depth 5 -Compress
                Send-Response $response $json
            }
            '^/api/full-info$' {
                $data = Get-FullSystemInfo
                $json = $data | ConvertTo-Json -Depth 5 -Compress
                Send-Response $response $json
            }
            '^/api/battery-info$' {
                $data = Get-BatteryInfo
                $json = $data | ConvertTo-Json -Depth 3 -Compress
                Send-Response $response $json
            }
            '^/api/email-config$' {
                if ($request.HttpMethod -eq "GET") {
                    $config = @{
                        recipientEmail = $script:EmailConfig.RecipientEmail
                        enableCPU      = $script:EmailConfig.EnableCPU
                        enableRAM      = $script:EmailConfig.EnableRAM
                        enableDisk     = $script:EmailConfig.EnableDisk
                        cpuThreshold   = $script:Thresholds.CPU
                        ramThreshold   = $script:Thresholds.RAM
                        diskThreshold  = $script:Thresholds.Disk
                    }
                    Send-Response $response ($config | ConvertTo-Json)
                }
                elseif ($request.HttpMethod -eq "POST") {
                    $reader = New-Object System.IO.StreamReader($request.InputStream)
                    $body = $reader.ReadToEnd()
                    $config = $body | ConvertFrom-Json
                    
                    $script:EmailConfig.RecipientEmail = $config.recipientEmail
                    $script:EmailConfig.EnableCPU = $config.enableCPU
                    $script:EmailConfig.EnableRAM = $config.enableRAM
                    $script:EmailConfig.EnableDisk = $config.enableDisk
                    $script:Thresholds.CPU = $config.cpuThreshold
                    $script:Thresholds.RAM = $config.ramThreshold
                    $script:Thresholds.Disk = $config.diskThreshold
                    
                    Send-Response $response (@{success = $true; message = "Configuration saved" } | ConvertTo-Json)
                }
            }
            '^/live$' {
                $html = Serve-File "live_monitor.html"
                if ($html) { Send-Response $response $html "text/html" }
            }
            '^/processes$' {
                $html = Serve-File "processes.html"
                if ($html) { Send-Response $response $html "text/html" }
            }
            '^/services$' {
                $html = Serve-File "services.html"
                if ($html) { Send-Response $response $html "text/html" }
            }
            '^/hardware$' {
                $html = Serve-File "hardware.html"
                if ($html) { Send-Response $response $html "text/html" }
            }
            '^/battery$' {
                $html = Serve-File "battery.html"
                if ($html) { Send-Response $response $html "text/html" }
            }
            '^/settings$' {
                $html = Serve-File "settings.html"
                if ($html) { Send-Response $response $html "text/html" }
            }
            '^/api/services$' {
                $services = Get-Service -ErrorAction SilentlyContinue | 
                Where-Object { $_.Status -ne 'Running' } |
                Select-Object -First 30 |
                ForEach-Object {
                    @{
                        Name        = $_.Name
                        DisplayName = $_.DisplayName
                        Status      = $_.Status.ToString()
                        StartType   = $_.StartType.ToString()
                    }
                }
                $json = @{ services = $services } | ConvertTo-Json -Depth 3 -Compress
                Send-Response $response $json
            }
            '^/generate-report$' {
                Start-Job -ScriptBlock {
                    & "$using:PSScriptRoot\generate_report.ps1"
                } | Out-Null
                $msg = @{ success = $true; message = "Report generation started" } | ConvertTo-Json
                Send-Response $response $msg
            }
            default {
                Send-Response $response "404 - Not Found" "text/plain" 404
            }
        }
    }
    catch {
        Write-Host "Request error: $_" -ForegroundColor Red
    }
}