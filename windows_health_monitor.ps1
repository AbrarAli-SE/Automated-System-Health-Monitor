<#
.SYNOPSIS
    Automated System Health Monitor (ASHM) - Dual-purpose diagnostic tool.
.DESCRIPTION
    Collects detailed hardware and OS data, applies health monitoring thresholds,
    and generates a single, self-contained, dark-themed HTML report.
    It includes deep dives into RAM, Storage, Processes, Event Logs, and OS configuration.
.NOTES
    Author: Gemini
    Version: 1.6 (FINAL: Implemented powercfg /batteryreport for reliable battery health, fixed UI layout, improved Paging File messaging.)
    Date: 2025-11-22
#>

# --- Configuration Section ---

# File Paths and Names
$ReportFileName = "ASHM_Health_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
$ReportPath = Join-Path $PSScriptRoot $ReportFileName
$BatteryReportTempFile = Join-Path $PSScriptRoot "battery-report-temp.html" # Temporary file for parsing

# Email Alert Configuration (Uncomment and configure to enable)
$EnableEmailAlerts = $false
$SmtpServer = "smtp.yourcompany.com"
$SmtpPort = 587
$FromAddress = "ashm-monitor@yourdomain.com"
$ToAddress = "system.admin@yourdomain.com"
$EmailSubject = "URGENT ASHM ALERT: System Health Status is "
# Credentials are required if authentication is needed, otherwise comment out.
# $User = "your_username"
# $Pass = "your_password"
# $Credential = New-Object System.Management.Automation.PSCredential($User, (ConvertTo-SecureString $Pass -AsPlainText -Force))

# Monitoring Thresholds
$CriticalCPU = 90  # %
$WarningCPU = 75   # %
$CriticalRAM = 90  # %
$WarningRAM = 75   # %
$CriticalDisk = 95 # %
$WarningDisk = 85  # %
$MaxErrorEvents = 10 # Number of Critical/Error events in 24 hours

# --- Helper Functions (Ensures all functions are loaded before data collection) ---

# FIX: Added [AllowNull()] to accept null objects without parameter binding error
function Get-SafeValue {
    param([Parameter()][AllowNull()]$Value, $Default = "N/A")
    # Use -ne $null for checking objects, -notmatch for empty strings/whitespace
    if ($Value -ne $null -and $Value -isnot [System.DBNull] -and $Value -notmatch '^\s*$') {
        # If the value is a single-element array (like an IP address array), return the first element
        if ($Value -is [Array] -and $Value.Count -eq 1) {
            return $Value[0]
        }
        return $Value
    }
    return $Default
}

# Function to generate Key/Value HTML tables
function Get-KeyValueTable {
    param([hashtable]$Data)
    
    $HTML = ""
    $Data.Keys | Sort-Object | ForEach-Object {
        $HTML += "<tr><td class='px-4 py-2 font-medium text-gray-400'>$_</td><td class='px-4 py-2 text-white'>$($Data[$_])</td></tr>"
    }
    return $HTML
}

# Function to generate RAM module table
function Get-RamTable {
    param([System.Collections.ArrayList]$Data)
    
    $HTML = @"
        <div class="overflow-x-auto rounded-lg shadow-lg border border-gray-700">
            <table class="min-w-full divide-y divide-gray-700">
                <thead class="bg-gray-700">
                    <tr>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Slot</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Capacity (GB)</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Speed (MHz)</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Manufacturer</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Part Number</th>
                    </tr>
                </thead>
                <tbody class="bg-gray-800 divide-y divide-gray-700">
"@
    
    $Data | ForEach-Object {
        $HTML += @"
                    <tr>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.Slot)</td>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.Capacity_GB)</td>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.Speed_MHz)</td>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.Manufacturer)</td>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.PartNumber)</td>
                    </tr>
"@
    }
    $HTML += "</tbody></table></div>"
    return $HTML
}

# Function to generate Disk table
function Get-DiskTable {
    param([System.Collections.ArrayList]$Data)
    
    $HTML = @"
        <div class="overflow-x-auto rounded-lg shadow-lg border border-gray-700">
            <table class="min-w-full divide-y divide-gray-700">
                <thead class="bg-gray-700">
                    <tr>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Model</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Type</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Interface</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Size (GB)</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Usage %</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Status</th>
                    </tr>
                </thead>
                <tbody class="bg-gray-800 divide-y divide-gray-700">
"@
    
    $Data | ForEach-Object {
        $StatusClass = switch ($_.Status) {
            "CRITICAL" {"bg-red-500 text-white"}
            "WARNING" {"bg-amber-500 text-gray-900"}
            "GREEN" {"bg-green-500 text-white"}
            default {"bg-gray-600 text-white"}
        }

        $HTML += @"
                    <tr>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.Model)</td>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.Type)</td>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.Interface)</td>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.SizeGB)</td>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.UsagePercent)%</td>
                        <td class="px-4 py-2 whitespace-nowrap text-sm">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium $StatusClass">$($_.Status)</span>
                        </td>
                    </tr>
