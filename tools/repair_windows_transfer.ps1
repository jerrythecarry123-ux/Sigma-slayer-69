& {
try {
    $molnPrevious = Get-History | Where-Object {
        $_.CommandLine -match '(?m)^H4sIAAAAAAACA80923IcN3b'
    } | Select-Object -Last 1
    if ($null -eq $molnPrevious) {
        throw 'Det gamla kommandot finns inte i detta fonster. Anvand samma PowerShell-fonster som gav CRC-felet.'
    }
    $molnMatch = [regex]::Match($molnPrevious.CommandLine, '(?m)^H4sIA[A-Za-z0-9+/=\s]+')
    $molnText = ($molnMatch.Value -replace '\s', '').Replace('CLiKUbxo3Vzm', 'CLiKUbxO3Vzm')
    $molnInput = [IO.MemoryStream]::new([Convert]::FromBase64String($molnText))
    $molnGzip = [IO.Compression.GZipStream]::new($molnInput, [IO.Compression.CompressionMode]::Decompress)
    $molnOutput = [IO.MemoryStream]::new()
    try {
        $molnGzip.CopyTo($molnOutput)
        $molnBytes = $molnOutput.ToArray()
    } finally {
        $molnGzip.Dispose()
        $molnInput.Dispose()
        $molnOutput.Dispose()
    }
    $molnHasher = [Security.Cryptography.SHA256]::Create()
    try {
        $molnHash = ([BitConverter]::ToString($molnHasher.ComputeHash($molnBytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $molnHasher.Dispose()
    }
    if ($molnHash -ne '13f9e8412f255cf377ede05070321de2709c471e056c89352be124fd57b865f8') {
        throw 'Filkontrollen misslyckades. Ingen fil har sparats.'
    }
    $molnFolder = [Environment]::GetFolderPath('DesktopDirectory')
    if ([string]::IsNullOrWhiteSpace($molnFolder)) {
        $molnFolder = [Environment]::GetFolderPath('UserProfile')
    }
    $molnPath = Join-Path $molnFolder ('Molnfiskarna-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.rbxlx')
    $molnFile = [IO.File]::Open($molnPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try {
        $molnFile.Write($molnBytes, 0, $molnBytes.Length)
    } finally {
        $molnFile.Dispose()
    }
    Write-Host 'Klart! Oppna filen i Roblox Studio:'
    Write-Host $molnPath
} catch {
    Write-Error $_.Exception.Message
}
}
