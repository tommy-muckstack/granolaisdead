# GranolaIsDead

Free, open-source Granola alternative. Part of the [IsDead series](https://yourappisdead.com). Served at `https://yourappisdead.com/granolaisdead`.

**Status: open source, not deployed yet**. Surfaces follow `templates/marketing-site.md` in `@isdead/design`: one marketing page (`/`, price comparison at `#pricing`), `/login`, and the app at `/app`.

## What works
- **Notes workspace:** sidebar of meetings grouped by date, per-account storage, titles, templates (general, 1:1, stand-up, customer discovery, interview), sample meeting.
- **Capture:** jot notes in a plain editor; record with the browser's SpeechRecognition (Chrome) or paste/edit a transcript (speaker labels like `Maya:` supported; timestamps ignored).
- **Enhance (no LLM, runs locally):** extractive summary, key points routed into template sections by keywords, your own lines kept in black with the best-matching transcript sentence attached in gray, decisions, action items with owner and due date, open questions. Re-enhance, tick actions off, copy or download Markdown.
- **Ask:** keyword retrieval over notes + transcript returns the matching lines with speakers (or says it can't find an answer).
- 11 unit tests for parsing, extraction, enhancement and retrieval; Playwright smoke test in `npm run shots`.

## Known gaps
- **Not generative AI:** summaries and notes are extractive (they quote the transcript) so they are less polished than Granola's, and action-item detection is pattern-based.
- No system-audio capture (browser speech recognition uses the microphone, and Chrome sends audio to Google). No calendar integration, sharing links, folders or team workspaces.
- Notes live in localStorage per account (no sync; Firestore is the next step).

## Auth
Shared Firebase project `yourappisdead` (email/password + Google), helpers in `lib/isdead-auth` (vendored from `isdead-design/auth`). The session cookie `isdead_session` has path `/`, so one sign-in covers every IsDead app. Env: `NEXT_PUBLIC_FIREBASE_*`, `FIREBASE_SERVICE_ACCOUNT_JSON`. Without them, `/login` shows "Sign-in not configured". The single demo account ("Use the demo account") is available outside production or with `DEMO_MODE=1`.

## Develop
```
npm install
npm run dev        # http://localhost:3000/granolaisdead
npm test           # unit tests
npm run typecheck
npm run build && npm run shots   # product screenshots + end-to-end smoke test (Playwright)
```
Theme and font: `vendor/isdead-design` (OFL fonts, see `fonts/*/OFL-*.txt`). Not affiliated with Granola; all trademarks belong to their owners. Apache-2.0.
