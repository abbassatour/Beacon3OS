
<div align="center">

---

## 💡 Executive Summary & Problem Statement

Assistive technology for the **285+ million visually impaired people worldwide** is severely broken:

1. **Extortionate Centralized Subscriptions:** Existing visual assistance apps charge up to $50–$200/month for AI assistance or human guidance.
2. **Privacy Invasion:** Sensitive camera feeds and daily life habits are stored on centralized cloud servers.
3. **Screen Clutter:** Modern mobile operating systems are designed around eye engagement, notification badges, and infinite feeds, making digital life exhausting for minimalists and hostile to the blind.

### The BeaconOS Solution

**BeaconOS** is an open-source, sovereign ambient operating system built on three revolutionary pillars:

* **Zero-UI Spatial Micro-Kernel:** Replaces app grids with an eyes-free, continuous Cartesian coordinate room system governed by critically damped Runge-Kutta springs ($\zeta = 1.0$).
* **100% Community-Subsidized AI Vision:** Camera inference (scene description, obstacle alerts, document OCR, currency detection) is subsidized by an on-chain Public Impact Pool deployed on **Arbitrum Sepolia L2**.
* **Zero-Latency Cross-Device State Relay:** Seamless ambient bridge connecting the **Android Phone Launcher**, **Fire TV Canvas** (living room), **Desktop Command Center** (PC), and **Alexa+ Echo Show** via Model Context Protocol (MCP).

---

## 🏛️ Three-Tier Hybrid Architecture

BeaconOS solves the classic blockchain dilemma (*how to deliver sub-5ms tactile voice responses without waiting for block confirmations*) using a **Three-Tier Sovereign Architecture**:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ TIER 1: CRITICALLY DAMPED LOCAL VAULT (Drift SQLite • 0ms Latency)          │
│ • Runs 100% offline on-device with encrypted local storage.                 │
│ • Manages Tasks, Alarms, Voice Memos, Contacts, and Spatial Room Topology.  │
│ • Zero tracking, zero surveillance.                                         │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ TIER 2: AMBIENT STATE RELAY (Edge Realtime Synchronization)                  │
│ • Sub-150ms bi-directional synchronization across the user's personal fleet:│
│   📱 Android Phone ◄──► 📺 Fire TV ◄──► 💻 Desktop ◄──► 🎙️ Alexa+ MCP      │
│ • Encrypted relay handles low-latency device localization and distress audio.│
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ TIER 3: VERIFIABLE PUBLIC GOOD (Arbitrum Sepolia L2 EVM Smart Contract)     │
│ • Self-Custodial Sovereign Burner Wallet (DID) generated on-device (No PWs).│
│ • BeaconImpactPool.sol: Community sponsorships fund AI vision tokens.        │
│ • Immutable On-Chain Emergency SOS Attestations with signed GPS coordinates. │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🌐 Cross-Device Fleet & Live Surfaces

| Surface                         | Platform                  | Key Interaction & Purpose                                                                                                                   |
| :------------------------------ | :------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------ |
| **📱 Spatial Phone**      | Android (System Launcher) | Eyes-free multi-touch gestures, high-contrast OLED, continuous haptic audio radar, and instant 3-tap SOS distress.                          |
| **📺 Living Room Canvas** | Fire TV & Android TV      | Ambient family radar, remote-driven acoustic device finder (100% siren ping), and living room agenda canvas.                                |
| **💻 Command Center**     | Windows, macOS, Linux     | Keyboard-driven Zen task Kanban board, spatial topology editor, and Sovereign DID inspector.                                                |
| **🎙️ Echo Show Bridge** | Alexa+ Simulator          | MCP Streamable HTTP bridge executing voice commands (`beacon_locate_phone`, `beacon_trigger_emergency_sos`) with rich multimodal cards. |

---

## ⛓️ On-Chain Public Good (Arbitrum Sepolia)

The **`BeaconImpactPool`** smart contract converts accessibility from a commercial commodity into an immutable decentralized public good.

