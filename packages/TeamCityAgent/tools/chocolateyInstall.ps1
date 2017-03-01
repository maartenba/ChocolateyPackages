
$ErrorActionPreference = 'Stop'; # stop on all errors

if ($env:chocolateyPackageParameters -eq $null) {
	throw "No parameters have been passed into Chocolatey install, e.g. -params 'serverUrl=http://... agentName=... agentDir=...'"
}

$parameters = ConvertFrom-StringData -StringData $env:chocolateyPackageParameters.Replace(" ", "`n")

## Validate parameters
if ($parameters["serverUrl"] -eq $null) {
    throw "Please specify the TeamCity server URL by passing it as a parameter to Chocolatey install, e.g. -params 'serverUrl=http://...'"
}
if ($parameters["agentDir"] -eq $null) {
    $parameters["agentDir"] = "$env:SystemDrive\buildAgent"
    Write-Host No agent directory is specified. Defaulting to $parameters["agentDir"]
}
if ($parameters["agentName"] -eq $null) {
    $defaultName = $true
    $parameters["agentName"] = "$env:COMPUTERNAME"
    Write-Host No agent name is specified. Defaulting to $parameters["agentName"]
}
if ($parameters["ownPort"] -eq $null) {
    $parameters["ownPort"] = "9090"
    Write-Host No agent port is specified. Defaulting to $parameters["ownPort"]
}

$packageName = "TeamCityAgent"
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

## Make local variables of it
$serverUrl = $parameters["serverUrl"];
$agentDir = $parameters["agentDir"];
$agentName = $parameters["agentName"];
$ownPort = $parameters["ownPort"];
$agentDrive = split-path $agentDir -qualifier

# Write out the install parameters to a file for reference during upgrade/uninstall
# This doesn't currently preserve anything during an upgrade, it just helps locate the service control batch files
$parameters.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose
$parameters.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Out-File "$toolsDir/install-parameters.txt" -Encoding ascii

$packageArgs = @{
  packageName   = "$packageName"
  unzipLocation = "$agentDir"
  url           = "$serverUrl/update/buildAgent.zip"
}
Install-ChocolateyZipPackage @packageArgs

# Generic function to read Java properties file into ordered dict
function Get-PropsDictFromJavaPropsFile ($configFile) {
    # Returns configProps ordered dict
    $config = Get-Content $configFile
    Write-Verbose "$config"
    $configProps = [ordered]@{}
    # The 'if' block lines strip comments to avoid invalid/duplicate key issues
    $config | %{if (`
                            (!($_.StartsWith('#')))`
                                -and (!($_.StartsWith(';')))`
                                -and (!($_.StartsWith(";")))`
                                -and (!($_.StartsWith('`')))`
                                -and (($_.Contains('=')))){
                                    $props = @()
                                    $props = $_.split('=',2)
                                    # Use Write-Host or Write-Verbose, Write-Output appends to the return value and breaks things
                                    Write-Verbose "Props are $props"
                                    $configProps.add($props[0],$props[1])
                            }
                    }
    return $configProps
}

# Configure agent
$buildAgentDistFile = "$agentDir\conf\buildAgent.dist.properties"
$buildAgentPropFile = "$agentDir\conf\buildAgent.properties"

if ($ownPort -eq "9090") {
# Simply replace config elements since we aren't adding any new entries
(Get-Content $buildAgentDistFile) | Foreach-Object {
    $_ -replace 'serverUrl=(?:\S+)', "serverUrl=$serverUrl" `
       -replace 'name=(?:\S+)', "name=$agentName"
    } | Set-Content $buildAgentPropFile
} else {
    # Since we are adding a new element and this can be tricky to get right
    # this rewrites the entire config without comments and updated values
    $buildAgentProps = Get-PropsDictFromJavaPropsFile $buildAgentDistFile

    Write-Verbose "Build Agent original settings"
    $buildAgentProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose

    # Set values that require customization
    $buildAgentProps['serverUrl'] = $serverUrl
    $buildAgentProps['name'] = $agentName
    $buildAgentProps['ownPort'] = $ownPort

    Write-Verbose "Build Agent updated settings"
    $buildAgentProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose
    $buildAgentProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Out-File $buildAgentPropFile -Encoding 'ascii'
}

# Supplying a custom agentName allows multiple instances on a single machine
# This rewrites the wrapper config file without comments, if you need the comments, don't supply an agentName when installing to get the default config
if (($defaultName -ne $true) -and ($agentName -ne "")) {
    $wrapperPropsFile = "$agentDir\launcher\conf\wrapper.conf"
    $wrapperProps = Get-PropsDictFromJavaPropsFile $wrapperPropsFile

    Write-Verbose "Java Service Wrapper original settings"
    $wrapperProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose
    $wrapperProps['wrapper.ntservice.name'] = "$agentName"
    $wrapperProps['wrapper.ntservice.displayname'] = "$agentName TeamCity Build Agent"
    $wrapperProps['wrapper.ntservice.description'] = "$agentName TeamCity Build Agent Service"

    Write-Verbose "Java Service Wrapper updated settings"
    $wrapperProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose
    $wrapperProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Out-File $wrapperPropsFile -Encoding 'ascii'
}

# Future state, catch failure and call chocolateyUninstall.ps1 or some other cleanup
# trap exit 1 { Start-ChocolateyProcessAsAdmin "/C `"$agentdir\bin\service.stop.bat; $agentDir\bin\service.uninstall.bat; rm -r -fo $agentDir `"" cmd }
#Start-ChocolateyProcessAsAdmin "/C `"$agentDrive && cd /d $agentDir\bin && $agentDir\bin\service.install.bat && $agentDir\bin\service.start.bat`"" cmd
Set-Location $agentDir\bin
Start-ChocolateyProcessAsAdmin "Start-Process -FilePath .\service.install.bat -WorkingDirectory $($agentDir)"
Start-ChocolateyProcessAsAdmin "Start-Process -FilePath .\service.start.bat -WorkingDirectory $($agentDir)"
