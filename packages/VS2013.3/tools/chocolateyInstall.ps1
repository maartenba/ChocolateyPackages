Install-ChocolateyPackage `
	'VS2013.3.exe' 'exe' "/Passive /NoRestart /Log $($env:temp)\VS20133.log" `
	'http://download.microsoft.com/download/0/4/1/0414085C-27A6-4842-ABC5-F545950A592F/VS2013.3.exe' -validExitCodes @(0,3010)