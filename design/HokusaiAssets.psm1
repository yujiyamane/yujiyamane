Set-StrictMode -Version Latest

function Get-HkTokens {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { throw "Token file not found: $Path" }
    $css = Get-Content $Path -Raw
    $tokens = @{}
    foreach ($m in [regex]::Matches($css, '--hk-([a-z0-9-]+):\s*([^;]+);')) {
        $val = ($m.Groups[2].Value -replace '/\*.*?\*/', '') -replace '\s+', ' '
        $tokens[$m.Groups[1].Value] = $val.Trim()
    }
    if ($tokens.Count -eq 0) { throw "No --hk-* tokens found in $Path" }
    return $tokens
}

function ConvertTo-HkOutlinedText {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Font,
        [Parameter(Mandatory)][double]$Size,
        [double]$X = 0,
        [double]$Y = 0,
        [string]$Fill = '#000000',
        [double]$LetterSpacingEm = 0,
        [switch]$Vertical,
        [string]$Id,
        [switch]$Measure
    )
    $py = Join-Path $PSScriptRoot 'outline_text.py'
    $argv = @($py, '--font', $Font, '--text', $Text, '--size', $Size,
              '--x', $X, '--y', $Y, '--fill', $Fill)
    if ($LetterSpacingEm) { $argv += @('--letter-spacing', $LetterSpacingEm) }
    if ($Vertical) { $argv += '--vertical' }
    if ($Id) { $argv += @('--id', $Id) }
    if ($Measure) { $argv += '--measure' }
    $out = & python @argv 2>&1
    if ($LASTEXITCODE -ne 0) { throw "outline_text.py failed: $out" }
    return ($out -join '')
}

