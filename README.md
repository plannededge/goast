# Goast — A social messaging app

No admin. No drama. No spam.

> Group chats for conversations that matter

Goast is an invite-only, AI-mediated, temporary group-chat PWA designed for teens and young adults (13-22). Group chats ("Goasts") dissolve by design, governed by members through voting rather than admins.

Goast replaces the noisy, spammy and impersonal group chats that people have been stuck with. With Goast, there are no influencers, no trolls, no spammers, no drama queens and kings. Just conversations with friends, family, and any group of people who want to plan, organise, celebrate or just vibe together.

## Another social app? Why?

Traditional social platforms are built on permanent content accumulation: more posts, more followers, more history. This permanence has well-documented consequences—cyberbullying that follows you for years, old posts resurfacing out of context, and the anxiety of maintaining a public persona.

Goast takes a different approach. Rather than bolting safety features onto an existing architecture, we designed the product around three constraints from the start:

### No DMs

Every conversation on Goast happens in a group of 3 or more. There are no private 1-on-1 messages. This removes the primary vector for targeted harassment and grooming—the hidden side channel where behaviour goes unwitnessed.

### No admins

Group chats typically have a single admin with unilateral control. On Goast, every significant decision—from changing the group name to removing a member—requires a vote. Power is distributed, not concentrated.

### No permanence

Goasts dissolve. There is no archive to haunt you, no content to screenshot and weaponise months later. When a conversation is done, it fades. This ephemerality is a core architectural choice, not a feature toggle.

These aren't community guidelines hoping for compliance. They're structural constraints enforced at the database level.

## How Goast works

### Creating a Goast

A Goast is a group chat with a purpose. You create one by inviting at least two other people—the minimum group size is always 3. You set a title, optionally a goal (e.g., "Plan a birthday night", "Organise a camping trip"), and dissolution rules.

### Inviting members

Goast is invite-only. There is no public signup, no discoverability, no open join links. You invite specific people using a link that expires after 72 hours. This keeps groups intentional and trusted.

### Messaging

By default, messages are rewritten by AI for clarity and tone before being sent. This smooths out edges without changing meaning—"This is stupid" might become "I'm not sure about this". You can still send your exact words using Direct mode, but this costs tokens (an in-app currency). The friction is deliberate: unmediated text requires a conscious choice.

### Governance by voting

Any member can propose changes: extend the Goast's lifetime, change the title, kick a member. All proposals go to a vote. Different actions require different thresholds—60% for most decisions, 75% for kicks. No single person can override the group.

### Dissolution

All Goasts dissolve. You set the rules at creation: a fixed lifetime (e.g., 7 days), or inactivity-based dissolution (e.g., dissolves if no messages for 4 days). When dissolution triggers, members have 24 hours to vote on extending. If the vote fails, the Goast enters a 7-day wind-down period and then archives. Message content is not retained after archival.

## AI features

Goast uses AI throughout the product. These are production features, not experiments. All AI calls route through Cloudflare AI Gateway for unified logging, caching, and rate limiting.

### Message rewriting (default path)

Every message passes through an LLM rewrite before being sent. The system prompt instructs the model to preserve meaning while smoothing tone, using teen-appropriate language and British English. Output is capped at 180 characters. If the AI call fails, the original message still sends (fail-open design). This uses OpenAI's GPT-5 Nano for low latency.

Technical details: Structured output via Zod schema validation. @mentions are preserved exactly. The rewrite is synchronous, blocking send until complete (typically <500ms).

### Direct text moderation

When users choose to bypass AI rewriting (Direct mode), messages still pass through a moderation layer. This checks for explicit hate speech, threats, sexual content, doxxing attempts, and self-harm content. Hard blocks prevent sending; soft flags are logged but allowed.

### Suggested replies

Four context-aware reply suggestions appear above the message composer. These are generated from the last 15 messages in the conversation. Uses OpenAI's GPT-5 Mini. Suggestions are casual and teen-appropriate.

### Chat agents (AI participants)

Goasts can have AI agents as participants. Three personas exist:

- **Riley (Jester)** — keeps things light, defuses tension with humour
- **Sage (Vibe Check)** — asks thoughtful questions, encourages quieter members
- **Quinn (Troll Defender)** — redirects trolling, supports targeted members

Agents use a "thought before action" pattern: each message triggers an internal evaluation of whether to respond. Eight heuristics determine intervention (relevance, urgency, coherence, persona fit, etc.). Agents have rate limits via a token pool that members can refill.

