# Demo application authorized with OAuth Resource Owner Flow performs scheduled data pulling from AMM

# AMM API parameters
$AMMhost = "<AMM_HOST>"
[String]$clientID = "<CLIENT_ID>"
[String]$clientSecret = "<CLIENT_SECRET>"

# Create pre-authorization header with client id and client secret
$jointClientIdSecret =  $clientID + ":" + $clientSecret
$script:EncodedClientCreds = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($jointClientIdSecret))
# user credentials
$AMMuserName
$AMMpassword

# latest token credentials
$script:currentToken = ""
$script:currentRefreshToken = ""

# Basic header 
$script:GET_request_Header = ""

Function Connect-ATE-API(){

    param(
            [Parameter(Mandatory=$true)][String]
            $username,
            [Parameter(Mandatory=$true)]
            [SecureString] $password
        )
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $Parameters = @{
        grant_type = "password"
        username = $username
        password = $UnsecurePassword
    }
    $Header = @{
        Authorization = "Basic $script:EncodedClientCreds"
        'Content-Type' = 'application/x-www-form-urlencoded'
    }

    $credentials = ((Invoke-WebRequest -Method Post -Uri "$AMMhost/api/oauth/token"  -Headers $Header -Body $Parameters).Content | ConvertFrom-Json)

    if ($credentials -ne $null){
        $script:currentToken = $credentials.access_token
        $script:currentRefreshToken = $credentials.refresh_token
        # set Header for GET requestS 
        $script:GET_request_Header =  @{
        'Authorization' = "Bearer $script:currentToken"
        }
        Write-Host -ForegroundColor Yellow "Credentials :"
        return $credentials
    }
}

Function tokenRefresh(){
    $Header = @{
        Authorization = "Basic $script:EncodedClientCreds"
        'Content-Type' = 'application/x-www-form-urlencoded'
    }
    $Parameters = @{
        grant_type = "refresh_token"
        refresh_token =  $script:currentRefreshToken
    }

    $credentials = ((Invoke-WebRequest -Method Post -Uri "$AMMhost/api/oauth/token"  -Headers $Header -Body $Parameters).Content | ConvertFrom-Json)
    if ($credentials -ne $null){
        Write-Host -ForegroundColor Yellow "Token Refreshed. With following response:"
        $script:currentToken = $credentials.access_token
        $script:currentRefreshToken = $credentials.refresh_token
          # set Header for GET requestS 
          $script:GET_request_Header =  @{
            'Authorization' = "Bearer $script:currentToken"
         }
         Write-Host -ForegroundColor Yellow "Credentials :"
        return $credentials
    }
}

Function tokenRevoke(){
    $Header = @{
        Authorization = "Bearer $script:currentToken"
        'Content-Type' = 'application/x-www-form-urlencoded'
    }

    $Parameters = @{
        access_token =  $script:currentToken
    }

    $revokedResponse = ((Invoke-WebRequest -Method Post -Uri "$AMMhost/api/oauth/expire"  -Headers $Header -Body $Parameters).Content | ConvertFrom-Json)
    if ($revokedResponse -ne $null){
        Write-Host -ForegroundColor Yellow "Token Revoked. With following response:"
        $script:currentToken = ""
        $script:currentRefreshToken = ""
          # set Header for GET requestS 
          $script:GET_request_Header =  @{
            'Authorization' = "Bearer $script:currentToken"
         }
         Write-Host -ForegroundColor Red "Revoked Token"
        return $revokedResponse
    }
}

Function Get-GateWay-Groups(){
    $groups = ((Invoke-WebRequest -Method Get -Uri "$AMMhost/api/v1/systems/groups"  -Headers $script:GET_request_Header).Content)
    
    if ($groups -ne $null){
        Write-Host -ForegroundColor Yellow "Groups :"
        return $groups
    }
}