function Get-HkTextWidth {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Font,
        [Parameter(Mandatory)][double]$Size,
        [double]$LetterSpacingEm = 0
    )
    [double](ConvertTo-HkOutlinedText -Text $Text -Font $Font -Size $Size `
        -LetterSpacingEm $LetterSpacingEm -Measure)
}

function New-HkBannerSvg {
    param(
        [Parameter(Mandatory)][hashtable]$Tokens,
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][string]$FontsDir
    )
    $w = [int]$Config.Width
    $h = [int]$Config.Height
    $t = $Tokens

    $fMono   = Join-Path $FontsDir 'IBMPlexMono-SemiBold.ttf'
    $fMonoMd = Join-Path $FontsDir 'IBMPlexMono-Medium.ttf'
    $fSerif  = Join-Path $FontsDir 'ShipporiMinchoB1-SemiBold.ttf'
    $fSans   = Join-Path $FontsDir 'ZenKakuGothicNew-Medium.ttf'

    $headerH = [int]($h * 0.62)
    $scallopY = $headerH
    $left = 64

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("<svg xmlns=`"http://www.w3.org/2000/svg`" width=`"$w`" height=`"$h`" viewBox=`"0 0 $w $h`" role=`"img`" aria-label=`"$($Config.Title)`">")
    [void]$sb.Append('<defs>')
    [void]$sb.Append("<linearGradient id=`"wash`" x1=`"0`" y1=`"0`" x2=`"0`" y2=`"1`">")
    [void]$sb.Append("<stop offset=`"0`" stop-color=`"$($t['blue-deep'])`"/>")
    [void]$sb.Append('<stop offset="0.35" stop-color="#1E4568"/>')
    [void]$sb.Append('<stop offset="0.68" stop-color="#3A6B96"/>')
    [void]$sb.Append('<stop offset="0.88" stop-color="#8FB3CC"/>')
    [void]$sb.Append("<stop offset=`"1`" stop-color=`"$($t['blue-pale'])`"/>")
    [void]$sb.Append('</linearGradient>')
    [void]$sb.Append("<clipPath id=`"card`"><rect x=`"1`" y=`"1`" width=`"$($w-2)`" height=`"$($h-2)`" rx=`"8`"/></clipPath>")
    [void]$sb.Append('</defs>')

    # washi card base + header wash, clipped to rounded card
    [void]$sb.Append("<g clip-path=`"url(#card)`">")
    [void]$sb.Append("<rect x=`"0`" y=`"0`" width=`"$w`" height=`"$h`" fill=`"$($t['card'])`"/>")
    [void]$sb.Append("<rect x=`"0`" y=`"0`" width=`"$w`" height=`"$scallopY`" fill=`"url(#wash)`"/>")

    # foam scallop divider: pale band + repeated foam circles (06L spec)
    $bandH = 14
    [void]$sb.Append("<rect x=`"0`" y=`"$scallopY`" width=`"$w`" height=`"$bandH`" fill=`"$($t['blue-pale'])`"/>")
    for ($cx = 9; $cx -lt ($w + 18); $cx += 18) {
        [void]$sb.Append("<circle cx=`"$cx`" cy=`"$($scallopY + $bandH)`" r=`"8`" fill=`"$($t['foam'])`"/>")
    }
    [void]$sb.Append("<rect x=`"0`" y=`"$($scallopY + $bandH + 8)`" width=`"$w`" height=`"$($h - $scallopY - $bandH - 8)`" fill=`"$($t['card'])`"/>")

    # kicker
    if ($Config.Kicker) {
        [void]$sb.Append((ConvertTo-HkOutlinedText -Text $Config.Kicker -Font $fMono -Size 15 `
            -X $left -Y 86 -Fill $t['gold'] -LetterSpacingEm 0.18 -Id 'kicker'))
    }
    # title
    [void]$sb.Append((ConvertTo-HkOutlinedText -Text $Config.Title -Font $fSerif -Size 56 `
        -X $left -Y 152 -Fill $t['card'] -Id 'title'))
    # tagline
    if ($Config.Tagline) {
        [void]$sb.Append((ConvertTo-HkOutlinedText -Text $Config.Tagline -Font $fSans -Size 21 `
            -X $left -Y 190 -Fill $t['blue-pale'] -Id 'tagline'))
    }

    # hanko top-right: vermilion rounded-3 square, vertical kanji in card colour
    if ($Config.Hanko) {
        $hx = $w - 116; $hy = 44; $hw = 52; $hh = 96
        [void]$sb.Append("<g id=`"hanko`"><rect x=`"$hx`" y=`"$hy`" width=`"$hw`" height=`"$hh`" rx=`"3`" fill=`"$($t['vermil'])`"/>")
        [void]$sb.Append((ConvertTo-HkOutlinedText -Text $Config.Hanko -Font $fSerif -Size 34 `
            -X ($hx + 9) -Y ($hy + 40) -Fill $t['card'] -Vertical))
        [void]$sb.Append('</g>')
    }

    # install command bar on washi zone
    if ($Config.ContainsKey('Install') -and $Config.Install) {
        $cmdSize = 19
        $prompt = '>'
        $pw = Get-HkTextWidth -Text "$prompt " -Font $fMonoMd -Size $cmdSize
        $cw = Get-HkTextWidth -Text $Config.Install -Font $fMonoMd -Size $cmdSize
        $barW = [math]::Ceiling($pw + $cw + 56)
        $barY = $scallopY + $bandH + 30
        $barH = 52
        [void]$sb.Append("<g id=`"install-bar`"><rect x=`"$left`" y=`"$barY`" width=`"$barW`" height=`"$barH`" rx=`"6`" fill=`"$($t['blue-deep'])`"/>")
        $ty = $barY + 33
        [void]$sb.Append((ConvertTo-HkOutlinedText -Text $prompt -Font $fMonoMd -Size $cmdSize `
            -X ($left + 22) -Y $ty -Fill $t['gold']))
        [void]$sb.Append((ConvertTo-HkOutlinedText -Text $Config.Install -Font $fMonoMd -Size $cmdSize `
            -X ($left + 22 + $pw + 6) -Y $ty -Fill $t['foam']))
        [void]$sb.Append('</g>')
    }

    [void]$sb.Append('</g>')
    # hairline border so the card reads on GitHub dark mode
    [void]$sb.Append("<rect x=`"1`" y=`"1`" width=`"$($w-2)`" height=`"$($h-2)`" rx=`"8`" fill=`"none`" stroke=`"$($t['hair'])`" stroke-width=`"1`"/>")
    [void]$sb.Append('</svg>')
    return $sb.ToString()
}

Export-ModuleMember -Function Get-HkTokens, ConvertTo-HkOutlinedText, Get-HkTextWidth, New-HkBannerSvg
