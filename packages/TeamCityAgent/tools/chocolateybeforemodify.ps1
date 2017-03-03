
$ErrorActionPreference = 'Stop' # stop on all errors

$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
# Don't use ConvertFrom-StringData as it corrupts Windows paths like C:\buildAgent
function Get-PropsDictFromJavaPropsFile ($configFile) {
    # Returns configProps ordered dict
    $config = Get-Content $configFile
    Write-Verbose "$config"
    $configProps = [ordered]@{}
    $config | %{if (`
                            (!($_.StartsWith('#')))`
                                -and (!($_.StartsWith(';')))`
                                -and (!($_.StartsWith(";")))`
                                -and (!($_.StartsWith('`')))`
                                -and (($_.Contains('=')))){
                                    $props = @()
                                    $props = $_.split('=',2)
                                    Write-Verbose "Props are $props"
                                    $configProps.add($props[0],$props[1])
                            }
                    }
    return $configProps
}
$installParametersFile = "$toolsDir/install-parameters.txt"
$installParameters = Get-PropsDictFromJavaPropsFile $installParametersFile
$installParameters.GetEnumerator() | % { "$($_.Name)=$($_.Value)" } | Write-Verbose
$agentDir = $installParameters["agentDir"]
$agentName = $installParameters["agentName"]
$agentDrive = split-path $agentDir -qualifier

Set-Location $agentDir\bin
Start-ChocolateyProcessAsAdmin "Start-Process -FilePath .\service.stop.bat -Wait"
Sleep 2
Start-ChocolateyProcessAsAdmin "Start-Process -FilePath .\service.uninstall.bat -Wait"