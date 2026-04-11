# ISS-003: Billing and subscription integration is missing

| Field | Value |
|---|---|
| Status | Open |
| Severity | Major |
| Phase | Phase 4 |
| Created | 2026-04-11 |
| Owner | Unassigned |

## Summary

Subscription data fields exist in the backend model, but there is no implemented billing API, paywall, or mobile purchase integration.

## Evidence

- Subscription persistence includes Stripe identifiers in `backend/app/models/__init__.py:276-289`.
- No billing or payment routes are registered in `backend/app/main.py:51-57`.
- Repository search shows no `stripe`, `in_app_purchase`, or paywall implementation in mobile app code or dependencies outside model fields.

## Impact

- Paid plan conversion cannot happen.
- Subscription state cannot drive entitlements in the product.
- Phase 4 launch remains commercially incomplete.

## Required Work

- [ ] Define billing API surface and subscription lifecycle flows
- [ ] Choose Stripe + platform in-app purchase split and document it
- [ ] Add paywall and plan UI to mobile
- [ ] Add entitlement checks for premium AI and long-form processing features
- [ ] Add webhook or server reconciliation for subscription state

## Validation

- [ ] User can start, restore, and cancel a subscription
- [ ] Entitlements update correctly on both backend and mobile
- [ ] Free-tier limits and paid-tier unlocks are enforced consistently
