# Hang Out — Product Roadmap (Features A–I)

> Companion to [Plan.md](Plan.md) (the original product brief) and [README.md](README.md).
> This file captures the product strategy + the full implementation roadmap for the next phase of
> features, so context is never lost between work sessions. Update the **Status** column as we go.

---

## The core reframe: from "events directory" to "relationship engine"

Meetup answers *"what event can I attend?"* — find an event, attend, leave, churn. The activity is the
product, and it's disposable. To go **beyond Meetup**, Hang Out treats **the activity as the excuse and
the relationship as the product**: the thing that compounds is the *recurring web of people you keep
hanging out with*.

This single reframe makes the four goals reinforce each other instead of competing:
- **Liquidity** gets you the first hang.
- **Community** turns the first hang into a 5th.
- **Retention** is the byproduct of having a standing group that meets.
- **Growth** happens because hanging out is inherently multiplayer — every activity is a built-in invite.

**North-star metric:** *repeat hangs between the same two people* (did A and B hang out again?). That's
the relationship graph forming. Decision rule for any feature: **does it increase repeat hangs?** If yes,
build it. If it just adds one-off events to a directory, it's Meetup.

**Audience strategy (founder was undecided):** *friends-first, expanding through trusted edges.* Seed
with friends-of-friends in one city (the cold-start path that works), but build the trust layer (H) and
Circles (A) from the start so a stranger is just "a friend-of-a-friend you haven't met yet." Safer and
more viral than Meetup's strangers-first model.

> Alignment note: the original [Plan.md](Plan.md) brief already envisioned friends lists, activity
> ratings, 2h reminders, host moderation (remove suspicious users), TikTok-style scrollable discovery,
> and future AI recommendations. The A–I roadmap below is the structured path to deliver that vision.

---

## Current state (what exists today)