"@
    }
    $HTML += "</tbody></table></div>"
    return $HTML
}

# Function to generate Hotfix table
function Get-HotfixTable {
    param($Data)
    
    $HTML = @"
        <div class="overflow-x-auto rounded-lg shadow-lg border border-gray-700">
            <table class="min-w-full divide-y divide-gray-700">
                <thead class="bg-gray-700">
                    <tr>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Hotfix ID</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Installed On</th>
                    </tr>
                </thead>
                <tbody class="bg-gray-800 divide-y divide-gray-700">
"@
    
    $Data | ForEach-Object {
        $InstalledOn = Get-SafeValue $_.InstalledOn
        if ($InstalledOn -ne "N/A" -and $InstalledOn -is [datetime]) {
            $InstalledOn = $InstalledOn.ToString("yyyy-MM-dd")
        }
        $HTML += @"
                    <tr>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.HotfixID)</td>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$InstalledOn</td>
                    </tr>
"@
    }
    $HTML += "</tbody></table></div>"
    return $HTML
}

# Function to generate Services table
function Get-ServiceTable {
    param($Data)
    
    $HTML = @"
        <div class="overflow-x-auto rounded-lg shadow-lg border border-gray-700">
            <table class="min-w-full divide-y divide-gray-700">
                <thead class="bg-gray-700">
                    <tr>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Name</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Start Type</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Status</th>
                    </tr>
                </thead>
                <tbody class="bg-gray-800 divide-y divide-gray-700">
"@
    
    $Data | ForEach-Object {
        $StatusClass = switch ($_.Status) {
            "Running" {"text-green-400"}
            "Stopped" {"text-red-400"}
            default {"text-gray-400"}
        }
        $StartTypeClass = switch ($_.StartType) {
            "Disabled" {"text-red-400 font-bold"}
            "Manual" {"text-amber-400"}
            default {"text-white"}
        }

        $HTML += @"
                    <tr>
                        <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.Name)</td>
                        <td class="px-4 py-2 whitespace-nowrap text-sm $StartTypeClass">$($_.StartType)</td>
                        <td class="px-4 py-2 whitespace-nowrap text-sm $StatusClass">$($_.Status)</td>
                    </tr>
"@
    }
    $HTML += "</tbody></table></div>"
    return $HTML
}

# Function to generate Paging File table
function Get-PagingTable {
    param($Data)
    
    $HTML = @"
        <div class="overflow-x-auto rounded-lg shadow-lg border border-gray-700">
            <table class="min-w-full divide-y divide-gray-700">
                <thead class="bg-gray-700">
                    <tr>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">File Name</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Initial Size (MB)</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Maximum Size (MB)</th>
                    </tr>
                </thead>
                <tbody class="bg-gray-800 divide-y divide-gray-700">
"@
    
    if ($Data.Count -gt 0) {
        $Data | ForEach-Object {
            $HTML += @"
                        <tr>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.FileName)</td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.InitialSizeMB)</td>
                            <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.MaxSizeMB)</td>
                        </tr>
"@
        }
    } else {
        # FIX: Display message if no Paging File data is found
        $HTML += @"
                        <tr>
                            <td colspan="3" class="px-4 py-4 text-center text-sm text-gray-400">Paging File Data Not Found or Automatically Managed.</td>
                        </tr>
"@
    }
    
    $HTML += "</tbody></table></div>"
    return $HTML
}


# Function to generate Top 10 Processes table
function Get-ProcessTable {
    param([System.Collections.ArrayList]$Data)
    
    $HTML = @"
        <div class="overflow-x-auto rounded-lg shadow-lg border border-gray-700">
            <table class="min-w-full divide-y divide-gray-700">
                <thead class="bg-gray-700">
                    <tr>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Process Name</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">PID</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">CPU %</th>
                        <th scope="col" class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-300">Working Set (MB)</th>
                    </tr>
                </thead>
                <tbody class="bg-gray-800 divide-y divide-gray-700">
"@
    
    $Data | ForEach-Object {
        $HTML += @"
            <tr>
                <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.Name)</td>
                <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.Id)</td>
                <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.CPU_Pct)</td>
                <td class="px-4 py-2 whitespace-nowrap text-sm text-white">$($_.WorkingSet_MB)</td>
            </tr>
