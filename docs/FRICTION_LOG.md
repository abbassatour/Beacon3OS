
# BeaconOS x Alexa+ MCP Developer Friction Log (Executive Summary)

> Submission for Amazon Developer Hackathon -- Evaluated for the 10% Friction Log Bonus
> Full 3-Part Deep-Dive Documentation available in the repository:
>
> - Part 1: Architecture, Test Harness & Streamable HTTP Transport (Located at docs/friction_log/01_architecture_and_transport.md)
> - Part 2: Multimodal Surface (Echo Show / MCP Apps) & Hardware Latency (Located at docs/friction_log/02_multimodal_and_latency.md)
> - Part 3: AWS Bedrock Integration, Tool Ergonomics & Recommendations (Located at docs/friction_log/03_aws_and_recommendations.md)

---

### Structured Friction Log Entries (6 Required Criteria)

#### 1. Streamable HTTP Unified Route (/mcp) vs. Deprecated Split Routes (/sse)

- **Specific Task Attempted:** Connect Alexa+ simulator to our self-hosted Python MCP server using Spec 2025-11-25.
- **Steps Taken:** Implemented mcp.server.fastmcp.FastMCP with transport="sse" and dispatched POST /mcp.
- **Expected vs. Actual Result:** Expected unified JSON-RPC handling. Actual result: HTTP 405 / 404 errors due to SDK wrappers defaulting to legacy split routes (/sse and /messages).
- **Severity Rating:** High (Blocks modern protocol adoption).
- **Workaround Used:** Bypassed wrappers and implemented custom FastAPI handlers for unified /mcp (POST for JSON-RPC and GET for SSE).
- **Actionable Suggestion:** Publish official Amazon starter templates explicitly detailing the unified /mcp route under Spec 2025-11-25.

#### 2. DNS Rebinding Protections vs. Local Web Simulator CORS

- **Specific Task Attempted:** Test living room Echo Show simulator (localhost:3000) against local MCP server (127.0.0.1:8000/mcp).
- **Steps Taken:** Issued cross-origin JSON-RPC requests containing MCP-Protocol-Version: 2025-11-25.
- **Expected vs. Actual Result:** Expected smooth local preflight. Actual: CORS preflight clashes, and loading via local filesystem sent Origin: null, triggering HTTP 403 Forbidden under DNS rebinding rules.
- **Severity Rating:** Medium (High local development friction).
- **Workaround Used:** Implemented custom FastAPI CORSMiddleware explicitly exposing protocol headers and whitelisting local origins.
- **Actionable Suggestion:** Add a --dev-allow-simulator-origin flag in Amazon Devices Builder Tools CLI for local prototyping.

#### 3. Standard Multimodal Component Runtimes (MCP Apps ui://)

- **Specific Task Attempted:** Render an interactive radar card on an Echo Show smart display when Alexa locates a misplaced phone.
- **Steps Taken:** Implemented MCP Apps pattern returning compound payloads (text for TTS + resource with ui:// metadata).
- **Expected vs. Actual Result:** Expected native Echo Show container rendering. Actual: Existing hosts lack an Echo Show runtime for ui:// resources, causing audio-visual desync between instant DOM rendering and delayed Web Speech buffer warmup.
- **Severity Rating:** High (Multimodal UX barrier).
- **Workaround Used:** Built a custom Vanilla JS Echo Show renderer with manual animation priming buffers in app.js.
- **Actionable Suggestion:** Release an official @amazon/echo-show-ui web component kit with standard Alexa cyan ring animations and WCAG AAA contrast modes.

#### 4. AWS Bedrock Converse API vs. MCP Tool Schema Divergence

- **Specific Task Attempted:** Integrate Amazon Bedrock Converse API (Claude 3.5 Sonnet / Nova) to autonomously orchestrate BeaconOS MCP tools.
- **Steps Taken:** Passed MCP tools/list payloads directly into Bedrock Converse API tool configuration.
- **Expected vs. Actual Result:** Schema rejected. MCP wraps parameters in inputSchema, whereas Bedrock strictly expects toolSpec with input.json.
- **Severity Rating:** Medium (Brittle translation boilerplate).
- **Workaround Used:** Built a dynamic Python schema converter mapping MCP JSON Schema envelopes to Bedrock toolSpec at runtime.
- **Actionable Suggestion:** Add native MCP-to-Bedrock conversion utilities in AWS SDK (boto3 / JS SDK).

#### 5. Lack of Native Out-of-Band IoT Hardware Push in MCP

- **Specific Task Attempted:** Actuate a physical phone (3000Hz siren and strobe) from a living room Alexa prompt in under 200ms.
- **Steps Taken:** Dispatched MCP tool call and attempted to actuate device directly over protocol stream.
- **Expected vs. Actual Result:** MCP is client-to-server only; it lacks a native downstream actuation/push mechanism for physical IoT devices.
- **Severity Rating:** High (Assistive emergency use cases require deterministic, low-latency actuation).
- **Workaround Used:** Engineered an external state pipeline (FastAPI writes pending action to PostgreSQL, phone executes via Supabase Realtime WebSocket in ~158ms).
- **Actionable Suggestion:** Standardize an optional MCP Device Transport Profile (e.g., downstream device callback URLs or push events) within the MCP specification.
