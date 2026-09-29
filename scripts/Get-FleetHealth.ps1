#Requires -Modules AWS.Tools.EC2, AWS.Tools.SimpleSystemsManagement, AWS.Tools.CloudWatch, AWS.Tools.SecurityToken

<#
.SYNOPSIS
    Fleet-wide health report for the Project-IaC-Advanced EC2 hosts.

.DESCRIPTION
    Queries every running EC2 instance tagged Project=terraform-advanced, runs a
    lightweight health probe on each over SSM Run Command (no SSH required),
    pulls the latest CloudWatch datapoints for CPU and status checks, and prints
    a fleet status table. Optionally exports the same data as HTML/CSV for
    "regulatory evidence"-style record keeping.

    Everything here runs as YOUR local IAM identity (via the AWS CLI/PowerShell
    credentials already configured for Terraform), not as the instances' IAM
    role - the two are separate permission boundaries. If this script gets
    AccessDenied on CloudWatch or SSM calls, check `Get-STSCallerIdentity`
    first before assuming the instance role is misconfigured.

.PARAMETER ProjectTag
    Value of the Project tag to filter instances by. Defaults to the tag value
    Terraform's default_tags block sets on everything in this project.

.PARAMETER Region
    AWS region to query. Defaults to us-east-1, matching the project's
    aws_region default.

