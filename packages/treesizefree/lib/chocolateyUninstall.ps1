

If (([environment]::Is64BitOperatingSystem) -match 'True'){$path = (Get-ItemProperty 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\TreeSize Free_is1\').InstallLocation}
Else {$path = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\TreeSize Free_is1').InstallLocation}
Uninstall-ChocolateyPackage 'treesizefree' 'exe' '/VERYSILENT /SUPPRESSMSGBOXES' ("$path" + "unins000.exe")