
$ErrorActionPreference = 'Stop'; # stop on all errors

$packageName = 'TeamCityAgent'
$zipFileName = 'buildAgent.zip'

$uninstalled = $false
Uninstall-ChocolateyZipPackage -PackageName $packageName `
                                -ZipFileName  $zipFileName
$uninstalled = $true
