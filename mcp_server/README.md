
# 🎙️ Alexa+ Multimodal Echo Show Simulator & MCP Bridge

An in-browser **Amazon Echo Show** multimodal smart display simulator and Model Context Protocol (MCP) client. Built for the **Amazon Developer Hackathon: Build, Ship, Shape (Alexa+ Track)** to bridge ambient living room voice interactions with the **BeaconOS** sovereign accessibility phone.

---

## 🌟 Overview

The Alexa+ Web Simulator provides a full fidelity, zero-install testing environment for Alexa+ agentic interactions. It simulates an Echo Show device in the user's living room that connects directly to the self-hosted **BeaconOS MCP Server** via **Streamable HTTP** (MCP Spec: `2025-11-25`).

When a user speaks to Alexa (e.g., *"Alexa, find my Beacon phone!"*), the simulator:

1. Translates voice queries into JSON-RPC 2.0 `tools/call` payloads.
2. Dispatches requests over Streamable HTTP to `http://127.0.0.1:8000/mcp`.
3. Synthesizes Alexa voice responses via the Web Speech API.
4. Renders interactive, high-contrast **MCP Apps** UI cards (Radar Locator, Telemetry Gauge, Emergency SOS Dashboard) inline on the simulated Echo Show screen.
5. Displays live protocol traffic in the **MCP Protocol Inspector** for hackathon judges.

---

## 🏛️ Architecture & Data Flow

```text
[Living Room Voice Command]
          │
          ▼  ("Alexa, find my Beacon phone!")
┌────────────────────────────────────────────────────────┐
│             Alexa+ Web Simulator (Client)              │
│  • Web Speech Recognition                              │
│  • Echo Show UI Viewport (MCP Apps Host)               │
│  • Live JSON-RPC Protocol Inspector                    │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ HTTP POST /mcp
                            │ Header: MCP-Protocol-Version: 2025-11-25
                            │ Accept: application/json, text/event-stream
                            ▼
┌────────────────────────────────────────────────────────┐
│               BeaconOS Python MCP Server               │
│               (FastAPI / Streamable HTTP)              │
│  • tool: beacon_locate_phone                           │
│  • returns text speech + ui:// resource payload        │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ SQL Insert (status: 'pending')
┌────────────────────────────────────────────────────────┐
│                   Supabase Realtime                    │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ WebSocket (< 180ms)
┌────────────────────────────────────────────────────────┐
│             BeaconOS Mobile App (Flutter)              │
│  • SoundCue.sosAlarm (100% volume siren)               │
│  • Camera torch strobe pulses (10x)                    │
│  • Emergency tactile haptic pulses                     │
└────────────────────────────────────────────────────────┘
```

---

## 🛠️ MCP Specification Compliance

* **Protocol Version:** `2025-11-25` (Streamable HTTP).
* **Transport Endpoint:** Unified `POST /mcp` and `GET /mcp` (Server-Sent Events).
* **Mandatory Request Headers:**
  * `MCP-Protocol-Version: 2025-11-25`
  * `Content-Type: application/json`
  * `Accept: application/json, text/event-stream`
* **JSON-RPC Version:** `2.0`
* **Security:** Local binding (`127.0.0.1`), origin verification, and DNS rebinding protections.

---

## 🧰 Available Voice Tools & Multimodal Cards

| Voice Prompt                                  | MCP Tool Called                  | Speech Output                                                                            | MCP App Card Rendered                                                                                      |
| :-------------------------------------------- | :------------------------------- | :--------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------- |
| **"Alexa, find my Beacon phone!"**      | `beacon_locate_phone`          | *"Your Beacon phone has been pinged. Maximum siren and flashlight strobe are active."* | **Acoustic Radar Locator**: Concentric animated rings, flashing phone icon, siren & torch telemetry. |
| **"Alexa, trigger emergency SOS"**      | `beacon_trigger_emergency_sos` | *"Emergency SOS broadcasted! Distress radar active and live coordinates dispatched."*  | **Emergency Dashboard**: High-contrast crimson card with live GPS latitude/longitude.                |
| **"Alexa, check phone battery"**        | `beacon_get_device_telemetry`  | *"Beacon phone is online with 88% battery in Blind Accessible Mode."*                  | **Device Telemetry Gauge**: 88% battery circle, latency meter (<150ms), profile badge.               |
| **"Alexa, what is my daily briefing?"** | `beacon_get_daily_briefing`    | *"Good day. You have 2 pending priorities. Top item is: Review Documentation."*        | **Daily Agenda Card**: Pending task summary and next alarm timestamp.                                |
| **"Alexa, add task: [Task Title]"**     | `beacon_create_task`           | *"I added '[Task Title]' to your Beacon agenda with high priority."*                   | **Task Confirmation**: Instant sync badge to phone's Drift SQLite storage.                           |

