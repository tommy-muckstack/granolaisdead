# GranolaIsDead

Free, open-source AI meeting notes for the Mac. Part of the [IsDead series](https://yourappisdead.com). Website served at `https://yourappisdead.com/granolaisdead`.

Free. No account, no subscription, no meeting bot.

## Status
GranolaIsDead is a **native Mac app** (in `mac/`). This repo's website is only its marketing page: there is no web app and no sign-in.

- **Download:** <https://yourappisdead.com/granolaisdead/download> redirects to the latest signed + notarized DMG on GitHub Releases (`releases/latest/download/GranolaIsDead.dmg`).
- **Requirements:** macOS 14.2+, Apple silicon or Intel.

## What the Mac app does
- Records your microphone and the Mac's system audio, so it works with any meeting app and never joins the call as a bot.
- Live, on-device transcription (Parakeet) with you and the other side labeled separately.
- Enhanced notes: your own notes plus the transcript, shaped by templates. Generated on-device with Apple Foundation Models on macOS 26, or with your own Claude or OpenAI API key.
- Chat with a meeting.
- Calendar "coming up" list and meeting detection.
- Automatic updates via Sparkle.

Not included: accounts, cloud sync, team sharing, Windows or iOS apps.

## Mac app
Build, run and release instructions live in [`mac/README.md`](mac/README.md).

## Website
Next.js (basePath `/granolaisdead`). Routes:
- `/`: look-alike marketing page; every download CTA goes to `/download`.
- `/pricing`: what paid AI notetakers charge vs. GranolaIsDead ($0).
- `/download`: 307 to the latest GitHub release DMG.
- Old web-app URLs (`/app/*`, `/login`, `/api/session/*`) permanently redirect to `/`.

No environment variables are needed.

```
npm install
npm run dev        # http://localhost:3000/granolaisdead
npm test           # unit tests
npm run typecheck
npm run build
```
Theme and font: `vendor/isdead-design` (OFL fonts, see `fonts/*/OFL-*.txt`). Not affiliated with Granola; all trademarks belong to their owners. Always get consent before recording a conversation. Apache-2.0.
