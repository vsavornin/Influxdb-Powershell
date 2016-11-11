Function Import-XMLConfig
{
<#
    .Synopsis
        Loads the XML Config File for Send-StatsToInfluxdb.

    .Description
        Loads the XML Config File for Send-StatsToInfluxdb.

    .Parameter ConfigPath
        Full path to the configuration XML file.

    .Example
        Import-XMLConfig -ConfigPath C:\Stats\Send-PowerShellInfluxdb.ps1

    .Notes
        NAME:      Start-MeasurementsToInfluxdb
        AUTHOR:       Vincent SAVORNIN
        WEBSITE:   https://github.com/vsavornin/Influxdb-Powershell
        BASED ON:  https://github.com/MattHodge/Graphite-PowerShell-Functions

#>
    [CmdletBinding()]
    Param
    (
        # Configuration File Path
        [Parameter(Mandatory = $true)]
        $ConfigPath
    )

    [hashtable]$Config = @{ }

    # Load Configuration File
    $xmlfile = [xml]([System.IO.File]::ReadAllText($configPath))

    # Set the Influxdb server location and port number
    $Config.InfluxdbHTTPProtocol = $xmlfile.Configuration.Influxdb.InfluxdbHTTPProtocol
    $Config.InfluxdbServer = $xmlfile.Configuration.Influxdb.InfluxdbServer
    $Config.InfluxdbHTTPPort = $xmlfile.Configuration.Influxdb.InfluxdbHTTPPort
    $Config.InfluxdbDatabase = $xmlfile.Configuration.Influxdb.InfluxdbDatabase

    # Get the HostName to use for the metrics from the config file
    $Config.NodeHostName = $xmlfile.Configuration.Influxdb.NodeHostName

    # Set the NodeHostName to ComputerName
    if($Config.NodeHostName -eq '$env:COMPUTERNAME')
    {
        $Config.NodeHostName = $env:COMPUTERNAME
    }

    # Get Metric Send Interval From Config
    [int]$Config.MetricSendIntervalSeconds = $xmlfile.Configuration.Influxdb.MetricSendIntervalSeconds

    # Convert Value in Configuration File to Bool for Sending via UDP
    [bool]$Config.SendUsingUDP = [System.Convert]::ToBoolean($xmlfile.Configuration.Influxdb.SendUsingUDP)

    # Convert Interval into TimeSpan
    $Config.MetricTimeSpan = [timespan]::FromSeconds($Config.MetricSendIntervalSeconds)

    # What is the metric path
    # $Config.MetricPath = $xmlfile.Configuration.Influxdb.MetricPath

    # Convert Value in Configuration File to Bool for showing Verbose Output
    [bool]$Config.ShowOutput = [System.Convert]::ToBoolean($xmlfile.Configuration.Logging.VerboseOutput)

    # Get the Host Tag Name to use for the metrics from the config file
    $Config.HostTagName = $xmlfile.Configuration.Influxdb.HostTagName

    # Get the Counter's Instance Tag Name to use for the metrics from the config file
    $Config.CounterInstanceTagName = $xmlfile.Configuration.Influxdb.CounterInstanceTagName

    #Create the Measurements Hash
    $Config.Measurements = @{}

    # Loop for each Measurement in configuration file
    foreach ($measurement in $xmlfile.Configuration.Measurements.Measurement)
    {
        # Create the Measurement Hash
        $Config.Measurements[$measurement.Name] = @{}

        # Retrieve the KeepTotal bool
        [bool]$Config.Measurements[$measurement.Name].skip_total = [System.Convert]::ToBoolean($measurement.SkipTotal)

        # Retrieve Tags list into an OrderedDictionary, to preserve the order (https://docs.influxdata.com/influxdb/v1.0/write_protocols/line_protocol_tutorial/)
        $Config.Measurements[$measurement.Name]["tags"] = New-Object System.Collections.Specialized.OrderedDictionary
        foreach ($tags in $measurement.MeasurementTags.Tag)
        {
            $Config.Measurements[$measurement.Name]["tags"][$tags.Name] = $tags.Value
        }
        # Add host tag to each Measurement
        $Config.Measurements[$measurement.Name]["tags"][$Config.HostTagName] = $Config.NodeHostName

        # Retrieve Fields list into a Hash
        $Config.Measurements[$measurement.Name]["fields"] = @{}
        foreach ($fields in $measurement.MeasurementFields.Field)
        {
            $Config.Measurements[$measurement.Name]["fields"][$fields.Name] = $fields.Counter
        }
    }

    # For debug purpose
    # $Config.Measurements["win_cpu"] | Format-Table | Out-String
    # $Config.Measurements["win_cpu"]["tags"] | Format-Table | Out-String
    # $Config.Measurements["win_cpu"]["fields"] | Format-Table | Out-String

    Return $Config
}