"@
    }
    $HTML += "</tbody></table></div>"
    return $HTML
}

# --- Data Collection Phase ---

Write-Host "Starting Automated System Health Monitor (ASHM) data collection..."

# 1. System and OS Info
$ComputerInfo = Get-ComputerInfo
$Bios = Get-CimInstance -ClassName Win32_BIOS | Select-Object -First 1

$LastBootUpTime = Get-SafeValue $ComputerInfo.LastBootUpTime
$Uptime = "N/A (Error retrieving time)"
if ($LastBootUpTime -ne "N/A") {
    try {
        $UptimeObject = (Get-Date) - (Get-Date $LastBootUpTime)
        $Uptime = "$($UptimeObject.Days)d $($UptimeObject.Hours)h $($UptimeObject.Minutes)m"
    }
    catch {
        $Uptime = "N/A (Date conversion failed)"
    }
}

$SystemData = @{
    'OS Name' = Get-SafeValue $ComputerInfo.OsName
    'OS Version' = Get-SafeValue $ComputerInfo.OsVersion
    'System Manufacturer' = Get-SafeValue $ComputerInfo.CsManufacturer
    'System Model' = Get-SafeValue $ComputerInfo.CsModel
    'BIOS Manufacturer' = Get-SafeValue $Bios.Manufacturer
    'BIOS Serial Number' = Get-SafeValue $Bios.SerialNumber
    'System Uptime' = $Uptime
}

# 2. CPU Details
$Processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
# FIX: Added L1 Cache property (often unavailable via WMI) and ensured L2/L3 are correctly calculated from KB
$CpuData = @{
    'Name' = Get-SafeValue $Processor.Name
    'Cores / Logical Processors' = "$(Get-SafeValue $Processor.NumberOfCores) / $(Get-SafeValue $Processor.NumberOfLogicalProcessors)"
    'L1 Cache Size' = "N/A (WMI limitation)" # L1 is rarely exposed by Win32_Processor
    'L2 Cache Size' = "$([math]::Round((Get-SafeValue $Processor.L2CacheSize 0) / 1024, 2)) MB"
    'L3 Cache Size' = "$([math]::Round((Get-SafeValue $Processor.L3CacheSize 0) / 1024, 2)) MB"
}

# FIX: Use reliable WMI PerfFormattedData for CPU Utilization
$PerfDataCPU = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor | Where-Object {$_.Name -eq '_Total'} | Select-Object -First 1 -ErrorAction SilentlyContinue
$CurrentCPUValue = Get-SafeValue $PerfDataCPU.PercentProcessorTime 0
$CurrentCPU = [math]::Round($CurrentCPUValue, 2)


# 3. Memory (RAM) Details
$PhysicalMemory = Get-CimInstance -ClassName Win32_PhysicalMemory

# FIX: Robust measurement for total RAM
$TotalRamCapacity = ($PhysicalMemory | Measure-Object -Property Capacity -Sum -ErrorAction SilentlyContinue).Sum
$TotalRamGB = if ($TotalRamCapacity -gt 0) { $TotalRamCapacity / 1GB } else { 0 }

# FIX: Use reliable WMI PerfFormattedData for RAM Utilization
$PerfDataRAM = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Memory | Select-Object -First 1 -ErrorAction SilentlyContinue
$AvailableMB = Get-SafeValue $PerfDataRAM.AvailableMBytes 0
$TotalMB = $TotalRamGB * 1024
$UsedMB = $TotalMB - $AvailableMB

# Calculate Usage Percentage safely
$CurrentRAM = if ($TotalMB -gt 0) { ($UsedMB / $TotalMB) * 100 } else { 0 }
$RamUsage = [math]::Round($CurrentRAM, 2)

# FIX: Ensure all RAM module properties are correctly retrieved.
$RamModuleData = $PhysicalMemory | Select-Object @{N='Capacity_GB';E={[math]::Round((Get-SafeValue $_.Capacity 0) / 1GB, 2)}},
                                                 @{N='Speed_MHz';E={Get-SafeValue $_.Speed}},
                                                 Manufacturer,
                                                 PartNumber,
                                                 @{N='Slot';E={Get-SafeValue $_.DeviceLocator "N/A"}}

