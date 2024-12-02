#חובה להריץ את הסקריפט הזה כאדמין על מנת לקבל מידע מכלל הכפתורים
 
 Add-Type -AssemblyName System.Windows.Forms

function Execute-SQLQuery {
    param (
        [string]$SQLServer,
        [string]$SQLDBName,
        [string]$SQLQuery
    )

    Add-Type -AssemblyName System.Data
   
    $SQLConnection = New-Object System.Data.SqlClient.SqlConnection
    $SQLConnection.ConnectionString = "Server=$SQLServer;Database=$SQLDBName;Trusted_Connection=yes;Connection Timeout=10;"
   
    $SQLCommand = New-Object System.Data.SqlClient.SqlCommand
    $SQLCommand.CommandText = $SQLQuery
    $SQLCommand.Connection = $SQLConnection

    try {
        $SQLConnection.Open()
        $SQLCommand.ExecuteNonQuery() | Out-Null
        $SQLConnection.Close()
        return "Query executed successfully."
    } catch {
        return "Error executing query: $_"
    }
}

function Insert-DataToSQL {
    param(
        [string]$serverName,
        [string]$metric,
        [string[]]$values
    )
   
    $SQLServer = "localhost\SQLEXPRESS"
    $SQLDBName = "project"
   
    foreach ($value in $values) {
        $SQLQuery = "INSERT INTO RemoteServerLogs (ServerName, Metric, JsonData) VALUES ('$serverName', '$metric', '$value');"
        $result = Execute-SQLQuery -SQLServer $SQLServer -SQLDBName $SQLDBName -SQLQuery $SQLQuery
    }
   
    return "Data inserted successfully."
}

$form = New-Object system.windows.forms.Form
$form.Text = "Remote Server Management"
$form.Size = New-Object System.Drawing.Size(500,400)
$form.StartPosition = "CenterScreen"

$labelServer = New-Object System.Windows.Forms.Label
$labelServer.Text = "Enter Remote Server Name:"
$labelServer.Size = New-Object System.Drawing.Size(150,20)
$labelServer.Location = New-Object System.Drawing.Point(10,20)
$form.Controls.Add($labelServer)

$txtServer = New-Object System.Windows.Forms.TextBox
$txtServer.Size = New-Object System.Drawing.Size(300,20)
$txtServer.Location = New-Object System.Drawing.Point(170,20)
$form.Controls.Add($txtServer)

$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.Size = New-Object System.Drawing.Size(450,150)
$outputBox.Location = New-Object System.Drawing.Point(10,250)
$form.Controls.Add($outputBox)

function Display-Output {
    param([string]$message)
    $outputBox.Text += "$message`r`n"
}

