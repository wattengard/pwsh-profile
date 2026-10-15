if (-not $ProfileTools.claude) { return }

function Invoke-Tellme {
    <#
    .SYNOPSIS
        Ask Claude a quick question and get a terse, copy-ready answer.
    .DESCRIPTION
        Runs claude non-interactively (print mode) with a system prompt that asks for the bare
        answer: commands in a single code block, no reasoning, no preamble. Tools, MCP servers,
        skills and session history are all off, so it is a plain one-shot question. The model comes
        from PROFILE_TELLME_MODEL (sonnet by default) and the thinking effort
        from PROFILE_TELLME_EFFORT (low by default). The words
        after the command are the question, no quotes needed: tellme how to list running
        containers in podman
    .NOTES
        Requires: claude
        Aliases: tellme
    #>
    if (-not $args) { Write-Host 'Usage: tellme <question>'; return }

    $system = @'
You answer questions typed at a shell prompt. You run non-interactively: no conversation, no follow-up, nobody to ask. Reply with the bare answer only: no reasoning, preamble, caveats, alternatives, optional flags, related tips or closing remarks. Plain text only, no headings, bold, bullets or tables. Commands go in a fenced code block with no prompt characters or comments, ready to copy and run. Give the single best command, never a second one, and end your reply right after the closing code fence. When several approaches exist, pick the most common one and say nothing about the others. The user is on Windows 11 in PowerShell 7 unless the question says otherwise. If the question is ambiguous, answer the most likely reading. For a conceptual question, answer in one or two plain sentences.

<example>
<question>how do I list all docker images</question>
<answer>
```
docker images
```
</answer>
</example>

<example>
<question>delete a remote git branch</question>
<answer>
```
git push origin --delete <branch>
```
</answer>
</example>

<example>
<question>find files bigger than 100MB under the current folder</question>
<answer>
```
Get-ChildItem -Recurse -File | Where-Object Length -gt 100MB
```
</answer>
</example>

<example>
<question>how to see what is using port 8080</question>
<answer>
```
Get-NetTCPConnection -LocalPort 8080 | Select-Object OwningProcess
```
</answer>
</example>

<example>
<question>what does chmod 755 do</question>
<answer>
It sets the owner to read, write and execute, and everyone else to read and execute.
</answer>
</example>
'@

    $model = if ($env:PROFILE_TELLME_MODEL -in 'haiku', 'sonnet', 'opus') { $env:PROFILE_TELLME_MODEL } else { 'sonnet' }
    $effort = if ($env:PROFILE_TELLME_EFFORT -in 'low', 'medium', 'high') { $env:PROFILE_TELLME_EFFORT } else { 'low' }
    # Run from the temp folder: claude loads the CLAUDE.md and project context of its working
    # folder as input, which in a big repo costs ten times more per call (measured) for nothing,
    # since tellme has no tools and cannot read files anyway.
    Push-Location $env:TEMP
    try {
        & $ProfileTools.claude -p --model $model --effort $effort --system-prompt $system --tools '' --strict-mcp-config --disable-slash-commands --no-session-persistence ($args -join ' ')
    }
    finally { Pop-Location }
}

Set-Alias -Name tellme -Value Invoke-Tellme