# 4. Storage Details (Unchanged, as logic is already robust)
$DiskData = @()
$PhysicalDisks = try {
    Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop | Select-Object DeviceID, Model, InterfaceType, MediaType
} catch {
    Write-Warning "Failed to retrieve physical disk details. Reporting only logical volume data."
    $PhysicalDisks = @()
}

$Volumes = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 -and $_.DeviceID -ne $null }

foreach ($Volume in $Volumes) {
    $Size = Get-SafeValue $Volume.Size 0
    $FreeSpace = Get-SafeValue $Volume.FreeSpace 0
    $SizeGB = [math]::Round($Size / 1GB, 2)
    $UsedGB = [math]::Round(($Size - $FreeSpace) / 1GB, 2)
    $UsagePercent = if ($SizeGB -gt 0) { [math]::Round(($UsedGB / $SizeGB) * 100, 2) } else { 0 }
    
    $Model = "Volume $($Volume.DeviceID)"
    $Type = "N/A (Physical details unavailable)"
    $Interface = "N/A"
    
    if ($PhysicalDisks.Count -gt 0) {
        try {
            $Partition = Get-CimAssociatedInstance -InputObject $Volume -Association Win32_LogicalDiskToPartition -ErrorAction SilentlyContinue
            $Drive = Get-CimAssociatedInstance -InputObject $Partition -Association Win32_DiskDriveToDiskPartition -ErrorAction SilentlyContinue | Select-Object -First 1
            
            if ($Drive) {
                $PhysicalDiskInfo = $PhysicalDisks | Where-Object { $_.DeviceID -eq $Drive.DeviceID } | Select-Object -First 1
                if ($PhysicalDiskInfo) {
                    $Model = "$(Get-SafeValue $PhysicalDiskInfo.Model) ($($Volume.DeviceID))"
                    $Type = switch (Get-SafeValue $PhysicalDiskInfo.MediaType 0) { 
                        4 {"HDD"} 
                        11 {"SSD"} 
                        12 {"Fixed media"} 
                        default {"Unknown"}
                    }
                    $Interface = Get-SafeValue $PhysicalDiskInfo.InterfaceType
                }
            }
        } catch {}
    }
    
    $DiskData += [PSCustomObject]@{
        Model = $Model
        Type = $Type
        Interface = $Interface
        SizeGB = $SizeGB
        UsagePercent = $UsagePercent
        Status = switch ($true) {
            ($UsagePercent -ge $CriticalDisk) {"CRITICAL"}
            ($UsagePercent -ge $WarningDisk) {"WARNING"}
            default {"GREEN"}
        }
    }
}

# 5. Display/Video Info
$Monitor = Get-CimInstance -ClassName Win32_DesktopMonitor | Select-Object -First 1
$VideoController = Get-CimInstance -ClassName Win32_VideoController | Select-Object -First 1

# FIX: Use Win32_VideoController properties for robust resolution detection
$HorizontalRes = Get-SafeValue $VideoController.CurrentHorizontalResolution "N/A"
$VerticalRes = Get-SafeValue $VideoController.CurrentVerticalResolution "N/A"

$DisplayData = @{
    'Primary Resolution' = "${HorizontalRes} x ${VerticalRes}"
    'Monitor Name' = Get-SafeValue $Monitor.Name
    'Video Processor (GPU)' = Get-SafeValue $VideoController.Name
    'Adapter RAM' = "$([math]::Round((Get-SafeValue $VideoController.AdapterRAM 0) / 1MB)) MB"
}

# 6. Battery Health (CRITICAL FIX: Use powercfg /batteryreport)
$BatteryHealth = @{
    'Design Capacity (mWh)' = "N/A (Desktop or report failed)"
    'Full Charge Capacity (mWh)' = "N/A (Desktop or report failed)"
    'Health (%)' = "N/A (Desktop or report failed)"
}

