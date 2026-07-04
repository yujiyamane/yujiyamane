BeforeAll {
    Import-Module "$PSScriptRoot\..\HokusaiAssets.psm1" -Force
    $script:themePath = "$PSScriptRoot\..\hokusai-theme.css"
    $script:fontsDir = $env:HK_FONTS_DIR ?? (Join-Path $PSScriptRoot '..\fonts')
    if (-not (Test-Path (Join-Path $fontsDir 'IBMPlexMono-Medium.ttf'))) {
        throw "Fonts not found — set HK_FONTS_DIR or download per design/README (Google Fonts: Shippori Mincho B1, Zen Kaku Gothic New, IBM Plex Mono)"
    }
}

Describe 'Get-HkTokens' {
    It 'parses core tokens from hokusai-theme.css' {
        $t = Get-HkTokens -Path $themePath
        $t['blue-deep'] | Should -Be '#16324D'
        $t['blue']      | Should -Be '#235A8C'
        $t['card']      | Should -Be '#FBF5E6'
        $t['gold']      | Should -Be '#F4C86A'
        $t['vermil']    | Should -Be '#B93A2B'
        $t['hair']      | Should -Be '#DFD2B2'
        $t['blue-pale'] | Should -Be '#C9DAE4'
        $t['foam']      | Should -Be '#E9F1F6'
    }
    It 'throws on missing file' {
        { Get-HkTokens -Path "$PSScriptRoot\nope.css" } | Should -Throw
    }
    It 'parses at least 20 tokens' {
        (Get-HkTokens -Path $themePath).Count | Should -BeGreaterOrEqual 20
    }
}

Describe 'ConvertTo-HkOutlinedText' {
    It 'returns a <g> fragment with <path> elements and no <text>' {
        $frag = ConvertTo-HkOutlinedText -Text 'pbi' -Font "$fontsDir\IBMPlexMono-SemiBold.ttf" -Size 24 -X 10 -Y 50 -Fill '#F4C86A'
        $frag | Should -Match '^<g '
        $frag | Should -Match '<path '
        $frag | Should -Not -Match '<text'
    }
    It 'handles Japanese text (hanko kanji)' {
        $frag = ConvertTo-HkOutlinedText -Text '匠技' -Font "$fontsDir\ShipporiMinchoB1-SemiBold.ttf" -Size 20 -X 0 -Y 0 -Fill '#FBF5E6' -Vertical
        $frag | Should -Match '<path '
    }
    It 'applies letter spacing (wider bounding output for spaced text)' {
        $plain  = ConvertTo-HkOutlinedText -Text 'AB' -Font "$fontsDir\IBMPlexMono-Medium.ttf" -Size 20 -X 0 -Y 0 -Fill '#000000'
        $spaced = ConvertTo-HkOutlinedText -Text 'AB' -Font "$fontsDir\IBMPlexMono-Medium.ttf" -Size 20 -X 0 -Y 0 -Fill '#000000' -LetterSpacingEm 0.18
        $spaced | Should -Not -Be $plain
    }
}

Describe 'New-HkBannerSvg' {
    BeforeAll {
        $script:cfg = @{
            Width = 1280; Height = 340
            Kicker = 'CLAUDE CODE PLUGIN'; Title = 'test-banner'
            Tagline = 'A test tagline'; Hanko = '匠技'
            Install = '/plugin marketplace add yujiyamane/pbi-ai-skills'
        }
        $script:svg = New-HkBannerSvg -Tokens (Get-HkTokens -Path $themePath) -Config $cfg -FontsDir $fontsDir
    }
    It 'is valid XML' {
        { [xml]$svg } | Should -Not -Throw
    }
    It 'has the configured dimensions' {
        $x = [xml]$svg
        $x.svg.width | Should -Be '1280'
        $x.svg.height | Should -Be '340'
    }
    It 'contains no <text> elements (all text outlined to paths)' {
        $svg | Should -Not -Match '<text[ >]'
    }
    It 'contains outlined path glyphs' {
        ([regex]::Matches($svg, '<path ')).Count | Should -BeGreaterThan 10
    }
    It 'uses token colours, not foreign hex' {
        $svg | Should -Match '#16324D'
        $svg | Should -Match '#F4C86A'
        $svg | Should -Match '#B93A2B'
    }
    It 'has the 1px hair border for dark-mode separation' {
        $svg | Should -Match 'stroke="#DFD2B2"'
    }
    It 'omits the install bar when config has none' {
        $c2 = @{ Width = 1280; Height = 340; Kicker = 'K'; Title = 'T'; Tagline = 'x'; Hanko = '匠技' }
        $s2 = New-HkBannerSvg -Tokens (Get-HkTokens -Path $themePath) -Config $c2 -FontsDir $fontsDir
        $s2 | Should -Not -Match 'install-bar'
    }
    It 'every fill/stroke colour in output comes from the token file' {
        $tokens = Get-HkTokens -Path $themePath
        $allowed = @($tokens.Values | ForEach-Object { $_.ToUpper() }) + @('NONE', '#1E4568', '#3A6B96', '#8FB3CC', '#D9E4E0')
        $hexes = [regex]::Matches($svg, '(?:fill|stroke|stop-color)="(#[0-9A-Fa-f]{6})"') | ForEach-Object { $_.Groups[1].Value.ToUpper() } | Sort-Object -Unique
        foreach ($h in $hexes) { $allowed | Should -Contain $h }
    }
}
