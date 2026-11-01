# Pure diagnostic redaction rules. Filesystem access belongs to infrastructure.
Set-StrictMode -Version Latest

function Get-KapselRedactedText {
    [CmdletBinding()]
    param([AllowEmptyString()] [string] $Text)

    if ([string]::IsNullOrEmpty($Text)) { return '' }

    $result = $Text
    # Replace the most specific locations first so tokens stay readable.
    $pathReplacements = @(
        @{ Value = $env:TEMP; Token = '%TEMP%' },
        @{ Value = $env:LOCALAPPDATA; Token = '%LOCALAPPDATA%' },
        @{ Value = $env:APPDATA; Token = '%APPDATA%' },
        @{ Value = $env:USERPROFILE; Token = '%USERPROFILE%' }
    )
    foreach ($item in $pathReplacements) {
        if (-not [string]::IsNullOrWhiteSpace([string] $item.Value)) {
            $result = [regex]::Replace(
                $result,
                [regex]::Escape([string] $item.Value),
                [string] $item.Token,
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            )
        }
    }

    # Account/machine names are only replaced as whole tokens, so a short user name
    # cannot corrupt ordinary words such as "Administrator".
    $nameReplacements = @(
        @{ Value = $env:USERNAME; Token = '%USERNAME%' },
        @{ Value = $env:COMPUTERNAME; Token = '%COMPUTERNAME%' }
    )
    foreach ($item in $nameReplacements) {
        if (-not [string]::IsNullOrWhiteSpace([string] $item.Value)) {
            $pattern = '(?i)(?<![\w.-]){0}(?![\w.-])' -f [regex]::Escape([string] $item.Value)
            $result = [regex]::Replace($result, $pattern, [string] $item.Token)
        }
    }

    # Catch profile paths whose variables were unavailable in this process.
    $result = [regex]::Replace($result, '(?i)\b[A-Z]:\\Users\\[^\\\s"'']+', '%USERPROFILE%')
    return $result
}

Export-ModuleMember -Function 'Get-KapselRedactedText'
