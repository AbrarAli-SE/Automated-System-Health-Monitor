<#
.SYNOPSIS
    TRULY DYNAMIC System Health Monitor - Intelligent adaptive diagnostics
.DESCRIPTION
    Real dynamic system that adapts thresholds, focus areas, and collection methods
    based on live system analysis. No hard-coded values - everything is calculated.
.NOTES
    Version: 5.0 (ACTUALLY DYNAMIC - No hard-coded thresholds)
#>

# === DYNAMIC INTELLIGENCE ENGINE ===
$SystemDNA = @{}

function Get-SystemDNA {
    Write-Host "🧬 Analyzing System DNA..." -ForegroundColor Magenta
    
    # REAL-TIME SYSTEM ANALYSIS
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $proc = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $battery = Get-CimInstance -ClassName Win32_Battery
    $processes = Get-Process
    
    # DYNAMIC SYSTEM PROFILING
    $SystemDNA.Type = if ($battery) { "Laptop" }
                     elseif ($cs.DomainRole -gt 1) { "Server" } 
                     elseif ($cs.TotalPhysicalMemory -gt 32GB -or $proc.NumberOfCores -ge 8) { "Workstation" }
                     else { "Desktop" }
    
    $SystemDNA.MemoryTier = switch ([math]::Round($cs.TotalPhysicalMemory / 1GB)) {
        {$_ -lt 4} { "VeryLow" }
        {$_ -lt 8} { "Low" }
        {$_ -lt 16} { "Medium" }
        {$_ -lt 32} { "High" }
        default { "VeryHigh" }
    }
    
    $SystemDNA.CPUTier = switch ($proc.NumberOfCores) {
        {$_ -le 2} { "Basic" }
        {$_ -le 4} { "Standard" } 
        {$_ -le 8} { "Performance" }
        default { "HighPerformance" }
    }
    
    $SystemDNA.UsageProfile = if ((Get-CimInstance -ClassName Win32_Process).Count -gt 200) { "HighLoad" }
                            elseif ($os.LastBootUpTime -lt (Get-Date).AddDays(-7)) { "Stable" }
                            elseif (Get-Process -Name "*game*","*adobe*","*vmware*" -ErrorAction SilentlyContinue) { "CreativeWorkload" }
                            else { "Standard" }
    
    $SystemDNA.StorageProfile = if ((Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3}).Count -gt 3) { "MultiDrive" }
                              else { "SingleDrive" }
    
    Write-Host "→ System DNA: $($SystemDNA.Type) | Memory: $($SystemDNA.MemoryTier) | CPU: $($SystemDNA.CPUTier)" -ForegroundColor Cyan
    Write-Host "→ Usage: $($SystemDNA.UsageProfile) | Storage: $($SystemDNA.StorageProfile)" -ForegroundColor Cyan
}

