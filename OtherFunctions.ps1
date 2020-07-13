Function Get-ZippedInstallScript ($nupkgPath) {
	#needed for accessing dotnet zip functions
	Add-Type -AssemblyName System.IO.Compression.FileSystem

	#open the nupkg as readonly
	$archive = [System.IO.Compression.ZipFile]::OpenRead($nupkgPath)

	#check if installscript in inside nuspec
	if ($archive.Entries.name -notcontains "chocolateyInstall.ps1") {
		$installScript = $null
		$status = "noscript"
	} else {
		#get path inside nupkg
		$ScriptPath = ($archive.Entries | Where-Object { $_.FullName -like "*chocolateyInstall.ps1" })

		#open the path
		$scriptStream = $ScriptPath.open()
		$reader = New-Object Io.streamreader($scriptStream)

		#read install script into installscript variable
		$installScript = $reader.Readtoend()
		$status = "ready"

		$scriptStream.close()
		$reader.close()

	}
	$archive.dispose()
	
	return $status, $installScript
}


Function Get-NuspecVersion ($nupkgPath) {
	#needed for accessing dotnet zip functions
	Add-Type -AssemblyName System.IO.Compression.FileSystem

	$archive = [System.IO.Compression.ZipFile]::OpenRead($nupkgPath)

 	$nuspecStream = ($archive.Entries | Where-Object { $_.FullName -like "*.nuspec" }).open()
	$nuspecReader = New-Object Io.streamreader($nuspecStream)
	$nuspecString = $nuspecReader.ReadToEnd()

	#cleanup opened variables
	$nuspecStream.close()
	$nuspecReader.close()
	$archive.dispose()
	
	return ([XML]$nuspecString).package.metadata.version, ([XML]$nuspecString).package.metadata.id
}


#no need return stuff
#changeme to work with individual strings
Function Extract-Nupkg ($obj) {
	#needed for accessing dotnet zip functions
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	[System.IO.Compression.ZipFile]::ExtractToDirectory($obj.origPath, $obj.versionDir)

	#force needed due to wacky permissions after extract
	Remove-Item -Force -Recurse -ea 0 -LiteralPath (Join-Path $obj.versionDir '_rels')
	Remove-Item -Force -Recurse -ea 0 -LiteralPath (Join-Path $obj.versionDir "package")
	Remove-Item -Force -Recurse -ea 0 -LiteralPath (Join-Path $obj.versionDir '[Content_Types].xml')
	Remove-Item -Force -Recurse -ea 0 -LiteralPath (Join-Path $obj.versionDir '__MACOSX')

}


#no need return stuff
#changeme to work with individual strings
Function Write-UnzippedInstallScript ($obj) {
	(Get-ChildItem $obj.toolsDir -Filter "*chocolateyinstall.ps1").fullname | % { Remove-Item -Force -Recurse -ea 0 -Path $_ } -ea 0
	$scriptPath = Join-Path $obj.toolsDir 'chocolateyinstall.ps1'
	Out-File -FilePath $scriptPath -InputObject $obj.installScriptMod -Force | Out-Null

}


#fixme to work with multiple versions and packages at one time, returning?
#changeme to work with individual strings
Function Write-PerPkg {
	param (
		[parameter(Mandatory=$true)][string]$version,
		[parameter(Mandatory=$true)][string]$nuspecID,
		[parameter(Mandatory=$true)][string]$personalPkgXMLPath
	)

	$nuspecID = $nuspecID.tolower()
	[XML]$perpkgXMLcontent = Get-Content $personalPkgXMLPath
	

	if ($perpkgXMLcontent.mypackages.internalized.pkg.id -notcontains "$nuspecID") {
		Write-Verbose "adding $nuspecID to internalized IDs"
		$addID = $perpkgXMLcontent.CreateElement("pkg")
		$addID.SetAttribute("id","$nuspecID")
		$perpkgXMLcontent.mypackages.internalized.AppendChild($addID)  | Out-Null
		$perpkgXMLcontent.save($PersonalPkgXMLPath)
		
		[XML]$perpkgXMLcontent = Get-Content $PersonalPkgXMLPath
	}
	
	Write-Verbose "adding $nuspecID $version to list of internalized packages"
	$addVersion = $perpkgXMLcontent.CreateElement("version")
	$addVersionText = $addVersion.AppendChild($perpkgXMLcontent.CreateTextNode("$version"))
	$perpkgXMLcontent.SelectSingleNode("//pkg[@id=""$nuspecID""]").appendchild($addVersion) | Out-Null
	$perpkgXMLcontent.save($PersonalPkgXMLPath)
	
}


Function Get-ChocoApiKeysUrls {
	$configPath = [System.IO.Path]::Combine([Environment]::GetEnvironmentVariable("ChocolateyInstall"), "config" , "chocolatey.config")
	If (Test-Path $configPath) {
		[XML]$configXML = Get-Content $configPath
		Return $configXML.chocolatey.apiKeys.apiKeys.source
	} else {
		Throw "$configPath is not valid, please check your chocolatey install"
	}
	
}

#no need return stuff
#changeme to work with single
Function download-fileBoth {
	param (
		[parameter(Mandatory=$true)][string]$url32 = $null,
		[parameter(Mandatory=$true)][string]$url64 = $null,
		[parameter(Mandatory=$true)][string]$filename32 = $null,
		[parameter(Mandatory=$true)][string]$filename64 = $null,
		[parameter(Mandatory=$true)][string]$toolsDir = $null
	)

	$dlwdFile32 = (Join-Path $obj.toolsDir "$filename32")
	$dlwdFile64 = (Join-Path $obj.toolsDir "$filename64")

	$dlwd = New-Object net.webclient
	$dlwd.Headers.Add('user-agent', [Microsoft.PowerShell.Commands.PSUserAgent]::firefox)
	
	if (Test-Path $dlwdFile32) {
		Write-Output "$dlwdFile32 appears to be downloaded"
	} else {
		$dlwd.DownloadFile($url32, $dlwdFile32)
	}

	if (Test-Path $dlwdFile64) {
		Write-Output "$dlwdFile64 appears to be downloaded"
	} else {
		$dlwd.DownloadFile($url64, $dlwdFile64)
	}

	$dlwd.dispose()
	# download-fileBoth -url32 $url32 -url64 $url64 -filename32 $filename32 -filename64 $filename64 -toolsDir $obj.toolsDir
}


