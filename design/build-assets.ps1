<#
Hokusai asset build pipeline.
Reads hokusai-theme.css design tokens, generates banner.svg with all text
outlined to paths (GitHub camo strips external fonts), then rasterises the
social preview PNG (1280x640) with resvg.

Usage:
  .\build-assets.ps1 -ConfigPath .\banner-config.json
                     [-FontsDir <dir>] [-ResvgPath <resvg.exe>]

banner-config.json:
  { "Width": 1280, "Height": 340, "Kicker": "...", "Title": "...",
    "Tagline": "...", "Hanko": "匠技", "Install": "...",
    "BannerOut": "../assets/banner.svg",
    "SocialPreviewOut": "../assets/social-preview.png" }

Requires: Python 3 + fonttools, resvg (social preview only).
Tests: Invoke-Pester .\tests\HokusaiAssets.Tests.ps1
#>
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'banner-config.json'),
    [string]$FontsDir = ($env:HK_FONTS_DIR ?? (Join-Path $PSScriptRoot 'fonts')),
    [string]$ResvgPath = ($env:HK_RESVG ?? 'resvg')
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HokusaiAssets.psm1') -Force

$cfgJson = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$cfg = @{}
$cfgJson.PSObject.Properties | ForEach-Object { $cfg[$_.Name] = $_.Value }

$tokens = Get-HkTokens -Path (Join-Path $PSScriptRoot 'hokusai-theme.css')
$svg = New-HkBannerSvg -Tokens $tokens -Config $cfg -FontsDir $FontsDir

$bannerOut = Join-Path $PSScriptRoot ($cfg['BannerOut'] ?? '..\assets\banner.svg')
New-Item -ItemType Directory -Force (Split-Path $bannerOut) | Out-Null
[System.IO.File]::WriteAllText($bannerOut, $svg, [System.Text.UTF8Encoding]::new($false))
Write-Host "banner.svg -> $bannerOut ($([math]::Round((Get-Item $bannerOut).Length/1KB,1)) KB)"

if ($cfg.ContainsKey('SocialPreviewOut') -and $cfg['SocialPreviewOut']) {
    if (-not (Test-Path $ResvgPath)) { throw "resvg not found at $ResvgPath" }
    $pngOut = Join-Path $PSScriptRoot $cfg['SocialPreviewOut']
    & $ResvgPath --width 1280 --height 640 --background '#FBF5E6' $bannerOut $pngOut
    Write-Host "social-preview.png -> $pngOut"
}
