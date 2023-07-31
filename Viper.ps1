function Write-LogMessage($message, $foregroundColor = 'White') {
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colorMessage = "$date - $message"
    Microsoft.PowerShell.Utility\Write-Host -ForegroundColor $foregroundColor $colorMessage
}

function Get-TenantName {
    Connect-AzureAD
    try {
        # Get tenant details
        $tenantDetail = Get-AzureADTenantDetail

        # Return the display name of the tenant
        return $tenantDetail.VerifiedDomain
    }
    catch {
        Write-Output "Error while fetching the tenant name: $_"
        exit
    }
}




function Show-Logo {
    Clear-Host
    $logo = @"
                                                                                    
                                                           ,                    
          &@@@@@@@@@@@@@@@&                          *@@@@@@@@@@@@@@@@/         
          @@@@@@@@@@@@@@@@@@@@@@.              .@@@@@@@@@@@@@@@@@@@@@@*         
           @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.          
        &@. ,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  /@,       
   (@   @@.   .@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@    @@@  #@.  
  @@@@@@@@@      ,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%      &@@@@@@@@/ 
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@. 
   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.  
 %   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,   .
  @.    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#    %@ 
   @@@      @@@@@@@@@@@@@@@@@      @@@@@@@@@@&     &@@@@@@@@@@@@@@@@,     .@@@  
    @@@@@            .(@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@/.            .@@@@%   
     .@@@@(      @@@@@@@/    @@@@@@@@@@( /@@@@@@@@@%    @@@@@@@       @@@@@     
       &@@@@      @@@@@@@@@                           @@@@@@@@.      @@@@,      
         @@@@*      @@@@@@@                          .@@@@@@@      @@@@&        
          .@@@@      %@@@@@                          @@@@@@       @@@@          
            @@@@       #@@@@                         @@@@        @@@(           
              @@@.        @@.                       @@&        #@@@             
               @@@/                                           @@@/              
                ,@@@                                         @@@                
                  @@@                                       @@@                 
                   @@/                                     @@@                  
                    @@                                     @#                   
                     @       *                    #        /                    
                             @@                  ,@,                            
                             @@@/               @@@@                            
                             @@@@@@          .@@@@@*                            
                              @@@@@@@@&. *@@@@@@@@/                             
                               #@@@@@@@@@@@@@@@@@                               
                                 .@@@@@@@@@@@@#     

"@
    $logo.ToCharArray() | ForEach-Object {
        Write-Host $_ -NoNewline
        Start-Sleep -Milliseconds .02
    }
    Write-Host ""
    Write-LogMessage "Viper" "Green"
}


function Expand-Property($object, $parentName = $null) {
    $properties = @{}
    foreach ($property in $object.PSObject.Properties) {
        $key = if ($parentName) { "$parentName.$($property.Name)" } else { $property.Name }
        if ($property.Value -is [PSCustomObject]) {
            $properties += Expand-Property -object $property.Value -parentName $key
        }
        else {
            $properties[$key] = $property.Value
        }
    }
    return $properties
}


function Format-AuditData($path, $TenantName) {
    $inputFile = "$($path)\AuditLogs_$($TenantName).csv"

    # Check if the file exists
    if (!(Test-Path -Path $inputFile)) {
        return
    }

    Write-LogMessage "Unpacking Audit Logs"

    # Read the CSV file
    $data = Import-Csv -Path $inputFile

    $outputFile = "$($path)\Converted_AuditLogs_$($TenantName).csv"

    # Initialize an empty array to hold the parsed data
    $parsedData = @()

    # Loop over each row in the data
    foreach ($row in $data) {
        # Create a new dictionary
        $rowDict = @{}

        # Add properties from the original row to the dictionary
        foreach ($property in $row.PSObject.Properties) {
            if ($property.Name -ne 'AuditData') {
                $rowDict[$property.Name] = $property.Value
            }
        }

        # Parse the JSON in the 'AuditData' column
        $auditData = ConvertFrom-Json -InputObject $row.AuditData

        # Remove the 'RecordType' property from $auditData
        $auditData.PSObject.Properties.Remove('RecordType')

        # Add properties from the parsed JSON to the dictionary
        $rowDict += Expand-Property -object $auditData

        # Convert the dictionary to a PSObject and add it to the parsed data
        $parsedData += New-Object PSObject -Property $rowDict
    }

    # Write the parsed data to a new CSV file
    $parsedData | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

    Write-LogMessage "Finished Unpacking Audit Logs" "Green"
}



function Read-UserInput {
    $userInput = Read-Host "Please enter the start date (as a number of days ago between 0 and 90, defaults to 90)"
    $startDaysAgo = $null
    
    # Set the default value if the input is empty
    if ([string]::IsNullOrWhiteSpace($userInput)) { 
        $startDaysAgo = 90 
    }
    # Validate the input if it is not empty
    elseif (![int32]::TryParse($userInput, [ref]$startDaysAgo)) {
        Write-LogMessage "Invalid input. Please enter a valid number." 'Red'
        exit
    }

    $directory = Read-Host "Please enter the directory to save the audit logs"
    
    if (!(Test-Path $directory -PathType Container)) {
        Write-LogMessage "Invalid directory. Please enter a valid directory." 'Red'
        exit
    }

    if ($startDaysAgo -lt 0 -or $startDaysAgo -gt 90) {
        Write-LogMessage "Start date should be between 0 and 90 days ago" 'Red'
        exit
    }

    return $startDaysAgo, $directory
}




function Get-DateRange($startDaysAgo) {
    [DateTime]$start = [DateTime]::UtcNow.AddDays(-$startDaysAgo)
    [DateTime]$end = Get-Date
    $end = $end.AddMinutes(-$end.Minute).AddSeconds(-$end.Second).AddMilliseconds(-$end.Millisecond)
    return $start, $end
}

function Connect-ExchangeService {
    if (!(Get-ConnectionInformation | Where-Object { $_.Name -match 'ExchangeOnline' -and $_.state -eq 'Connected' })) { 
        Connect-ExchangeOnline -ShowBanner:$false
        Write-LogMessage "Connected to Exchange" "Green"
    }
    else {
        Write-LogMessage "Already connected to Exchange Online"
    }

    $config = Get-AdminAuditLogConfig
    if ($null -eq $config -or !$config.UnifiedAuditLogIngestionEnabled) {
        Write-LogMessage "Audit logging not enabled on tenant" 'Red'
        exit
    }
}


function Get-AllAuditRecords($start, $end, $recordType, $outputPath, $TenantName) {
    $resultSize = 1000
    $sessionID = New-SessionID

    Write-LogMessage "Extracting $($recordType) Logs"

    do {
        $results = Search-AuditLog $start $end $sessionID $resultSize $outputPath $recordType
    } while ($results)

    Write-LogMessage "Finished Extracting $($recordType) Logs" "Green"
}




function Get-TimeInterval($start, $end, $intervalMinutes, $intervalCount) {
    [DateTime]$currentStart = $start.AddMinutes($intervalCount * $intervalMinutes)
    [DateTime]$currentEnd = $currentStart.AddMinutes($intervalMinutes)

    if ($currentEnd -gt $end) {
        $currentEnd = $end
    }

    return $currentStart, $currentEnd
}


function New-SessionID() {
    return [Guid]::NewGuid().ToString() + "_" + "ExtractLogs" + (Get-Date).ToString("yyyyMMddHHmmssfff")
}


function Search-AuditLog($start, $end, $sessionID, $resultSize, $outputPath, $recordType) {
    $maxRetries = 3
    $retryCount = 0

    while ($retryCount -lt $maxRetries) {
        try {
            $results = Search-UnifiedAuditLog -StartDate $start -EndDate $end -SessionId $sessionID -SessionCommand ReturnLargeSet -ResultSize $resultSize -RecordType $recordType

            if (($results | Measure-Object).Count -ne 0) {
                $results | Export-Csv -Path "$($outputPath)\AuditLogs_$($TenantName).csv" -Append -NoTypeInformation -Encoding UTF8
            }

            return $results
        }
        catch {
            if ($_.Exception.Message -like "*503*") {
                Write-LogMessage "Server unavailable. Retrying in 10 seconds..." 'Yellow'
                Start-Sleep -Seconds 10
                $retryCount++
                continue
            }
            else {
                throw $_
            }
        }
    }
    Write-LogMessage "Server unavailable after $maxRetries retries. Exiting..." 'Red'
    exit
}


function Show-Progress($intervalCount, $totalIntervals) {
    $progress = [math]::Round((($intervalCount / $totalIntervals) * 100), 0)
    Write-Progress -Activity "Retrieving audit records" -Status "$progress% Complete:" -PercentComplete $progress
}


function main {
    $startDaysAgo, $outputPath = Read-UserInput
    $start, $end = Get-DateRange $startDaysAgo
    $TenantName = Get-TenantName

    Show-Logo

    Write-LogMessage "Searching from $start to $end" "Green"

    Connect-ExchangeService

    $recordTypes = "AzureActiveDirectoryAccountLogon", "AzureActiveDirectoryStsLogon"
   
    foreach ($recordType in $recordTypes) {
        Get-AllAuditRecords $start $end $recordType $outputPath $TenantName
    }
    
    Format-AuditData $outputPath $TenantName
}

main