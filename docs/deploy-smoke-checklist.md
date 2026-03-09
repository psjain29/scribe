# Deploy + Smoke Checklist (Platform Agnostic)

Use this checklist to verify a deployment before submitting the challenge.

## 1) Required Environment Variables

| Category | Variable | Required | Notes |
|---|---|---:|---|
| Phoenix | `SECRET_KEY_BASE` | Yes | Generate with `mix phx.gen.secret` |
| Phoenix | `PHX_HOST` | Yes | Public host, no scheme (example: `app.example.com`) |
| Phoenix | `PORT` | Yes | Usually provided by platform |
| DB | `DATABASE_URL` | Yes | Postgres connection string |
| DB | `POOL_SIZE` | Optional | Defaults to `10` |
| Google OAuth | `GOOGLE_CLIENT_ID` | Yes | |
| Google OAuth | `GOOGLE_CLIENT_SECRET` | Yes | |
| Google OAuth | `GOOGLE_REDIRECT_URI` | Dev only | Prod Google callback is derived from `PHX_HOST` in runtime |
| HubSpot OAuth | `HUBSPOT_CLIENT_ID` | Yes | |
| HubSpot OAuth | `HUBSPOT_CLIENT_SECRET` | Yes | |
| Salesforce OAuth | `SALESFORCE_CLIENT_ID` | Yes | Connected App consumer key |
| Salesforce OAuth | `SALESFORCE_CLIENT_SECRET` | Yes | Connected App consumer secret |
| Salesforce OAuth | `SALESFORCE_REDIRECT_URI` | Yes | Must match OAuth app callback |
| Salesforce OAuth | `SALESFORCE_SITE` | Optional | Default: `https://login.salesforce.com` |
| AI | `GEMINI_API_KEY` | Yes | Must have active model quota |
| Recall | `RECALL_API_KEY` | Required for Recall path | |
| Recall | `RECALL_REGION` | Required for Recall path | |
| Optional social | `LINKEDIN_CLIENT_ID`/`LINKEDIN_CLIENT_SECRET`/`LINKEDIN_REDIRECT_URI` | Optional | Needed only for LinkedIn flow |
| Optional social | `FACEBOOK_CLIENT_ID`/`FACEBOOK_CLIENT_SECRET`/`FACEBOOK_REDIRECT_URI` | Optional | Needed only for Facebook flow |

## 2) OAuth Callback URL Matrix

| Provider | Local callback | Deployed callback |
|---|---|---|
| Google | `http://localhost:4000/auth/google/callback` | `https://<PHX_HOST>/auth/google/callback` |
| HubSpot | `http://localhost:4000/auth/hubspot/callback` | `https://<PHX_HOST>/auth/hubspot/callback` |
| Salesforce | `http://localhost:4000/auth/salesforce/callback` | `https://<PHX_HOST>/auth/salesforce/callback` |

Notes:
- Register both local and deployed callback URLs in each provider console.
- Salesforce sandbox uses `SALESFORCE_SITE=https://test.salesforce.com`.

## 3) Platform-Neutral Release / Migrate / Start

```bash
# Build release artifacts
MIX_ENV=prod mix deps.get
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix compile
MIX_ENV=prod mix release

# Run DB migrations using release task
_build/prod/rel/social_scribe/bin/social_scribe eval "SocialScribe.Release.migrate"

# Start server
PHX_SERVER=true _build/prod/rel/social_scribe/bin/social_scribe start
```

## 4) Manual Smoke Script (Evaluator Flow)

1. Login via Google at `/`.
2. Open `/dashboard/settings`.
3. Connect Salesforce account and verify success flash.
4. Connect HubSpot account and verify success flash.
5. Open `/dashboard/meetings` and select a meeting with transcript.
6. Open Salesforce modal (`/dashboard/meetings/:id/salesforce`).
7. Search and select a Salesforce contact.
8. Verify suggestion rows show existing vs suggested values.
9. Keep one changed row selected and click `Update Salesforce`.
10. Verify success flash and confirm the field change in Salesforce UI.
11. Open HubSpot modal (`/dashboard/meetings/:id/hubspot`).
12. Search/select HubSpot contact and apply one selected change.
13. Verify HubSpot success path and confirm update in HubSpot UI.

## 5) Safety and Error Checks

1. Unsupported provider is shown as a safe message (no crash).
2. Empty/no-op suggestions do not produce update payload.
3. Validation errors (for example duplicate email) show actionable inline/flash message.
4. Contact fetch/search failures keep modal interactive with retry path.

## 6) Evidence Template (Capture for Submission)

### Video proof
- [Done] One end-to-end video for Salesforce flow (connect -> search/select -> suggestions -> update success)
- [Done] One end-to-end video for HubSpot regression flow (search/select -> update success)
- [Done] Video clearly shows deployed app URL in browser address bar

### Terminal proof
- [Done] `mix test` output with `0 failures`
- [Done] Any focused regression suites used

### Final submission checklist
- [Done] Public repo URL ready
- [Done] Deployed app URL ready
- [Done] Both links verified from incognito browser
