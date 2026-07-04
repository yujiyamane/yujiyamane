# Hokusai asset pipeline

Generates the profile banner from `hokusai-theme.css` design tokens. All text is outlined to vector paths (GitHub's camo proxy strips external fonts from SVGs), so the banner renders identically everywhere with zero font dependencies.

```
./build-assets.ps1 -ConfigPath ./banner-config.json
```

Requirements:

- PowerShell 7+, Python 3 with `fonttools`
- Fonts (not committed — OFL-licensed, download from [Google Fonts](https://github.com/google/fonts)): Shippori Mincho B1 SemiBold, Zen Kaku Gothic New Regular/Medium/Bold, IBM Plex Mono Medium/SemiBold. Place in `design/fonts/` or set `HK_FONTS_DIR`
- [resvg](https://github.com/linebender/resvg) on PATH (or `HK_RESVG`) — only for social-preview PNG export

Tests (14, Pester 5):

```
Invoke-Pester ./tests/HokusaiAssets.Tests.ps1
```

Palette change = edit `hokusai-theme.css`, run the script, commit. No colour is hardcoded outside the token file — the test suite enforces it.