Function Get-Gateways(){
    param(
            [Parameter(Mandatory=$true)]
            [AllowNull()]    
            $heartbeat,
            [Parameter(Mandatory=$true)] #ex MG90, MP70
            [AllowNull()]
            $platforms,
            [Parameter(Mandatory=$true)] #ex 3G, 4G, 5G
            [AllowNull()]
            $cellulars,
            [Parameter(Mandatory=$true)] # NOTE use groupid = 0 to get parent group id
            [AllowNull()]
            $groupid
        )

    $Parameters = @{
        heartbeat= $heartbeat
        platforms = $platforms
        cellulars = $cellulars
        groupid = $groupid
    }

    $gateways = ((Invoke-WebRequest -Method Get -Uri "$AMMhost/api/v1/systems"  -Headers $script:GET_request_Header -Body  $Parameters).Content)
    if ($gateways -ne $null){
        Write-Host -ForegroundColor Yellow "Gateways :"
        return $gateways
    }
}

Function Get-Gateway-Latest-Stats(){
    param(
        [Parameter(Mandatory=$true)]
        $uid,
        [Parameter(Mandatory=$true)] #ex ReportIdleTime, GPS%20Location-latitude, GPS%20Location-longitude
        $ids
    )
    $Parameters = @{
        ids= $ids
    }
    $latestStats = ((Invoke-WebRequest -Method Get -Uri "$AMMhost/api/v1/systems/$uid/data"  -Headers $script:GET_request_Header -Body  $Parameters).Content)
    if ($latestStats -ne $null){
        Write-Host -ForegroundColor Yellow "Latest Stats :"
        return $latestStats
    }

}

Function Get-Historical-Stats(){
    param(
        [Parameter(Mandatory=$true)] #gateway uid
        $targetid,
        [Parameter(Mandatory=$true)]
        [AllowNull()]    
        $from,
        [Parameter(Mandatory=$true)]
        [AllowNull()]    
        $to,
        [Parameter(Mandatory=$true)]  #ex ReportIdleTime, GPS%20Location-latitude, GPS%20Location-longitude
        $dataid
    )
    
    $Parameters = @{
        targetid = $targetid 
        from     = $from
        to       = $to
        dataid   = $dataid
    }

    $historicalStats = ((Invoke-WebRequest -Method Get -Uri "$AMMhost/api/v1/systems/data/raw"  -Headers $script:GET_request_Header -Body  $Parameters).Content)
    if ($historicalStats -ne $null){
        Write-Host -ForegroundColor Yellow "Historical Stats :"
        return $historicalStats
    }
    
}

Function getCommands(){
            Write-Host -ForegroundColor Yellow "Following commands are available:"
            Write-Host "1. Connect-ATE-API"
            Write-Host "2. tokenRefresh"
            Write-Host "3. tokenRevoke"
            Write-Host "4. Get-Historical-Stats"
            Write-Host "5. Get-Gateway-Latest-Stats"
            Write-Host "6. Get-GateWay-Groups"
            Write-Host "7. Get-Gateways"
            Write-Host "8. Q - to quit the script"
}
 
Connect-ATE-API 

