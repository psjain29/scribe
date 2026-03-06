# Local Setup

## Prerequisites
- Elixir/Erlang
- PostgreSQL
- Node.js

## Install and run
```bash
mix setup
mix phx.server
```

## Runtime Environment Variables
The app reads these at runtime from `config/runtime.exs`.

### Core auth + integrations
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_REDIRECT_URI` (dev: `http://localhost:4000/auth/google/callback`)
- `LINKEDIN_CLIENT_ID`
- `LINKEDIN_CLIENT_SECRET`
- `LINKEDIN_REDIRECT_URI` (dev: `http://localhost:4000/auth/linkedin/callback`)
- `FACEBOOK_CLIENT_ID`
- `FACEBOOK_CLIENT_SECRET`
- `FACEBOOK_REDIRECT_URI` (dev: `http://localhost:4000/auth/facebook/callback`)
- `HUBSPOT_CLIENT_ID`
- `HUBSPOT_CLIENT_SECRET`
- `RECALL_API_KEY`
- `RECALL_REGION`
- `GEMINI_API_KEY`

### Notes
- This repo uses `FACEBOOK_CLIENT_ID` / `FACEBOOK_CLIENT_SECRET` (not `FACEBOOK_APP_ID` / `FACEBOOK_APP_SECRET`).
- `HUBSPOT_REDIRECT_URI` is not read from runtime config; callback path is `/auth/hubspot/callback`.

## OAuth callback paths
- Google: `/auth/google/callback`
- LinkedIn: `/auth/linkedin/callback`
- Facebook: `/auth/facebook/callback`
- HubSpot: `/auth/hubspot/callback`
