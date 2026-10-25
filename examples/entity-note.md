---
tags: [project]
status: active
created: 2026-01-01
updated: 2026-01-15
entities: [Auth System, Alice (teammate)]
---

# My App

Links: [[Auth System]], [[Alice (teammate)]]

## What this is
A SaaS dashboard for tracking widget metrics. React frontend, Node backend, PostgreSQL. Deployed on Railway.

## Current status
- (2026-01-15) Auth rewrite to JWT complete, dual-read migration running. See [[2026-01-15-auth-rewrite]]
- (2026-01-10) Dashboard v2 shipped with real-time charts via WebSocket
- (2026-01-03) Onboarded [[Alice (teammate)]] to the backend codebase

## Key findings / decisions
- JWT with 15-min access tokens, 7-day refresh tokens (decided 2026-01-15)
- WebSocket over SSE for real-time: lower latency, better reconnection handling
- PostgreSQL over SQLite: need concurrent writes from multiple workers

## Open questions
- [ ] Should we add rate limiting per API key or per user?
- [ ] Redis vs in-memory for the rate limiter

## Sessions
- [[2026-01-15-auth-rewrite]]
- [[2026-01-10-dashboard-v2]]
