Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (!(Get-Command -ErrorAction Silentlycontinue nuget.exe)) {
    choco install -y nuget.commandline
}

$nuspec = [xml](Get-Content XUnit.nuspec)
$version = $nuspec.package.metadata.version

Remove-Item -Force -Recurse -ErrorAction Silentlycontinue tmp
& $nugetExe install `
    xunit.runner.console `
    -Version $version `
    -OutputDirectory tmp
$expectedFrameworks = @(
    'net452'
    'netcoreapp1.0'
    'netcoreapp2.0'
)
$actualFrameworks = Get-ChildItem tmp/xunit.runner.console.$version/tools `
    | ForEach-Object { $_.Name } `
    | Sort-Object
if (Compare-Object $expectedFrameworks $actualFrameworks) {
    throw "Expecting the source nuget package to have the $expectedFrameworks frameworks but it has $actualFrameworks; you must revise the package."
}
mkdir tmp/pkg/tools | Out-Null
Move-Item tmp/xunit.runner.console.$version/tools/net452/* tmp/pkg/tools
Copy-Item XUnit.nuspec tmp/pkg
Push-Location tmp/pkg
try {
    choco pack XUnit.nuspec
	move *.nupkg ../../../
} finally {
    Pop-Location
}
