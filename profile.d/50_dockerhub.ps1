if (-not $ProfileTools.fzf) { return }

function script:Format-HubCount {
    # 13502531642 -> 13.5G, 21409 -> 21.4k; keeps the fzf columns narrow.
    param([double]$Count)
    $units = @(@(1e9, 'G'), @(1e6, 'M'), @(1e3, 'k'))
    foreach ($unit in $units) {
        if ($Count -ge $unit[0]) { return ('{0:0.#}{1}' -f ($Count / $unit[0]), $unit[1]) }
    }
    "$([int]$Count)"
}

function Search-DockerHub {
    <#
    .SYNOPSIS
        Search Docker Hub, pick an image with fzf and return a "run" command for it.
    .DESCRIPTION
        Queries the Docker Hub search API, lists the results in fzf (relevance order, with
        official images marked, stars and pulls), and returns "<runtime> run --rm -it <image>" for
        the one you pick. By default it returns the text and does not run it; with --run (or -Run)
        it runs the command instead and returns nothing. The runtime is
        PROFILE_CONTAINER_RUNTIME ('docker' or 'podman'). Podman gets a fully qualified name
        (docker.io/library/nginx) because it does not assume Docker Hub for short names.
        The query may be several words without quotes.
    .EXAMPLE
        dhs nginx
    .EXAMPLE
        dhs --run lazysql
    .NOTES
        Requires: fzf (docker or podman only to run an image; without --run it is only named in the command)
        Aliases: dhs
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        [string[]]$Query,
        [switch]$Run
    )

    # "--run" is not a PowerShell parameter, so it arrives as part of the query; take it out.
    if ($Query -contains '--run') { $Run = $true; $Query = @($Query | Where-Object { $_ -ne '--run' }) }
    $text = ($Query -join ' ').Trim()
    if (-not $text) { Write-Warning 'Give a search query.'; return }
    $uri = 'https://hub.docker.com/v2/search/repositories/?page_size=50&query=' + [uri]::EscapeDataString($text)
    try {
        $response = Invoke-RestMethod -Uri $uri -TimeoutSec 15 -ErrorAction Stop
    }
    catch {
        Write-Warning "Docker Hub search failed: $($_.Exception.Message)"
        return
    }
    $images = @($response.results)
    if (-not $images) { Write-Warning "No images found for '$text'."; return }

    $fg = $PSStyle.Foreground
    $reset = $PSStyle.Reset
    $nameWidth = [Math]::Min(45, ($images | ForEach-Object { $_.repo_name.Length } | Measure-Object -Maximum).Maximum)
    $rows = for ($i = 0; $i -lt $images.Count; $i++) {
        $image = $images[$i]
        $official = $image.is_official ? "$($fg.Green)official$reset" : '        '
        $stars = (script:Format-HubCount $image.star_count).PadLeft(6)
        $pulls = (script:Format-HubCount $image.pull_count).PadLeft(7)
        "$i`t$($image.repo_name.PadRight($nameWidth))  $official  $($fg.Yellow)$stars stars$reset  $($fg.Cyan)$pulls pulls$reset  $($fg.BrightBlack)$($image.short_description)$reset"
    }

    $selected = $rows | & $ProfileTools.fzf --ansi --height=50% --layout=reverse --no-multi --info=inline-right `
        --tiebreak=index --delimiter '\t' --with-nth '2..' "--prompt=run ($text)> "
    if ($LASTEXITCODE -ne 0 -or -not $selected) { return }

    $image = $images[[int]($selected -split "`t", 2)[0]]
    $runtime = $env:PROFILE_CONTAINER_RUNTIME -eq 'podman' ? 'podman' : 'docker'
    $reference = $image.repo_name
    if ($runtime -eq 'podman') {
        $reference = $image.repo_name.Contains('/') ? "docker.io/$reference" : "docker.io/library/$reference"
    }
    $arguments = @('run', '--rm', '-it', $reference)
    if (-not $Run) { return "$runtime $($arguments -join ' ')" }

    if (-not (Get-Command $runtime -CommandType Application -ErrorAction Ignore)) {
        Write-Warning "$runtime is not installed. The command would have been: $runtime $($arguments -join ' ')"
        return
    }
    & $runtime @arguments
}

Set-Alias -Name dhs -Value Search-DockerHub
