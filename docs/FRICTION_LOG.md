
# 🛠️ BeaconOS × Alexa+ MCP Developer Friction Log (Part 1/3)

**Evaluation Focus:** System Architecture, Test Harness, and Streamable HTTP Transport Layer
**Target Specification:** Model Context Protocol (MCP) `2025-11-25`
**Host Environment:** Simulated Alexa+ Echo Show Smart Display & Web Client
**Server Target:** Self-Hosted Python MCP Server (`mcp_server/server.py`)
**Actuator Device:** BeaconOS Sovereign Accessibility Phone (Flutter / Android)

---

## 1. Executive Summary & Evaluation Scope

### 1.1 Architectural Intent

The goal of this implementation is to provide an ambient, voice-actuated safety bridge between Amazon smart home devices (**Alexa+** / Echo Show) and a visually impaired user's smartphone running **BeaconOS**.

In a real-world scenario, a blind user who misplaces their phone in the living room cannot rely on a phone-based screen reader to locate it. They issue a hands-free ambient prompt to their home speaker:

> *"Alexa, find my Beacon phone!"*

The Alexa+ host interacts with our self-hosted MCP Server via the open **Streamable HTTP** transport standard (`2025-11-25`). The server validates the request, executes the `beacon_locate_phone` tool, returns a multimodal response (text speech + inline interactive UI card), and pushes a real-time event to the physical device to trigger loud frequency sirens, camera torch strobes, and tactile haptic pulses.

```text
[Living Room Ambient Prompt]
            │
            ▼  ("Alexa, find my Beacon phone!")
┌────────────────────────────────────────────────────────┐
│           Alexa+ Host / Web Simulator Client           │
│  • Web Speech Recognition                              │
│  • Multimodal Echo Show Viewport (MCP Apps Host)       │
│  • Live Protocol Inspector Panel                       │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ HTTP POST /mcp
                            │ Headers: MCP-Protocol-Version: 2025-11-25
                            │          Accept: application/json, text/event-stream
                            ▼
┌────────────────────────────────────────────────────────┐
│               BeaconOS Python MCP Server               │
│               (FastAPI / Streamable HTTP)              │
│  • Tool Invocation: beacon_locate_phone                │
│  • Multimodal payload generation (ui:// resource)      │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ SQL Insert (status: 'pending')
┌────────────────────────────────────────────────────────┐
│                   Supabase Realtime                    │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ WebSocket (<180ms latency)
┌────────────────────────────────────────────────────────┐
│             BeaconOS Mobile App (Flutter)              │
│  • SoundCue.sosAlarm (100% Volume Acoustic Siren)      │
│  • Camera Flashlight Strobe (10x pulses)               │
│  • High-frequency emergency haptics                    │
└────────────────────────────────────────────────────────┘
```

### 1.2 Evaluation Testbed Specifications

* **Operating Systems:** Linux (Ubuntu 22.04 LTS), macOS Sonoma 14.6, Windows 11.
* **Server Runtime:** Python 3.11+, FastAPI 0.115.0, Uvicorn 0.32.0, Pydantic 2.10.0, official `mcp` SDK (1.3.0+).
* **Protocol Transports Evaluated:** `stdio`, legacy `HTTP+SSE` (`2024-11-05`), and `Streamable HTTP` (`2025-11-25`).
* **Client Implementation:** Vanilla JavaScript browser environment acting as an Echo Show multimodal surface.
* **Database & Realtime Broker:** PostgreSQL 15 via Supabase Realtime replication.
* **Target Mobile Environment:** Android API 34 (Google Pixel) running Flutter 3.24+ with Drift SQLite and custom native MethodChannels.

---

## 2. Transport Layer Friction & Specification Evolution (2024 vs. 2025-11-25)

### 2.1 The Legacy Disconnect: Split Endpoints vs. Single Unified Endpoint

#### Observed Friction

A developer building an MCP integration encounters conflicting documentation and starter samples across community repositories. Early implementations built against specification version `2024-11-05` enforce a split-endpoint pattern:

1. `GET /sse`: Dedicated solely to opening the Server-Sent Events stream and emitting an initial `endpoint` URI event containing a session identifier.
2. `POST /messages?session_id=...`: Used exclusively for sending JSON-RPC requests and notifications.

When upgrading to the hackathon-mandated **Spec 2025-11-25 (Streamable HTTP)**, the architecture shifts fundamentally to a **single unified endpoint path** (e.g., `https://example.com/mcp`) that must service both `GET` and `POST` methods.

#### Technical Pain Point & Reproduction

When using high-level framework wrappers such as `mcp.server.fastmcp.FastMCP` with `transport="sse"`, the server automatically exposes the deprecated split routes (`/sse` and `/messages`). Connecting an Alexa+ simulator expecting the unified `2025-11-25` Streamable HTTP endpoint resulted in:

* `HTTP 405 Method Not Allowed` when issuing `POST /mcp`.
* `HTTP 404 Not Found` when issuing `GET /mcp`.

```text
# Legacy 2024-11-05 Flow (Deprecated):
Client  ─── GET /sse ──────────────────────────► Server (Opens stream, emits session URI)
Server  ─── event: endpoint \n data: /messages ─► Client
Client  ─── POST /messages?session_id=abc ─────► Server (202 Accepted)

# Modern 2025-11-25 Streamable HTTP Flow (Mandatory):
Client  ─── POST /mcp (JSON-RPC) ──────────────► Server (Returns JSON or SSE stream)
Client  ─── GET /mcp (Accept: text/event-stream)► Server (Opens standalone SSE notification channel)
```

#### Resolution & DX Assessment

