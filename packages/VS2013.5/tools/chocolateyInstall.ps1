Install-ChocolateyPackage `
	'VS2013.5.exe' 'exe' "/Passive /NoRestart /Log $($env:temp)\VS20135.log" `
	'http://download.microsoft.com/download/A/F/9/AF95E6F8-2E6E-49D0-A48A-8E918D7FD768/VS2013.5.exe' -validExitCodes @(0,3010)