try {
    # 1. Generate the HTML report temporarily
    Start-Process -FilePath powercfg -ArgumentList "/batteryreport /output $BatteryReportTempFile /Duration 1" -Wait -NoNewWindow -ErrorAction Stop

    # 2. Read the key data from the report file
    $BatteryReportContent = Get-Content -Path $BatteryReportTempFile -Raw -ErrorAction Stop

    # 3. Use regex to extract Design Capacity (in mWh)
    $DesignMatch = $BatteryReportContent | Select-String -Pattern 'Design Capacity</td>\s*<td[^>]*>([^<]+)mWh'
    $Design = if ($DesignMatch) { [long]($DesignMatch.Matches[0].Groups[1].Value -replace '[^\d]', '') } else { 0 }

    # 4. Use regex to extract Full Charge Capacity (in mWh)
    $FullChargeMatch = $BatteryReportContent | Select-String -Pattern 'Full Charge Capacity</td>\s*<td[^>]*>([^<]+)mWh'
    $FullCharge = if ($FullChargeMatch) { [long]($FullChargeMatch.Matches[0].Groups[1].Value -replace '[^\d]', '') } else { 0 }

    # 5. Calculate Health Percentage
    if ($Design -gt 0) {
        $Health = [math]::Round(($FullCharge / $Design) * 100, 2)
        $BatteryHealth['Design Capacity (mWh)'] = $Design
        $BatteryHealth['Full Charge Capacity (mWh)'] = $FullCharge
        $BatteryHealth['Health (%)'] = $Health
    } else {
        $BatteryHealth['Design Capacity (mWh)'] = "No battery detected (Desktop)"
        $BatteryHealth['Full Charge Capacity (mWh)'] = "No battery detected (Desktop)"
        $BatteryHealth['Health (%)'] = "N/A"
    }
}
catch {
    # Cleanup and log failure
    Write-Warning "PowerCfg battery report failed. Using default N/A values."
}
finally {
    # 6. Clean up the temporary file
    if (Test-Path $BatteryReportTempFile) { Remove-Item $BatteryReportTempFile -Force }
}

# 7. Process and Service Info
$Processes = Get-Process -ErrorAction SilentlyContinue | Sort-Object CPU -Descending

$Top10Processes = $Processes | Select-Object -First 10 Name, Id, @{N='CPU_Pct';E={[math]::Round((Get-SafeValue $_.CPU 0), 2)}}, @{N='WorkingSet_MB';E={[math]::Round((Get-SafeValue $_.WorkingSet 0) / 1MB, 2)}}
$ProcessCount = $Processes.Count
$ServiceCount = (Get-Service -ErrorAction SilentlyContinue).Count

# 8. Event Log Analysis (Last 24 hours)
$StartTime = (Get-Date).AddDays(-1)
$ErrorEvents = Get-WinEvent -FilterHashtable @{LogName='System', 'Application'; Level=1, 2; StartTime=$StartTime} -ErrorAction SilentlyContinue
$EventCount = $ErrorEvents.Count

# 9. Network Info (UI Change: Moved to Column 2)
$NetworkAdapter = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPAddress -ne $null -and $_.DHCPEnabled } | Select-Object -First 1
$NetworkData = @{
    'Description' = Get-SafeValue $NetworkAdapter.Description
    'IP Address' = Get-SafeValue $NetworkAdapter.IPAddress[0]
    'MAC Address' = Get-SafeValue $NetworkAdapter.MACAddress
}

# 10. OS Deep Dive
$Hotfixes = Get-Hotfix | Select-Object HotfixID, InstalledOn | Sort-Object InstalledOn -Descending
$HotfixCount = $Hotfixes.Count
$ProblematicServices = Get-Service | Where-Object { $_.StartType -ne 'Auto' -and $_.StartType -ne 'Disabled' } | Select-Object Name, StartType, Status | Sort-Object StartType, Name

$PagingFileInfo = Get-CimInstance -ClassName Win32_PageFile -ErrorAction SilentlyContinue
$PagingData = @()
if ($PagingFileInfo) {
    foreach ($PagingFile in $PagingFileInfo) {
        $PagingData += [PSCustomObject]@{
            FileName = Get-SafeValue $PagingFile.Name
            InitialSizeMB = Get-SafeValue $PagingFile.InitialSize
            MaxSizeMB = Get-SafeValue $PagingFile.MaximumSize
        }
    }
}


# --- Monitoring & Status Determination Phase ---

# Determine Overall Status (Logic uses CurrentCPU and RamUsage which are now robustly calculated)
$OverallStatus = "GREEN"
$StatusMessage = @()

# CPU Check
if ($CurrentCPU -ge $CriticalCPU) {
    $OverallStatus = "CRITICAL"
    $StatusMessage += "CPU usage ($([int]$CurrentCPU)%) is CRITICAL."
} elseif ($CurrentCPU -ge $WarningCPU -and $OverallStatus -eq "GREEN") {
    $OverallStatus = "WARNING"
    $StatusMessage += "CPU usage ($([int]$CurrentCPU)%) is WARNING."
}

