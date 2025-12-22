# Goast

**Here then gone.**

> *Conversations that matter, right now. Everything else fades away.*

---

## Executive Summary

**Goast** is a reimagined communication network designed for the post-social-media generation. Built in response to the growing global movement for safer online spaces for teens, Goast fundamentally changes the architecture of digital connection.

We replaced the permanent, anxiety-inducing "feed" with **ephemeral, self-governing group chats**. There are no influencers, no infinite scrolls, and no permanent records. Just you and your friends, in the moment. When the conversation stops, the Goast dissolves—like solid smoke.

---

## The Philosophy

Traditional social media is built on **accumulation**: more posts, more followers, more history. This accumulation breeds toxicity, comparison, and anxiety.

Goast is built on **dissolution**.

- **Anti-Toxicity by Design:** We didn't just write better community guidelines; we built a system where toxicity is economically expensive and kindness is the default.
- **No Admin Dictators:** There are no single admins with absolute power. Every major decision—from changing the group name to removing a member—is a democratic vote.
- **Group First:** We removed the #1 vector for online bullying: the Direct Message. Every conversation on Goast happens in a group of 3 or more.

---

## The Experience

### Solid Smoke
Every group chat ("Goast") is temporary. It exists only as long as it is alive with conversation. If the vibe fades, the Goast fades. There is no "archive" to haunt you years later.

### Polished by Default
When you type a message, our AI instantly polishes it—smoothing out edges, checking for hurtful language, and ensuring the vibe stays friendly. Want to say *exactly* what you typed? You can, but it costs **Tokens**. Friction is applied to negativity; kindness is free.

### Democracy in Action
Want to extend the life of your chat? Want to change the topic? **Vote on it.** Governance is distributed. You own your community.

### Identity, Reimagined
No uploaded photos. No "perfect" usernames. Your identity is generated for you—a unique, deterministic avatar and a whimsical username (like `swift.blue.piano`). You are defined by your actions and the badges you earn, not by your selfie game.

---

## The "Black Box" AI

Goast feels like magic, but it's powered by a sophisticated, privacy-first AI layer designed to protect, not survey.

### The Polisher
Our message augmentation layer sits between your keyboard and the chat. It understands context, teen slang, and intent, offering a gentler version of your thought without losing your meaning. It turns "This is stupid" into "I'm not loving this," preserving the sentiment while removing the sting.

### The Vibe Check
We don't "monitor" chats like a surveillance state. Instead, the system senses the *momentum* and *sentiment* of a conversation. When energy drops or toxicity rises, the Goast naturally begins to dissolve. It's an automated immune system for your social circle.

### The Historian
When a Goast finally dissolves, no raw logs remain. The AI generates a vague, thematic summary of what the group achieved together (e.g., "Planned the beach trip," "Debated the best pizza toppings"), awards badges for roles played (The Peacemaker, The Hype Person), and then wipes the slate clean.

---

## Engineering & Technology

Goast is a modern Progressive Web App (PWA) built for speed, safety, and scale. We use cutting-edge technology to ensure that "temporary" really means temporary.

### The Stack

| Layer | Technology |
|-------|------------|
| **Framework** | Next.js 15 (App Router) |
| **Language** | TypeScript (Strict Mode) |
| **Database** | PostgreSQL (with Prisma ORM) |
| **Realtime** | WebSocket-based event architecture |
| **Styling** | Tailwind CSS + Custom Design System ("Spectral") |

### The Test Stack: Reliability is Safety

Because Goast is a safety-first platform, our testing strategy goes beyond standard bug checking. We employ a rigorous "Red Teaming" approach.

- **AI Smoke Tests:** We run automated scripts that fire varied, challenging, and edge-case inputs at our AI layer. This ensures the "Polisher" cannot be tricked into letting toxic content slip through and that our moderation rails hold firm under pressure.
- **Simulation Testing:** We simulate entire lifecycles of group chats—creating, chatting, voting, and dissolving—thousands of times to ensure the mathematical models behind our "Token Economy" and "Dissolution Timers" remain balanced and fair.
- **Privacy Verification:** Automated tests verify that when a Goast dissolves, data is actually effectively removed or anonymized in accordance with our strict privacy promises.

---

## Roadmap

### Phase 1: Closed Alpha (Q1 2026)
- **Goal:** Product-market fit validation & safety testing.
- **Audience:** 500 hand-picked users in Australia.
- **Focus:** Core chat mechanics, voting systems, and AI model tuning.

### Phase 2: Invite-Only Beta (Q2 2026)
- **Goal:** Prove viral coefficient & refine AI models.
- **Audience:** 5,000 users via viral invite mechanics.
- **Focus:** Scaling infrastructure, "Token Economy" balancing, and badge reputation systems.

### Phase 3: Launch (Q3 2026)
- **Goal:** Establish as the go-to platform for safe digital connection.
- **Audience:** General public (starting in Australia).
- **Focus:** International expansion, advanced governance features, and native mobile apps.

---

## Contributing

We welcome feedback and ideas! This repository serves as our public roadmap and community hub.

- **Feature Requests:** [Open an issue](../../issues/new?template=feature_request.yml)
- **Bug Reports:** [Report a bug](../../issues/new?template=bug_report.yml)
- **Discussions:** Share your thoughts in [Issues](../../issues)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*Note: This repository serves as a public roadmap and technology showcase. Internal security configurations, proprietary AI prompt engineering, and specific abuse-prevention mechanisms are abstracted.*
