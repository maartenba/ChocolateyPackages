
$ErrorActionPreference = 'Stop'; # stop on all errors

if ($env:chocolateyPackageParameters -eq $null) {
	throw "No parameters have been passed into Chocolatey install, e.g. -params 'serverUrl=http://... agentName=... agentDir=... serviceAccount=... serviceAccountPassword=...'"
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

if ($parameters["agentWorkDir"] -eq $null) {
    $agentDir = $parameters["agentDir"];
    $parameters["agentWorkDir"] = "$agentDir\work"
    Write-Host No agent work directory is specified. Defaulting to $parameters["agentWorkDir"]
}

if ($parameters["agentTempDir"] -eq $null) {
    $agentDir = $parameters["agentDir"];
    $parameters["agentTempDir"] = "$agentDir\temp"
    Write-Host No agent temp directory is specified. Defaulting to $parameters["agentTempDir"]
}

if ($parameters["agentSystemDir"] -eq $null) {
    $agentDir = $parameters["agentDir"];
    $parameters["agentSystemDir"] = "$agentDir\system"
    Write-Host No agent system directory is specified. Defaulting to $parameters["agentSystemDir"]
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

if ($parameters["serviceAccount"] -eq $null) {
    $defaultServiceAccount = $true
    Write-Host No service account provided, will run as system account.
}

$agentZipArchiveName = "buildAgent.zip"
if ($parameters["downloadFullAgent"] -eq $true) {
    $agentZipArchiveName = "buildAgentFull.zip"
    Write-Host Will download full agent ZIP archive with plugins.
}

$packageName = "TeamCityAgent"
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

## Make local variables of it
$serverUrl = $parameters["serverUrl"];
$agentDir = $parameters["agentDir"];
$agentWorkDir = $parameters["agentWorkDir"].Replace("\","\\");
$agentTempDir = $parameters["agentTempDir"].Replace("\","\\");
$agentSystemDir = $parameters["agentSystemDir"].Replace("\","\\");
$agentName = $parameters["agentName"];
$ownPort = $parameters["ownPort"];
$serviceAccount = $parameters["serviceAccount"];
$serviceAccountPassword = $parameters["serviceAccountPassword"];
$agentDrive = split-path $agentDir -qualifier
$buildAgentDistFile = "$agentDir\conf\buildAgent.dist.properties"
$buildAgentPropFile = "$agentDir\conf\buildAgent.properties"

if($serviceAccount -ne $null)
{
    if($serviceAccount -notlike "*\*")
    {
        Write-Verbose "Service account has no '\' assuming local user"
        $serviceAccount = ".\$serviceAccount"
    }
}

# Write out the install parameters to a file for reference during upgrade/uninstall
# This doesn't currently preserve anything during an upgrade, it just helps locate the service control batch files
$parameters.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose
$parameters.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Out-File "$toolsDir/install-parameters.txt" -Encoding ascii

$currentConfig = $null
if((Test-Path -Path $buildAgentPropFile) -eq $true)
{
    Write-Verbose "Loading previous install settings"
    $currentConfig = Get-Content -Path $buildAgentPropFile
}

$packageArgs = @{
  packageName   = "$packageName"
  unzipLocation = "$agentDir"
  url           = "$serverUrl/update/$agentZipArchiveName"
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
if($currentConfig -ne $null)
{
    Write-Verbose "Keeping previous install settings"
    Set-Content -Path $buildAgentPropFile -Value $currentConfig
    $buildAgentProps = Get-PropsDictFromJavaPropsFile $buildAgentPropFile
}
else
{
    $buildAgentProps = Get-PropsDictFromJavaPropsFile $buildAgentDistFile
}

Write-Verbose "Build Agent original settings"
$buildAgentProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose

# Set values that require customization
$buildAgentProps['serverUrl'] = $serverUrl
$buildAgentProps['name'] = $agentName
$buildAgentProps['workDir'] = $agentWorkDir
$buildAgentProps['tempDir'] = $agentTempDir
$buildAgentProps['systemDir'] = $agentSystemDir
$buildAgentProps['ownPort'] = $ownPort

Write-Verbose "Build Agent updated settings"
$buildAgentProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose
$buildAgentProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Out-File $buildAgentPropFile -Encoding 'ascii'

# This rewrites the wrapper config file without comments, if you need the comments,
# don't supply an agentName or serviceAccount when installing to get the default config
if (-Not ($defaultName -eq $true -And $defaultServiceAccount -eq $true)) {
    $wrapperPropsFile = "$agentDir\launcher\conf\wrapper.conf"
    $wrapperProps = Get-PropsDictFromJavaPropsFile $wrapperPropsFile

    Write-Verbose "Java Service Wrapper original settings"
    $wrapperProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose
    # Supplying a custom agentName allows multiple instances on a single machine
    if (-Not ($defaultName -eq $true -Or $agentName -eq "")) {
        $wrapperProps['wrapper.ntservice.name'] = "$agentName"
        $wrapperProps['wrapper.ntservice.displayname'] = "$agentName TeamCity Build Agent"
        $wrapperProps['wrapper.ntservice.description'] = "$agentName TeamCity Build Agent Service"
    }
    if($serviceAccount -ne $null){
        $wrapperProps['wrapper.ntservice.account'] = "$serviceAccount"
	$wrapperProps['wrapper.ntservice.interactive'] = "false"
    }
    if($serviceAccountPassword -ne $null){
        $wrapperProps['wrapper.ntservice.password'] = "$serviceAccountPassword"
    }

    Write-Verbose "Java Service Wrapper updated settings"
    $wrapperProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose
    $wrapperProps.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Out-File $wrapperPropsFile -Encoding 'ascii'
}

# TODO: catch failure and call chocolateyUninstall.ps1 or some other cleanup
$workingDirectory = Join-Path $agentDir "bin"
Start-ChocolateyProcessAsAdmin "Set-Location $workingDirectory; Start-Process -FilePath .\service.install.bat -Wait"
Sleep 2
Start-ChocolateyProcessAsAdmin "Set-Location $workingDirectory; Start-Process -FilePath .\service.start.bat -Wait"
Sleep 2

$checkServiceName = "TCBuildAgent"
if (-Not ($defaultName -eq $true -Or $agentName -eq "")) {
    $checkServiceName = $agentName
}

if((Get-Service | Where-Object {$_.Status -eq "Running" -and $_.Name -eq $checkServiceName } | Measure-Object).Count -eq 0) {
    Set-PowerShellExitCode 1
} else {
    Set-PowerShellExitCode 0
}
