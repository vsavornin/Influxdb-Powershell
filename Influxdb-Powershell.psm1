Set-StrictMode -Version Latest
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# Determine The Path Of The XML Config File
$configPath = [string](Split-Path -Parent $MyInvocation.MyCommand.Definition) + '\StatsToInfluxdbConfig.xml'

# Internal Functions
. $here\Functions\Internal.ps1
. $here\Functions\Start-MeasurementsToInfluxdb.ps1

$functionsToExport = @(
    'Start-MeasurementsToInfluxdb',
	'Import-XMLConfig'
)

Export-ModuleMember -Function $functionsToExport
