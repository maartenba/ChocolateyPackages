Install-ChocolateyPackage `
	'VS2013.4.exe' 'exe' "/Passive /NoRestart /Log $($env:temp)\VS20134.log" `
	'http://download.microsoft.com/download/9/4/3/9430B009-5E55-4D48-ADA6-CBC1E025573E/VS2013.4.exe' -validExitCodes @(0,3010)