# http://support-hq.blogspot.com/2011/07/using-clause-for-powershell.html
function PSUsing
{
    param (
        [System.IDisposable] $inputObject = $(throw "The parameter -inputObject is required."),
        [ScriptBlock] $scriptBlock = $(throw "The parameter -scriptBlock is required.")
    )

    Try
    {
        &$scriptBlock
    }
    Finally
    {
        if ($inputObject -ne $null)
        {
            if ($inputObject.psbase -eq $null)
            {
                $inputObject.Dispose()
            }
            else
            {
                $inputObject.psbase.Dispose()
            }
        }
    }
}

# ===>>> CHANGE THIS TO SEND TO INFLUXDB
# function SendMetrics
# {
    # param (
        # [string]$InfluxdbServer,
        # [int]$InfluxdbHTTPPort,
        # [string[]]$Metrics,
        # [switch]$IsUdp = $false,
        # [switch]$TestMode = $false
    # )

    # if (!($TestMode))
    # {
        # try
        # {
            # if ($isUdp)
            # {
                # PSUsing ($udpobject = new-Object system.Net.Sockets.Udpclient($InfluxdbServer, $InfluxdbHTTPPort)) -ScriptBlock {
                    # $enc = new-object system.text.asciiencoding
                    # foreach ($metricString in $Metrics)
                    # {
                        # $Message += "$($metricString)`n"
                    # }
                    # $byte = $enc.GetBytes($Message)

                    # Write-Verbose "Byte Length: $($byte.Length)"
                    # $Sent = $udpobject.Send($byte,$byte.Length)
                # }

                # Write-Verbose "Sent via UDP to $($InfluxdbServer) on port $($InfluxdbHTTPPort)."
            # }
            # else
            # {
                # PSUsing ($socket = New-Object System.Net.Sockets.TCPClient) -ScriptBlock {
                    # $socket.connect($InfluxdbServer, $InfluxdbHTTPPort)
                    # PSUsing ($stream = $socket.GetStream()) {
                        # PSUSing($writer = new-object System.IO.StreamWriter($stream)) {
                            # foreach ($metricString in $Metrics)
                            # {
                                # $writer.WriteLine($metricString)
                            # }
                            # $writer.Flush()
                            # Write-Verbose "Sent via TCP to $($InfluxdbServer) on port $($InfluxdbHTTPPort)."
                        # }
                    # }
                # }
            # }
        # }
        # catch
        # {
            # $exceptionText = GetPrettyProblem $_
            # Write-Error "Error sending metrics to the Influxdb Server. Please check your configuration file. `n$exceptionText"
        # }
    # }
# }
# END ===>>> CHANGE THIS TO SEND TO INFLUXDB

function GetPrettyProblem {
    param (
        $Problem
    )

    $prettyString = (Out-String -InputObject (format-list -inputobject $Problem -Property * -force)).Trim()
    return $prettyString
}

function StringIsNullOrWhitespace([string] $string)
{
    if ($string -ne $null) { $string = $string.Trim() }
    return [string]::IsNullOrEmpty($string)
}

Function DateTimeToUnixTimestamp([datetime]$DateTime)
{
    $utcDate = $DateTime.ToUniversalTime()
    # Convert to a Unix time without any rounding
    [uint64]$UnixTime = [double]::Parse((Get-Date -Date $utcDate -UFormat %s))
    return [uint64]$UnixTime
}

