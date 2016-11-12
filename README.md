# Influxdb-Powershell
Powershell script to send Windows Performance counters to an InfluxDB Server, all configurable from a simple XML file.

[![GitHub Version](https://img.shields.io/github/release/vsavornin/Influxdb-Powershell.svg)](https://github.com/vsavornin/Influxdb-Powershell/releases)

Based on :
* MattHodge PowerShell Functions for InfluxDB [https://github.com/MattHodge/Graphite-PowerShell-Functions](https://github.com/MattHodge/Graphite-PowerShell-Functions)
* yukiusagi2052' scripts : [https://github.com/yukiusagi2052/PowerShell-InfluxDB](https://github.com/yukiusagi2052/PowerShell-InfluxDB)

## Features

* Sends Metrics to InfluxDB in Line Protocol using TCP (or UDP - maybe in future)
* Can collect Windows Performance Counters
* Converts time to UTC on sending
* All configuration can be done from a simple XML file
* Allows you to override the hostname in Windows Performance Counters before sending on to InfluxDB
* Allows configuring Tags and Fields Name sent to InfluxDB
* Allows to send Measurements Metrics compatible with Telegraf ones into the same Database
* Allows to send Measurements Metrics compatible between different localized versions of Windows into the same database
* Reloads the XML configuration file automatically. For example, if more counters are added to the configuration file, the script will notice and start sending metrics for them to InfluxDB in the next send interval
* Additional functions are exposed that allow you to send data to InfluxDB from PowerShell easily. [Here](#functions) is the list of included functions
* Script can be installed to run as a service

## TODO

- [ ] Allow authentication to IndluxDB REST API with username & password URL parameters (API endpoint `/write`)
- [ ] Allow secure connection with encrypted password in HTTP Headers
- [ ] Limit the number of metrics sent if more than a parameter's value in the configuration file (ie. `<InfluxdbBatchSize>1000</InfluxdbBatchSize>`, like Telegraf `metric_batch_size` parameter)

## Installation

1. Download the repository and place into a PowerShell Modules directory called **Influxdb-Powershell**. The module directories can be found by running `$env:PSModulePath` in PowerShell. For example, `C:\Program Files\WindowsPowerShell\Modules\Influxdb-PowerShell`
2. Verify your folder structure, with the *.psd1* and *.psm1* files inside the **Influxdb-Powershell** folder
3. Make sure the files are un-blocked by right clicking on them and going to properties.
4. Modify the *StatsToInfluxdbConfig.xml* configuration file. Instructions [here](#config).
5. Open PowerShell and ensure you set your Execution Policy to allow scripts be run. For example `Set-ExecutionPolicy RemoteSigned`.

### Modifying the Configuration File

The configuration file is fairly self-explanatory, but here is a description for each of the values.

The default configuration file is located under the home directory of Influxdb-Powershell : `StatsToInfluxdbConfig.xml`.

Default configuration file name and path can be overriden with the `-ConfigFile` parameter when running `Start-MeasurementsToInfluxdb` function.

#### <a name="config"></a>Influxdb Configuration Section (`<Influxdb>`)

Configuration Name | Description
--- | ---
InfluxdbHTTPProtocol | The protocol used to communicate with InfluxDB REST API. `http` or `https`
InfluxdbServer | The server name or IP adress where the InfluxDB database server is running.
InfluxdbHTTPPort | The port number for InfluxDB REST API. Its default port number is `8086`.
InfluxdbDatabase | The Influxdb Database where the metrics are sent.
NodeHostName | This allows you to override the hostname of the server before sending the metrics on to INfluxDB. Default is use `$env:COMPUTERNAME`, which will use the local computer name.
MetricSendIntervalSeconds | The interval to send metrics to InfluxDB. I recommend 10 seconds or greater. The more metrics you are collecting the longer it takes to send them to the InfluxDB server. You can see how long it takes to send the metrics each time the loop runs by using running the `Start-MeasurementsToInfluxdb` function and having *VerboseOutput* set to *True*.
SendUsingUDP | `Not implemented yet` Sends metrics via UDP instead of TCP.
HostTagName | The tag name sent to influxDB for the NodeHostName value. Default is `host` (compatible with Influxdata Telegraf).
CounterInstanceTagName | The tag name sent to influxDB for the Instance value of a Windows Performance Counter. Default is `instance` (compatible with Influxdata Telegraf).


#### Measurements Section (`<Measurements>`)

Example :
```xml
<Measurements>
    <Measurement Name="win_cpu">
        <MeasurementTags>
            <Tag Name="objectname" Value="Processor"/>
        </MeasurementTags>
        <MeasurementFields>
            <Field Name="Percent_Idle_Time" Counter="\Processeur(*)\% d’inactivité"/>
            <Field Name="Percent_Interrupt_Time" Counter="\Processeur(*)\% temps d’interruption"/>
            <Field Name="Percent_Privileged_Time" Counter="\Processeur(*)\% temps privilégié"/>
            <Field Name="Percent_Processor_Time" Counter="\Processeur(*)\% temps processeur"/>
            <Field Name="Percent_User_Time" Counter="\Processeur(*)\% temps utilisateur"/>
        </MeasurementFields>
        <SkipTotal>False</SkipTotal>
    </Measurement>
</Measurements>
```

This section lists the performance counters you want the machine to send to specific InfluxDB database measurement.

You can get the list of performance counters available on your system:
* from Performance Monitor (perfmon.exe)
* by using the command `typeperf -qx` in a command prompt.

I have included some basic performance counters in the configuration file. Asterisks can be used as a wildcard for instance.


##### Measurement Section (`<Measurement Name="">`)
Each InfluxDB Measurement has its configuration section.


Specify the Name of the Measurement where all the Tags and Fields specified in this section will be sent :
`<Measurement Name="win_cpu">`
Here, the metrics will be written to the win_cpu measurement of the `InfluxdbDatabase`

Sub-Section | XML Tag | Description
--- | --- | ---
MeasurementTags | `<MeasurementTags>` | The tag objectname describes the Counter Object from which the metrics are taken. If you get counter `\Processor(*)\% idle time`, you might set it to `<Tag Name="objectname" Value="Processor"/>`.<br>You might add as many Tags you want (not tested yet)
MeasurementFields | `<MeasurementFields>` | Here you list all the Fields you want to feed the Measurement with.<br>You must configure the Field's Name and it's Value with a Performance Counter Path : `<Field Name="Percent_User_Time" Counter="\Processeur(*)\% temps utilisateur"/>`
SkipTotal | `<SkipTotal>` | If you want to skip the `_Total` instance of the Performance Counters, set this option to `True`.<br>Default is `False`.

#### Logging Configuration Section

This section allows you to turn on or off Verbose output. This is useful when testing but is better left off when running as a service as you won't be able to see the output.

Configuration Name | Description
--- | ---
VerboseOutput | Will provide each of the metrics that were sent over to Carbon and the total execution time of the loop.


## Usage - Windows Performance Counters

The following shows how to use the `Start-MeasurementsToInfluxdb`, which will collect Windows performance counters and send them to InfluxDB.

1. Open PowerShell
2. Import the Module by running `Import-Module -Name Influxdb-PowerShell`
3. Start the script by using the function `Start-MeasurementsToInfluxdb`. If you want Verbose details, use `Start-MeasurementsToInfluxdb -Verbose`.

You may need to run the PowerShell instance with Administrative rights depending on the performance counters you want to access. This is due to the scripts use of the `Get-Counter` CmdLet.

From the [Get-Counter help page on TechNet](http://technet.microsoft.com/library/963e9e51-4232-4ccf-881d-c2048ff35c2a(v=wps.630).aspx):

> Performance counters are often protected by access control lists (ACLs). To get all available performance counters, open Windows PowerShell with the "Run as administrator" option.

That is all there is to getting your Windows performance counters into InfluxDB.

## Installing as a Service

Once you have edited the configuration file and verified everything is functioning correctly by running either `Start-MeasurementsToInfluxdb` in an interactive PowerShell session, you might want to install this script as a service.

The easiest way to achieve this is using NSSM - the Non-Sucking Service Manager.

1. Download nssm from [nssm.cc](http://nssm.cc)
2. Open up an Administrative command prompt and run `nssm install InfluxdbPowerShell`. (You can call the service whatever you want).
3. A dialog will pop up allowing you to enter in settings for the new service. The following table below contains the settings to use.
4. Click *Install Service*
5. Make sure the service is started and it is set to Automatic
6. Check your Graphite server and make sure the metrics are coming in

The below configurations will show how to run either `Start-MeasurementsToInfluxdb` as a service. If you want to run both on the same server, you will need to create two seperate services, one for each script.

### Running Start-MeasurementsToInfluxdb as a Service

The following configuration can be used to run `Start-MeasurementsToInfluxdb` as a service.

Setting Name | Value
--- | ---
Path | C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
Startup Directory | Leave Blank
Options | -command "& { Import-Module -Name Influxdb-PowerShell ; Start-MeasurementsToInfluxdb }"

If you want to remove a service, read the NSSM documentation [http://nssm.cc/commands](http://nssm.cc/commands) for instructions.

### Installing as a Service Using PowerShell
1. Download nssm from [nssm.cc](http://nssm.cc) and save it into a directory
2. Open an Administrative PowerShell consolen and browse to the directory you saved NSSM
3. Run `Start-Process -FilePath .\nssm.exe -ArgumentList 'install InfluxdbPowerShell "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "-command "& { Import-Module -Name Graphite-PowerShell ; Start-MeasurementsToInfluxdb }"" ' -NoNewWindow -Wait`
4. Check the service installed successfully `Get-Service -Name InfluxdbPowerShell`
5. Start the service `Start-Service -Name InfluxdbPowerShell`

## <a name="functions">Included Functions</a>

There are several functions that are exposed by the module which are available to use in an ad-hoc manner.

For a list of functions in the module, run `Get-Command -Module Influxdb-PowerShell`. For full help for these functions run `Get-Help | <Function Name>`

Function Name | Description
--- | ---
Start-MeasurementsToInfluxdb | The function to collect Windows Performance Counters. This is an endless loop which will send metrics to InfluxDB.
