param([Parameter(Mandatory)][string]$Executable)
$ErrorActionPreference = 'Stop'
$Executable = (Resolve-Path -LiteralPath $Executable).Path
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('BinaryPacker-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $sandbox | Out-Null
$count = 0

function Check([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Run([string[]]$Files = @(), [int]$ExitCode = 0) {
    $settings = New-Object Diagnostics.ProcessStartInfo
    $settings.FileName = $Executable
    $settings.Arguments = ($Files | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $settings.UseShellExecute = $false
    $settings.CreateNoWindow = $true
    $settings.RedirectStandardInput = $true
    $settings.RedirectStandardOutput = $true
    $settings.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($settings)
    try {
        $process.StandardInput.Close()
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Execution timed out' }
        Check ($process.ExitCode -eq $ExitCode) "Unexpected exit code: $($process.ExitCode), $($errors.Result)"
        return $output.Result + $errors.Result
    }
    finally { $process.Dispose() }
}
function Verify([string]$Source, [string]$Packed, [byte[]]$Expected) {
    $reader = New-Object IO.BinaryReader([IO.File]::OpenRead($Packed))
    try {
        Check ([Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -ceq 'SBIN') 'Wrong magic'
        Check ($reader.ReadUInt16() -eq 1) 'Wrong format version'
        $length = $reader.ReadUInt16()
        Check ($reader.ReadUInt64() -eq $Expected.LongLength) 'Wrong payload length'
        Check ([Text.Encoding]::UTF8.GetString($reader.ReadBytes($length)) -ceq [IO.Path]::GetFileName($Source)) 'Wrong filename'
        Check ([Convert]::ToBase64String($reader.ReadBytes($Expected.Length)) -ceq [Convert]::ToBase64String($Expected)) 'Wrong payload'
        Check ($reader.BaseStream.Position -eq $reader.BaseStream.Length) 'Unexpected trailing bytes'
        Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes($Source)) -ceq [Convert]::ToBase64String($Expected)) 'Source modified'
    }
    finally { $reader.Dispose() }
}
function Passed([string]$Name) {
    $script:count++
    Write-Output "PASS $Name"
}

try {
    Check ((Run).Contains('BinaryPacker.exe')) 'No usage text'
    Passed 'usage'

    $text = Join-Path $sandbox ('한글 공백 ' + [char]::ConvertFromUtf32(0x1F40D) + '.txt')
    $payload = [Text.Encoding]::UTF8.GetBytes("첫째 줄`r`n둘째 줄`0")
    [IO.File]::WriteAllBytes($text, $payload)
    Check ((Run @($text)).Contains([IO.Path]::GetFileName($text))) 'Unicode console output lost'
    Verify $text "$text.sb" $payload
    Passed 'Unicode paths, text and null byte'

    $empty = Join-Path $sandbox 'empty'
    [IO.File]::WriteAllBytes($empty, [byte[]]@())
    Run @($empty) | Out-Null
    Verify $empty "$empty.sb" ([byte[]]@())
    Passed 'empty extensionless file'

    $binary = Join-Path $sandbox 'model.bin'
    $bytes = New-Object byte[] (3 * 1024 * 1024 + 17)
    (New-Object Random(13)).NextBytes($bytes)
    [IO.File]::WriteAllBytes($binary, $bytes)
    Run @($binary) | Out-Null
    Verify $binary "$binary.sb" $bytes
    Passed 'binary spanning four copy chunks'

    [IO.File]::WriteAllText("$binary (1).sb", 'preserve')
    Run @($binary) | Out-Null
    Verify $binary "$binary (2).sb" $bytes
    Verify $binary "$binary.sb" $bytes
    Check ([IO.File]::ReadAllText("$binary (1).sb") -ceq 'preserve') 'Existing file overwritten'
    Passed 'collision numbering and original preservation'

    Run @("$text.sb") | Out-Null
    Verify "$text.sb" "$text.sb.sb" ([IO.File]::ReadAllBytes("$text.sb"))
    Passed 'SB file input'

    $missing = Join-Path $sandbox 'missing'
    Run @($sandbox, $missing, $empty, $text) 1 | Out-Null
    Verify $empty "$empty (1).sb" ([byte[]]@())
    Verify $text "$text (1).sb" $payload
    Check (-not (Test-Path -LiteralPath "$missing.sb")) 'Output for invalid input'
    Passed 'batch continues after directory and missing input'

    $locked = Join-Path $sandbox 'locked.dat'
    [IO.File]::WriteAllBytes($locked, $payload)
    $writer = [IO.File]::Open($locked, 'Open', 'ReadWrite', 'Read')
    try { Run @($locked) 1 | Out-Null }
    finally { $writer.Dispose() }
    Check (-not (Test-Path -LiteralPath "$locked.sb")) 'Writer conflict generated output'
    Passed 'reject source with active writer'

    $gold = Join-Path $sandbox 'a'
    [IO.File]::WriteAllBytes($gold, [byte[]](0, 255))
    Run @($gold) | Out-Null
    $hex = [BitConverter]::ToString([IO.File]::ReadAllBytes("$gold.sb"))
    Check ($hex -ceq '53-42-49-4E-01-00-01-00-02-00-00-00-00-00-00-00-61-00-FF') 'SB v1 fixture mismatch'
    Passed 'exact SB v1 byte fixture'

    Check ((Get-Item -LiteralPath $Executable).VersionInfo.ProductVersion -eq '1.1.0') 'Wrong release version'
    Passed 'Windows executable version'
    Write-Output "$count integration tests passed."
}
finally {
    $absoluteSandbox = [IO.Path]::GetFullPath($sandbox)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $absoluteSandbox.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($absoluteSandbox) -notlike 'BinaryPacker-test-*') { throw 'Unsafe cleanup path' }
    Remove-Item -LiteralPath $absoluteSandbox -Recurse -Force
}
