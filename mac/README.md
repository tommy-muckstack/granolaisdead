# GranolaIsDead for Mac

A native SwiftUI meeting notepad that looks and works like Granola. Free, open source, no account.

- **No bot.** Records your microphone ("Me") and your computer's audio ("Them", through a CoreAudio process tap). Nothing joins the call.
- **On-device transcription.** Parakeet TDT 0.6B through [FluidAudio](https://github.com/FluidInference/FluidAudio), on the Neural Engine. The live transcript appears while people talk. The ~600 MB model downloads once.
- **Enhanced notes.** When a meeting ends, your rough notes and the transcript become structured notes. Your own lines stay in full ink; generated lines are gray. Action items get checkboxes. There are ten templates (1 to 1, Hiring, Weekly Team Meeting, Customer: Discovery, VC: Pitch…).
  - Engine order: your own Claude/OpenAI key (optional, Settings → AI), then Apple's on-device model (macOS 26 with Apple Intelligence), then a basic extractive fallback that runs anywhere.
- **Chat.** Ask about one meeting, or across all of them.
- **Calendar.** "Coming up" reads macOS Calendar through EventKit (Google, Outlook and iCloud accounts already added to the Mac). A prompt appears a minute before a meeting, or when Zoom, Meet, Teams, FaceTime, Slack or Webex starts using the mic.
- **Updates.** Sparkle 2, EdDSA-signed appcast, installed automatically between meetings.

Notes are JSON files in `~/Library/Application Support/GranolaIsDead/notes`. Audio is kept 14 days, then deleted.

## Develop

```
cd mac
./scripts/run-dev.sh          # build, assemble a signed .app, launch
swift test                    # chunker, parser, echo filter, fallback enhancer
.build/debug/GranolaIsDead --transcribe meeting.wav   # 16 kHz mono WAV through the live pipeline
```

To open a specific screen at launch for screenshots, set `GID_ROUTE`: `note:<uuid>[:transcript|:chat|:mynotes]`, `chat`, `search` or `settings:<Tab>`.

Layout:

| Folder | What's in it |
|---|---|
| `src/Audio` | Mic engine, system-audio tap, WAV writer, Parakeet facade |
| `src/Meetings` | Recorder, speech chunker, echo filter, meeting detector, calendar, floating indicator |
| `src/AI` | Notes engine, prompts, fallback enhancer, Claude/OpenAI providers, Keychain |
| `src/Notes` | Model, JSON store, templates |
| `src/UI` | Every screen |

The audio engines come from My Man (Apache-2.0, same authors).

## Release

```
RELEASE_VERSION=1.0.0 RELEASE_BUILD=1 ./scripts/build-direct.sh
```

The script builds a universal binary, signs it with Developer ID and the hardened runtime, notarizes and staples the app, then builds, notarizes and staples the DMG. It signs the update with Sparkle (Keychain account `granolaisdead`) and uploads to Vercel Blob:
- `granolaisdead.dmg`
- `granolaisdead-<version>.dmg`
- `granolaisdead-appcast.xml`

Finally it publishes a GitHub release with `GranolaIsDead.dmg`. The website's `/download` redirects to `releases/latest/download/GranolaIsDead.dmg`.

Icon: `swift scripts/make-icon.swift && ./scripts/make-icns.sh`.

## Fonts

Inter and IBM Plex Serif, both under the SIL Open Font License (see `src/Resources/Fonts/OFL-*.txt`). They are the open fonts Granola itself falls back to; its own fonts are proprietary and not shipped.

Not affiliated with Granola. All trademarks belong to their owners.
