# Two-line prompt modeled on "pure": blank line, path, then a caret.
# The caret turns red when the previous command failed.

function prompt {
    $succeeded = $?

    $path = $PWD.ProviderPath
    if ($path.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) {
        $path = '~' + $path.Substring($HOME.Length)
    }

    $caretColor = $succeeded ? $PSStyle.Foreground.Magenta : $PSStyle.Foreground.Red

    "`n$($PSStyle.Foreground.Blue)$path$($PSStyle.Reset)`n$caretColor❯$($PSStyle.Reset) "
}
