# Test Runbook

## One-time setup
```bash
mix setup
```

## Run full test suite
```bash
mix test
```

## Run focused suites
```bash
mix test test/social_scribe_web/live/hubspot_modal_test.exs
mix test test/social_scribe_web/live/hubspot_modal_mox_test.exs
mix test test/social_scribe/hubspot_api_test.exs
mix test test/social_scribe/hubspot_suggestions_test.exs
```

## Optional strict compile check
```bash
mix compile --warnings-as-errors
```