### Agent guardrails

Pattern-based detection for teen safety (self-harm, grooming, exploitation), provocation resistance (jailbreak attempts, prompt injection), and scope enforcement (off-topic requests, advice-seeking). Crisis detection triggers resources from Samaritans, Childline, and Shout.

### Goast summaries

When a Goast dissolves, an AI generates a thematic summary of what was discussed ("Planned the beach trip", "Debated pizza toppings"). Uses Google Gemini 2.5 Pro for large context windows. The summary is viewable for 30 days; raw message content is not retained.

### Link analysis (Spectral Links)

Shared links are enriched with AI-generated metadata using Perplexity Sonar. Categories include Video, Audio, Location, Social, Commerce, Event, Article. This provides richer link previews without requiring users to click through.

### Avatar generation

Users can generate AI avatars using Replicate. Sliders control vibe, energy, expression, and other parameters. Generation costs 25 tokens. A moderation pass is required before avatars are saved.

### Reaction image generation (Reaction Lab)

Users can generate custom reaction images from templates for use in chat. Costs 10 tokens per generation. Images are saved to a personal "deck" for instant reuse.

## Tech stack

### Frontend

| Technology          | Version | Purpose                                      |
|---------------------|---------|----------------------------------------------|
| Next.js             | 15.x    | Framework (App Router, Server Components, Turbopack) |
| React               | 19.x    | UI library                                   |
| TypeScript          | 5.7.x   | Language (strict mode)                        |
| Tailwind CSS        | 3.4.x   | Styling                                      |
| Framer Motion       | 11.x    | Animations                                   |
| TanStack Query      | 5.x     | Server state (via tRPC integration)            |
| class-variance-authority | 0.7.x | Component variants                           |
| Servist             | 9.x     | PWA/Service Worker                           |

### Backend / API

| Technology          | Version | Purpose                                      |
|---------------------|---------|----------------------------------------------|
| tRPC                | 11.x RC | End-to-end type-safe RPC                      |
| Prisma              | 5.22.x  | ORM                                          |
| PostgreSQL          | 17.x    | Database (Fly.io Managed Postgres)             |
| Zod                 | 3.24.x  | Runtime validation                           |
| Ingest              | 3.27.x  | Background job processing                     |
| Pusher              | 5.2.x   | Real-time WebSocket messaging                 |

### LLMOps

| Technology          | Purpose                                      |
|---------------------|----------------------------------------------|
| Cloudflare AI Gateway | Unified AI proxy, request logging, caching, key management |
| OpenAI API          | Message rewriting (GPT-5 Nano), suggestions (GPT-5 Mini), moderation |
| Google Gemini API   | Chat summaries (Gemini 2.5 Pro, large context) |
| Perplexity Sonar API | Link analysis and enrichment                  |
| Replicate           | AI avatar generation                         |

### Infrastructure

| Technology          | Purpose                                      |
|---------------------|----------------------------------------------|
| Fly.io              | App hosting (Next.js) + Managed Postgres       |
| Cloudflare Workers  | Marketing site hosting (via OpenNext adapter)  |
| Cloudflare R2       | Object storage (avatars, images)               |
| Doppler             | Secrets management                           |
| Postmark            | Transactional email                          |
| web-push            | Push notifications                           |

### Monitoring & analytics

| Technology | Purpose                                      |
|------------|----------------------------------------------|
| Sentry     | Error tracking, performance monitoring, session replay |
| Mixpanel   | Product analytics (browser + server-side)      |

### Build tooling

| Technology      | Version | Purpose                                      |
|-----------------|---------|----------------------------------------------|
| pnpm            | 9.14.x  | Package manager                              |
| Turborepo       | 2.3.x   | Monorepo build system                         |
| Vitest          | 4.x     | Unit testing                                 |
| Testing Library | 16.x    | Component testing                            |
| Husky           | 9.x     | Git hooks                                    |

## Contributing

We welcome feedback and ideas. This repository serves as our public roadmap and community hub.

- **Feature Requests:** [Open an issue](https://github.com/goast/goast/issues/new?labels=feature)
- **Bug Reports:** [Report a bug](https://github.com/goast/goast/issues/new?labels=bug)
- **Discussions:** [Share your thoughts in Issues](https://github.com/goast/goast/discussions)

## Licence

This project is licensed under the MIT Licence — see the [LICENCE](LICENSE) file for details.
