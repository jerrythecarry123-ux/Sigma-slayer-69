#!/usr/bin/env python3
"""Create an offline copy/paste transfer for Windows when chat downloads fail."""
import base64
import gzip
import hashlib
import textwrap

from build_place import ROOT, PLACE_NAME, build


def create_transfer() -> str:
    place = ROOT / "artifacts" / PLACE_NAME
    build(place)
    original = place.read_bytes()
    encoded = base64.b64encode(gzip.compress(original, mtime=0)).decode("ascii")
    checksum = hashlib.sha256(original).hexdigest()
    # Verify the exact transfer representation, including pasted line breaks.
    wrapped = "\n".join(textwrap.wrap(encoded, 96))
    assert gzip.decompress(base64.b64decode(wrapped)) == original
    return """& {
$molnData = @'
PAYLOAD
'@
try {
    $molnInput = [IO.MemoryStream]::new([Convert]::FromBase64String($molnData))
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
    if ($molnHash -ne 'CHECKSUM') {
        throw 'Kopieringen blev ofullstandig. Kopiera hela kodrutan igen.'
    }
    $molnDesktop = [Environment]::GetFolderPath('DesktopDirectory')
    if ([string]::IsNullOrWhiteSpace($molnDesktop)) {
        $molnDesktop = [Environment]::GetFolderPath('UserProfile')
    }
    $molnName = 'Molnfiskarna-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.rbxlx'
    $molnPath = Join-Path $molnDesktop $molnName
    $molnFile = [IO.File]::Open($molnPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try {
        $molnFile.Write($molnBytes, 0, $molnBytes.Length)
    } finally {
        $molnFile.Dispose()
    }
    Write-Host 'Klart! Oppna denna fil i Roblox Studio:'
    Write-Host $molnPath
} catch {
    Write-Error ('Kunde inte skapa filen: ' + $_.Exception.Message)
}
}
""".replace("PAYLOAD", wrapped).replace("CHECKSUM", checksum)


if __name__ == "__main__":
    path = ROOT / "artifacts/Skapa-Molnfiskarna.ps1"
    script = create_transfer()
    path.write_text(script, encoding="utf-8-sig")
    print(script)
