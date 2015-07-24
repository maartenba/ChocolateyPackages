Install-ChocolateyPackage `
	'VS2013.2.exe' 'exe' "/Passive /NoRestart /Log $($env:temp)\VS20132.log" `
	'http://download.microsoft.com/download/6/7/8/6783FB22-F77D-45C5-B989-090ED3E49C7C/VS2013.2.exe' -validExitCodes @(0,3010)