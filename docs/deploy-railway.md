# Railway Deployment Runbook

This is the fastest reliable path to deploy this Phoenix app on Railway.

## 1) Prerequisites
- Railway account (https://railway.app)
- GitHub repo connected to Railway
- OAuth apps ready for Google, HubSpot, Salesforce
- Postgres will be created inside Railway

## 2) Create project and services
1. In Railway, click `New Project`.
2. Choose `Deploy from GitHub repo` and select your fork/repo.
3. Add a `PostgreSQL` service in the same project.
4. Open your app service, then open `Settings -> Networking` and click `Generate Domain`.
5. Copy the generated domain, for example: `your-app.up.railway.app`.

## 3) Configure environment variables (app service)
Open app service `Variables` and set:

- `SECRET_KEY_BASE` (generate locally with `mix phx.gen.secret`)
- `PHX_HOST` = `<your-generated-domain-without-https>`
- `DATABASE_URL` = reference Railway Postgres `DATABASE_URL`
- `POOL_SIZE` = `10`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_REDIRECT_URI` = `http://localhost:4000/auth/google/callback` (local only; prod Google callback is derived from `PHX_HOST`)
- `HUBSPOT_CLIENT_ID`
- `HUBSPOT_CLIENT_SECRET`
- `SALESFORCE_CLIENT_ID`
- `SALESFORCE_CLIENT_SECRET`
- `SALESFORCE_REDIRECT_URI` = `https://<your-domain>/auth/salesforce/callback`
- `SALESFORCE_SITE` = `https://login.salesforce.com` (or `https://test.salesforce.com` for sandbox)
- `GEMINI_API_KEY`
- `RECALL_API_KEY`
- `RECALL_REGION`

Optional only if you use these flows:
- `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET`, `LINKEDIN_REDIRECT_URI`
- `FACEBOOK_CLIENT_ID`, `FACEBOOK_CLIENT_SECRET`, `FACEBOOK_REDIRECT_URI`

Notes:
- `PORT` is usually injected by Railway automatically.
- Keep `PHX_HOST` as host only (no `https://`).

## 4) Deploy
1. Trigger a deploy from Railway UI (`Deployments -> Redeploy`) or push to the configured branch.
2. Wait for deployment to become healthy.

This repo uses `Dockerfile` and starts with `/app/bin/server`.

## 5) Run database migrations
After each deploy with schema changes, run migration once:

1. Open the app service shell in Railway UI.
2. Run:
```bash
/app/bin/migrate
```

Alternative (Railway CLI):
```bash
railway run /app/bin/migrate
```

## 6) Update OAuth callback URLs in provider consoles
Use your Railway domain.

- Google authorized redirect URI:
  - `https://<your-domain>/auth/google/callback`
- HubSpot redirect URL:
  - `https://<your-domain>/auth/hubspot/callback`
- Salesforce callback URL:
  - `https://<your-domain>/auth/salesforce/callback`

## 7) Production smoke test (must pass)
1. Open `https://<your-domain>`.
2. Login with Google.
3. Open `/dashboard/settings` and connect Salesforce.
4. Connect HubSpot.
5. Open a meeting with transcript.
6. Open Salesforce modal (`/dashboard/meetings/:id/salesforce`).
7. Search/select contact, apply one selected change, verify success flash.
8. Verify the field changed in Salesforce.
9. Open HubSpot modal (`/dashboard/meetings/:id/hubspot`) and run one update.
10. Verify HubSpot still works (regression check).

## 8) Fast troubleshooting
- App boot fails with DB error: `DATABASE_URL` missing/wrong reference.
- OAuth redirect mismatch: callback URL in provider console does not match exact Railway URL.
- Salesforce login against sandbox: set `SALESFORCE_SITE=https://test.salesforce.com`.
- Gemini 429/quota: use active quota project/key and valid model limits in Google AI Studio.
- App starts but inaccessible: ensure Railway domain generated and service healthy.
