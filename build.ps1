Write-Host "Building Chocolatey packages..."

$nugetExe = (Resolve-Path nuget.exe).Path

Remove-Item -Path artifacts -Force -Recurse -ErrorAction SilentlyContinue
mkdir artifacts | Out-Null

$nuspecs = Get-ChildItem -Path packages -Filter *.nuspec -Exclude tmp -Recurse

foreach ($nuspec in $nuspecs) {
    if (Test-Path "$($nuspec.Directory)\package.ps1") {
        Push-Location $nuspec.Directory
        .\package.ps1
        Pop-Location
    } else {
        choco pack $nuspec.FullName --output-directory "$PWD\artifacts"
    }
}

Write-Host "Finished building Chocolatey packages."