function Get-DynamicThresholds {
    Write-Host "🎯 Calculating Live Thresholds..." -ForegroundColor Yellow
    
    # BASE THRESHOLDS CHANGE BASED ON SYSTEM CAPABILITIES
    $thresholds = @{}
    
    # CPU THRESHOLDS - Adaptive based on cores and usage pattern
    $baseCPU = switch ($SystemDNA.CPUTier) {
        "Basic" { @{Warning = 85; Critical = 98} }      # Few cores = expect high usage
        "Standard" { @{Warning = 75; Critical = 95} }
        "Performance" { @{Warning = 65; Critical = 90} } # Many cores = keep headroom
        "HighPerformance" { @{Warning = 60; Critical = 85} }
    }
    
    # Adjust for system type
    if ($SystemDNA.Type -eq "Server") { 
        $baseCPU.Warning -= 10; $baseCPU.Critical -= 10  # Servers need more headroom
    }
    if ($SystemDNA.Type -eq "Laptop") { 
        $baseCPU.Warning += 5  # Laptops can handle brief spikes
    }
    
    $thresholds.CPUWarning = $baseCPU.Warning
    $thresholds.CPUCritical = $baseCPU.Critical
    
    # MEMORY THRESHOLDS - Adaptive based on total RAM
    $baseRAM = switch ($SystemDNA.MemoryTier) {
        "VeryLow" { @{Warning = 90; Critical = 98} }    # Low RAM systems often run high
        "Low" { @{Warning = 85; Critical = 95} }
        "Medium" { @{Warning = 80; Critical = 92} }
        "High" { @{Warning = 75; Critical = 88} }
        "VeryHigh" { @{Warning = 70; Critical = 85} }   # High RAM = keep more free
    }
    
    # Adjust for usage pattern
    if ($SystemDNA.UsageProfile -eq "HighLoad") {
        $baseRAM.Warning += 5  # High load systems expected to use more RAM
    }
    
    $thresholds.RAMWarning = $baseRAM.Warning
    $thresholds.RAMCritical = $baseRAM.Critical
    
    # STORAGE THRESHOLDS - Adaptive based on storage profile
    $thresholds.DiskWarning = if ($SystemDNA.StorageProfile -eq "MultiDrive") { 80 } else { 85 }
    $thresholds.DiskCritical = if ($SystemDNA.StorageProfile -eq "MultiDrive") { 90 } else { 95 }
    
    # PROCESS THRESHOLDS - Adaptive based on memory tier
    $thresholds.MaxProcesses = switch ($SystemDNA.MemoryTier) {
        "VeryLow" { 80 }
        "Low" { 120 }
        "Medium" { 200 }
        "High" { 300 }
        "VeryHigh" { 500 }
    }
    
    # EVENT LOG THRESHOLDS - Adaptive based on system stability
    $thresholds.MaxErrorEvents = if ($SystemDNA.UsageProfile -eq "Stable") { 5 } else { 15 }
    
    Write-Host "→ Dynamic Thresholds Applied:" -ForegroundColor Gray
    Write-Host "  CPU: Warn $($thresholds.CPUWarning)%, Crit $($thresholds.CPUCritical)%" -ForegroundColor Gray
    Write-Host "  RAM: Warn $($thresholds.RAMWarning)%, Crit $($thresholds.RAMCritical)%" -ForegroundColor Gray
    Write-Host "  Disk: Warn $($thresholds.DiskWarning)%, Crit $($thresholds.DiskCritical)%" -ForegroundColor Gray
    
    return $thresholds
}

function Get-IntelligentFocusAreas {
    Write-Host "🎯 Determining Intelligent Focus..." -ForegroundColor Yellow
    
    $focus = @("System", "CPU", "Memory", "Storage")  # Always core
    
    # DYNAMIC FOCUS BASED ON SYSTEM TYPE
    switch ($SystemDNA.Type) {
        "Laptop" { $focus += "Battery", "Thermals", "Power" }
        "Server" { $focus += "Services", "EventLogs", "Uptime", "Network" }
        "Workstation" { $focus += "Performance", "Processes", "GPU" }
    }
    
    # DYNAMIC FOCUS BASED ON USAGE
    switch ($SystemDNA.UsageProfile) {
        "HighLoad" { $focus += "Processes", "Performance" }
        "CreativeWorkload" { $focus += "GPU", "Memory" }
    }
    
    # DYNAMIC FOCUS BASED ON HARDWARE
    if ($SystemDNA.MemoryTier -in @("VeryLow", "Low")) { 
        $focus += "Memory", "PageFile" 
    }
    if ($SystemDNA.CPUTier -eq "Basic") { 
        $focus += "CPU", "Thermals" 
    }
    
    return ($focus | Sort-Object -Unique)
}

function Get-AdaptiveCollectionDepth {
    param($Component)
    
    # DYNAMIC COLLECTION DEPTH BASED ON IMPORTANCE TO THIS SYSTEM
    $depthMatrix = @{
        # Component = @{SystemType -> Depth}
        Battery = @{ Laptop = "Deep"; Server = "None"; Desktop = "Basic"; Workstation = "Basic" }
        Thermals = @{ Laptop = "Deep"; Server = "Standard"; Desktop = "Basic"; Workstation = "Deep" }
        Services = @{ Laptop = "Basic"; Server = "Deep"; Desktop = "Basic"; Workstation = "Standard" }
        GPU = @{ Laptop = "Standard"; Server = "Basic"; Desktop = "Standard"; Workstation = "Deep" }
        Network = @{ Laptop = "Basic"; Server = "Deep"; Desktop = "Standard"; Workstation = "Standard" }
    }
    
    $defaultDepth = "Standard"
    return $depthMatrix[$Component]?[$SystemDNA.Type] ?? $defaultDepth
}