while(($inp = Read-Host -Prompt "`nSelect a command, use -h to see a list of available commands") -ne "Q"){
    switch($inp){
        Get-Gateways {
            Function task(){
                param(
                    [Parameter(Mandatory=$true)]
                    $waitTime,
                    [Parameter(Mandatory=$true)]
                    $heartbeat,
                    [Parameter(Mandatory=$true)]
                    $platforms,
                    [Parameter(Mandatory=$true)]
                    $cellulars,
                    [Parameter(Mandatory=$true)]
                    $groupid
                )
                $continue = $true
                while($continue){
                    $error.clear()
                    $TempResponse = Get-Gateways $heartbeat $platforms $cellulars $groupid  
                    write-host $TempResponse
                    $err = ($TempResponse | ConvertFrom-Json).error
                    # write-host $err
                    if((-not ([string]::IsNullOrEmpty($err))) -OR $error ){
                        $continue = $false
                        continue
                    }
                    if ([console]::KeyAvailable){
                        Set-PSReadlineKeyHandler -Chord Ctrl+F8 -ScriptBlock { 
                            $continue = $false
                        }
                        Break
                    }
                    Write-Host ""
                    Write-Host -ForegroundColor Red "Press Ctrl+F8 to quit."
                    Write-Host ""
                    Start-Sleep -s $waitTime
                }
            }
            task
        }

       Get-GateWay-Groups {
            Function task(){
                param(
                [Parameter(Mandatory=$true)]
                    $waitTime
                )
                $continue = $true
                $error.clear()
                while($continue){
                    $TempResponse = Get-GateWay-Groups  
                    write-host $TempResponse
                    $err = ($TempResponse | ConvertFrom-Json).error
                    write-host $err
                    if(-not ([string]::IsNullOrEmpty($err)) -OR $error){
                        $continue = $false
                        continue
                    }
                    if ([console]::KeyAvailable){
                        Set-PSReadlineKeyHandler -Chord Ctrl+F8 -ScriptBlock { 
                            $continue = $false
                        }
                        Break
                    }
                    Write-Host ""
                    Write-Host -ForegroundColor Red "Press Ctrl+F8 to quit."
                    Write-Host ""
                    Start-Sleep -s  $waitTime
                }
            }

            task
       }

       Get-Gateway-Latest-Stats {
            Function task(){
                param(
                    [Parameter(Mandatory=$true)]
                    $waitTime,
                    [Parameter(Mandatory=$true)]
                    $uid,
                    [Parameter(Mandatory=$true)]
                    $ids
                )
                $continue = $true
                while($continue){
                    $error.clear()
                    $TempResponse = Get-Gateway-Latest-Stats $uid $ids 
                    write-host $TempResponse
                    $err = ($TempResponse | ConvertFrom-Json).error
                    write-host $err
                    if(-not ([string]::IsNullOrEmpty($err)) -OR $error ){
                        $continue = $false
                        continue
                    }
                    if ([console]::KeyAvailable){
                        Set-PSReadlineKeyHandler -Chord Ctrl+F8 -ScriptBlock { 
                            $continue = $false
                        }
                        Break
                    }
                    Write-Host ""
                    Write-Host -ForegroundColor Red "Press Ctrl+F8 to quit."
                    Write-Host ""
                    Start-Sleep -s $waitTime
                }
            }
            task
       }
       Get-Historical-Stats{
        Function task(){
            param(
                [Parameter(Mandatory=$true)]
                    $waitTime,
                [Parameter(Mandatory=$true)]
                $targetid,
                [Parameter(Mandatory=$true)]
                $from,
                [Parameter(Mandatory=$true)]
                $to,
                [Parameter(Mandatory=$true)]
                $dataid
             )
            $continue = $true
            while($continue){
                $error.clear()
                $TempResponse = Get-Historical-Stats $targetid $from $to $dataid
                write-host $TempResponse
                $err = ($TempResponse | ConvertFrom-Json).error
                write-host $err
                if(-not ([string]::IsNullOrEmpty($err)) -OR $error){
                    $continue = $false
                    continue
                }
                elseif ([console]::KeyAvailable){
                    Set-PSReadlineKeyHandler -Chord Ctrl+F8 -ScriptBlock { 
                        $continue = $false
                    }
                    Break
                }
                Write-Host ""
                Write-Host -ForegroundColor Red "Press Ctrl+F8 to quit."
                Write-Host ""
                Start-Sleep -s $waitTime
            }
        }
        task
       }

       tokenRefresh{
           tokenRefresh
       }
       
       tokenRevoke{
           tokenRevoke
       }
       Connect-ATE-API{
            Connect-ATE-API
       }

        getCommands{
            getCommands
       }

       
        -h{
           getCommands
       }
       
       Q {
           "End"
        }
       
       default {
            $error.clear()   
            "Invalid entry"
            getCommands
       }
    }
}
