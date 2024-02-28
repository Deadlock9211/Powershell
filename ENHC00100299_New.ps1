# Fetching the VM credential
try {
    $vCenterCredential = Get-Credential #-Target $configFile.vCenterCredential
    $vCenterDetails = $configFile.vCenterServerName -split ','
}
catch {
    & $LogEntry -LogMessage "ERROR - $_"
}

# Define your vCenter server details
$vCenterServer = ""
$vCenterUsername = $vCenterCredential.Username
$vCenterPassword = $vCenterCredential.GetNetworkCredential().Password

# Connect to vCenter server
Connect-VIServer -Server $vCenterServer -User $vCenterUsername -Password $vCenterPassword

# 1. General Details
$vcDetails = Get-View ServiceInstance
$vcName = $vcDetails.Content.About.Name
$vcVersion = $vcDetails.Content.About.Version
$vcBuild = $vcDetails.Content.About.Build

# 2. Number of Hosts
$hostCount = Get-VMHost | Measure-Object | Select-Object -ExpandProperty Count

# 3. Number of Templates
$templateCount = (Get-VM | Where-Object { $_.ExtensionData.Config.Template }).Count

# 4. Hosts in Maintenance Mode
$hostsMaintenance = Get-VMHost | Where-Object { $_.ConnectionState -eq "Maintenance" } count

# 5. Hosts in Disconnected State
$hostsDisconnected = Get-VMHost | Where-Object { $_.ConnectionState -eq "Disconnected" } count

# 6. NTP Server check for a given NTP Name
#$ntpName = "your_ntp_server_name"
#$ntpHosts = Get-VMHost | Where-Object { $_.ExtensionData.Config.DateTimeInfo.NtpConfig | Where-Object { $_.Service.Enabled -eq $true -and $_.Service.Server -contains $ntpName } }

# NTP Service check
$ntpService = Get-VMHost | Get-VMHostService | Where-Object { $_.Key -eq "ntpd" } | ConvertTo-Html -Property Name,Running,Status
$ntpServices = Get-VMHost; $runningNTP = @(); $stoppedNTP = @(); foreach ($host in $hosts) { $ntpService = $host | Get-VMHostService | Where-Object { $_.Key -eq "ntpd" } }

$activeAlerts = Get-Alarm -Entity (Get-VMHost) | Where-Object { $_.Enabled -eq $true }

# Dead SCSI Luns
$deadLuns = Get-VMHost | Get-ScsiLun | Where-Object { $_.MultipathPolicy -eq "Dead" }

# Disconnect from vCenter server
Disconnect-VIServer -Server $vCenterServer -Confirm:$false

# Generate the output report in HTML
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>vCenter Server Report</title>
    <style>
        body {
            text-align: center;
        }
        .table-container {
            margin: 20px auto;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            border: 1px solid black;
            padding: 8px;
            text-align: left;
        }
        th {
            background-color: #f2f2f2;
        }
    </style>
</head>
<body>
    <h1>ESXI Health Check Report</h1>

    <div class="table-container">
        <h2>General Details</h2>
        <table>
            <tr>
                <th>vCenter Name</th>
                <td>$vcName</td>
            </tr>
            <tr>
                <th>vCenter Version</th>
                <td>$vcVersion</td>
            </tr>
            <tr>
                <th>vCenter Build</th>
                <td>$vcBuild</td>
            </tr>
        </table>
    </div>

    <div class="table-container">
        <h2>Hosts Details</h2>
        <table>
            <tr>
                <th>Number of Hosts</th>
            </tr>
            <tr>
                <td>$hostCount</td>
            </tr>
        </table>
    </div>

    <div class="table-container">
        <h2>Templates Details</h2>
        <table>
            <tr>
                <th>Number of Templates</th>
            </tr>
            <tr>
                <td>$templateCount</td>
            </tr>
        </table>
    </div>

    <div class="table-container">
        <h2>Hosts in Maintenance Mode</h2>
        <table>
            <tr>
                <th>Hosts in Maintenance Mode</th>
            </tr>
            <tr>
                <td>$($hostsMaintenance -join ", ")</td>
            </tr>
        </table>
    </div>

    <div class="table-container">
        <h2>Hosts in Disconnected State</h2>
        <table>
            <tr>
                <th>Hosts in Disconnected State</th>
            </tr>
            <tr>
                <td>$($hostsDisconnected -join ", ")</td>
            </tr>
        </table>
    </div>

    <div class="table-container">
        <h2>NTP Service Check</h2>
        <table>
            <tr>
                <th>NTP Service Status</th>
            </tr>
            <tr>
                <td>$($ntpService.ServiceState)</td>
            </tr>
        </table>
    </div>
"@

$htmlContent += @"
        <h2>Host Active Alerts</h2>
        <table>
"@


foreach ($alert in $activeAlerts) {
$htmlContent += @"
            <tr>
                <th>Active Alerts</th>
            </tr>
            <tr>
                <td>$($alert)</td>
            </tr>
        </table>
 
"@
}

$htmlContent += @"
    <div class="table-container">
        <h2>Dead SCSI Luns</h2>
        <table>
            <tr>
                <th>Dead LUNs</th>
            </tr>
            <tr>
                <td>$($deadLuns -join ", ")</td>
            </tr>
        </table>
    </div>

</body>
</html>

"@

# Save the HTML report to a file
$htmlContent | Out-File -FilePath "C:\Users\SAMADANK\Desktop\output0194.html" -Encoding UTF8