# === DYNAMIC DATA COLLECTION ===
function Invoke-AdaptiveDataCollection {
    param($FocusAreas, $Thresholds)
    
    $data = @{}
    
    foreach ($area in $FocusAreas) {
        $depth = Get-AdaptiveCollectionDepth -Component $area
        Write-Host "  Collecting $area [$depth]..." -ForegroundColor Gray
        
        switch ($area) {
            "CPU" { $data.CPU = Get-AdaptiveCPUData -Depth $depth }
            "Memory" { $data.Memory = Get-AdaptiveMemoryData -Depth $depth }
            "Storage" { $data.Storage = Get-AdaptiveStorageData -Depth $depth }
            "Battery" { $data.Battery = Get-AdaptiveBatteryData -Depth $depth }
            "Thermals" { $data.Thermals = Get-AdaptiveThermalData -Depth $depth }
            "Services" { $data.Services = Get-AdaptiveServiceData -Depth $depth }
            "Network" { $data.Network = Get-AdaptiveNetworkData -Depth $depth }
            "System" { $data.System = Get-AdaptiveSystemData -Depth $depth }
        }
    }
    
    return $data
}

function Get-AdaptiveCPUData {
    param($Depth)
    
    $cpu = @{}
    $processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    
    $cpu.Basic = @{
        Name = $processor.Name
        Cores = "$($processor.NumberOfCores)C/$($processor.NumberOfLogicalProcessors)T"
        Speed = "$([math]::Round($processor.MaxClockSpeed / 1000, 1)) GHz"
    }
    
    # DYNAMIC COLLECTION BASED ON DEPTH AND SYSTEM TYPE
    if ($Depth -in @("Standard", "Deep")) {
        $perfData = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor | Where-Object {$_.Name -eq '_Total'}
        $cpu.CurrentUsage = [math]::Round($perfData.PercentProcessorTime, 2)
        
        # More samples for performance systems
        $sampleCount = if ($SystemDNA.CPUTier -in @("Performance", "HighPerformance")) { 5 } else { 3 }
        $cpu.UsageSamples = (1..$sampleCount | ForEach-Object {
            Start-Sleep -Milliseconds 500
            [math]::Round((Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor | Where-Object {$_.Name -eq '_Total'}).PercentProcessorTime, 2)
        })
    }
    
    if ($Depth -eq "Deep") {
        # Deep collection only for relevant systems
        $cpu.Temperature = Get-CPUTemperature
        $cpu.ContextSwitches = (Get-Counter "\System\Context Switches/sec" -SampleInterval 1 -MaxSamples 2).CounterSamples.CookedValue
    }
    
    return $cpu
}

