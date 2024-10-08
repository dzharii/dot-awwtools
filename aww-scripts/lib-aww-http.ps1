enum RestDslLogLevels {
    Verbose = 3
    Info    = 2
    Error   = 1
}

$script:RestDslLogLevel = [RestDslLogLevels]::Verbose

# Generates a unique request ID
function Get-RestDslRequestId {
    return [Guid]::NewGuid().ToString().Replace("-", "")
}

# Logs the beginning of a REST API request
function Log-RestDslBegin {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Id,

        [Parameter(Mandatory = $true)]
        [string] $Method,

        [Parameter(Mandatory = $true)]
        [string] $Uri,

        [Parameter(Mandatory = $false)]
        [hashtable] $Headers = @{},

        [Parameter(Mandatory = $false)]
        [string] $Body = ""
    )

    if ($script:RestDslLogLevel -ge 2)
    {
        Write-Host ""
        Write-Host "REQUEST Id=$($Id)" -BackgroundColor Black -ForegroundColor Gray
        Write-Host "$($Method) $($Uri)" -BackgroundColor Black -ForegroundColor White
    }

    if ($Headers) {
        foreach ($key in $Headers.Keys) {
            $key = "$($key)".ToLower()

            if ($script:RestDslLogLevel -ge 3)
            {
                if ($key -eq "authorization") {
                    Write-Host "$($key): ..."
                } else {
                    Write-Host "$($key): $($Headers[$key])"
                }
            }
        }
    }

    if ($script:RestDslLogLevel -ge 3)
    {
        if ($Body) {
            Write-Host ""
            Write-Host $Body
            Write-Host ""
        }
    }
}

# Logs the end of a REST API request
function Log-RestDslEnd {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Id,

        [Parameter(Mandatory = $false)]
        [PSCustomObject] $Body
    )

    $colorParamsBody = @{
        BackgroundColor = "Black"
        ForegroundColor = "White"
    }

    if ($script:RestDslLogLevel -ge 2)
    {
        Write-Host "FINISHED REQUEST Id=[$($Id)]" -BackgroundColor Black -ForegroundColor Gray
        Write-Host "RESPONSE" -BackgroundColor Black -ForegroundColor Gray
    }

    if ($script:RestDslLogLevel -ge 3)
    {
        try {
            $formattedJson = $Body | ConvertTo-Json
            Write-Host $formattedJson @colorParamsBody
        } catch {
            Write-Host $Body @colorParamsBody
        }
    }
}

# Logs details of an HTTP error
function Log-HttpError {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Id,

        [Parameter(Mandatory = $true)]
        [PSCustomObject] $HttpError
    )

    $errorColorParams = @{
        BackgroundColor = "Black"
        ForegroundColor = "Red"
    }

    if ($script:RestDslLogLevel -ge 1)
    {
        Write-Host "FAILED REQUEST Id=[$($Id)]" @errorColorParams
        if ($HttpError -and $HttpError.Exception) {
            Write-Host $HttpError.Exception @errorColorParams
            Write-Host ""
            try {
                $result = $HttpError.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($result)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();
                Write-Host "ERROR RESPONSE BODY:" @errorColorParams
                try {
                    $formattedJson = $responseBody | ConvertFrom-Json | ConvertTo-Json
                    Write-Host $formattedJson @errorColorParams
                } catch {
                    Write-Host $responseBody @errorColorParams
                }
            }
            catch { }
        } else {
            Write-Host $HttpError @errorColorParams
        }
    }
}

function Invoke-AwwHttpGet {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri,
        [Parameter(Mandatory = $false)]
        [hashtable] $Headers = @{}
    )

    $modifiedHeaders = $Headers.Clone()

    $params = @{
        Uri = $Uri
        Method = "GET"
        Headers = $modifiedHeaders
    }

    $response = "";

    $telemetryId = Get-RestDslRequestId
    Log-RestDslBegin -Id $telemetryId @params

    try {
        $response = Invoke-RestMethod @params
        Log-RestDslEnd -Id $telemetryId -Body $response
    } catch {
        Log-HttpError -Id $telemetryId -HttpError $_
        throw
    }
    return $response;
}

function Invoke-AwwHttpPost {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri,
        [Parameter(Mandatory = $false)]
        [hashtable] $Headers =  @{},
        [Parameter(Mandatory = $false)]
        [string] $Body = $null
    )

    $modifiedHeaders = $Headers.Clone()

    $params = @{
        Uri = $Uri
        Method = "POST"
        Headers = $modifiedHeaders
        Body = $Body
    }

    $response = "";

    $telemetryId = Get-RestDslRequestId
    Log-RestDslBegin -Id $telemetryId @params

    try {
        $response = Invoke-RestMethod @params
        Log-RestDslEnd -Id $telemetryId -Body $response
    } catch {
        Log-HttpError -Id $telemetryId -HttpError $_
        throw
    }
    return $response;
}

function Invoke-AwwHttpPatch {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri,
        [Parameter(Mandatory = $false)]
        [hashtable] $Headers =  @{},
        [Parameter(Mandatory = $false)]
        [string] $Body = $null
    )

    $modifiedHeaders = $Headers.Clone()

    $params = @{
        Uri = $Uri
        Method = "PATCH"
        Headers = $modifiedHeaders
        Body = $Body
    }

    $response = "";

    $telemetryId = Get-RestDslRequestId
    Log-RestDslBegin -Id $telemetryId @params

    try {
        $response = Invoke-RestMethod @params
        Log-RestDslEnd -Id $telemetryId -Body $response
    } catch {
        Log-HttpError -Id $telemetryId -HttpError $_
        throw
    }
    return $response;
}

function Invoke-AwwHttpDelete {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri,
        [Parameter(Mandatory = $false)]
        [hashtable] $Headers =  @{}
    )
    $modifiedHeaders = $Headers.Clone()

    $params = @{
        Uri = $Uri
        Method = "DELETE"
        Headers = $modifiedHeaders
    }

    $response = "";

    $telemetryId = Get-RestDslRequestId
    Log-RestDslBegin -Id $telemetryId @params

    try {
        $response = Invoke-RestMethod @params
        Log-RestDslEnd -Id $telemetryId -Body $response
    } catch {
        Log-HttpError -Id $telemetryId -HttpError $_
        throw
    }
    return $response;
}