$btnCpu = New-Object System.Windows.Forms.Button
$btnCpu.Text = "Get CPU Usage"
$btnCpu.Size = New-Object System.Drawing.Size(200,30)
$btnCpu.Location = New-Object System.Drawing.Point(10,60)
$btnCpu.Add_Click({
    $server = $txtServer.Text
    if ($server) {
        $cpuUsage = (Get-WmiObject -ComputerName $server -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        Display-Output "CPU Usage on ${server}: $cpuUsage%"
        Insert-DataToSQL -serverName $server -metric "CPU Usage" -values @("$cpuUsage")
    } else {
        Display-Output "Please enter a server name."
    }
})
$form.Controls.Add($btnCpu)

$btnMemory = New-Object System.Windows.Forms.Button
$btnMemory.Text = "Get Memory Usage"
$btnMemory.Size = New-Object System.Drawing.Size(200,30)
$btnMemory.Location = New-Object System.Drawing.Point(220,60)
$btnMemory.Add_Click({
    $server = $txtServer.Text
    if ($server) {
        $memInfo = Get-WmiObject -ComputerName $server -Class Win32_OperatingSystem
        $memUsage = [math]::round((($memInfo.TotalVisibleMemorySize - $memInfo.FreePhysicalMemory) / $memInfo.TotalVisibleMemorySize) * 100, 2)
        Display-Output "Memory Usage on ${server}: $memUsage%"
        Insert-DataToSQL -serverName $server -metric "Memory Usage" -values @("$memUsage")
    } else {
        Display-Output "Please enter a server name."
    }
})
$form.Controls.Add($btnMemory)

$btnAdmins = New-Object System.Windows.Forms.Button
$btnAdmins.Text = "List Local Admins"
$btnAdmins.Size = New-Object System.Drawing.Size(200,30)
$btnAdmins.Location = New-Object System.Drawing.Point(10,100)
$btnAdmins.Add_Click({
    $server = $txtServer.Text
    if ($server) {
        $admins = Get-WmiObject -ComputerName $server -Class Win32_GroupUser | Where-Object { $_.GroupComponent -match 'Administrators' } | ForEach-Object { ([WMI]$_.PartComponent).Name }
        Display-Output "Local Administrators on ${server}: $($admins -join ', ')"
        Insert-DataToSQL -serverName $server -metric "Local Admins" -values $admins
    } else {
        Display-Output "Please enter a server name."
    }
})
$form.Controls.Add($btnAdmins)

$btnFirewall = New-Object System.Windows.Forms.Button
$btnFirewall.Text = "Check Firewall Status"
$btnFirewall.Size = New-Object System.Drawing.Size(200,30)
$btnFirewall.Location = New-Object System.Drawing.Point(220,100)
$btnFirewall.Add_Click({
    $server = $txtServer.Text
    if ($server) {
        $firewallStatus = Invoke-Command -ComputerName $server -ScriptBlock {
            Get-NetFirewallProfile | Select-Object Name, Enabled
        }
        foreach ($status in $firewallStatus) {
            Display-Output "Firewall status on ${server} for $($status.Name): $($status.Enabled)"
            Insert-DataToSQL -serverName $server -metric "Firewall Status - $($status.Name)" -values @("$($status.Enabled)")
        }
    } else {
        Display-Output "Please enter a server name."
    }
})
$form.Controls.Add($btnFirewall)

$btnRdpUsers = New-Object System.Windows.Forms.Button
$btnRdpUsers.Text = "List RDP Users"
$btnRdpUsers.Size = New-Object System.Drawing.Size(200,30)
$btnRdpUsers.Location = New-Object System.Drawing.Point(10,140)
$btnRdpUsers.Add_Click({
    $server = $txtServer.Text
    if ($server) {
        $rdpUsers = Get-WmiObject -ComputerName $server -Class Win32_GroupUser | Where-Object { $_.GroupComponent -match 'Remote Desktop Users' } | ForEach-Object { ([WMI]$_.PartComponent).Name }
        Display-Output "Remote Desktop Users on ${server}: $($rdpUsers -join ', ')"
        Insert-DataToSQL -serverName $server -metric "RDP Users" -values $rdpUsers
    } else {
        Display-Output "Please enter a server name."
    }
})
$form.Controls.Add($btnRdpUsers)

$btnFailedAuth = New-Object System.Windows.Forms.Button
$btnFailedAuth.Text = "Check Failed Auth Logs"
$btnFailedAuth.Size = New-Object System.Drawing.Size(200,30)
$btnFailedAuth.Location = New-Object System.Drawing.Point(220,140)
$btnFailedAuth.Add_Click({
    $server = $txtServer.Text
    if ($server) {
        $logs = Invoke-Command -ComputerName $server -ScriptBlock {
            Get-EventLog -LogName Security -EntryType FailureAudit -InstanceId 4625 | Select-Object TimeGenerated, Message
        }
        foreach ($log in $logs) {
            $logEntry = "Time: $($log.TimeGenerated), Message: $($log.Message)"
            Display-Output "Failed Authentication Log on ${server}: $logEntry"
            Insert-DataToSQL -serverName $server -metric "Failed Auth Logs" -values @($logEntry)
        }
    } else {
        Display-Output "Please enter a server name."
    }
})
$form.Controls.Add($btnFailedAuth)

$form.ShowDialog()
