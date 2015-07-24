$downloadLink32 = 'http://downloads.sourceforge.net/project/tortoisesvn/1.8.9/Application/TortoiseSVN-1.8.9.26117-win32-svn-1.8.11.msi';
$downloadLink64 = 'http://downloads.sourceforge.net/project/tortoisesvn/1.8.9/Application/TortoiseSVN-1.8.9.26117-x64-svn-1.8.11.msi';

Install-ChocolateyPackage 'tortoisesvn' 'msi' '/quiet /norestart ADDLOCAL=ALL' $downloadLink32 $downloadLink64