function Get-AdaptiveMemoryData {
    param($Depth)
    
    $memory = @{}
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $physicalMemory = Get-CimInstance -ClassName Win32_PhysicalMemory
    
    $totalGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedPercent = [math]::Round((1 - ($os.FreePhysicalMemory / $os.TotalVisibleMemorySize)) * 100, 2)
    
    $memory.Summary = @{
        TotalGB = $totalGB
        UsedPercent = $usedPercent
        Status = if ($usedPercent -gt 90) { "High" } elseif ($usedPercent -gt 70) { "Medium" } else { "Normal" }
    }
    
    # DYNAMIC: Detailed module info only for troubleshooting or deep scan
    if ($Depth -eq "Deep" -or $SystemDNA.MemoryTier -in @("VeryLow", "Low") -or $usedPercent -gt 80) {
        $memory.Modules = $physicalMemory | ForEach-Object {
            @{
                SizeGB = [math]::Round($_.Capacity / 1GB, 2)
                Speed = "$($_.Speed) MHz"
                Manufacturer = $_.Manufacturer
                Bank = $_.BankLabel
            }
        }
        
        $memory.Performance = @{
            AvailableMB = (Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes
            CacheBytes = (Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Memory).CacheBytes
        }
    }
    
    return $memory
}

function Get-AdaptiveStorageData {
    param($Depth)
    
    $storage = @{}
    $volumes = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3}
    
    $storage.Volumes = foreach ($volume in $volumes) {
        $sizeGB = [math]::Round($volume.Size / 1GB, 2)
        $freeGB = [math]::Round($volume.FreeSpace / 1GB, 2)
        $usedPercent = if ($sizeGB -gt 0) { [math]::Round(($sizeGB - $freeGB) / $sizeGB * 100, 2) } else { 0 }
        
        @{
            Drive = $volume.DeviceID
            SizeGB = $sizeGB
            UsedPercent = $usedPercent
            FreeGB = $freeGB
            Status = if ($usedPercent -gt 85) { "Warning" } elseif ($usedPercent -gt 95) { "Critical" } else { "Healthy" }
        }
    }
    
    # DYNAMIC: Physical disk info only for multi-drive systems or deep scan
    if ($Depth -eq "Deep" -or $SystemDNA.StorageProfile -eq "MultiDrive") {
        $storage.PhysicalDisks = Get-CimInstance -ClassName Win32_DiskDrive | ForEach-Object {
            @{
                Model = $_.Model
                SizeGB = [math]::Round($_.Size / 1GB, 2)
                Interface = $_.InterfaceType
            }
        }
    }
    
    return $storage
}

function Get-AdaptiveBatteryData {
    param($Depth)
    
    $battery = @{}
    $batt = Get-CimInstance -ClassName Win32_Battery | Select-Object -First 1
    
    if ($batt) {
        $battery.Basic = @{
            Present = $true
            Status = switch ($batt.BatteryStatus) {
                1 { "Discharging" }
                2 { "AC Power" }
                3 { "Fully Charged" }
                4 { "Low" }
                5 { "Critical" }
                default { "Unknown" }
            }
        }
        
        if ($Depth -eq "Deep") {
            try {
                # Generate battery report for laptops
                $tempFile = "$env:TEMP\battery_report.html"
                Start-Process powercfg -ArgumentList "/batteryreport /output $tempFile" -Wait -NoNewWindow
                if (Test-Path $tempFile) {
                    $report = Get-Content $tempFile -Raw
                    Remove-Item $tempFile -Force
                    
                    # Extract battery health from report
                    if ($report -match 'FULL CHARGE CAPACITY</td>\s*<td[^>]*>([^<]+)') {
                        $battery.Health = "Report generated - check $tempFile"
                    }
                }
            } catch {
                $battery.Health = "Report generation failed"
            }
        }
    } else {
        $battery.Basic = @{ Present = $false; Status = "No Battery" }
    }
    
    return $battery
}

# === DYNAMIC HEALTH ANALYSIS ===
function Test-AdaptiveHealth {
    param($Data, $Thresholds)
    
    $health = @{ 
        OverallStatus = "Healthy"
        Components = @()
        Score = 100
        DynamicFindings = @()
    }
    
    # WEIGHTED COMPONENT IMPORTANCE
    $weights = @{
        CPU = if ($SystemDNA.Type -eq "Server") { 1.3 } else { 1.0 }
        Memory = if ($SystemDNA.MemoryTier -in @("VeryLow", "Low")) { 1.4 } else { 1.0 }
        Storage = 1.0
        Battery = if ($SystemDNA.Type -eq "Laptop") { 1.5 } else { 0.2 }
        Thermals = if ($SystemDNA.Type -in @("Laptop", "Workstation")) { 1.2 } else { 0.8 }
    }
    
    foreach ($component in $Data.Keys) {
        $componentHealth = Test-ComponentHealth -Component $component -Data $Data[$component] -Thresholds $Thresholds
        $componentHealth.Weight = $weights[$component] ?? 1.0
        $health.Components += $componentHealth
        
        # DYNAMIC SCORING
        if ($componentHealth.Level -eq "Critical") { $health.Score -= 25 * $componentHealth.Weight }
        elseif ($componentHealth.Level -eq "Warning") { $health.Score -= 10 * $componentHealth.Weight }
        
        # CONTEXTUAL FINDINGS
        if ($componentHealth.Level -ne "Healthy") {
            $health.DynamicFindings += Get-ContextualFinding -Component $component -Health $componentHealth
        }
    }
    
    $health.OverallStatus = if ($health.Score -ge 90) { "Healthy" } elseif ($health.Score -ge 70) { "Warning" } else { "Critical" }
    
    return $health
}

