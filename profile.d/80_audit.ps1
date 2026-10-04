function Invoke-ProfileAudit {
    <#
    .SYNOPSIS
        Report which optional tools the profile found, and how to install the missing ones.
    .DESCRIPTION
        Reads the tool registry in tools.ps1 and the lookup results from startup. Each missing
        tool is listed with what it does, an install command, and its project page. The report
        reflects what this shell saw when it started, so open a new shell after installing.
    .PARAMETER PassThru
        Also return one object per tool (Name, Found, Path, Description, Install, Url).
    .NOTES
        Aliases: audit
    #>
    [CmdletBinding()]
    param([switch]$PassThru)

    $results = foreach ($spec in $global:ProfileToolSpecs) {
        $path = $global:ProfileTools[$spec.Name]
        [pscustomobject]@{
            Name        = $spec.Name
            Found       = [bool]$path
            Path        = $path
            Description = $spec.Description
            Install     = $spec.Hint ?? "winget install --id $($spec.Winget) --exact"
            Url         = $spec.Url
        }
    }

    $green = $PSStyle.Foreground.Green
    $red = $PSStyle.Foreground.Red
    $dim = $PSStyle.Foreground.BrightBlack
    $reset = $PSStyle.Reset
    $width = ($results.Name | Measure-Object -Property Length -Maximum).Maximum

    Write-Host "`nProfile tool audit`n"
    foreach ($tool in $results) {
        $name = $tool.Name.PadRight($width)
        if ($tool.Found) {
            Write-Host "  $green✓$reset $name  $dim$($tool.Path)$reset"
        }
        else {
            Write-Host "  $red✗$reset $name  $($tool.Description)"
            Write-Host "      $dim install:$reset $($tool.Install)"
            Write-Host "      $dim    more:$reset $($tool.Url)"
        }
    }

    $found = @($results | Where-Object Found).Count
    Write-Host "`n$found of $($results.Count) tools found."
    if ($found -lt $results.Count) {
        Write-Host "Fragments that need a missing tool are skipped. Open a new shell after installing.`n"
    }
    else {
        Write-Host ''
    }

    if ($PassThru) { $results }
}

Set-Alias -Name audit -Value Invoke-ProfileAudit