To comply with the `2025-11-25` standard, we bypassed standard convenience wrappers and engineered explicit FastAPI handlers managing both verbs under `/mcp`:

```python
@app.post("/mcp")
async def handle_streamable_post(request: Request):
    # Validates JSON-RPC payload, processes initialize, tools/list, tools/call
    # Returns application/json response with MCP-Protocol-Version header
    ...

@app.get("/mcp")
async def handle_streamable_get(request: Request):
    # Initiates standalone SSE stream with keep-alive priming comment
    ...
```

*Recommendation for Amazon DevRel:* The official Amazon Devices Builder Tools and Alexa+ documentation should include a migration guide clarifying that `transport="sse"` in existing Python samples represents the deprecated `2024-11-05` standard, and provide starter templates utilizing the unified `/mcp` route.

---

### 2.2 Protocol Version Negotiation & Header Strictness

#### Observed Friction

Specification `2025-11-25` requires that:

1. Clients MUST include the `MCP-Protocol-Version: <protocol-version>` header on requests.
2. Clients issuing `POST` requests MUST supply an `Accept` header indicating support for both `application/json` and `text/event-stream`.
3. If an unrecognized or invalid protocol version is provided, the server MUST return `HTTP 400 Bad Request`.

#### Technical Friction

During early testing with browser-based tools and cURL scripts:

* Omitting `MCP-Protocol-Version` or specifying a format like `v1` or `2024-11-05` triggered unhandled `400 Bad Request` errors.
* Because the error returned at the HTTP gateway level before reaching JSON-RPC validation, testing tools reported empty bodies or generic HTML error pages rather than a standard JSON-RPC error payload (`code: -32600`).

#### Engineering Workaround

In our FastAPI server implementation, we added explicit header negotiation logic with backward-compatibility fallbacks:

```python
SPEC_VERSION = "2025-11-25"

@app.middleware("http")
async def validate_protocol_headers(request: Request, call_next):
    if request.url.path == "/mcp":
        client_version = request.headers.get("MCP-Protocol-Version", SPEC_VERSION)
        # Prevent hard crash on minor version mismatches during local testing
        if client_version not in ["2025-11-25", "2026-01-26"]:
            return JSONResponse(
                status_code=400,
                content={
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32600,
                        "message": f"Unsupported MCP-Protocol-Version: '{client_version}'. Minimum supported is 2025-11-25."
                    }
                }
            )
    response = await call_next(request)
    response.headers["MCP-Protocol-Version"] = SPEC_VERSION
    return response
```

---

### 2.3 DNS Rebinding Protections & Web Simulator CORS Clashes

#### Specification Requirement

The Streamable HTTP specification includes a strict security warning:

> *"Servers MUST validate the Origin header on all incoming connections to prevent DNS rebinding attacks. If the Origin header is present and invalid, servers MUST respond with HTTP 403 Forbidden. When running locally, servers SHOULD bind only to localhost (127.0.0.1) rather than all network interfaces (0.0.0.0)."*

#### Developer Friction

When developing the Alexa+ Web Simulator (`alexa_simulator/index.html`):

1. Serving the web simulator from `http://localhost:3000` while the MCP server ran on `http://127.0.0.1:8000` created cross-origin preflight requests (`OPTIONS /mcp`).
2. Browsers enforce CORS prior to application-level Origin checks. If the server validates Origin strictly per the MCP spec without properly configured CORS preflight handling, browsers fail silently with:
   `Fetch API cannot load http://127.0.0.1:8000/mcp. Response to preflight request doesn't pass access control check.`
3. If the developer runs `alexa_simulator/index.html` via the local filesystem (`file://`), the browser sends `Origin: null`, which triggers `403 Forbidden` under default DNS rebinding validation rules.

#### Resolution Implemented

We resolved this by combining FastAPI's `CORSMiddleware` with explicit header exposure:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000", "null"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["MCP-Protocol-Version", "MCP-Session-Id"],
)
```

*Recommendation for Amazon DevRel:* Provide a pre-configured local development proxy or flag in the Amazon Devices Builder Tools CLI (e.g., `--dev-allow-simulator-origin`) so developers do not have to weaken their server's security posture to test browser-based Echo Show simulators.

---

### 2.4 Session Management, SSE Priming, and Connection Loss

#### Specification Requirement

For stateful sessions, the server MAY assign an `MCP-Session-Id` header during the `initialize` handshake. For SSE streams, the server SHOULD immediately send a priming event with an event ID to allow reconnection via the `Last-Event-ID` header.

#### Observed Friction

1. **Event Priming Deadlocks:** Several client implementations wait indefinitely for a first event before completing the handshake. If a server opens `Content-Type: text/event-stream` on `GET /mcp` but does not immediately yield a comment or priming notification, client timeouts trigger after 5 to 10 seconds.
2. **Silent Disconnections:** When running an Alexa simulator in modern browsers (Chrome/Edge), background tab throttling causes browsers to terminate dormant SSE connections. The specification states that disconnection should not be interpreted as request cancellation, yet clients lacked an automatic reconnection cursor.

#### Resolution Implemented

In our SSE response generator, we implemented immediate keep-alive priming comments and correlation headers:

```python
@app.get("/mcp")
async def handle_streamable_get(request: Request):
    async def sse_event_stream():
        # Prime event required by 2025-11-25 spec
        yield f": keep-alive\n\n"
        init_event = {
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
            "params": {"server": "BeaconOS-MCP", "spec": SPEC_VERSION}
        }
        yield f"data: {json.dumps(init_event)}\n\n"

    headers = {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "MCP-Protocol-Version": SPEC_VERSION
    }
    return StreamingResponse(sse_event_stream(), headers=headers)
```