.PARAMETER ReportPath
    Optional. If supplied, also writes a timestamped HTML and CSV report to
    this directory (created if it doesn't exist). Intended for a git-ignored
    local `reports/` folder - these are point-in-time snapshots, not meant to
    be committed.

.PARAMETER SkipCommandProbe
    Skip the SSM Run Command health probe (uptime / disk / nginx / last
    telemetry-upload.service run from the journal) and only report EC2 +
    CloudWatch data. Useful for a
    quick check when you don't need the extra ~10-20 seconds the Run Command
    round-trip takes per instance.

.EXAMPLE
    .\Get-FleetHealth.ps1

    Prints a fleet status table to the console.

.EXAMPLE
    .\Get-FleetHealth.ps1 -ReportPath .\reports

    Prints the table AND writes reports\fleet-health-<timestamp>.html and .csv.
#>

[CmdletBinding()]
param(
    [string]$ProjectTag = "terraform-advanced",

    [string]$Region = "us-east-1",

    [string]$ReportPath,

    [switch]$SkipCommandProbe
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ("-" * $Text.Length) -ForegroundColor Cyan
}

# Sanity check: confirm which identity we're actually running as before
# doing anything else, since AccessDenied further down is easy to
# misattribute to the wrong set of credentials.
try {
    $identity = Get-STSCallerIdentity -Region $Region
    Write-Host "Running as: $($identity.Arn)" -ForegroundColor DarkGray
}
catch {
    throw "Could not confirm AWS identity - check your AWS CLI/PowerShell credentials are configured (aws configure / Set-AWSCredential) before running this script. Original error: $($_.Exception.Message)"
}

Write-Section "Discovering fleet (Project=$ProjectTag, region=$Region)"

$filter1 = New-Object Amazon.EC2.Model.Filter -Property @{ Name = "tag:Project"; Values = $ProjectTag }
$filter2 = New-Object Amazon.EC2.Model.Filter -Property @{ Name = "instance-state-name"; Values = "running" }

$instances = (Get-EC2Instance -Filter $filter1, $filter2 -Region $Region).Instances

if (-not $instances -or $instances.Count -eq 0) {
    Write-Host "No running instances found with tag Project=$ProjectTag in $Region." -ForegroundColor Yellow
    Write-Host "Either the fleet isn't applied right now, or it's tagged/regioned differently than expected." -ForegroundColor Yellow
    return
}

Write-Host "Found $($instances.Count) running instance(s)."

$results = foreach ($instance in $instances) {
    $nameTag = ($instance.Tags | Where-Object { $_.Key -eq "Name" }).Value
    if (-not $nameTag) { $nameTag = $instance.InstanceId }

    Write-Host "  Checking $nameTag ($($instance.InstanceId))..." -ForegroundColor DarkGray

    # --- CloudWatch: latest CPU and status-check datapoints ---
    $now = (Get-Date).ToUniversalTime()
    $cpuStat = Get-CWMetricStatistic -Namespace "AWS/EC2" -MetricName "CPUUtilization" `
        -Dimension @{ Name = "InstanceId"; Value = $instance.InstanceId } `
        -StartTime $now.AddMinutes(-15) -EndTime $now -Period 300 `
        -Statistic Average -Region $Region -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Datapoints |
        Sort-Object Timestamp -Descending | Select-Object -First 1

    $statusCheckStat = Get-CWMetricStatistic -Namespace "AWS/EC2" -MetricName "StatusCheckFailed" `
        -Dimension @{ Name = "InstanceId"; Value = $instance.InstanceId } `
        -StartTime $now.AddMinutes(-15) -EndTime $now -Period 300 `
        -Statistic Maximum -Region $Region -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Datapoints |
        Sort-Object Timestamp -Descending | Select-Object -First 1

    $cpuValue = if ($cpuStat) { [math]::Round($cpuStat.Average, 1) } else { $null }
    $statusCheckFailed = if ($statusCheckStat) { [int]$statusCheckStat.Maximum -eq 1 } else { $null }

    # --- SSM Run Command: live probe of the box itself ---
    $probeOutput = $null
    $probeStatus = "skipped"

    if (-not $SkipCommandProbe) {
        try {
            $probeScript = @(
                'echo "--UPTIME--"; uptime',
                'echo "--DISK--"; df -h / | tail -1',
                'echo "--NGINX--"; systemctl is-active nginx',
                'echo "--LAST-TELEMETRY--"; journalctl -u telemetry-upload.service -n 1 --no-pager -o short-iso 2>/dev/null | grep -v "^-- " || echo "no telemetry runs found"'
            ) -join "; "

            $send = Send-SSMCommand -InstanceId $instance.InstanceId `
                -DocumentName "AWS-RunShellScript" `
                -Parameter @{ commands = $probeScript } `
                -Region $Region

            # Run Command is async - poll briefly for completion rather than
            # assuming it's instant.
            $deadline = (Get-Date).AddSeconds(20)
            do {
                Start-Sleep -Seconds 2
                $invocation = Get-SSMCommandInvocationDetail -CommandId $send.CommandId -InstanceId $instance.InstanceId -Region $Region -ErrorAction SilentlyContinue
            } while ($invocation -and $invocation.Status -in @("Pending", "InProgress") -and (Get-Date) -lt $deadline)

            if ($invocation -and $invocation.Status -eq "Success") {
                $probeOutput = $invocation.StandardOutputContent
                $probeStatus = "ok"
            }
            elseif ($invocation) {
                $probeStatus = "failed: $($invocation.Status)"
            }
            else {
                $probeStatus = "timed out waiting for result"
            }
        }
        catch {
            # Most common cause: SSM agent not yet registered (just booted) or
            # the instance role is missing AmazonSSMManagedInstanceCore.
            $probeStatus = "error: $($_.Exception.Message)"
        }
    }

    [PSCustomObject]@{
        Name              = $nameTag
        InstanceId        = $instance.InstanceId
        State             = $instance.State.Name
        PrivateIp         = $instance.PrivateIpAddress
        CpuPercent        = $cpuValue
        StatusCheckFailed = $statusCheckFailed
        SsmProbe          = $probeStatus
        ProbeOutput       = $probeOutput
    }
}

Write-Section "Fleet status"
$results | Format-Table Name, InstanceId, State, PrivateIp, CpuPercent, StatusCheckFailed, SsmProbe -AutoSize

$failing = $results | Where-Object { $_.StatusCheckFailed -eq $true -or $_.SsmProbe -like "error:*" -or $_.SsmProbe -like "failed:*" }
if ($failing) {
    Write-Host ""
    Write-Host "$($failing.Count) host(s) need attention:" -ForegroundColor Red
    foreach ($f in $failing) {
        Write-Host "  - $($f.Name): status-check-failed=$($f.StatusCheckFailed), ssm-probe=$($f.SsmProbe)" -ForegroundColor Red
    }
}
else {
    Write-Host ""
    Write-Host "All hosts reporting healthy." -ForegroundColor Green
}

if (-not $SkipCommandProbe) {
    Write-Section "Probe detail"
    foreach ($r in $results) {
        Write-Host "$($r.Name):" -ForegroundColor White
        if ($r.ProbeOutput) {
            Write-Host $r.ProbeOutput
        }
        else {
            Write-Host "  (no probe output - $($r.SsmProbe))" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

if ($ReportPath) {
    if (-not (Test-Path $ReportPath)) {
        New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $csvPath = Join-Path $ReportPath "fleet-health-$timestamp.csv"
    $htmlPath = Join-Path $ReportPath "fleet-health-$timestamp.html"

    $results | Select-Object Name, InstanceId, State, PrivateIp, CpuPercent, StatusCheckFailed, SsmProbe |
        Export-Csv -Path $csvPath -NoTypeInformation

    $htmlFragment = $results |
        Select-Object Name, InstanceId, State, PrivateIp, CpuPercent, StatusCheckFailed, SsmProbe |
        ConvertTo-Html -Fragment -PreContent "<h1>Fleet Health Report</h1><p>Generated $timestamp UTC by Get-FleetHealth.ps1</p>"

    $htmlFragment | Out-File -FilePath $htmlPath -Encoding utf8

    Write-Section "Report written"
    Write-Host "CSV:  $csvPath"
    Write-Host "HTML: $htmlPath"
}
