$ErrorActionPreference = 'Stop'
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$installation = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $installation) { throw 'Visual Studio C++ build tools are required.' }
$msbuild = Join-Path $installation 'MSBuild/Current/Bin/MSBuild.exe'
& $msbuild "$PSScriptRoot/BinaryPacker.sln" /m /p:Configuration=Release /p:Platform=x64 /verbosity:minimal
if ($LASTEXITCODE -ne 0) { throw 'Release x64 build failed.' }
$executable = Join-Path $PSScriptRoot 'build/x64/Release/BinaryPacker.exe'
& "$PSScriptRoot/tests/Verify.ps1" -Executable $executable

$version = (Get-Item -LiteralPath $executable).VersionInfo.ProductVersion
$dist = Join-Path $PSScriptRoot 'dist'
$package = Join-Path $dist "BinaryPacker-v$version-win64"
New-Item -ItemType Directory -Path $package -Force | Out-Null
Copy-Item -LiteralPath $executable -Destination "$dist/BinaryPacker.exe" -Force
Copy-Item -LiteralPath $executable -Destination "$package/BinaryPacker.exe" -Force
Copy-Item -LiteralPath "$PSScriptRoot/README.md" -Destination "$package/README.md" -Force
Compress-Archive -Path "$package/*" -DestinationPath "$package.zip" -Force
$hash = (Get-FileHash -LiteralPath "$package.zip" -Algorithm SHA256).Hash
"$hash  $([IO.Path]::GetFileName($package)).zip" | Set-Content -LiteralPath "$dist/SHA256SUMS.txt" -Encoding ascii
Write-Output "Release: $dist/BinaryPacker.exe"
Write-Output "Package: $package.zip"
