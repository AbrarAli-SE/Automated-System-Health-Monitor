<#
.SYNOPSIS
    Automated System Health Monitor (ASHM) - Windows Core Report Generation.
    This script gathers system data (OS, CPU, Memory, Disk) and generates a
    visually formatted HTML report file.
#>

# --- Configuration ---
$ReportFileName = "system_health_report_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".html"
$ReportTitle = "System Health Report - $(Get-ComputerInfo -Property CsName | Select-Object -ExpandProperty CsName)"
$SystemStatus = "OK"

# --- Utility Function for Data Collection ---
function Get-DataHtmlBlock {
    param(
        [string]$Title,
        [string]$Content
    )
    $HTML = @"
    <h2>$Title</h2>
    <pre>$Content</pre>
"@
    return $HTML
}

# --- Data Collection ---
Write-Host "Gathering system data for Windows..."

# 1. Computer & OS Info
$OSInfo = Get-ComputerInfo -Property WindowsProductName, CsName, OsVersion, OsBuildNumber, OsArchitecture | Out-String
$HostName = Get-ComputerInfo -Property CsName | Select-Object -ExpandProperty CsName
$CurrentDate = Get-Date -Format "F"

# 2. CPU & Load
$CPUInfo = Get-ComputerInfo -Property CsProcessors | Out-String
# Get CPU utilization percentage over a very short sample interval
$LoadAverage = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue | Out-String
$TopProcesses = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 -Property ProcessName, Id, CPU, WorkingSet | Format-Table -AutoSize | Out-String

# 3. Memory (RAM) Info
$TotalMemoryGB = [Math]::Round(((Get-ComputerInfo -Property TotalPhysicalMemory).TotalPhysicalMemory / 1GB), 2)
$FreeMemoryGB = [Math]::Round(((Get-ComputerInfo -Property FreePhysicalMemory).FreePhysicalMemory / 1GB), 2)
$MemoryInfo = @"
Total RAM: $TotalMemoryGB GB
Free RAM: $FreeMemoryGB GB
"@

# 4. Storage (Disk Space)
# Exclude system volumes (like C:) to make 'df -h' look-alike data cleaner, focusing on usage
$DiskInfo = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3} | Select-Object DeviceID, @{Name="Size (GB)";Expression={[Math]::Round($_.Size / 1GB, 2)}}, @{Name="Free (GB)";Expression={[Math]::Round($_.Freespace / 1GB, 2)}}, @{Name="Used (%)";Expression={[Math]::Round((($_.Size - $_.Freespace) / $_.Size) * 100, 0)}} | Format-Table -AutoSize | Out-String

# 5. BIOS/Internal Hardware Info
$BiosInfo = Get-ComputerInfo -Property BiosManufacturer, BiosSeralNumber | Out-String

# --- HTML Content Generation (EMOJIS REMOVED FOR STABILITY) ---
$ReportContent = ""
$ReportContent += Get-DataHtmlBlock "System Identity & OS" $OSInfo
$ReportContent += Get-DataHtmlBlock "Processor and Architecture" $CPUInfo
$ReportContent += Get-DataHtmlBlock "Memory Usage" $MemoryInfo
$ReportContent += Get-DataHtmlBlock "Disk Space Utilization" $DiskInfo
$ReportContent += Get-DataHtmlBlock "Real-Time Load" $LoadAverage
$ReportContent += Get-DataHtmlBlock "Top 5 CPU-Consuming Processes" $TopProcesses
$ReportContent += Get-DataHtmlBlock "BIOS/Internal Hardware Details" $BiosInfo


# --- Final HTML Structure ---
$HTMLReport = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ReportTitle</title>
    <style>
        body {
            font-family: Inter, sans-serif;
            background-color: #f0f4f8;
            color: #333;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background: #ffffff;
            padding: 30px;
            border-radius: 12px;
            box-shadow: 0 10px 20px rgba(0, 0, 0, 0.1);
        }
        h1 {
            color: #4CAF50; /* Green theme */
            border-bottom: 3px solid #4CAF50;
            padding-bottom: 10px;
            margin-bottom: 25px;
            font-weight: 700;
        }
        h2 {
            color: #2E7D32; /* Darker green */
            margin-top: 30px;
            padding-left: 10px;
            border-left: 5px solid #2E7D32;
            font-weight: 600;
        }
        pre, code {
            background-color: #e8f5e9; /* Light green background */
            padding: 15px;
            border-radius: 8px;
            overflow-x: auto;
            white-space: pre-wrap;
            word-wrap: break-word;
            border: 1px solid #c8e6c9;
            font-size: 0.9em;
        }
        p strong {
            color: #388E3C;
        }
    </style>
</head>
<body>

<div class="container">
    <h1>Automated System Health Monitor (ASHM) Report</h1>
    <p><strong>Hostname:</strong> $HostName</p>
    <p><strong>Generated on:</strong> $CurrentDate</p>
    
    $ReportContent

    <p style="text-align: center; margin-top: 40px; color: #757575;">End of ASHM Windows Core Report</p>
</div>

</body>
</html>
"@

# --- Write the Report ---
$HTMLReport | Out-File -FilePath $ReportFileName -Encoding UTF8

Write-Host "✅ Report successfully generated: $ReportFileName"
Write-Host "Open the file in your web browser to view the formatted report."