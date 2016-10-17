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

## Make local variables of it
$serverUrl = $parameters["serverUrl"];
$agentDir = $parameters["agentDir"];
$agentName = $parameters["agentName"];
$ownPort = $parameters["ownPort"];
$agentDrive = split-path $agentDir -qualifier

## Temporary folder
$tempFolder = $env:TEMP

## Download from TeamCity server
Get-ChocolateyWebFile 'buildAgent.zip' "$tempFolder\buildAgent.zip" "$serverUrl/update/buildAgent.zip"

## Extract
New-Item -ItemType Directory -Force -Path $agentDir
Get-ChocolateyUnzip "$tempFolder\buildAgent.zip" $agentDir  

## Clean up
#del /Q "$tempFolder\buildAgent.zip"

# Configure agent
copy $agentDir\conf\buildAgent.dist.properties $agentDir\conf\buildAgent.properties
# ConvertFrom-StringData equivalent to longer format but loses key ordering (both strip comments)
#$buildAgentProps = convertfrom-stringdata (Get-Content $agentDir\conf\buildAgent.properties | Out-String)
$buildAgentProps = [ordered]@{}
$buildAgentConfig = get-content $agentDir\conf\buildAgent.properties
# The 'if' block lines strip comments to avoid invalid/duplicate key issues
$buildAgentConfig | %{if (`
                            (!($_.StartsWith('#'))) `
                                -and (!($_.StartsWith(';')))`
                                -and (!($_.StartsWith(";")))`
                                -and (!($_.StartsWith('`')))`
                                -and (($_.Contains('=')))){
                                    $buildAgentProps.add($_.split('=',2)[0],$_.split('=',2)[1])
                                }
                    }
Write-Verbose "Build Agent original settings"
$buildAgentProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose

$buildAgentProps['serverUrl'] = $serverUrl
$buildAgentProps['name'] = $agentName
$buildAgentProps['ownPort'] = $ownPort
# Write out the keys seen
Write-Verbose "Build Agent updated settings"
$buildAgentProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose
$buildAgentProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Out-File $agentDir\conf\buildAgent.properties

# Configure service wrapper to allow multiple instances on a single machine
# This rewrites the wrapper config file without comments, if you need the comments, don't supply the agentName when installing to get the default config
if (-Not ($defaultName -eq $true)) {
    $wrapperProps = [ordered]@{}
    $wrapperConf = get-content $agentDir\launcher\conf\wrapper.conf 
    $wrapperConf | %{if (`
                            (!($_.StartsWith('#')))`
                                -and (!($_.StartsWith(';')))`
                                -and (!($_.StartsWith(";")))`
                                -and (!($_.StartsWith('`')))`
                                -and (($_.Contains('=')))){
                                    $wrapperProps.add($_.split('=',2)[0],$_.split('=',2)[1])
                            }
                    }
    Write-Verbose "Java Service Wrapper original settings"
    $wrapperProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose
    # Name of the service
    $wrapperProps['wrapper.ntservice.name'] = "$agentName"
    # Display name of the service
    $wrapperProps['wrapper.ntservice.displayname'] = "$agentName TeamCity Build Agent"
    # Description of the service
    $wrapperProps['wrapper.ntservice.description'] = "$agentName TeamCity Build Agent Service"
    #$wrapperProps['']
    # Write out the keys seen, can't do it inline because JavaServiceWrapper is picky about encoding
    Write-Verbose "Java Service Wrapper updated settings"
    $wrapperProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose
    $wrapperProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Out-File $agentDir\launcher\conf\wrapper.conf -Encoding 'ASCII'
}

# Future state, catch failure and call chocolateyUninstall.ps1 or some other cleanup
# trap exit 1 { Start-ChocolateyProcessAsAdmin "/C `"$agentdir\bin\service.stop.bat; $agentDir\bin\service.uninstall.bat; rm -r -fo $agentDir `"" cmd }
Start-ChocolateyProcessAsAdmin "/C `"$agentDrive && cd /d $agentDir\bin && $agentDir\bin\service.install.bat && $agentDir\bin\service.start.bat`"" cmd
