# Architecture Overview

## Goal
This codebase keeps CRM integration easy to extend without changing existing HubSpot behavior.
The architecture separates OAuth, CRM data access, AI suggestion generation, and LiveView UI orchestration.

## End-to-End Flow
1. User opens a meeting page in `SocialScribeWeb.MeetingLive.Show`.
2. User searches/selects a CRM contact through modal UI.
3. LiveView calls `SocialScribe.CRM` to search/fetch/update contacts.
4. LiveView calls `SocialScribe.CRMSuggestions` to generate and merge AI suggestions.
5. `CRMSuggestions` resolves provider strategy at runtime and builds a safe, allowlisted update payload.
6. LiveView applies selected changes and shows success/error feedback.

## Architecture Boundaries
`OAuth and session boundary`
- Routes: `/auth/:provider`, `/auth/:provider/callback`.
- Controller: `SocialScribeWeb.AuthController`.
- Credential storage: `user_credentials`, scoped by `user_id + provider + external_account_id`.

`CRM data-plane boundary`
- Facade: `SocialScribe.CRM`.
- Contract: `SocialScribe.CRM.ProviderBehaviour`.
- Providers: `SocialScribe.CRM.Providers.HubspotProvider`, `SocialScribe.CRM.Providers.SalesforceProvider`.
- Provider API details (tokens, retries, endpoint specifics) stay out of LiveView.

`AI suggestion-plane boundary`
- Public AI interface: `SocialScribe.AIContentGeneratorApi`.
- Generic CRM suggestion API: `generate_crm_suggestions(provider, meeting)`.
- Orchestrator: `SocialScribe.CRMSuggestions`.
- Runtime strategy registry: `SocialScribe.CRMSuggestions.Registry` via config `:crm_suggestion_strategies`.
- Strategy modules store provider metadata only: labels, allowlists, key maps, prompt guidance.

`UI orchestration boundary`
- Coordinator: `SocialScribeWeb.MeetingLive.Show`.
- Components: HubSpot and Salesforce modal components.
- UI holds interaction state only; business logic lives in CRM/CRMSuggestions.

## Error Handling Policy
- User-safe messages are shown in modal inline errors and flashes.
- Unsupported-provider flows return one safe message from `CRMSuggestions.unsupported_provider_message/0`.
- Malformed CRM responses and CRM validation failures are mapped to actionable feedback.
- Internal details are logged for debugging, not exposed directly to end users.

## How To Add Another CRM
1. Add provider API client and provider adapter implementing `ProviderBehaviour`.
2. Add CRM suggestion strategy module (allowlist, labels, key maps, prompt guidance).
3. Register strategy in `:crm_suggestion_strategies` config.
4. Add OAuth settings/connect callback wiring.
5. Add provider-specific modal wiring if needed, while keeping `CRM` and `CRMSuggestions` contracts unchanged.

## Why Commit Range `89ade43..3b6e6b2` (dev_salesforce_integration) Improved Extensibility
The branch dev_salesforce_integration changes moved from provider-specific wiring to a stable extension pattern.

`Make the change easy first`
- `f353865`: introduced a thin CRM dispatcher and provider contract before deeper Salesforce work.

`Add Salesforce as a vertical slice without breaking HubSpot`
- `16afa87`: Salesforce credential persistence + OAuth connect flow.
- `52f5d15`: Salesforce CRM adapter and resilient API tests.
- `f7bffa4`: Salesforce meeting modal shell and workflow integration.

`Harden reliability and edge-case handling`
- `4cf7096`, `350af8b`: OAuth failure handling and user-friendly classification.
- `26f943e`: malformed Salesforce search response handling.
- `cee30d1`: clearer Salesforce validation feedback.
- `57cefa5`: user-safe 429 rate-limit handling for AI suggestions.

`Unify suggestion architecture for future CRMs`
- `c534e61`: strategy-registry based CRM suggestion unification.
- `63741fe`: regression coverage for HubSpot and Salesforce suggestion paths.

`Improve operability and handoff quality`
- `3365274`, `7fe85ff`, `071d7c9`: docs, architecture clarity, and deploy/smoke runbooks.
- `3b6e6b2`: reverted to a stable supported Gemini model for current API path.

Result: Apart from clear Salesforce success and edge case handling that provides users with a seamless CX, graciously handling edge cases, code wise adding another CRM now just requires a new provider adapter, strategy module and simply its config addition, with no churn in existing HubSpot/Salesforce paths, making the design easily extensible to new CRMs.