# RAM Check
if ($RamUsage -ge $CriticalRAM) {
    $OverallStatus = "CRITICAL"
    $StatusMessage += "RAM usage ($([int]$RamUsage)%) is CRITICAL."
} elseif ($RamUsage -ge $WarningRAM -and $OverallStatus -eq "GREEN") {
    $OverallStatus = "WARNING"
    $StatusMessage += "RAM usage ($([int]$RamUsage)%) is WARNING."
}

# Disk Check
if ($DiskData | Where-Object {$_.Status -eq "CRITICAL"}) {
    $OverallStatus = "CRITICAL"
    $StatusMessage += "One or more disks have CRITICAL usage."
} elseif (($DiskData | Where-Object {$_.Status -eq "WARNING"}) -and $OverallStatus -eq "GREEN") {
    $OverallStatus = "WARNING"
    $StatusMessage += "One or more disks have WARNING usage."
}

# Event Log Check
if ($EventCount -ge $MaxErrorEvents) {
    $OverallStatus = "CRITICAL"
    $StatusMessage += "Excessive (>$MaxErrorEvents) critical/error events in the last 24 hours ($EventCount found)."
} elseif ($EventCount -ge ($MaxErrorEvents / 2) -and $OverallStatus -eq "GREEN") {
    $OverallStatus = "WARNING"
    $StatusMessage += "High number of critical/error events in the last 24 hours ($EventCount found)."
}

if ($OverallStatus -eq "GREEN") {
    $StatusMessage += "System health is optimal."
}
$StatusMessage = $StatusMessage -join " | "
$StatusColor = switch ($OverallStatus) {
    "CRITICAL" {"#ef4444"} # Red-500
    "WARNING" {"#f59e0b"}  # Amber-500
    "GREEN" {"#22c55e"}    # Green-500
    default {"#4b5563"}    # Gray-600
}

# --- Email Alerting (Conditional) ---

if ($EnableEmailAlerts -and ($OverallStatus -eq "CRITICAL" -or $OverallStatus -eq "WARNING")) {
    try {
        Write-Host "Sending Email Alert..."
        Send-MailMessage -SmtpServer $SmtpServer `
            -Port $SmtpPort `
            -From $FromAddress `
            -To $ToAddress `
            -Subject "$EmailSubject $OverallStatus" `
            -Body $StatusMessage `
            -BodyAsHtml `
            -UseSsl `
            -Credential $Credential # Uncomment if credentials are used
    }
    catch {
        Write-Warning "Failed to send email alert: $($_.Exception.Message)"
    }
}

# --- HTML Generation Phase ---

