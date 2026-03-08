# Architecture Overview

## Request and Auth Boundaries
- `SocialScribeWeb.Router` handles OAuth at `/auth/:provider` and `/auth/:provider/callback`.
- Auth callback handling lives in `SocialScribeWeb.AuthController`.
- CRM credentials are persisted per user in `user_credentials` and scoped by provider.
- Meeting pages (`/dashboard/meetings/:id`, `/hubspot`, `/salesforce`) are protected by authenticated LiveView routes.

## CRM Data Plane
- `SocialScribe.CRM` is the CRM dispatcher used by UI orchestration.
- Provider contract: `SocialScribe.CRM.ProviderBehaviour` (`search_contacts/2`, `get_contact/2`, `update_contact/3`).
- Implementations:
  - `SocialScribe.CRM.Providers.HubspotProvider`
  - `SocialScribe.CRM.Providers.SalesforceProvider`
- Provider-specific API and token lifecycle details stay in provider API modules, not in LiveView code.

## AI Suggestion Plane
- Public AI interface: `SocialScribe.AIContentGeneratorApi`.
- CRM suggestion entrypoint: `generate_crm_suggestions(provider, meeting)`.
- `SocialScribe.CRMSuggestions` orchestrates provider-safe suggestion flow:
  - generate from meeting
  - merge with selected contact
  - build allowlisted update payload
- Runtime strategy resolution uses `SocialScribe.CRMSuggestions.Registry` with config map `:crm_suggestion_strategies`.
- Strategy modules hold provider metadata only (field labels, allowlist/update keys, prompt guidance).

## Meeting LiveView Orchestration
- `SocialScribeWeb.MeetingLive.Show` coordinates modal flows for HubSpot and Salesforce.
- Data-plane calls go through `SocialScribe.CRM`.
- Suggestion generation and payload shaping go through `SocialScribe.CRMSuggestions`.
- UI components (`HubspotModalComponent`, `SalesforceModalComponent`) handle interaction state (search, select, apply toggles).

## Error Handling Boundaries
- User-safe errors are surfaced in modal inline errors or flash messages.
- Unsupported provider flows return one safe message from `CRMSuggestions.unsupported_provider_message/0`.
- CRM update validation errors are translated to actionable Salesforce messages where possible.
- Internal diagnostics (unexpected OAuth/API failures, JSON parse issues) are logged without exposing provider internals to end users.
