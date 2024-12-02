
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


function Insert-DeviceStatus {
    param(
        [string]$IPAddress,
        [int]$Status
    )
    
    $SQLServer = "localhost\SQLEXPRESS"
    $SQLDBName = "project"
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $SQLQuery = "INSERT INTO NetworkDevices (IPAddress, Status, Timestamp) VALUES ('$IPAddress', $Status, '$Timestamp');"
    Execute-SQLQuery -SQLServer $SQLServer -SQLDBName $SQLDBName -SQLQuery $SQLQuery
}

#המיקום בו מכניסים את הכתובות של המתגים, המדפסות, חומות האש, מוצרי האחסון 
$ipList = @("127.0.0.1")

foreach ($ip in $ipList) {
    $pingResult = Test-Connection -ComputerName $ip -Count 1 -Quiet
    if ($pingResult) {
        Write-Host "Ping to $ip successful: 1"
        Insert-DeviceStatus -IPAddress $ip -Status 1
    } else {
        Write-Host "Ping to $ip failed: 0"
        Insert-DeviceStatus -IPAddress $ip -Status 0
    }
}