#no need return stuff
Function download-fileSingle {
	param (
		[parameter(Mandatory=$true)][string]$url = $null,
		[parameter(Mandatory=$true)][string]$filename = $null,
		[parameter(Mandatory=$true)][string]$toolsDir = $null
	)

	$dlwdFile = (Join-Path $obj.toolsDir "$filename")
	$dlwd = New-Object net.webclient
	$dlwd.Headers.Add('user-agent', [Microsoft.PowerShell.Commands.PSUserAgent]::firefox)
	
	if (Test-Path $dlwdFile) {
		Write-Output "$dlwdFile appears to be downloaded"
	} else {
		$dlwd.DownloadFile($url, $dlwdFile)
	}

	$dlwd.dispose()
	# download-fileSingle -url $url32 -filename $filename32 -toolsDir $obj.toolsDir
}


#no need return stuff
#changeme to work single
Function mod-installcpkg-both {
	param ( 
		[parameter(Mandatory=$true)]$obj,
		[parameter(Mandatory=$true)][int]$urltype,
		[parameter(Mandatory=$true)][int]$argstype,
		[switch]$needsTools,
		[switch]$needsEA,
		[switch]$stripQueryString,
		[switch]$checksum,
		[switch]$x64NameExt,
		[switch]$DeEncodeSpace,
		[switch]$removeEXE,
		[int]$checksumType
	)
	
	
	
	if ($urltype -eq 0) {
		$fullurl32 = ($obj.installScriptOrig -split "`n" | Select-String -pattern " Url ").tostring()
		$fullurl64 = ($obj.installScriptOrig -split "`n" | Select-String -pattern " Url64bit ").tostring()
	} elseif ($urltype -eq 1) {
		$fullurl32 = ($obj.installScriptOrig -split "`n" | Select-String -pattern '^\$Url32 ').tostring()
		$fullurl64 = ($obj.installScriptOrig -split "`n" | Select-String -pattern '^\$Url64 ').tostring()
	} elseif ($urltype -eq 2) {
		$fullurl32 = ($obj.installScriptOrig -split "`n" | Select-String -pattern '^\$Url ').tostring()
		$fullurl64 = ($obj.installScriptOrig -split "`n" | Select-String -pattern '^\$Url64 ').tostring()
	} elseif ($urltype -eq 3) {
		$fullurl32 = ($obj.installScriptOrig -split "`n" | Select-String -pattern " Url ").tostring()
		$fullurl64 = ($obj.installScriptOrig -split "`n" | Select-String -pattern " Url64 ").tostring()
	} elseif ($urltype -eq 4) {
		$fullurl32 = ($obj.installScriptOrig -split "`n" | Select-String -pattern "Url ").tostring()
		$fullurl64 = ($obj.installScriptOrig -split "`n" | Select-String -pattern "Url64 ").tostring()
	} else {
		Write-Error "could not find url type"
	}


	
	$url32 = ($fullurl32 -split "'" | Select-String -Pattern "http").tostring()
	$url64 = ($fullurl64 -split "'" | Select-String -Pattern "http").tostring()

	if ($stripQueryString) {
		$url32 = $url32 -split "\?" | select-object -First 1
		$url64 = $url64 -split "\?" | select-object -First 1
	}
	
	$filename32 = ($url32 -split "/" | Select-Object -Last 1).tostring()
	$filename64 = ($url64 -split "/" | Select-Object -Last 1).tostring()
	
	if ($DeEncodeSpace) {
		$filename32 = $filename32 -replace '%20' , " "
		$filename64 = $filename64 -replace '%20' , " "
	}

	if ($x64NameExt) {
		$filename64 = $filename64.Insert(($filename64.Length - 4), "_x64")
	}


	if ($argstype -eq 0) {
		$filePath32 = 'file     = (Join-Path $toolsDir "' + $filename32 + '")'
		$filePath64 = 'file64	= (Join-Path $toolsDir "' + $filename64 + '")'
		$obj.installScriptMod = $obj.installScriptMod -replace "packageArgs = @{" , "$&`n    $filePath32`n    $filePath64"
	} else {
		Write-Error "could not find args type"
	}


	$obj.installScriptMod = $obj.installScriptMod -replace "Install-ChocolateyPackage" , "Install-ChocolateyInstallPackage"


	if ($needsTools) {
		$obj.installScriptMod = '$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"' + "`n" + $obj.InstallScriptMod
	}
	if ($needsEA) {
		$obj.installScriptMod = '$ErrorActionPreference = ''Stop''' + "`n" + $obj.InstallScriptMod
	}
	if ($removeEXE) {
		$exeRemoveString = "`n" + 'Get-ChildItem $toolsDir\*.exe | ForEach-Object { Remove-Item $_ -ea 0; if (Test-Path $_) { Set-Content "$_.ignore" } }'
		$obj.installScriptMod = $obj.installScriptMod + $exeRemoveString
	}


	Write-Output "Downloading $($obj.NuspecID) files"
	download-fileBoth -url32 $url32 -url64 $url64 -filename32 $filename32 -filename64 $filename64 -toolsDir $obj.toolsDir
	#add checksum here, or in download file?

}