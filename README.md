# FlashPaste

Select text in Safari or Preview, move to your Quizlet tab, and it is already pasted into the next term or definition field. A tiny macOS menu-bar app for making flashcards without the copy, switch, click, paste loop.

## How it works

1. With FlashPaste enabled, releasing the mouse (or finishing a shift+arrow selection) in a source app sends Cmd+C to that app and stores the selection as *pending*.
2. When a window whose title contains "Quizlet" becomes focused, FlashPaste pastes the pending text into the focused field and presses Tab to reach the next one.
3. Pastes alternate between **term** and **definition**: one Tab after each paste by default (both counts configurable, in case Quizlet puts a control between fields).

Nothing is generated or rewritten. The tool only moves, and optionally tidies, the text you selected.

## Requirements

- macOS 13 or later.
- Accessibility permission (for the event tap, the window observer and the synthetic key presses).
- Pairs well with a focus-follows-mouse tool such as AutoRaise, so that moving the mouse to Quizlet is the handoff. It does not need one: clicking into the Quizlet window works too.

## Install

**Download:** grab `FlashPaste.zip` from the Releases page, unzip, move `FlashPaste.app` to Applications. The app is not notarized, so the first time use right-click, Open.

**Build from source:**

```sh
./build.sh          # builds and ad-hoc signs build/FlashPaste.app
./make-release.sh   # also zips it to build/FlashPaste.zip
```

Rebuilding re-signs the app, so macOS may ask for Accessibility permission again. If the app stops working after a rebuild, remove FlashPaste from System Settings, Privacy & Security, Accessibility, and add it back.

## Usage and hotkeys

Launch the app. It starts **disabled**; enable it from the menu or with the hotkey. The menu-bar icon is dimmed while disabled.

| Hotkey | Action |
|---|---|
| ctrl+opt+Q | Enable / disable |
| ctrl+opt+X | Skip the pending capture (bad selection) |
| ctrl+opt+R | Reset the next field to *term* |
| ctrl+opt+Z | Undo last paste (when that preference is on) |

Menu items: Enabled, Skip pending capture, Reset to term, Preferences, Open config file, Reload config, Launch at login, Quit. The menu also shows the next field and the pending capture.

## Preferences

All toggles apply immediately and are saved to the config file.

- **Clean PDF text** (default on): joins hard line breaks, repairs words hyphenated across lines, collapses whitespace, trims. Paragraph breaks are kept as a single newline.
- **Strip leading bullets and numbering**: removes "• ", "- ", "1. ", "(2) ", "a) " from the start of each captured line.
- **Capture feedback**: a short sound and a small HUD on capture and paste.
- **Only capture while a Quizlet window exists**: copying in Safari or Preview is left alone unless a Quizlet window is open somewhere.
- **Keep capture history**: a submenu of the last 10 captures; click one to re-queue it.
- **Undo last paste hotkey**: enables ctrl+opt+Z, which shift-tabs back into the field just filled, selects all, deletes, and steps the term/definition state back.

## Config

`~/Library/Application Support/FlashPaste/config.json`, created with defaults on first launch. Edit it (Open config file), then choose Reload config.

| Key | Default | Meaning |
|---|---|---|
| `sourceApps` | `["com.apple.Safari", "com.apple.Preview"]` | Bundle IDs that selections are captured from |
| `quizletApps` | `["com.apple.Safari"]` | Bundle IDs that may own the Quizlet window |
| `quizletTitlePattern` | `"Quizlet"` | Case-insensitive substring of the window title |
| `focusDelay` | `0.15` | Seconds to wait after the Quizlet window gains focus before pasting |
| `tabsAfterTerm` | `1` | Tabs sent after pasting a term |
| `tabsAfterDef` | `1` | Tabs sent after pasting a definition |
| `cleanPDFText`, `stripBullets`, `captureFeedback`, `autoPause`, `captureHistory`, `undoLastPaste` | see above | Preference toggles |

Unknown keys are preserved. Invalid JSON falls back to defaults and logs a warning.


FlashPaste is an unofficial tool and is not affiliated with Quizlet.
