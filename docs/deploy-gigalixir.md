# Gigalixir Deployment Runbook

## 1) Prerequisites
- Gigalixir CLI installed and authenticated
- Heroku CLI installed (used by Gigalixir workflow)
- A Postgres addon/database provisioned on Gigalixir
- OAuth apps updated with deployed callback URLs

## 2) Create app and database
```bash
gigalixir create -n <your-app-name>
gigalixir pg:create --free
```

## 3) Set config vars
```bash
gigalixir config:set \
  SECRET_KEY_BASE="<secret>" \
  PHX_HOST="<your-app-name>.gigalixirapp.com" \
  POOL_SIZE="10" \
  GOOGLE_CLIENT_ID="<...>" \
  GOOGLE_CLIENT_SECRET="<...>" \
  HUBSPOT_CLIENT_ID="<...>" \
  HUBSPOT_CLIENT_SECRET="<...>" \
  SALESFORCE_CLIENT_ID="<...>" \
  SALESFORCE_CLIENT_SECRET="<...>" \
  SALESFORCE_REDIRECT_URI="https://<your-app-name>.gigalixirapp.com/auth/salesforce/callback" \
  SALESFORCE_SITE="https://login.salesforce.com" \
  GEMINI_API_KEY="<...>" \
  RECALL_API_KEY="<...>" \
  RECALL_REGION="<...>"
```

`DATABASE_URL` is typically injected by the Gigalixir Postgres addon.

## 4) Deploy
```bash
git push gigalixir <branch>:main
```

## 5) Run migrations
```bash
gigalixir ps:migrate
```

## 6) OAuth callback updates
Update provider consoles:
- Google: `https://<your-app-name>.gigalixirapp.com/auth/google/callback`
- HubSpot: `https://<your-app-name>.gigalixirapp.com/auth/hubspot/callback`
- Salesforce: `https://<your-app-name>.gigalixirapp.com/auth/salesforce/callback`

## 7) Post-deploy smoke checks
1. Open app URL and login with Google.
2. Connect Salesforce and HubSpot in Settings.
3. Open one meeting with transcript.
4. Execute Salesforce update flow and verify CRM update.
5. Execute HubSpot update flow and verify CRM update.
6. Keep video proof and terminal evidence for submission.

## 8) Common triage
- OAuth redirect mismatch: recheck callback URL and env vars.
- 429 from Gemini: verify active quota/model in AI Studio for the key in `GEMINI_API_KEY`.
- Migration failures: confirm DB addon health and rerun `gigalixir ps:migrate`.
