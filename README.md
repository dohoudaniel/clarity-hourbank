# HourBank 🕒 — On-Chain Time-Banking & Skill Exchange

**Tagline:** Exchange hours, not just tokens — HourBank is a modular Clarity project that enables communities to trade time-credits for services. Users register, list skills, book hourly sessions, lock time-credits in escrow, and settle on completion — with reputation, simple dispute resolution, and testable, Clarinet-ready smart contracts.

---

## Table of Contents

* [What is HourBank?](#what-is-hourbank)
* [Why build on Stacks / Clarity?](#why-build-on-stacks--clarity)
* [Project goals](#project-goals)
* [Architecture & Contracts](#architecture--contracts)
* [Repository layout](#repository-layout)
* [Getting started (local development)](#getting-started-local-development)
* [Common flows & example calls](#common-flows--example-calls)
* [Testing strategy & running tests](#testing-strategy--running-tests)
* [Debugging tips & common pitfalls](#debugging-tips--common-pitfalls)
* [Security considerations](#security-considerations)
* [Design tradeoffs & choices](#design-tradeoffs--choices)
* [Contributing](#contributing)
* [Release & Pull Request Guidance](#release--pull-request-guidance)
* [Roadmap & future work](#roadmap--future-work)
* [License](#license)

---

## What is HourBank?

HourBank is a decentralized, on-chain time-banking and skill exchange platform implemented in **Clarity**. Instead of paying only with traditional currency, members exchange **time-credits** (1 credit ≈ 1 hour). The system supports:

* user registration and profiles,
* skill listings by providers,
* secure booking & deposits (escrow),
* a minimal time-credit fungible token,
* reputation tracking,
* basic dispute resolution.

The aim is to enable trustful, local or global peer exchanges (tutoring, mentorship, volunteering, micro-services), anchored on deterministic Clarity contracts and covered by Clarinet tests.

---

## Why build on Stacks / Clarity?

Clarity is a decidable, predictable smart contract language that prioritizes safety and correctness. For community systems like HourBank, determinism and the ability to statically analyze behavior matter — they reduce surprises when trust and micro-rewards are at stake.

---

## Project goals

* **Safety first:** contracts that are simple, auditable, and testable.
* **Modularity:** single-responsibility contracts to keep logic small and composable.
* **Test coverage:** unit + integration tests that run in Clarinet.
* **Developer ergonomics:** clear README, example flows, and PR guidance.

---

## Architecture & Contracts

HourBank splits responsibility across **7 modular contracts** (single-responsibility principle):

1. **`user-registry.clar`** — register/unregister users, retrieve user metadata (store only hashes for privacy).
2. **`skill-registry.clar`** — providers add/update/remove skill entries (metadata stored off-chain; hash on-chain).
3. **`time-credit-token.clar`** — minimal fungible token representing hours; mint/burn (admin or controlled gateway), `balance-of`, `transfer`.
4. **`escrow.clar`** — lock time-credits for bookings, release to provider on approval or refund on cancel/failed flow.
5. **`booking-manager.clar`** — create booking requests, accept bookings, mark delivery, request/approve completion; interacts with `escrow` and `time-credit-token` via traits.
6. **`reputation.clar`** — track reputation points per user; increment on successful sessions, decrement on slashes/no-shows.
7. **`dispute-resolver.clar`** — simple dispute lifecycle: open dispute, voting by designated arbitrators (or owner fallback), finalize and instruct escrow.

Each contract exposes a compact public API (define-public functions) and `;;` doc comments for every public-facing symbol.

---

## Repository layout

```
hourbank/
├─ contracts/
│  ├─ user-registry.clar
│  ├─ skill-registry.clar
│  ├─ booking-manager.clar
│  ├─ escrow.clar
│  ├─ time-credit-token.clar
│  ├─ reputation.clar
│  └─ dispute-resolver.clar
├─ tests/
│  ├─ user-registry.test.ts
│  ├─ skill-registry.test.ts
│  ├─ booking-manager.test.ts
│  ├─ escrow.test.ts
│  ├─ time-credit-token.test.ts
│  ├─ reputation.test.ts
│  ├─ dispute-resolver.test.ts
│  └─ integration.test.ts
├─ README.md
└─ .gitignore
```

> The Clarity core logic is designed to be \~300 lines across the `contracts/` directory (excluding comments and tests). This helps maintain small, auditable code units.

---

## Getting started (local development)

### Prerequisites

* Node.js (LTS recommended)
* Clarinet (see Clarinet docs — install via `npm i -g @hirosystems/clarinet` or follow official instructions)
* Git

### Clone & install

```bash
git clone https://github.com/<your-username>/hourbank.git
cd hourbank
npm install      # if your tests/tooling use npm; otherwise not strictly required
```

### Compile contracts

```bash
clarinet check
```

Expected: `clarinet check` should complete with **no errors**.

---

## Common flows & example calls

Below are example `clarinet console` snippets that represent common flows. Replace `tx-sender`, `tx-sender2`, `tx-admin` with the principals configured in your Clarinet tests.

### 1. Register users

```lisp
(contract-call? .user-registry register "QmHashUserA" tx-sender)
(contract-call? .user-registry register "QmHashProvider" tx-sender2)
```

### 2. Provider adds a skill

```lisp
(contract-call? .skill-registry add-skill tx-sender2 "QmSkillHash" u1) ;; 1 hour sessions
```

### 3. Admin mints time credits to requester

```lisp
(contract-call? .time-credit-token mint tx-admin tx-sender u5) ;; give 5 credits
```

### 4. Requester creates a booking (locks 1 credit)

```lisp
(contract-call? .booking-manager create-booking tx-sender <skill-id> u1 <scheduled-ts>)
```

### 5. Provider accepts booking

```lisp
(contract-call? .booking-manager accept-booking tx-sender2 <booking-id>)
```

### 6. After session: provider requests completion; requester approves

```lisp
(contract-call? .booking-manager request-completion tx-sender2 <booking-id>)
(contract-call? .booking-manager approve-completion tx-sender <booking-id>)
```

Result: `escrow` releases 1 credit to provider; `reputation` increments for provider.

### 7. Dispute flow (if needed)

```lisp
(contract-call? .dispute-resolver raise-dispute tx-sender <booking-id> "No show")
;; Arbitrators cast votes via dispute-resolver; finalization instructs escrow to refund or pay.
```

---

## Testing strategy & running tests

Tests are written in Clarinet TypeScript format under `tests/`. They include:

* Unit tests per contract — happy path + at least one edge case.
* Integration test that runs the full lifecycle (register → add skill → mint → book → accept → deliver → approve) and a dispute scenario.

Run the whole suite:

```bash
clarinet test
```

If tests fail, run a single test with the `--grep` flag or run Clarinet in verbose mode if available.

---

## Debugging tips & common pitfalls

When `clarinet check` or `clarinet test` fails, follow these steps:

1. **Read the error message carefully**
   Clarity/Clarinet messages point to the offending contract and line. Often it's a type mismatch, undefined symbol, or missing `define-public`.

2. **Check function signatures**
   Ensure the argument types and return `ok/err` patterns match expected use in calls and tests.

3. **Auth checks (`tx-sender`)**
   Many errors come from calling a function that expects the contract owner or a specific principal. Validate the `tx-sender` used in tests.

4. **Trait and contract imports**
   If an imported trait or contract name is misspelled or the contract path is wrong, compilation fails. Keep contract names consistent.

5. **Numeric types**
   Use unsigned integer (`uX`) consistently. Avoid negative arithmetic and check for overflow — Clarity errors on invalid ops.

6. **Test time & timestamps**
   If your booking code relies on timestamps, ensure tests simulate correct `block` contexts or use relative windows in tests.

7. **Use `clarinet console` for interactive debug**
   Run small interactions, inspect contract read-only getters, and verify storage values before/after transactions.

8. **Verbose tests / logs**
   Add event logs or small read-only getters to make state visible for assertions in tests.

---

## Security considerations

* **On-chain privacy:** Only store hashes & minimal metadata. Do not store plain, sensitive user data on-chain.
* **Reputation slashing:** Design slashing amounts and thresholds conservatively to avoid griefing.
* **Admin privileges:** Keep admin/minting privilege minimal and auditable. Consider multisig or DAO upgrades for production.
* **Replay & double-booking:** Booking-manager should protect against double-acceptance and overlapping slots.
* **Escrow finalization:** Ensure finalization paths are unambiguous (approve, refund, or dispute resolution). Avoid "stuck funds" edge cases.

---

## Design tradeoffs & choices

* **Time-credits vs native tokens:** Time-credits simplify math and UX; they can be represented as an internal fungible token for transfers & escrow.
* **Simple dispute resolver:** To keep contracts small and safe, dispute resolution is minimal (arbitrator voting / owner fallback). Production systems could add staking, DAO governance, or oracle-backed proofs.
* **Off-chain metadata:** Descriptions and proof-of-delivery should live off-chain (e.g., IPFS) with the contract storing only hashes.

---

## Contributing

We welcome contributions. Suggested workflow:

1. Fork the repo.
2. Create a feature branch: `feature/<short-description>`.
3. Write small, focused commits. Use commit prefixes:

   * `feat:` new functionality
   * `fix:` bug fixes
   * `test:` tests
   * `docs:` documentation
4. Run `clarinet check` and `clarinet test` before opening a PR.
5. Open a PR against `main` with a descriptive title and the following sections in the description:

   * Summary
   * Motivation
   * Files changed
   * How to test
   * Risk / Security considerations

---

## Release & Pull Request Guidance

For meaningful PRs:

* Group logically related changes into atomic commits (e.g., contracts + tests in same commit).
* PR title example: `feat(hourbank): v0.1 — core modules, token, escrow & dispute resolver`.
* PR body should include:

  * Short summary
  * Problem statement
  * What changed (list of contracts & tests)
  * How to run tests and manual verification steps
  * Security considerations & known limitations

---

## Roadmap & future work

* UI/UX: React DApp with Hiro Wallet integration and calendar view.
* Arbitration improvements: arbitrator staking, weighted votes.
* Cross-community credit bridges: mint/burn gateways between HourBank instances.
* Analytics: leaderboards and privacy-preserving metrics.
* Gas & audit pass for production readiness.

---

## License

This project is released under the **MIT License**. See `LICENSE` in the repo for details.