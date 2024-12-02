
$apiUrl = "http://moriyaprojectsnonrealurl.nir.co.il/rest/api/expierdprojects"
$username = "Monitor"
$password = "Aa123456"
$apiName = "ExpiredProjectsAPI"
$method = "GET"
$apiid = 1


$credential = New-Object System.Management.Automation.PSCredential ($username, (ConvertTo-SecureString $password -AsPlainText -Force))

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


function Insert-ApiResponseLog {
    param(
        [string]$apiName,
        [string]$method,
        [string]$value, 
	
    )
    
    $SQLServer = "localhost\SQLEXPRESS"
    $SQLDBName = "project"
    
    $SQLQuery = "INSERT INTO ApiData (APIid, ApiName, Method, Value) VALUES ('$apiid', '$apiName', '$method', '$value');"
    $result = Execute-SQLQuery -SQLServer $SQLServer -SQLDBName $SQLDBName -SQLQuery $SQLQuery
    return $result
}


try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Credential $credential

       $numberOfExpiredProjects = $response

      Write-Output "Number of projects in violation: $numberOfExpiredProjects"

      $insertResult = Insert-ApiResponseLog -apiName $apiName -method $method -value $numberOfExpiredProjects
    Write-Output $insertResult

} catch {
    Write-Output "Error accessing API: $_"
}
