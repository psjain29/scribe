# Fly.io Deployment Runbook

## 1) Prerequisites
- `flyctl` installed and authenticated
- A Postgres database URL available (Fly Postgres or external)
- OAuth apps updated with deployed callback URLs

## 2) Create the Fly app
```bash
fly launch --no-deploy --name <your-app-name> --region iad
```

If needed, set internal port to `4000` in `fly.toml` service config.

## 3) Set secrets
```bash
fly secrets set \
  SECRET_KEY_BASE="<secret>" \
  PHX_HOST="<your-app-name>.fly.dev" \
  DATABASE_URL="<postgres-url>" \
  POOL_SIZE="10" \
  GOOGLE_CLIENT_ID="<...>" \
  GOOGLE_CLIENT_SECRET="<...>" \
  HUBSPOT_CLIENT_ID="<...>" \
  HUBSPOT_CLIENT_SECRET="<...>" \
  SALESFORCE_CLIENT_ID="<...>" \
  SALESFORCE_CLIENT_SECRET="<...>" \
  SALESFORCE_REDIRECT_URI="https://<your-app-name>.fly.dev/auth/salesforce/callback" \
  SALESFORCE_SITE="https://login.salesforce.com" \
  GEMINI_API_KEY="<...>" \
  RECALL_API_KEY="<...>" \
  RECALL_REGION="<...>"
```

Optional: add LinkedIn/Facebook secrets only if those flows are needed.

## 4) Deploy
```bash
fly deploy
```

## 5) Run migrations
```bash
fly ssh console -C "/app/bin/social_scribe eval 'SocialScribe.Release.migrate'"
```

## 6) OAuth callback updates
Update provider consoles:
- Google: `https://<your-app-name>.fly.dev/auth/google/callback`
- HubSpot: `https://<your-app-name>.fly.dev/auth/hubspot/callback`
- Salesforce: `https://<your-app-name>.fly.dev/auth/salesforce/callback`

## 7) Post-deploy smoke checks
1. Open `https://<your-app-name>.fly.dev` and login with Google.
2. Connect Salesforce and HubSpot in Settings.
3. Open one meeting and run Salesforce modal update flow.
4. Run HubSpot modal update flow to confirm regression safety.
5. Run `mix test` locally and keep output for evidence.

## 8) Quick rollback basics
```bash
fly releases
fly deploy --image <previous-image-ref>
```
