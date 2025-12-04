# server.ps1 - ASHM Live API Server
# Run: powershell -ExecutionPolicy Bypass -File .\server.ps1
# Requires: Windows PowerShell (5.1) or PowerShell 7+. No external modules.

Add-Type -AssemblyName System.Web

$prefix = "http://localhost:8000/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
try {
    $listener.Start()
} catch {
    Write-Error "Failed to start HTTP listener. Are you running as a user that can listen on this port? $_"
    exit 1
}
Write-Host "ASHM Live API running at $prefix (endpoint: ${prefix}stats)"

# Helper: safe extraction
function Get-Safe {
    param($v, $default = $null)
    if ($null -ne $v) { return $v } else { return $default }
}

function Collect-FullStats {
    try {
        # Timestamp
        $ts = (Get-Date).ToString("s")

        # System / BIOS / OS
        $ci = Get-ComputerInfo -ErrorAction SilentlyContinue
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
        $sys = @{
            OSName = Get-Safe $ci.OsName "Unknown"
            OSVersion = Get-Safe $ci.OsVersion "Unknown"
            SystemManufacturer = Get-Safe $ci.CsManufacturer "Unknown"
            SystemModel = Get-Safe $ci.CsModel "Unknown"
            BIOSManufacturer = Get-Safe $bios.Manufacturer "Unknown"
            BIOSSerial = Get-Safe $bios.SerialNumber "Unknown"
        }

        # Uptime
        try {
            $boot = Get-Safe $ci.LastBootUpTime $null
            if ($boot) {
                $uptimeSpan = (Get-Date) - (Get-Date $boot)
                $uptime = "{0}d {1}h {2}m" -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes
            } else {
                $uptime = "N/A"
            }
        } catch { $uptime = "N/A" }
        $sys.Uptime = $uptime

        # CPU
        $proc = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq "_Total" } | Select-Object -First 1
        $cpuPercent = [math]::Round((Get-Safe $proc.PercentProcessorTime 0),2)
        $cpuObj = @{
            UsagePercent = $cpuPercent
        }

        # RAM
        $perfMem = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Memory -ErrorAction SilentlyContinue | Select-Object -First 1
        $availableMB = [double](Get-Safe $perfMem.AvailableMBytes 0)
        # total RAM from Win32_ComputerSystem
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue | Select-Object -First 1
        $totalMB = 0
        if ($cs -and $cs.TotalPhysicalMemory) {
            $totalMB = [math]::Round(($cs.TotalPhysicalMemory / 1MB),2)
        }
        $usedMB = [math]::Round(($totalMB - $availableMB),2)
        $ramPercent = if ($totalMB -gt 0) { [math]::Round(($usedMB / $totalMB) * 100, 2) } else { 0 }
        $ramObj = @{
            TotalMB = $totalMB
            UsedMB = $usedMB
            FreeMB = $availableMB
            UsagePercent = $ramPercent
        }

        # Disks (logical)
        $vols = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 3 }
        $diskList = @()
        foreach ($v in $vols) {
            $sizeGB = if ($v.Size) { [math]::Round(($v.Size / 1GB),2) } else { 0 }
            $freeGB = if ($v.FreeSpace) { [math]::Round(($v.FreeSpace / 1GB),2) } else { 0 }
            $usedGB = [math]::Round(($sizeGB - $freeGB),2)
            $usagePercent = if ($sizeGB -gt 0) {[math]::Round(($usedGB / $sizeGB) * 100,2)} else {0}
            $diskList += @{
                DeviceID = $v.DeviceID
                SizeGB = $sizeGB
                FreeGB = $freeGB
                UsedGB = $usedGB
                UsagePercent = $usagePercent
            }
        }

        # Top processes (CPU descending)
        $procs = Get-Process -ErrorAction SilentlyContinue | Sort-Object CPU -Descending | Select-Object -First 10
        $procList = @()
        foreach ($p in $procs) {
            $procList += @{
                Name = $p.ProcessName
                Id = $p.Id
                CPU = [math]::Round((Get-Safe $p.CPU 0),2)
                WorkingSetMB = [math]::Round((Get-Safe $p.WorkingSet64 0)/1MB,2)
            }
        }

        # Services: non-auto or problematic
        $serviceSet = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.StartType -ne 'Automatic' } | Select-Object -First 100
        $svcList = @()
        foreach ($s in $serviceSet) {
            $svcList += @{
                Name = $s.Name
                DisplayName = $s.DisplayName
                Status = $s.Status
                StartType = $s.StartType
            }
        }

        # Hotfixes (recent 5 valid)
        try {
            $hotfixes = Get-HotFix -ErrorAction SilentlyContinue |
                Where-Object { $_.InstalledOn -ne $null } |                # skip null dates
                Sort-Object InstalledOn -Descending |                     # sort newest first
                Select-Object -First 5 |
                ForEach-Object { 
                    @{
                        KB = $_.HotFixID
                        InstalledOn = $_.InstalledOn.ToString("yyyy-MM-dd")
                    }
                }
        } catch {
            $hotfixes = @()
        }

        # Paging file info
        $paging = Get-CimInstance -ClassName Win32_PageFile -ErrorAction SilentlyContinue
        $pageList = @()
        if ($paging) {
            foreach ($p in $paging) {
                $pageList += @{
                    Name = $p.Name
                    InitialSizeMB = $p.InitialSize
                    MaxSizeMB = $p.MaximumSize
                }
            }
        }

        # Battery (attempt via powercfg)
        $battery = @{
            Present = $false
            DesignCapacity = $null
            FullCharge = $null
            HealthPct = $null
        }
        try {
            $tempFile = Join-Path $env:TEMP "battery-report-temp.html"
            Start-Process -FilePath powercfg -ArgumentList "/batteryreport /output `"$tempFile`" /duration 1" -Wait -NoNewWindow -ErrorAction SilentlyContinue
            if (Test-Path $tempFile) {
                $content = Get-Content $tempFile -Raw -ErrorAction SilentlyContinue
                if ($content -match 'Design Capacity</td>\s*<td[^>]*>([\d,]+) mWh') {
                    $d = $matches[1] -replace '[^\d]'
                    $battery.Present = $true
                    $battery.DesignCapacity = [int]$d
                }
                if ($content -match 'Full Charge Capacity</td>\s*<td[^>]*>([\d,]+) mWh') {
                    $f = $matches[1] -replace '[^\d]'
                    $battery.FullCharge = [int]$f
                }
                if ($battery.DesignCapacity -and $battery.FullCharge) {
                    $battery.HealthPct = [math]::Round(($battery.FullCharge / $battery.DesignCapacity) * 100,2)
                }
                Remove-Item $tempFile -ErrorAction SilentlyContinue
            }
        } catch {}

        # Event errors count (last 24 hours)
        try {
            $startT = (Get-Date).AddDays(-1)
            $errors = Get-WinEvent -FilterHashtable @{LogName=@('System','Application'); Level=@(1,2); StartTime=$startT} -ErrorAction SilentlyContinue
            $errorCount = if ($errors) { $errors.Count } else { 0 }
        } catch { $errorCount = 0 }

        # Network (first adapter with IP)
        $net = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -ne $null } | Select-Object -First 1
        $network = @{
            Description = Get-Safe $net.Description "Unknown"
            IP = if ($net -and $net.IPAddress) { $net.IPAddress[0] } else { $null }
            MAC = Get-Safe $net.MACAddress "Unknown"
        }

        # Overall status simple rules
        $overall = "GREEN"
        if ($cpuPercent -ge 90 -or $ramPercent -ge 90 -or ($diskList | Where-Object { $_.UsagePercent -ge 95 })) { $overall = "CRITICAL" }
        elseif ($cpuPercent -ge 75 -or $ramPercent -ge 75 -or ($diskList | Where-Object { $_.UsagePercent -ge 85 })) { $overall = "WARNING" }

        # Compose final object
        $obj = @{
            timestamp = $ts
            overallStatus = $overall
            system = $sys
            cpu = $cpuObj
            ram = $ramObj
            disks = $diskList
            processes = $procList
            services = $svcList
            hotfixes = $hotfixes
            paging = $pageList
            battery = $battery
            eventErrors24h = $errorCount
            network = $network
        }

        return $obj
    } catch {
        return @{ error = "collection_failed"; message = $_.Exception.Message }
    }
}

# Main loop
while ($listener.IsListening) {
    $context = $listener.GetContext()
    $req = $context.Request
    $res = $context.Response

    # CORS support and basic routing
    $res.AddHeader("Access-Control-Allow-Origin", "*")
    $res.AddHeader("Access-Control-Allow-Methods", "GET, OPTIONS")
    $res.AddHeader("Access-Control-Allow-Headers", "Content-Type")

    if ($req.HttpMethod -eq "OPTIONS") {
        $res.StatusCode = 204
        $res.OutputStream.Close()
        continue
    }

    $path = $req.Url.AbsolutePath.TrimEnd("/")
    if ($path -eq "" -or $path -eq "/") {
        $msg = @{ message = "ASHM Live API. Use /stats" }
        $out = $msg | ConvertTo-Json -Depth 3
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($out)
        $res.ContentType = "application/json"
        $res.ContentLength64 = $buffer.Length
        $res.OutputStream.Write($buffer,0,$buffer.Length)
        $res.OutputStream.Close()
        continue
    }

    if ($path -eq "/stats") {
        $data = Collect-FullStats
        $json = $data | ConvertTo-Json -Depth 6
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json; charset=utf-8"
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes,0,$bytes.Length)
        $res.OutputStream.Close()
        continue
    }

    # Unknown route
    $res.StatusCode = 404
    $msg = @{ error = "not_found"; path = $path }
    $out = $msg | ConvertTo-Json -Depth 2
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($out)
    $res.ContentType = "application/json"
    $res.ContentLength64 = $buffer.Length
    $res.OutputStream.Write($buffer,0,$buffer.Length)
    $res.OutputStream.Close()
}