* **Network:** Arbitrum Sepolia Testnet (Chain ID: `421614`)
* **Contract Address:** `0x14541544321A8b456C931fF648EbEB16eE1eB349`
* **Explorer:** [Arbiscan Sepolia](https://sepolia.arbiscan.io)

### Core Contract Capabilities:

1. **`sponsorPool()` (Payable):** Community donors and philanthropists deposit ETH/USDC to subsidize AI inference for visually impaired users worldwide.
2. **`logAiInferenceImpact(string featureType)`:** Emits verifiable on-chain *Proof-of-Impact* receipts whenever an AI vision scan (OCR, currency, obstacles) is completed.
3. **`attestEmergencySos(int64 latE6, int64 lngE6, uint8 battery)`:** Records an immutable, tamper-proof rescue attestation to the blockchain during critical emergencies, ensuring rescue services and relatives receive untampered proof of distress.

---

## 👁️ Dual Interaction Personas

BeaconOS features a single unified engine that adapts to two distinct human needs:

### 1. Blind Accessible Mode (High-Contrast Ice-Void OLED)

* **Visual Tokens:** Pitch-black background (`#000000`) with high-contrast `#00E5FF` Cyan and `#FFFF00` Yellow accents (WCAG 2.2 AAA, 21:1 contrast ratio).
* **Sonic Compass & Haptics:** Continuous spatial drone audio frequencies shift depending on cardinal direction (North, South, East, West) and floor altitude ($Z$-Axis).
* **Safety Gestures:** Rapid 3-tap anywhere on screen triggers maximum emergency siren, strobe flashlight, SMS dispatch, and Arbitrum on-chain attestation.

### 2. Digital Minimalist Mode (Editorial Warm Paper)

* **Visual Tokens:** Calming textured warm paper canvas (`#FAF7F2`) and carbon ink typography (`#1C1917`).
* **Calm Computing:** No algorithmic feeds, zero red notification badges, zero app icons. Access phone features via voice or intentional Cartesian navigation.
* **Deep Work Rhythm:** Integrated Pomodoro intervals and auto-archiving priority lists.

---

## 🤖 Zero-UI Voice Intent Bus & Multimodal AI

BeaconOS implements a two-tier voice pipeline:

* **Tier 1 — Sub-5ms Sovereign Fast Path:** Instant regex matching for offline device controls (Flashlight, battery check, lock screen, timers, system alarms).
* **Tier 2 — Multimodal AI Reasoning (Gemini 2.0 Flash):** Deep scene comprehension, document OCR, currency evaluation, and complex agenda synthesis.

---

## 🛠️ Project Structure

```text
BeaconOS/
├── contracts/                  # Solidity Smart Contracts (BeaconImpactPool.sol)
├── packages/
│   ├── cloud_sync_api/         # Supabase Realtime synchronization client
│   ├── launcher_repository/    # Orchestrator micro-kernel & domain repositories
│   ├── local_vault_api/        # Encrypted Drift SQLite tables & schema migrations
│   ├── system_hardware_api/    # Platform MethodChannels (Alarms, Torch, Battery, GPS)
│   └── voice_ai_api/           # TTS, STT, and Gemini 2.0 Flash agent
├── lib/
│   ├── agenda/                 # Floor 0 (Tasks) & Floor 1 (Archive behaviors)
│   ├── cockpit/                # Floor 0 (Today Canvas) & Floor 1 (Sovereign DID & Engine)
│   ├── comms/                  # Floor 0 (Contacts & SOS) & Floor 1 (Radar settings)
│   ├── focus/                  # Floor 0 (Pomodoro & Alarms) & Floor 1 (Chimes tuning)
│   ├── vision/                 # Floor 0 (AI Vision Studio) & Floor 1 (Inspection settings)
│   ├── impact_pool/            # Web3 Public Goods & Sovereign Wallet UI
│   ├── spatial_shell/          # Matrix4 3D portal transforms & touch physics
│   ├── desktop/                # Desktop Command Center (Sidebar, Grid studio)
│   ├── fire_tv/                # Fire TV Leanback canvas & living room bridge
│   └── bootstrap.dart          # Production entrypoint & hardware initialization
├── alexa_simulator/            # Web-based Echo Show simulator for judges
└── mcp_server/                 # Python Model Context Protocol Streamable HTTP server
```

---

## 🚀 Getting Started

### Prerequisites

* Flutter SDK (`>= 3.44.0` / Dart `^3.12.0`)
* Java 17 & Android SDK (for Android Phone & Fire TV builds)
* Python 3.10+ (for running the Alexa MCP server)

### 1. Clone & Configure

```bash
git clone https://github.com/abbassatour/BeaconOS.git
cd BeaconOS
cp .env.example .env
```

Fill in your `.env` credentials:

```env
SUPABASE_URL=https://your-supabase-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
OPENROUTER_API_KEY=your_gemini_openrouter_key
WEB3_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
IMPACT_CONTRACT_ADDRESS=0x14541544321A8b456C931fF648EbEB16eE1eB349
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run on Target Platform

* **Android Phone (Development):**
  ```bash
  flutter run --flavor development -t lib/main_development.dart
  ```
* **Desktop Command Center (Windows/macOS/Linux):**
  ```bash
  flutter run -d windows -t lib/main_windows.dart
  ```
* **Fire TV / Android TV Canvas:**
  ```bash
  flutter run --flavor development -t lib/main_firetv.dart
  ```
* **Run Alexa+ MCP Bridge Server:**
  ```bash
  cd mcp_server
  pip install -r requirements.txt
  python server.py
  ```

---

## 🏆 Hackathon Tracks & Impact Alignment

* **Public Goods & Social Impact:** Converts assistive AI from private SaaS into community-funded, decentralized public infrastructure.
* **Arbitrum & L2 Scalability:** Leverages Arbitrum Sepolia for micro-attestations and sub-cent sponsorship transactions.
* **DePIN & Hardware Integration:** Integrates real smartphones, smart TVs, and voice assistants into a verifiable edge network.
* **Human-Centered AI:** Demonstrates Gemini 2.0 Flash in a real-world, high-stakes accessibility scenario with zero screen dependencies.

---

## 📄 License

This project is licensed under the **PolyForm Noncommercial License 1.0.0** — free for all noncommercial, educational, and open-source accessibility use.

---

<div align="center">
<b>Built with intentionality for humanity. 🕊️</b><br>
<i>BeaconOS Team • Hackathon Final Submission</i>
</div>