# Generate HTML content using the collected data and functions
$HtmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ASHM: System Health Report - $(Get-Date)</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');
        body { font-family: 'Inter', sans-serif; }
        .progress-bar-container { background-color: #374151; border-radius: 9999px; height: 10px; margin-top: 4px; overflow: hidden; }
        .progress-bar-fill { height: 100%; border-radius: 9999px; transition: width 0.3s ease-in-out; }
    </style>
</head>
<body class="bg-gray-900 text-gray-100 p-4 sm:p-8">
    <div class="max-w-7xl mx-auto space-y-10">
        <!-- Header & Status Panel -->
        <header class="pb-6 border-b border-gray-700">
            <h1 class="text-4xl font-extrabold text-white">Automated System Health Monitor (ASHM)</h1>
            <p class="text-gray-400 mt-2">Report Generated: $(Get-Date -Format 'F')</p>
        </header>

        <!-- System Status Summary -->
        <div class="p-6 rounded-xl shadow-2xl" style="background-color: $(if($OverallStatus -eq 'GREEN'){'#1f2937'}else{$StatusColor});">
            <div class="flex items-center justify-between">
                <h2 class="text-3xl font-bold">System Status: <span class="text-white">($OverallStatus)</span></h2>
                <div class="px-4 py-2 rounded-full text-lg font-bold" style="background-color: $(if($OverallStatus -ne 'GREEN'){$StatusColor}else{'#000'}); color: $(if($OverallStatus -eq 'WARNING'){$StatusColor}else{'#fff'});">
                    $OverallStatus
                </div>
            </div>
            <p class="text-lg mt-3 text-white">Reason: $StatusMessage</p>
        </div>

        <!-- Metric Visualization -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <!-- CPU Utilization -->
            <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                <h3 class="text-xl font-semibold mb-3">CPU Utilization</h3>
                <p class="text-3xl font-bold text-teal-400">$([int]$CurrentCPU)%</p>
                <div class="progress-bar-container">
                    <div class="progress-bar-fill" style="width: $([int]$CurrentCPU)%; background-color: $(switch ($true) { ($CurrentCPU -ge $CriticalCPU) {'#ef4444'} ($CurrentCPU -ge $WarningCPU) {'#f59e0b'} default {'#22c55e'} });"></div>
                </div>
                <p class="text-xs text-gray-500 mt-2">Thresholds: Warning > $($WarningCPU)%, Critical > $($CriticalCPU)%</p>
            </div>

            <!-- RAM Utilization -->
            <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                <h3 class="text-xl font-semibold mb-3">RAM Utilization</h3>
                <p class="text-3xl font-bold text-teal-400">$([int]$RamUsage)%</p>
                <p class="text-sm text-gray-400 mb-2">Total: $([math]::Round($TotalRamGB, 2)) GB</p>
                <div class="progress-bar-container">
                    <div class="progress-bar-fill" style="width: $([int]$RamUsage)%; background-color: $(switch ($true) { ($RamUsage -ge $CriticalRAM) {'#ef4444'} ($RamUsage -ge $WarningRAM) {'#f59e0b'} default {'#22c55e'} });"></div>
                </div>
                <p class="text-xs text-gray-500 mt-2">Thresholds: Warning > $($WarningRAM)%, Critical > $($CriticalRAM)%</p>
            </div>

            <!-- Event Log Errors -->
            <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                <h3 class="text-xl font-semibold mb-3">Event Errors (24h)</h3>
                <p class="text-3xl font-bold $(if($EventCount -ge $MaxErrorEvents){'text-red-500'}else{'text-white'})">$EventCount</p>
                <p class="text-sm text-gray-400 mt-2">Critical/Error events in System/App logs.</p>
                <p class="text-xs text-gray-500 mt-2">Critical Threshold: > $($MaxErrorEvents) events</p>
            </div>
        </div>

        <!-- ---------------------------------------------------- -->
        <!-- Deep Dive Sections (TWO COLUMNS) -->
        <!-- ---------------------------------------------------- -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mt-10">

            <!-- COLUMN 1: System, CPU, Display, & Battery -->
            <div class="space-y-8">
                <!-- System & OS Details -->
                <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                    <h3 class="text-2xl font-bold mb-4 border-b border-gray-700 pb-3 text-indigo-400">System & OS</h3>
                    <table class="min-w-full">
                        <tbody>
                            $(Get-KeyValueTable $SystemData)
                        </tbody>
                    </table>
                </div>

                <!-- CPU Core Details (Including L1/L2/L3) -->
                <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                    <h3 class="text-2xl font-bold mb-4 border-b border-gray-700 pb-3 text-indigo-400">CPU & Cache</h3>
                    <table class="min-w-full">
                        <tbody>
                            $(Get-KeyValueTable $CpuData)
                        </tbody>
                    </table>
                </div>

                <!-- Display/Video Details (Fixed Resolution) -->
                <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                    <h3 class="text-2xl font-bold mb-4 border-b border-gray-700 pb-3 text-indigo-400">Display & Video</h3>
                    <table class="min-w-full">
                        <tbody>
                            $(Get-KeyValueTable $DisplayData)
                        </tbody>
                    </table>
                </div>

                <!-- Battery Health (FIXED: Using powercfg report parsing) -->
                <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                    <h3 class="text-2xl font-bold mb-4 border-b border-gray-700 pb-3 text-indigo-400">Battery Health</h3>
                    <table class="min-w-full">
                        <tbody>
                            $(Get-KeyValueTable $BatteryHealth)
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- COLUMN 2: Memory, Storage, Paging, & Network (UI Adjusted) -->
            <div class="space-y-8">
                <!-- RAM Module Breakdown -->
                <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                    <h3 class="text-2xl font-bold mb-4 border-b border-gray-700 pb-3 text-green-400">RAM Module Breakdown</h3>
                    $(Get-RamTable $RamModuleData)
                </div>

                <!-- Storage Details (Fixed Overflow) -->
                <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                    <h3 class="text-2xl font-bold mb-4 border-b border-gray-700 pb-3 text-green-400">Storage Details (Physical Disks & Usage)</h3>
                    $(Get-DiskTable $DiskData)
                </div>
                
                <!-- Paging File Info (FIXED: Added fallback message) -->
                <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                    <h3 class="text-2xl font-bold mb-4 border-b border-gray-700 pb-3 text-purple-400">Paging File (Virtual Memory) Information</h3>
                    $(Get-PagingTable $PagingData)
                </div>

                <!-- Network Info (UI CHANGE: Moved here for layout balance) -->
                <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                    <h3 class="text-2xl font-bold mb-4 border-b border-gray-700 pb-3 text-indigo-400">Network</h3>
                    <table class="min-w-full">
                        <tbody>
                            $(Get-KeyValueTable $NetworkData)
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
        
        <!-- ---------------------------------------------------- -->
        <!-- OS Deep Dive & Diagnostics (Full Width) -->
        <!-- ---------------------------------------------------- -->
        <div class="space-y-8 mt-10">

            <!-- Top 10 CPU Processes -->
            <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                <h3 class="text-2xl font-bold mb-4 border-b border-gray-700 pb-3 text-yellow-400">Top 10 CPU-Consuming Processes</h3>
                <p class="text-sm text-gray-400 mb-4">Total Processes: $ProcessCount | Total Services: $ServiceCount</p>
                $(Get-ProcessTable $Top10Processes)
            </div>

            <!-- Hotfix Details -->
            <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                <h3 class="text-2xl font-bold mb-4 border-b border-gray-700 pb-3 text-yellow-400">Windows Hotfix History ($HotfixCount Patches)</h3>
                $(Get-HotfixTable $Hotfixes)
            </div>

            <!-- Problematic Services -->
            <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-gray-700">
                <h3 class="text-2xl font-bold mb-4 border-b border-gray-700 pb-3 text-yellow-400">Non-Auto Services (Manual/Disabled)</h3>
                $(Get-ServiceTable $ProblematicServices)
            </div>

            <!-- Performance Visualization (Chart.js Implementation) -->
            <div class="bg-gray-800 p-6 rounded-xl shadow-lg border border-blue-600">
                <h3 class="text-2xl font-bold mb-4 text-blue-400">Performance Visualization (CPU/RAM Utilization)</h3>
                <div class="h-96 mt-4 p-4 flex items-center justify-center">
                    <!-- Chart area -->
                    <canvas id="resourceChart"></canvas>
                </div>
            </div>
        </div>

        <footer class="text-center text-gray-500 pt-8 border-t border-gray-800">
            ASHM Report | Generated by PowerShell | Core Goal: Diagnostic Audit & Procurement Check
        </footer>
    </div>
    
    <script>
        // --- Chart.js Scripting ---
        document.addEventListener('DOMContentLoaded', function() {
            // Data collected directly from PowerShell variables
            const cpuUsage = $([math]::Round($CurrentCPU, 1));
            const ramUsage = $([math]::Round($RamUsage, 1));

            const data = {
                labels: ['CPU Used', 'RAM Used', 'CPU Idle', 'RAM Free'],
                datasets: [{
                    data: [
                        cpuUsage, 
                        ramUsage, 
                        (100 - cpuUsage), 
                        (100 - ramUsage)
                    ].map(v => Math.max(0, v)), // Ensure no negative values
                    backgroundColor: [
                        'rgba(239, 68, 68, 0.8)', // Red for CPU Used
                        'rgba(52, 211, 153, 0.8)', // Teal/Green for RAM Used
                        'rgba(239, 68, 68, 0.2)', // Light Red for CPU Idle
                        'rgba(52, 211, 153, 0.2)' // Light Teal/Green for RAM Free
                    ],
                    borderColor: '#1f2937',
                    borderWidth: 2
                }]
            };

            const config = {
                type: 'doughnut',
                data: data,
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            position: 'top',
                            labels: {
                                color: '#e5e7eb' // Light gray for text
                            }
                        },
                        title: {
                            display: true,
                            text: 'Combined Resource Utilization Breakdown',
                            color: '#a5b4fc' // Indigo/Blue for title
                        },
                        tooltip: {
                            callbacks: {
                                label: function(context) {
                                    let label = context.label || '';
                                    if (label) {
                                        label += ': ';
                                    }
                                    if (context.parsed !== null) {
                                        label += context.parsed.toFixed(1) + '%';
                                    }
                                    return label;
                                }
                            }
                        }
                    }
                }
            };

            const chartCanvas = document.getElementById('resourceChart');
            if (chartCanvas) {
                new Chart(chartCanvas, config);
            }
        });
    </script>
</body>
</html>
"@

# Output the HTML file
try {
    $HtmlContent | Out-File $ReportPath -Encoding UTF8
    Write-Host "Success: Report generated at '$ReportPath'"
    
    # Auto-Open UX Feature
    Write-Host "Opening report in default browser..."
    Invoke-Item $ReportPath
}
catch {
    Write-Error "An error occurred during file creation or opening: $($_.Exception.Message)"
}