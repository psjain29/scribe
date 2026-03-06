# Salesforce Challenge Plan

This checklist tracks delivery for the Salesforce CRM integration challenge.

## Current Status
- [x] Confirm correct challenge baseline repo (`atomkirk/scribe` fork)
- [x] Local app bootstrapped and Google login validated
- [ ] Docs bootstrap and setup cleanup
- [ ] Micro CRM backend seam
- [ ] Salesforce credential persistence + OAuth
- [ ] Salesforce API adapter (search/get/update + token refresh)
- [ ] Salesforce meeting modal flow
- [ ] AI suggestion contract + merge safety
- [ ] Salesforce tests + HubSpot regression tests
- [ ] Deploy smoke checklist and final documentation

## Locked Design Constraints
- Keep scope tight: backend seam only, no generic CRM UI rewrite in this iteration.
- Reuse existing HubSpot UX patterns for Salesforce modal interactions.
- Enforce OAuth state validation and strict field allowlist for updates.
- Use small, reviewable commits and preserve existing HubSpot behavior.

## Acceptance Summary
- Salesforce can be connected from Settings via OAuth.
- Salesforce contact search/select works from meeting details modal.
- AI suggestions show existing vs suggested values by field.
- Selected allowlisted fields update Salesforce successfully.
- Existing HubSpot flow remains functional.
