# Generates a unique request ID
function Get-RestDslRequestId {
    return [Guid]::NewGuid().ToString().Replace("-", "")
}

function Write-AwwLog {
    param (
        [string] $message,
        [string] $ForegroundColor = "White",
        [string] $BackgroundColor = "Black"
    )
    if ($script:AWWLOG) {
        $script:AWWLOG.WriteHost($message)
    } else {
        Write-Host $message -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
    }
}

function Write-AwwError {
    param (
        [string] $message
    )
    if ($script:AWWLOG) {
        $script:AWWLOG.WriteError($message)
    } else {
        Write-Host $message -ForegroundColor Red
    }
}

function Write-AwwWarning {
    param (
        [string] $message
    )
    if ($script:AWWLOG) {
        $script:AWWLOG.WriteWarning($message)
    } else {
        Write-Host $message -ForegroundColor Yellow
    }
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

    Write-AwwLog -message ""
    Write-AwwLog -message "REQUEST Id=$($Id)" -ForegroundColor Gray
    Write-AwwLog -message "$($Method) $($Uri)" -ForegroundColor White

    if ($Headers) {
        foreach ($key in $Headers.Keys) {
            $key = "$($key)".ToLower()
            if ($key -eq "authorization") {
                Write-AwwLog -message "$($key): ..."
            } else {
                Write-AwwLog -message "$($key): $($Headers[$key])"
            }
        }
    }

    if ($Body) {
        Write-AwwLog -message ""
        Write-AwwLog -message $Body
        Write-AwwLog -message ""
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

    Write-AwwLog -message "FINISHED REQUEST Id=[$($Id)]" -ForegroundColor Gray
    Write-AwwLog -message "RESPONSE" -ForegroundColor Gray

    try {
        $formattedJson = $Body | ConvertTo-Json
        Write-AwwLog -message $formattedJson -ForegroundColor $colorParamsBody.ForegroundColor -BackgroundColor $colorParamsBody.BackgroundColor
    } catch {
        Write-AwwLog -message $Body -ForegroundColor $colorParamsBody.ForegroundColor -BackgroundColor $colorParamsBody.BackgroundColor
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

    Write-AwwLog -message "FAILED REQUEST Id=[$($Id)]" -ForegroundColor $errorColorParams.ForegroundColor -BackgroundColor $errorColorParams.BackgroundColor
    if ($HttpError -and $HttpError.Exception) {
        Write-AwwLog -message $HttpError.Exception -ForegroundColor $errorColorParams.ForegroundColor -BackgroundColor $errorColorParams.BackgroundColor
        Write-AwwLog -message ""
        try {
            $result = $HttpError.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
            Write-AwwLog -message "ERROR RESPONSE BODY:" -ForegroundColor $errorColorParams.ForegroundColor -BackgroundColor $errorColorParams.BackgroundColor
            try {
                $formattedJson = $responseBody | ConvertFrom-Json | ConvertTo-Json
                Write-AwwLog -message $formattedJson -ForegroundColor $errorColorParams.ForegroundColor -BackgroundColor $errorColorParams.BackgroundColor
            } catch {
                Write-AwwLog -message $responseBody -ForegroundColor $errorColorParams.ForegroundColor -BackgroundColor $errorColorParams.BackgroundColor
            }
        }
        catch { }
    } else {
        Write-AwwLog -message $HttpError -ForegroundColor $errorColorParams.ForegroundColor -BackgroundColor $errorColorParams.BackgroundColor
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