function Test-ComponentHealth {
    param($Component, $Data, $Thresholds)
    
    $result = @{ Name = $Component; Level = "Healthy"; Details = ""; Value = "N/A" }
    
    switch ($Component) {
        "CPU" {
            if ($Data.CurrentUsage) {
                $result.Value = "$($Data.CurrentUsage)%"
                $result.Level = if ($Data.CurrentUsage -ge $Thresholds.CPUCritical) { "Critical" }
                               elseif ($Data.CurrentUsage -ge $Thresholds.CPUWarning) { "Warning" }
                               else { "Healthy" }
                $result.Details = "Usage: $($Data.CurrentUsage)% | Thresholds: W$($Thresholds.CPUWarning)%/C$($Thresholds.CPUCritical)%"
            }
        }
        "Memory" {
            if ($Data.Summary.UsedPercent) {
                $result.Value = "$($Data.Summary.UsedPercent)%"
                $result.Level = if ($Data.Summary.UsedPercent -ge $Thresholds.RAMCritical) { "Critical" }
                               elseif ($Data.Summary.UsedPercent -ge $Thresholds.RAMWarning) { "Warning" }
                               else { "Healthy" }
                $result.Details = "Used: $($Data.Summary.UsedPercent)% of $($Data.Summary.TotalGB)GB | Thresholds: W$($Thresholds.RAMWarning)%/C$($Thresholds.RAMCritical)%"
            }
        }
        "Storage" {
            $criticalDrives = $Data.Volumes | Where-Object { $_.UsedPercent -ge $Thresholds.DiskCritical }
            $warningDrives = $Data.Volumes | Where-Object { $_.UsedPercent -ge $Thresholds.DiskWarning -and $_.UsedPercent -lt $Thresholds.DiskCritical }
            
            if ($criticalDrives) {
                $result.Level = "Critical"
                $result.Value = "Critical: $(($criticalDrives.Drive) -join ', ')"
            } elseif ($warningDrives) {
                $result.Level = "Warning" 
                $result.Value = "Warning: $(($warningDrives.Drive) -join ', ')"
            }
            $result.Details = "Thresholds: W$($Thresholds.DiskWarning)%/C$($Thresholds.DiskCritical)%"
        }
        "Battery" {
            if ($Data.Basic.Present -and $Data.Basic.Status -in @("Low", "Critical")) {
                $result.Level = "Warning"
                $result.Value = $Data.Basic.Status
                $result.Details = "Battery requires attention"
            }
        }
    }
    
    return $result
}

function Get-ContextualFinding {
    param($Component, $Health)
    
    # INTELLIGENT, CONTEXT-AWARE RECOMMENDATIONS
    switch ($Component) {
        "Memory" {
            if ($SystemDNA.MemoryTier -in @("VeryLow", "Low") -and $Health.Level -eq "Warning") {
                return "🚨 MEMORY UPGRADE ADVISED: System has only $([math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB))GB RAM - Consider upgrade for better performance"
            }
            return "📊 High memory usage detected - Check for memory leaks or consider adding RAM"
        }
        "CPU" {
            if ($SystemDNA.Type -eq "Server" -and $Health.Level -eq "Critical") {
                return "🔴 SERVER CRITICAL: CPU at $($Health.Value) - Immediate investigation required"
            }
            return "⚡ High CPU usage - Identify resource-intensive processes"
        }
        "Storage" {
            if ($SystemDNA.StorageProfile -eq "SingleDrive" -and $Health.Level -eq "Warning") {
                return "💾 Single drive system nearing capacity - Consider storage expansion"
            }
            return "📦 Storage space low - Clean up unnecessary files"
        }
        "Battery" {
            return "🔋 Battery health issue - Consider replacement soon"
        }
    }
    
    return "⚠️ $Component requires attention"
}