# To be compatible with PSv2
# Code adapted From : https://github.com/yukiusagi2052/PowerShell-InfluxDB
function Invoke-HttpMethod {
  [CmdletBinding()]
  Param(
      [string] $URI,
      [string] $Method,
      [string] $Body
  )

  [Bool] $MethodResult = $True
  [Int] $MethodRetryWaitSecond = 10
  [Int] $MaxMethodRetry = 6

  For($WriteRetryCount=0; $WriteRetryCount -lt $MaxMethodRetry; $WriteRetryCount++){

    $WebRequest = [System.Net.WebRequest]::Create($URI)
    $WebRequest.ContentType = "application/x-www-form-urlencoded"
    $BodyStr = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $Webrequest.ContentLength = $BodyStr.Length
    $WebRequest.ServicePoint.Expect100Continue = $false
    $webRequest.Method = $Method

    # [System.Net.WebRequest]::GetRequestStream()
    Try{
      $RequestStream = $WebRequest.GetRequestStream()

      # [System.IO.Stream]::Write()
      Try{
        $RequestStream.Write($BodyStr, 0, $BodyStr.length)
      } Catch {
        Write-Error $_.Exception.ErrorRecord
        $MethodResult = $False
      }
      $MethodResult = $True

    } Catch {
      # $Error | Get-Member
      Write-Error $_.Exception.ErrorRecord
      $MethodResult = $False
    } Finally {
      $RequestStream.Close()
    }

    # [System.Net.WebRequest]::GetResponse()
    If($MethodResult){
      Try{
        [System.Net.WebResponse] $resp = $WebRequest.GetResponse();
        $MethodResult = $True
      } Catch {
        Write-Error $_.Exception.ErrorRecord
        $MethodResult = $False
      }
    }

    # [System.Net.WebResponse]::GetResponseStream()
    If($MethodResult){
      Try{
        $rs = $resp.GetResponseStream();
        $MethodResult = $True
      } Catch {
        Write-Error $_.Exception.ErrorRecord
        $MethodResult = $False
      }
    }

    # [System.IO.StreamReader]::ReadToEnd()
    If($MethodResult){
      Try{
        [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
        [string] $results = $sr.ReadToEnd();
        $MethodResult = $True
      } Catch {
        Write-Error $_.Exception.ErrorRecord
        $MethodResult = $False
      } Finally {
        $sr.Close();
      }
    }

    If($MethodResult){
        return $results;
    } Else {
      If ($WriteRetryCount -lt $MaxMethodRetry) {
        Write-Verbose "Retry $WriteRetryCount / $MaxMethodRetry"
        Remove-Variable RequestStream
        Remove-Variable BodyStr
        Remove-Variable WebRequest
        #[System.GC]::Collect([System.GC]::MaxGeneration)
        Start-Sleep -Seconds $MethodRetryWaitSecond
      } Else {
        Write-Verbose "Max Retry Reached !"
      }
    }
  } #For .. (WriteRetry) .. Loop
}

# Code adapted From : https://github.com/yukiusagi2052/PowerShell-InfluxDB
Function Invoke-InfluxWriteRaw {
  <#
  .SYNOPSIS
    Send Metrics to InfluxDB server in Line Protocol
  #>
  [CmdletBinding()]
  Param(
    [string]$Protocol,
    [string]$Server,
    [string]$Port,
    [string]$DbName,
    [string]$Username,
    [string]$Password,
    [string]$Precision = "s",
    [string]$LineProtocolMeasurements,
    [switch]$TestMode = $false
  )

    # InfluxDB API URL
    [String]$resource = $Protocol + "://" + $Server + ":" + $Port + "/write?db=" + $DbName + "&precision=" + $Precision

    # Verbose
    Write-Verbose "Post URI : $resource"
    Write-Verbose "Post Data: $LineProtocolMeasurements"

    if($TestMode -eq $False)
    {
        # Post to InfluxDB
        Invoke-HttpMethod -Uri $resource -Method POST -Body $LineProtocolMeasurements -Debug
    }
    else
    {
        Write-Verbose "TestMode is activated : nothing is sent to InfluxDB"
    }
}

# CleanUp Functions for Line Protocol
# https://docs.influxdata.com/influxdb/v1.0/write_protocols/line_protocol_tutorial/#special-characters-and-keywords
Function Influxdb-Quote-Measurement {
    Param(
        [string]$InputString
    )
    $QuotedString = $InputString.trim() -replace "((?:[, ])\w*)",'\$1'
    return [string]$QuotedString
}

Function Influxdb-Quote-Tag-FieldKey {
    Param(
        [string]$InputString
    )
    $QuotedString = $InputString.trim() -replace "((?:[, =])\w*)",'\$1'
    return [string]$QuotedString
}

Function Influxdb-Quote-FieldVal {
    Param(
        [string]$InputString
    )
    # $QuotedString = $InputString.trim() -replace "((?:[`"])\w*)",'\$1'
    $QuotedString = $InputString.trim()
    return [string]$QuotedString
}
