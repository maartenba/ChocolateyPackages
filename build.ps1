Write-Host "Building Chocolatey packages..."

$nuspecs = Get-ChildItem -Path $PSScriptRoot -Filter *.nuspec -Recurse

foreach ($nuspec in $nuspecs) {
    choco pack $nuspec.FullName
}

$artifactsFolder = "./artifacts"

Remove-Item -Path $artifactsFolder -Force -Recurse -ErrorAction SilentlyContinue
New-Item $artifactsFolder -Force -Type Directory | Out-Null
Move-Item *.nupkg $artifactsFolder

Write-Host "Finished building Chocolatey packages."