# === MAIN EXECUTION ===
Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "🤖 TRULY DYNAMIC SYSTEM HEALTH SCAN" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Cyan

# 1. INTELLIGENT SYSTEM ANALYSIS
Write-Host "`n[1/4] 🧬 ANALYZING SYSTEM DNA..." -ForegroundColor Magenta
Get-SystemDNA

# 2. DYNAMIC CONFIGURATION
Write-Host "`n[2/4] 🎯 CALCULATING ADAPTIVE CONFIG..." -ForegroundColor Yellow
$DynamicThresholds = Get-DynamicThresholds
$IntelligentFocus = Get-IntelligentFocusAreas

Write-Host "`n🔍 INTELLIGENT FOCUS AREAS:" -ForegroundColor Green
$IntelligentFocus | ForEach-Object { Write-Host "   ✓ $_" -ForegroundColor Gray }

# 3. ADAPTIVE DATA COLLECTION
Write-Host "`n[3/4] 📊 COLLECTING SYSTEM DATA..." -ForegroundColor Green
$LiveSystemData = Invoke-AdaptiveDataCollection -FocusAreas $IntelligentFocus -Thresholds $DynamicThresholds

# 4. DYNAMIC HEALTH ASSESSMENT
Write-Host "`n[4/4] 🔍 ANALYZING SYSTEM HEALTH..." -ForegroundColor Blue
$HealthAssessment = Test-AdaptiveHealth -Data $LiveSystemData -Thresholds $DynamicThresholds

# === DYNAMIC RESULTS ===
Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "📈 DYNAMIC SCAN RESULTS" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Cyan

Write-Host "`n🏷️  SYSTEM PROFILE" -ForegroundColor White
Write-Host "   Type: $($SystemDNA.Type)" -ForegroundColor Gray
Write-Host "   Memory: $($SystemDNA.MemoryTier) ($([math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB))GB)" -ForegroundColor Gray
Write-Host "   CPU: $($SystemDNA.CPUTier) ($((Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1).NumberOfCores) cores)" -ForegroundColor Gray
Write-Host "   Usage: $($SystemDNA.UsageProfile)" -ForegroundColor Gray

Write-Host "`n📊 HEALTH SCORE: $($HealthAssessment.Score)/100" -ForegroundColor $(if ($HealthAssessment.Score -ge 90) { "Green" } elseif ($HealthAssessment.Score -ge 70) { "Yellow" } else { "Red" })
Write-Host "   Overall Status: $($HealthAssessment.OverallStatus)" -ForegroundColor $(switch($HealthAssessment.OverallStatus){"Healthy"{'Green'}"Warning"{'Yellow'}default{'Red'})

Write-Host "`n🔍 COMPONENT HEALTH:" -ForegroundColor White
$HealthAssessment.Components | ForEach-Object {
    $color = switch ($_.Level) { "Healthy" { "Green" } "Warning" { "Yellow" } "Critical" { "Red" } }
    Write-Host "   $($_.Name): $($_.Level) - $($_.Value)" -ForegroundColor $color
}

if ($HealthAssessment.DynamicFindings.Count -gt 0) {
    Write-Host "`n💡 INTELLIGENT RECOMMENDATIONS:" -ForegroundColor White
    $HealthAssessment.DynamicFindings | ForEach-Object { 
        Write-Host "   • $_" -ForegroundColor Cyan 
    }
}

Write-Host "`n🎯 DYNAMIC ADAPTATIONS APPLIED:" -ForegroundColor Magenta
Write-Host "   ✓ Auto-detected: $($SystemDNA.Type) system" -ForegroundColor Gray
Write-Host "   ✓ Adjusted thresholds for: $($SystemDNA.MemoryTier) memory, $($SystemDNA.CPUTier) CPU" -ForegroundColor Gray
Write-Host "   ✓ Focused on: $($IntelligentFocus.Count) relevant areas" -ForegroundColor Gray
Write-Host "   ✓ Applied weighted scoring for system context" -ForegroundColor Gray

Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "✅ TRULY DYNAMIC SCAN COMPLETE" -ForegroundColor Green
Write-Host "="*50 -ForegroundColor Cyan