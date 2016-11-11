Function Start-MeasurementsToInfluxdb
{
<#
    .Synopsis
        Starts the loop which sends Windows Performance Counters to Influxdb.

    .Description
        Starts the loop which sends Windows Performance Counters to Influxdb. Configuration is all done from the StatsToInfluxdbConfig.xml file.

    .Parameter Verbose
        Provides Verbose output which is useful for troubleshooting

    .Parameter ConfigFile
        Set the Path of a specific Config File in XML format (default is Influxdb-Powershell/StatsToInfluxdbConfig.xml)

    .Parameter TestMode
        Metrics that would be sent to Influxdb is shown, without sending the metric on to Influxdb.

    .Example
        PS> Start-MeasurementsToInfluxdb -TestMode

        Will start the endless loop to send stats to Influxdb for Testing purpose. No data wil be sent.

    .Example
        PS> Start-MeasurementsToInfluxdb

        Will start the endless loop to send stats to Influxdb

    .Example
        PS> Start-MeasurementsToInfluxdb -ConfigFile "c:\path_to_confif\StatsToInfluxdbConfig_FR.xml"

        Will start the endless loop to send stats to Influxdb

    .Example
        PS> Start-MeasurementsToInfluxdb -Verbose

        Will start the endless loop to send stats to Influxdb and provide Verbose output.

    .Notes
        NAME:      Start-MeasurementsToInfluxdb
        AUTHOR:       Vincent SAVORNIN
        WEBSITE:   https://github.com/vsavornin/Influxdb-Powershell
        BASED ON:  https://github.com/MattHodge/Graphite-PowerShell-Functions
#>
    [CmdletBinding()]
    Param
    (
        # Enable Test Mode. Metrics will not be sent to Influxdb
        [Parameter(Mandatory = $false)]
        [switch]$TestMode,
        [switch]$ExcludePerfCounters = $false,
        [string]$ConfigFile = $configPath
    )

    # Run The Load XML Config Function
    Write-Verbose "Loading config file from : $($ConfigFile)"
    $Config = Import-XMLConfig -ConfigPath $ConfigFile

    # Get Last Run Time
    $sleep = 0

    $configFileLastWrite = (Get-Item -Path $ConfigFile).LastWriteTime

    # Start Endless Loop
    while ($true)
    {
        # Loop until enough time has passed to run the process again.
        if($sleep -gt 0) {
            Start-Sleep -Milliseconds $sleep
        }

        # Used to track execution time
        $iterationStopWatch = [System.Diagnostics.Stopwatch]::StartNew()

        $nowUtc = [datetime]::UtcNow

        # Round Time to Nearest Time Period
        $nowUtc = $nowUtc.AddSeconds(- ($nowUtc.Second % $Config.MetricSendIntervalSeconds))

        $metricsToSend = @{}

        if(-not $ExcludePerfCounters)
        {
            # Initialize variable for mapping infos from Config File
            $mapping_field_measurement = @{}
            $mapping_counter_field = @{}

            foreach ($measurement_key in $Config.Measurements.Keys)
            {
                foreach ($field_key in $Config.Measurements[$measurement_key]["fields"].Keys)
                {
                    # Tag temporarely with Measurement Name to avoid bad mapping if there are multiple fields with same name accross different measurements
                    $mapping_field_measurement[$measurement_key + "#" + $field_key] = $measurement_key
                    $mapping_counter_field[$Config.Measurements[$measurement_key]["fields"][$field_key]] = $measurement_key + "#" + $field_key
                }
            }

            # Create the counters array
            $counters = @($mapping_counter_field.Keys)

            # Get counters
            $collections = Get-Counter -Counter $counters -SampleInterval 1 -MaxSamples 1
            $samples = $collections.CounterSamples
            Write-Verbose "All Samples Collected"

            # Create the main measurement Array
            $measurements = @{}

            # Loop Through All the samples collected
            foreach($sample in $samples)
            {
                # Vars re-initialization
                $curr_field = $null
                $curr_measurement = $null
                $curr_instance = $null
                $curr_value = $null

                # Get the Influxdb Field from the current Counter Path
                foreach ($counter in $mapping_counter_field.Keys)
                {
                    # Define regex from Counter Path for matching
                    $regex = [Regex]::Escape($counter) -replace "\\\*", ".*"
                    # Get the field from the matched Counter Path
                    if([string]$sample.Path -match $regex) {
                        $curr_field = $mapping_counter_field[$counter]
                        break
                    }
                }
                # Write-Verbose "GET $curr_field FROM $($sample.Path)"

                # Get the Influxdb Measurement from the Field discovered
                $curr_measurement = $mapping_field_measurement[$curr_field]
                # Write-Verbose "GET $curr_measurement FROM $curr_field"

                # Get Instance Name (if not exists then "-")
                if (StringIsNullOrWhitespace($sample.InstanceName)) { $curr_instance = "-" }
                else { $curr_instance = $sample.InstanceName }

                # Get the Influxdb fields' value
                $curr_value = $sample.CookedValue
                # Write-Verbose "$curr_measurement -> $curr_field ($curr_instance) = $curr_value"


                # Feed the Measurements Hash and Skip _Total instance if configured
                if($Config.Measurements[$measurement_key].skip_total -and $sample.InstanceName -match "_Total" )
                {
                    Write-Verbose "Skiping _Total for $($Config.Measurements[$measurement_key]["fields"][$field_key])"
                }
                else
                {
                    # Init Hashes if new Measurement
                    if($measurements[$curr_measurement] -eq $null) { $measurements[$curr_measurement] = @{} }

                    # Init Hashes if new Instance
                    if($measurements[$curr_measurement][$curr_instance] -eq $null) { $measurements[$curr_measurement][$curr_instance] = @{} }

                    # Remove Measurement Name
                    $curr_field = $curr_field -replace "^.*#",""

                    # Feed the measurements Hash
                    $measurements[$curr_measurement][$curr_instance][$curr_field] = $curr_value
                    #Write-Verbose "To send : $($curr_measurement)[$($curr_instance)].$($curr_field) = $($curr_value)"
                }
            }
        }

        $line_protocol_measurements = @()
        # Create the final metrics to send in Line Protocol Format
        foreach ($measurement_key in $Config.Measurements.Keys) {
            foreach ($instance in $measurements[$measurement_key].Keys)
            {
                $line_str = "$(Influxdb-Quote-Measurement($measurement_key)),"
                # Add the Instance tag if needed
                if ($instance -ne "-") {
                    $Config.Measurements[$measurement_key]["tags"][$Config.CounterInstanceTagName] = $instance
                }
                # Sort Tags by key for better performance in InfluxDB
                $line_str += ($Config.Measurements[$measurement_key]["tags"].GetEnumerator() | Sort -Property Name | % { "$(Influxdb-Quote-Tag-FieldKey($_.Key))=$(Influxdb-Quote-Tag-FieldKey($_.Value))" }) -join ','

                # Create the fields part of the line protocol
                $line_str += ' '
                $line_str += ($measurements[$measurement_key][$instance].GetEnumerator() | % { "$(Influxdb-Quote-Tag-FieldKey($_.Key))=$(Influxdb-Quote-FieldVal($_.Value))" }) -join ','

                # Add the timestamp
                $line_str += ' ' + (DateTimeToUnixTimestamp($nowUtc))

                # Feed the Array of meassurements
                $line_protocol_measurements += $line_str
            }
        }

        # Send To Influxdb Server
        $sendBulkInfluxdbMetricsParams = @{
            "Protocol" = $Config.InfluxdbHTTPProtocol
            "Server" = $Config.InfluxdbServer
            "Port" = $Config.InfluxdbHTTPPort
            "DbName" = $Config.InfluxdbDatabase
            "Username" = $null
            "Password" = $null
            "LineProtocolMeasurements" = $line_protocol_measurements -join "`n"
            "TestMode" = $TestMode
        }
        Invoke-InfluxWriteRaw @sendBulkInfluxdbMetricsParams

        # Reloads The Configuration File After the Loop so new counters can be added on the fly
        if((Get-Item $ConfigFile).LastWriteTime -gt (Get-Date -Date $configFileLastWrite)) {
            $Config = Import-XMLConfig -ConfigPath $ConfigFile
        }

        $iterationStopWatch.Stop()
        $collectionTime = $iterationStopWatch.Elapsed
        $sleep = $Config.MetricTimeSpan.TotalMilliseconds - $collectionTime.TotalMilliseconds
        if ($Config.ShowOutput)
        {
            # Write To Console How Long Execution Took
            $VerboseOutPut = 'PerfMon Job Execution Time: ' + $collectionTime.TotalSeconds + ' seconds'
            Write-Output $VerboseOutPut
        }
    }
}
