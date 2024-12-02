function Get-CredentialsFromFile {
    param (
        [string]$usernameFilePath,
        [string]$passwordFilePath
    )

    $SQLUsername = Get-Content $usernameFilePath
    $SQLPassword = Get-Content $passwordFilePath

    return @{
        Username = $SQLUsername.Trim()
        Password = $SQLPassword.Trim()
    }
}


function Execute-SQLQuery {
    param (
        [string]$SQLServer,
        [string]$SQLDBName,
        [string]$SQLQuery,
        [string]$SQLUsername,
        [string]$SQLPassword
    )

    Add-Type -AssemblyName System.Data
    
    $SQLConnection = New-Object System.Data.SqlClient.SqlConnection
    $SQLConnection.ConnectionString = "Server=$SQLServer;Database=$SQLDBName;User Id=$SQLUsername;Password=$SQLPassword;Connection Timeout=10;"
    
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
        [string]$value,
        [string]$SQLUsername,
        [string]$SQLPassword
    )
    
    $SQLServer = "localhost\SQLEXPRESS"  
    $SQLDBName = "project"  

    $SQLQuery = "INSERT INTO RemoteServerLogs (ServerName, Metric, JsonData) VALUES ('$serverName', '$metric', '$value');"
    $result = Execute-SQLQuery -SQLServer $SQLServer -SQLDBName $SQLDBName -SQLQuery $SQLQuery -SQLUsername $SQLUsername -SQLPassword $SQLPassword

    return $result
}


$usernameFilePath = "\\filessrv1\c$\config\sql_username.txt"
$passwordFilePath = "\\filessrv1\c$\config\sql_password.txt"

$credentials = Get-CredentialsFromFile -usernameFilePath $usernameFilePath -passwordFilePath $passwordFilePath


$server = hostname
$cpuUsage = (Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
Insert-DataToSQL -serverName $server -metric "CPU Usage" -value "$cpuUsage%" -SQLUsername $credentials.Username -SQLPassword $credentials.Password


$memInfo = Get-WmiObject -Class Win32_OperatingSystem
$memUsage = [math]::round((($memInfo.TotalVisibleMemorySize - $memInfo.FreePhysicalMemory) / $memInfo.TotalVisibleMemorySize) * 100, 2)
Insert-DataToSQL -serverName $server -metric "Memory Usage" -value "$memUsage%"


$drive = Get-PSDrive -Name C
$diskFreeGB = [math]::round($drive.Free / 1GB, 2)
Insert-DataToSQL -serverName $server -metric "Disk C Free Space (GB)" -value "$diskFreeGB GB"


$admins = Get-WmiObject -Class Win32_GroupUser | Where-Object { $_.GroupComponent -match 'Administrators' } | ForEach-Object { ([WMI]$_.PartComponent).Name }
foreach ($admin in $admins) {
    Insert-DataToSQL -serverName $server -metric "Local Admin" -value "$admin"
}


$rdpUsers = Get-WmiObject -Class Win32_GroupUser | Where-Object { $_.GroupComponent -match 'Remote Desktop Users' } | ForEach-Object { ([WMI]$_.PartComponent).Name }
foreach ($rdpUser in $rdpUsers) {
    Insert-DataToSQL -serverName $server -metric "RDP User" -value "$rdpUser"
}


$firewallProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled
foreach ($profile in $firewallProfiles) {
    $fwStatus = if ($profile.Enabled) { "Enabled" } else { "Disabled" }
    Insert-DataToSQL -serverName $server -metric "Firewall Status - $($profile.Name)" -value "$fwStatus"
}


$failedLogins = Get-EventLog -LogName Security -EntryType FailureAudit -InstanceId 4625 | Select-Object TimeGenerated, Message
foreach ($log in $failedLogins) {
    $logEntry = "Time: $($log.TimeGenerated), Message: $($log.Message)"
    Insert-DataToSQL -serverName $server -metric "Failed Login Attempt" -value "$logEntry"
}


Insert-DataToSQL -serverName $server -metric "Health Check" -value "OK"