**Built & working:** Google sign-in; Discover feed (6 emoji-category filters, like, join); activity
details (hero, meta, who's-going avatars with real photos, share, open-chat); create activity;
per-activity group chat (auto-created at the 2nd joiner); My Activities; real user profiles in a `users`
collection; live profile stats (joined/hosted).

**Stubbed / missing:** Friends (empty screen; `AppUser.friendIds` never persisted); notifications &
reminders (i18n keys `notifications.joinRequest/accept/deny/reminder*` exist, no implementation); system
chat messages (`Message.isSystem` + i18n `chat.systemJoined` exist, never used); real maps/location
coords (place is free text); profile bio/interests (local-only, lost on restart); capacity/RSVP states;
post-event loop; moderation (host can't remove members).

**Architecture to build on:** repository pattern (abstract + Mock + Firestore, switched by
`AppConfig.useMockBackend`); Provider DI in `app.dart`/`main.dart`; `firestore.rules` per collection;
JSON i18n in `assets/i18n/en_US.json`; `AnalyticsService` event conventions.

---

## Friction to fix (woven into Phase 1 — these leak the existing funnel)

1. **Bio & interests evaporate on restart** (local-only in `profile_screen.dart`) — yet interests fuel
   recommendations + matching. Persist to `users` doc. *Highest ROI, smallest effort.*
2. **Friends tab is a dead end** — a whole nav slot → empty screen.
3. **Chat is silent/contextless** — no "Alex joined", no "starts in 2h". Plumbing exists, unused.
4. **No post-activity loop** — peak goodwill (just after a fun hang) is wasted.
5. **Join is the only signal** — no "Interested/maybe", no waitlist.
6. **Flat chronological feed** — no location, no "your friends are going", no trending.
7. **Empty cold-start feed** — `isSuggested` flag exists but is unused in ranking.

---

## The features (A–I)

| ID | Feature | Primary loop | Status |
|----|---------|--------------|--------|
| A | **Circles** — recurring micro-communities | Community + all four | ✅ Shipped (manual-test pending) |
| B | **Post-hang loop** — recap → add people → "Hang again?" | Growth + Retention | ✅ Shipped (manual-test pending) |
| C | **Friends graph** + "your people are going" | Growth | ✅ Shipped (manual-test pending) |
| D | **Notifications & reminders** (push + inbox) | Retention | ⬜ Not started |
| E | **Interested / Save / Waitlist + capacity** | Liquidity + signal | ⬜ Not started |
| F | **"Hang out now"** — spontaneity mode | Retention | ⬜ Not started |
| G | **Place intelligence** — coords, maps, "near me" | Liquidity | ⬜ Not started |
| H | **Trust & safety** — mutual-friend context, verify, report/block, host moderation | Enables strangers | ⬜ Not started |
| I | **Reputation & rituals** — pro-social status, streaks, history | Community depth | ⬜ Not started |

### A. Circles — recurring micro-communities (the centerpiece)
Small, named, persistent groups ("Tuesday Tennis", "The Brunch Club"). A Circle is a standing container
that spins up activities repeatedly with one tap, keeps a persistent chat between hangs, and accrues
shared history. The biggest structural differentiator from Meetup (which only has heavyweight public
Groups). Builds on existing primitives: `memberIds` + a persistent chat + a way to mint activities.

### B. The post-hang loop
After `startAt` passes: "How was [activity]?" → one-tap vibe rating, prompt to **add the people you met**
as friends / to a Circle, and a **"Hang again?"** button that pre-fills a new activity with the same
people. Highest-leverage growth+retention loop; absent today. Ties to the brief's "rate activities".

### C. Friends graph + "your people are going"
Make `friendIds` real: friend requests (`accept`/`deny` keys exist), then surface "3 friends are going"
on cards and "friends free this week". People join *people*, not events. Safest growth path + trust layer.

### D. Notifications & reminders
Wire FCM push + in-app inbox: someone joined your activity, your activity starts in 2h (key exists),
a friend started a hang nearby, your Circle's slot is open. The retention heartbeat + delivery mechanism
for most other loops.

### E. Lightweight intent: Interested / Save / Waitlist + capacity
Soft "Interested" state (distinct from join), optional capacity with auto-waitlist. Captures demand
signal currently thrown away; nudges fence-sitters; creates healthy scarcity.

### F. Spontaneity mode — "Hang out now"
"Down to hang in the next 2 hours" broadcast to friends/Circles/nearby with a short TTL. The unmet need
Meetup ignores (tonight, who's free?). A distinct high-frequency habit loop.

### G. Place intelligence
Promote `placeSuggestion` from free text to real places (coords + map + "near me" sorting + distance on
cards). Geo-discovery + venue pages. Deferred earlier; the liquidity unlock past one friend group.

### H. Trust & safety as a feature
Verified profiles, mutual-friend / Circle context before joining, report/block, host moderation (remove
members — in the brief), optional vetted/women-only. Treat trust as a product surface (badges, "2
mutuals"). What lets the app safely open to strangers.

### I. Reputation & rituals
Light *pro-social* status: "showed up to 12 hangs", "hosted 5", Circle streaks, shared history/photo
wall. Rewards showing up + bringing people together, not vanity metrics. Makes leaving feel like
abandoning a community.

---

## Execution sequencing (most powerful first, none ignored)

We take them **one at a time**, each as its own implementation plan + PR, verified before the next.
Ordering balances impact, dependency, and the "fix the leaks first" principle.

- **Phase 1 — Foundation & cheap wins (do first):**
  - **F1.** Persist profile **bio + interests** to `users` (friction #1; unblocks C, E, recommendations).
  - **F2.** **System chat messages** (friction #3; "X joined", host events) — plumbing already exists.
  - **C.** **Friends graph** (friend requests, friends list, "friends are going") — foundational social
    graph that A, B, D, H all lean on. *This is where we start the real feature work.*

- **Phase 2 — The differentiators:**
  - **A.** **Circles** (the centerpiece; depends on the friends graph from C).
  - **B.** **Post-hang loop** (ratings + "add people" → feeds C and A; depends on friends/circles).
  - **D.** **Notifications & reminders** (delivery layer for join-requests, reminders, Circle nudges).

- **Phase 3 — Scale & depth:**
  - **E.** Interested / Waitlist / capacity.
  - **G.** Place intelligence (coords, maps, near-me).
  - **H.** Trust & safety surfaces (incl. host moderation).
  - **I.** Reputation & rituals.

> Why start the *feature* work at **C (Friends)** rather than **A (Circles)**: Circles, the post-hang
> loop, "friends are going", and most of trust & safety all assume a friend graph exists. Building C
> first means A and B land faster and richer. F1/F2 come even earlier because they're tiny and unblock
> recommendations + make chat feel alive immediately.

---

## Working agreement (how we build each feature)

- One feature at a time: its own implementation plan (models → repository interface + Mock + Firestore →
  `firestore.rules` → DI wiring → UI → i18n keys → analytics events), then verify, then next.
- Follow existing patterns: repository abstraction, Provider DI, JSON i18n, analytics naming
  (`Hang:${name}:Clicked` / `:Typing` / `:OnLoad` / `${action}:Success`).
- **Testing:** per the owner's standing instruction, **manual testing only** — do not add/modify
  automated tests. Keep `flutter analyze` clean.
- Firebase changes are made **via the Firebase console (browser), not CLI**; `firestore.rules` is edited
  in-repo and pasted into the console by the owner.
- Update this file's **Status** column and check off sub-steps as each ships.

---

## Status log

- _2026-06-04_ — Roadmap created.
- _2026-06-04_ — **Phase 1 / F1 (persist bio + interests) + F2 (system chat messages) shipped.**
  - F1: `AppUser` gained `bio` + `interests`; `UserRepository` gained `fetchProfile` + `upsertIdentity`
    (sign-in now writes identity only, never clobbering saved bio/interests); profile screen hydrates +
    persists on edit/toggle. Stored in `users/{uid}`.
  - F2: `ChatRepository.sendSystemMessage`; `FeedController` emits "X joined the activity" on chat
    creation (host + 2nd joiner) and each later join (system `senderId` = actor's uid, `type: 'system'`
    — no rules change); chat screen renders a centered muted system pill.
  - `flutter analyze` clean. Manual-test pending on device.
- _2026-06-04_ — **Feature C (Friends graph) shipped.**
  - New: `FriendRequest`/`FriendshipStatus` model, `FriendRepository` (+ Firestore/Mock),
    `FriendsController`. `friend_requests/{id}` collection; friendship = mutual `users.friendIds`
    (arrayUnion on accept). Added `displayNameLower` for prefix search.
  - UI: full Friends tab (search, incoming requests Accept/Deny, outgoing Pending+Cancel, friends list),
    nav-icon **badge** for pending incoming, **Add/Requested/Accept/Friends** button on the read-only
    user profile, **"N friends going"** badge on feed cards, real **Friends** stat on profile.
  - `firestore.rules`: `friend_requests` block + field-scoped cross-user `friendIds` append (mirrors the
    `likedBy` pattern). **Owner must publish updated rules in the Firebase console.**
  - `flutter analyze` clean. Manual-test pending (two Google accounts).
- _2026-06-04_ — **Feature A (Circles) shipped — the centerpiece.**
  - New: `Circle`/`CircleInvite` models, `CircleRepository` (+ Firestore/Mock), `CirclesController`,
    Circles tab, circle detail screen, create-circle sheet. `Activity.circleId` links spun-up hangouts.
  - Persistent circle chat **reuses the generic chat layer** at `chats/{circleId}` (renamed
    `ChatScreen.activityId` → `chatId`). **Invite + accept** membership mirrors friend requests.
    "Plan a hangout" pre-fills Create Activity with circle members + circleId.
  - Nav: added a **Circles tab** (5-item bar) with an invite **badge**; **Profile moved off the bar**
    to an app-bar avatar (`ProfileAvatarButton`) on every main screen.
  - `firestore.rules`: `circles` + `circle_invites` blocks (field-scoped `memberIds` self-append on
    accept, mirroring friendIds). **Owner must republish rules in the console.**
  - `flutter analyze` clean. Manual-test pending.
- _2026-06-04_ — **Feature B (Post-hang loop) shipped.**
  - `Activity.ratings` (uid→1–5) + `rateActivity` repo method. "Ended" = `startAt < now`.
  - Recap **sheet** (rate stars + "people you met" with Add-friend reusing the friends flow + "Hang
    again"); **card** in My Activities **Past** section (split into Upcoming/Past); dismissible **banner**
    on the Discover feed for the latest un-recapped hang.
  - Create Activity gained `prefillTitle/Place/Category` (+ `initState`) for "Hang again".
  - `firestore.rules`: members may write the `ratings` field (field-scoped). **Owner republishes.**
  - `flutter analyze` clean. Manual-test pending (age an activity's `startAt` to the past).
  - **Next up: D — Notifications & reminders**, then E, G, H, I per the roadmap.
- _2026-10-05_ — **Release blockers 1–3: security rules hardening.**
  - `firestore.rules` rewritten: field-level activity updates (no hostId/title takeover, no adding
    others, no forged likes/ratings; host can't rate own hang), circle-private hangouts, chat +
    message membership checks, sender impersonation blocked, party-scoped list rules.
  - System chat lines are now **structured events** (`joined`/`planned`/`hostLeft`/`creatorLeft`)
    rendered via i18n; rules verify names/titles against real docs.
  - Friend requests / circle invites use deterministic ids (`{from}_{to}`, `{circle}_{to}`) and are
    deleted after accept; Discover/host-stats queries filter `circleId == null`.
  - New `firestore.indexes.json` (activities `circleId`+`startAt`). **Owner must publish rules and
    create the index in the console.** Verified with a throwaway emulator script (97 cases).
- _2026-10-05_ — **Release blocker 4: user safety (report / block / remove member).**
  - Report sheet (reason + details) for users (profile menu), activities (details ⋯ menu) and
    messages (long-press in chat) → `reports` collection (create-only).
  - Block / unblock from profile or chat: hides their activities, requests and search results,
    replaces their chat messages with a placeholder, and severs friendship / pending requests.
  - Hosts remove members from the who's-going row (activity + chat); `removedIds` blocks rejoin.
  - Rules: `blocks`, `reports`, `removedIds`, blocked-user join/request/invite denial. **Owner
    republishes rules** and reviews reports daily (see RELEASE_CHECKLIST).
- _2026-10-05_ — **Store-required UGC items: terms acceptance, content filter, contact.**
  - `TermsGate` (wraps `HomeShell`): signed-in users must accept the community rules + Terms/Privacy
    before using the app; stored as `users/{uid}.termsVersion` (+ `termsAcceptedAt`). Bump
    `kTermsVersion` in `lib/core/legal/legal.dart` to re-prompt everyone after material changes.
  - `docs/terms.md` + `docs/privacy-policy.md` bundled as assets and viewable in-app
    (`LegalDocScreen`) from the gate and Profile → Settings (Privacy Policy, Terms, Help & contact).
  - `ContentFilter` (client-side word list, EN + RO, leet/diacritics aware) rejects public text:
    activity title/description/place, circle name, profile name/bio and custom interests. Chat is
    deliberately unfiltered (private conversation); Report message + Block cover it.
  - Contact email `letshangout45@gmail.com` filled into the docs and shown in-app.
- **Legal docs aligned with the code.** Privacy policy now discloses uploaded photos (avatar,
  activity covers), Firebase Analytics + Storage, reports/blocks, terms acceptance, what deletion
  keeps, and GDPR legitimate-interest basis. Minimum age raised to **18+** (terms, policy,
  agreement checkbox; `kTermsVersion` → 2 so everyone re-accepts). Added
  `docs/delete-account.md` (Play's web deletion URL). Advertising-ID collection disabled on
  Android (manifest) and iOS (Podfile) so the "no ad identifiers" claim holds.
