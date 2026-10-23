# Monochrome

**Monochrome** is a lightweight, native mobile web browser for macOS built with AppKit and WebKit (`WKWebView`). It renders websites using an iPhone Safari user agent inside compact, mobile-sized macOS windows—ideal for distraction-free browsing, side-by-side reference windows, and testing responsive mobile layouts.

---

## Features

- **Mobile Viewport & User Agent**: Sends an iOS Safari (`iPhone`) user agent so websites serve their fast, clean mobile layouts on macOS.
- **iPhone Viewport Presets**: Quickly switch between 6 standard iPhone logical viewport dimensions (`⌘1`–`⌘6`), defaulting to **SE (`375 × 667`)** with resizable bounds from `320 × 480` up to `440 × 956`.
- **Compact Expanded Toolbar**: Native macOS toolbar displaying **Back**, **Reload / Stop**, **Home**, and the **Address** field by default, with optional customizable items (**Forward**, **New**, **Loading** indicator, spaces).
- **Toggleable Status Bar**: Optional bottom status bar (hidden by default, toggleable from **View → Show Status Bar** or `⌘/`) showing the downloading page size and total site size (`KB` / `MB`) on the left and live window dimensions (`width × height px`) on the right.
- **LZFSE-Compressed Browsing History**: Stores up to 1,000 normalized, deduplicated URLs in most-recently-used (MRU) order inside `UserDefaults` using Apple's LZFSE compression—requiring zero external database files.
- **Inline Address Bar Autocomplete**: Suggests and highlights matching URL suffixes from browsing history as you type, handling optional `http(s)://` and `www.` prefixes and prioritizing clean paths before query strings.
- **Smart Address & Search Bar**: Navigates directly to URLs or domains and routes search queries through a configurable search engine (defaulting to DuckDuckGo: `https://duckduckgo.com/?q=`).
- **Multi-Window & Tabbed Browsing**: Built on `NSDocument` to support multiple independent browser windows and native macOS window tabs (`⌘N`, `⌘T`).
- **Trackpad Gestures & Zoom**: Supports two-finger swipe back/forward navigation gestures and pinch-to-zoom magnification.

---

## Window Size Presets

Accessible from the **View** menu or via keyboard shortcuts:

| Preset | Width | Height | Shortcut |
| :--- | :--- | :--- | :--- |
| **5s** (`320px`) | `320px` | `568px` | `⌘1` |
| **Mini** (`360px`) | `360px` | `780px` | `⌘2` |
| **SE** (`375px`) *(Default)* | `375px` | `667px` | `⌘3` |
| **e** (`390px`) | `390px` | `844px` | `⌘4` |
| **Pro** (`402px`) | `402px` | `874px` | `⌘5` |
| **Max** (`440px`) | `440px` | `956px` | `⌘6` |

---

## Keyboard Shortcuts

| Action | Shortcut |
| :--- | :--- |
| New Window / Tab | `⌘N` / `⌘T` |
| Open Location (Focus Address Bar) | `⌘L` |
| Reload Page | `⌘R` |
| Reload From Origin | `⇧⌘R` |
| Stop Loading | `⌘.` |
| Back | `⌘[` |
| Forward | `⌘]` |
| Home | `⇧⌘H` |
| Find on Page | `⌘F` |
| Preferences | `⌘,` |
| Customize Toolbar | `⌥⌘T` |
| Show / Hide Status Bar | `⌘/` |
| Resize Window (`5s` – `Max`) | `⌘1` – `⌘6` |

---

## Preferences & Defaults

Open **Monochrome → Preferences…** (`⌘,`) to choose a homepage and search engine preset or configure custom URLs:

- **Brave**: `https://search.brave.com/` | `https://search.brave.com/search?q=`
- **DuckDuckGo** *(Default)*: `https://duckduckgo.com/` | `https://duckduckgo.com/?q=`
- **Google**: `https://www.google.com/` | `https://www.google.com/search?q=`
- **Custom**: Custom **Homepage** and **Search Engine** URL fields (shown when **Custom** is selected)

Settings and LZFSE-compressed browsing history (`BrowsingHistory`) are stored in `UserDefaults` under `com.lucianmarin.Monochrome`.

---

## Project Structure

- `Monochrome/AppDelegate.swift` — Application lifecycle and default `Homepage` / `SearchEngine` registration.
- `Monochrome/Document.swift` — Browser window controller (`NSDocument`), programmatic `NSToolbarDelegate`, `WKNavigationDelegate` / `WKUIDelegate`, window size presets, `BrowsingHistory` LZFSE store, and `NSTextFieldDelegate` inline autocomplete.
- `Monochrome/Preferences.swift` & `Monochrome/Preferences.xib` — Preferences window controller bound to `NSUserDefaultsController`.
- `Monochrome/Base.lproj/Document.xib` — Browser window nib and `WKWebView` configuration.
- `Monochrome/Base.lproj/MainMenu.xib` — Application menu bar and keyboard shortcuts.

---

## Building & Running

1. Open `Monochrome.xcodeproj` in Xcode (Swift 5, macOS SDK).
2. Select the **Monochrome** scheme and press **Run** (`⌘R`), or build from the command line:

```bash
xcodebuild -project Monochrome.xcodeproj -scheme Monochrome -configuration Release build
```

---

## License

Copyright © Lucian Marin. All rights reserved.