---

## 📂 File Structure

```text
alexa_simulator/
├── index.html       # Echo Show chassis, ambient Alexa light bar & Inspector
├── style.css        # Dark mode WCAG AAA styling, animations & radar graphics
├── app.js           # MCP Streamable HTTP client, speech engine & card renderer
└── README.md        # Documentation and running guide
```

---

## 🚀 Getting Started

### 1. Prerequisites

* A modern web browser supporting the Web Speech API (Google Chrome, Microsoft Edge, or Safari).
* The BeaconOS MCP Server running locally.

### 2. Start the MCP Server

In the root directory of the repository:

```bash
cd mcp_server
python -m venv venv
source venv/bin/activate       # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python server.py
```

*The server will be running on `http://127.0.0.1:8000/mcp`.*

### 3. Open the Simulator

Serve the simulator using any static HTTP server:

```bash
cd alexa_simulator
python -m http.server 3000
```

Open **`http://localhost:3000`** in your browser.

*(Alternatively, you can open `index.html` directly in your browser without a local web server).*

---

## 🧪 Testing the End-to-End Experience

1. **Verify Connection:**

   * Ensure the badge in the top right of the Echo Show header indicates **MCP Online**.
   * The default endpoint input in the inspector is configured to `http://127.0.0.1:8000/mcp`.
2. **Trigger an Action:**

   * Click any quick preset button (e.g., `📍 "Find my phone"`).
   * Or click the **Microphone** button and speak: `"Alexa, find my Beacon phone!"`.
3. **Verify Echo Show Display:**

   * Watch the bottom **Alexa Cyan Light Bar** pulse with animation.
   * Listen to Alexa's synthesized voice response.
   * View the interactive **Acoustic Beacon Locator** card appear on screen.
4. **Verify Protocol Inspector:**

   * The right panel displays the exact JSON-RPC 2.0 `tools/call` request with the required `MCP-Protocol-Version: 2025-11-25` header.
   * The server response shows the returned text content alongside the `ui://` resource card payload.
5. **Verify Phone Reaction:**

   * If the BeaconOS Flutter app is running on an Android device or emulator connected to the same Supabase instance, the phone immediately triggers its siren sound, pulses the camera flashlight 10 times, and fires tactile haptic alerts.

---

## 🔍 Protocol Inspector Reference

Example payload logged during a tool execution:

**Request (`POST /mcp`):**

```json
{
  "jsonrpc": "2.0",
  "id": "call-1728734912000",
  "method": "tools/call",
  "params": {
    "name": "beacon_locate_phone",
    "arguments": {
      "reason": "Alexa living room query: find my phone"
    }
  }
}
```

**Response (`200 OK`):**

```json
{
  "jsonrpc": "2.0",
  "id": "call-1728734912000",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Your Beacon phone has been pinged. Maximum siren and flashlight strobe are active."
      },
      {
        "type": "resource",
        "resource": {
          "uri": "ui://beacon/beacon_locate_phone",
          "data": {
            "type": "radar_locator",
            "title": "Acoustic Beacon Active",
            "status": "Pinging Hardware",
            "pulse_rate": "high",
            "siren_frequency": "3000Hz - Loud",
            "flashlight": "Strobe Active"
          }
        }
      }
    ],
    "isError": false
  }
}
```

---

## 📄 License

This simulator is part of the BeaconOS project, licensed under the **MIT License**.
