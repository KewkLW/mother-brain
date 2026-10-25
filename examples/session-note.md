---
wing: sessions
tags: [session, my-app, auth]
created: 2026-01-15
entities: [My App, Auth System, Alice (teammate)]
---

# 2026-01-15 — Auth Rewrite

Links: [[My App]], [[Auth System]]

## What Happened

Rewrote the auth middleware to use JWT instead of session cookies. [[Alice (teammate)]] flagged the cookie approach as a blocker for the mobile app since cookies don't work well with native HTTP clients.

## Key Discoveries
- The old session store was hitting Redis 3x per request (once for session lookup, once for CSRF, once for rate limiting)
- JWT with short-lived access tokens (15 min) + refresh tokens eliminates 2 of those 3 Redis calls
- Found that [[Auth System]] had a bug where expired sessions weren't being cleaned up, causing a slow memory leak in Redis

## Decisions
- JWT with 15-min access tokens, 7-day refresh tokens stored in httpOnly cookies
- Keep Redis for rate limiting only
- Migration: dual-read (accept both session and JWT) for 2 weeks, then cut over

## What's Next
- [ ] Write migration script for existing sessions
- [ ] Update [[My App]] API docs with new auth flow
- [ ] Load test the JWT validation path
