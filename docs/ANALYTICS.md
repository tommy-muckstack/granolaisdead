# Analytics (PostHog)

One PostHog project (US cloud, project **666931**) collects the hub and every IsDead app. The contract is the hub's
`yourappisdead/ANALYTICS.md`; this file is how GranolaIsDead follows it.
The web side is only the marketing site and the Mac installer download. The Mac app in `mac/` has its own Swift analytics (`platform: mac`) and is not covered here.

## Setup
- `NEXT_PUBLIC_POSTHOG_KEY` (the project's publishable token) and `NEXT_PUBLIC_POSTHOG_HOST=https://us.posthog.com` are set on the Vercel project. No key → analytics is a no-op.
- Requests go through this app's own origin: `<basePath>/ingest/*` → `us.i.posthog.com` (rewrites in `next.config.mjs`, with `skipTrailingSlashRedirect: true`).
- `<Analytics />` and `<LinkTracking />` are mounted once in `app/layout.tsx`. `Analytics` sends PostHog's `$pageview` per route change. Autocapture, session replay, heatmaps and web-vitals capture are off.
- Privacy: `scrub` (before_send) keeps only origin + path in URL properties, drops `title`, and masks private path segments (none needed: the site has no private links).
- posthog-js drops automated browsers. In dev, `localStorage.isdead_ph_debug = "1"` turns on verbose logs and lets Playwright capture (used by the kit's `ph-check.mjs`); production keeps the bot filter.

## Super properties (registered on every event)
| property | value | meaning |
| --- | --- | --- |
| `product` | `granolaisdead` | the one property to filter by |
| `surface` | `landing` \| `app` | always `landing`: there is no web app |
| `platform` | `web` | |
| `env` | `production` \| `development` | |

## Identity
There are no web accounts, so nobody is identified on the site.

## Events
| event | properties | where |
| --- | --- | --- |
| `landing_download_clicked` | `target` (`mac`), `placement` | any link to `/download` (home and pricing) |
| `landing_cta_clicked` | `target` (`pricing`, `github`, `releases`, `issues`, `license`, `hub`), `placement` | any other marketing link |

## Rules
- Event names are `app_<object>_<action>` / `landing_<object>_<action>`, snake_case, past tense, never containing the product name. They are defined only in `lib/analytics/taxonomy.ts`; the unit test enforces the prefixes.
- Properties are kinds, counts, ids and booleans only. Never titles, file names, messages, comment text, emails or URLs. Don't use the legacy super-property names (`source`, `app`, `app_id`, `site_id`, `environment`) as event properties.
- `landing_cta_clicked` / `landing_download_clicked` come from one delegated click listener (`LinkTracking` in `lib/analytics/posthog.tsx`) that classifies `<a>` destinations, so new marketing links are tracked without code. `placement` is the page region (`nav`, `footer`, or the enclosing section's id/class).

## Where the calls live
`lib/analytics/` (client, taxonomy, link tracking, scrub). Tests: `tests/unit/analytics.test.ts`.
