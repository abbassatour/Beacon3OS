/**
 * Alexa+ Echo Show Simulator - Client Logic
 * Implements MCP Spec 2025-11-25 (Streamable HTTP Transport)
 */

const SPEC_VERSION = "2025-11-25";

// DOM Elements
const mcpEndpointInput = document.getElementById("mcpEndpointInput");
const logsContainer = document.getElementById("logsContainer");
const echoDisplay = document.getElementById("echoDisplay");
const idleView = document.getElementById("idleView");
const cardViewport = document.getElementById("cardViewport");
const speechOverlay = document.getElementById("speechOverlay");
const alexaSpeechText = document.getElementById("alexaSpeechText");
const lightBar = document.getElementById("lightBar");
const micBtn = document.getElementById("micBtn");
const userInput = document.getElementById("userInput");
const echoClock = document.getElementById("echoClock");
const bigTime = document.getElementById("bigTime");
const bigDate = document.getElementById("bigDate");

let isListening = false;
let speechRecognizer = null;

// Clock Updater
function updateClock() {
  const now = new Date();
  const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  const dateStr = now.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });
  echoClock.textContent = timeStr;
  bigTime.textContent = timeStr;
  bigDate.textContent = dateStr;
}
setInterval(updateClock, 1000);
updateClock();

// ==============================================================================
// 🎙️ SPEECH RECOGNITION & SYNTHESIS
// ==============================================================================

if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  speechRecognizer = new SpeechRecognition();
  speechRecognizer.continuous = false;
  speechRecognizer.interimResults = false;
  speechRecognizer.lang = 'en-US';

  speechRecognizer.onstart = () => {
    isListening = true;
    micBtn.classList.add("listening");
    lightBar.classList.add("active");
  };

  speechRecognizer.onresult = (event) => {
    const transcript = event.results[0][0].transcript;
    userInput.value = transcript;
    processAlexaQuery(transcript);
  };

  speechRecognizer.onend = () => {
    isListening = false;
    micBtn.classList.remove("listening");
  };

  speechRecognizer.onerror = (e) => {
    console.error("Speech Recognition Error:", e);
    isListening = false;
    micBtn.classList.remove("listening");
    lightBar.classList.remove("active");
  };
}

micBtn.addEventListener("click", () => {
  if (!speechRecognizer) {
    alert("Speech recognition is not supported in this browser. Please use Chrome or Edge.");
    return;
  }
  if (isListening) {
    speechRecognizer.stop();
  } else {
    speechRecognizer.start();
  }
});

function speakWithAlexaVoice(text) {
  if ('speechSynthesis' in window) {
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 1.05;
    utterance.pitch = 1.1;
    // اختيار صوت أنثوي طبيعي إن وجد
    const voices = window.speechSynthesis.getVoices();
    const naturalVoice = voices.find(v => v.name.includes("Natural") || v.name.includes("Samantha") || v.name.includes("Google US English"));
    if (naturalVoice) utterance.voice = naturalVoice;
    
    window.speechSynthesis.speak(utterance);
  }
}

// ==============================================================================
// 🚀 MCP STREAMABLE HTTP CLIENT
// ==============================================================================

async function postMcp(payload) {
  const url = mcpEndpointInput.value.trim();
  const requestId = payload.id || `req-${Date.now()}`;
  payload.id = requestId;

  logInspector("req", `POST /mcp (${payload.method})`, payload);

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "MCP-Protocol-Version": SPEC_VERSION
      },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      const errText = await res.text();
      logInspector("err", `HTTP ${res.status}`, errText);
      throw new Error(`MCP Error ${res.status}: ${errText}`);
    }

    const data = await res.json();
    logInspector("res", `JSON-RPC Result (${payload.method})`, data);
    return data;
  } catch (err) {
    logInspector("err", `Network Failure`, { error: err.message });
    throw err;
  }
}

// ==============================================================================
// 🧠 AGENT INTENT DISPATCHER & MULTIMODAL RENDERING
// ==============================================================================

async function processAlexaQuery(rawQuery) {
  const query = rawQuery.trim().toLowerCase();
  lightBar.classList.add("active");

  showAlexaSpeech("Analyzing living room request...");

  let toolName = "beacon_get_daily_briefing";
  let toolArgs = {};

  if (query.includes("find") || query.includes("locate") || query.includes("where is my phone")) {
    toolName = "beacon_locate_phone";
    toolArgs = { reason: "Alexa living room query: " + rawQuery };
  } else if (query.includes("sos") || query.includes("emergency") || query.includes("help")) {
    toolName = "beacon_trigger_emergency_sos";
    toolArgs = { emergency_type: "hands_free_living_room", notes: rawQuery };
  } else if (query.includes("battery") || query.includes("telemetry") || query.includes("status")) {
    toolName = "beacon_get_device_telemetry";
    toolArgs = {};
  } else if (query.includes("task") || query.includes("remind") || query.includes("add")) {
    toolName = "beacon_create_task";
    const cleanTitle = rawQuery.replace(/alexa,?\s*(add task|remind me to|create task)/i, "").trim() || "Living Room Task";
    toolArgs = { title: cleanTitle, priority: "high" };
  }

  try {
    // 1. استدعاء الأداة عبر مواصفة Streamable HTTP
    const rpcResponse = await postMcp({
      jsonrpc: "2.0",
      method: "tools/call",
      params: {
        name: toolName,
        arguments: toolArgs
      }
    });

    const content = rpcResponse.result?.content || [];
    let speech = "Action executed.";
    let uiCard = null;

    for (const item of content) {
      if (item.type === "text") speech = item.text;
      if (item.type === "resource") uiCard = item.resource?.data;
    }

    // 2. نطق الاستجابة وعرض شريط الصوت
    showAlexaSpeech(speech);
    speakWithAlexaVoice(speech);

    // 3. عرض بطاقة الـ MCP Apps المناسبة
    renderMcpAppCard(uiCard, toolName);

  } catch (err) {
    showAlexaSpeech("Could not connect to the Beacon MCP server. Check endpoint.");
  } finally {
    setTimeout(() => {
      lightBar.classList.remove("active");
    }, 2500);
  }
}

function showAlexaSpeech(text) {
  speechOverlay.style.display = "flex";
  alexaSpeechText.textContent = text;
}

function renderMcpAppCard(cardData, toolName) {
  if (!cardData) return;

  idleView.style.display = "none";
  cardViewport.style.display = "block";

  if (cardData.type === "radar_locator") {
    cardViewport.innerHTML = `
      <div class="mcp-card">
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <div>
            <h2 style="font-size:20px; font-weight:900; color:var(--alexa-cyan);">ACOUSTIC BEACON LOCATOR</h2>
            <p style="color:var(--text-muted); font-size:12px;">Active ping dispatched to BeaconOS hardware</p>
          </div>
          <span style="background:rgba(0,210,255,0.15); color:var(--alexa-cyan); padding:4px 10px; border-radius:12px; font-weight:800; font-size:11px;">
            STREAMING HARDWARE
          </span>
        </div>

        <div class="radar-box">
          <div class="radar-circle">
            <div class="radar-pulse-ring"></div>
            <div class="phone-icon-center">📱</div>
          </div>
        </div>

        <div class="mcp-meta-grid">
          <div class="meta-cell">
            <div class="meta-title">SIREN VOLUME</div>
            <div class="meta-val" style="color:var(--warning-yellow);">100% MAXIMUM</div>
          </div>
          <div class="meta-cell">
            <div class="meta-title">CAMERA TORCH</div>
            <div class="meta-val" style="color:var(--alexa-cyan);">STROBE ACTIVE</div>
          </div>
          <div class="meta-cell">
            <div class="meta-title">HAPTICS PULSE</div>
            <div class="meta-val">EMERGENCY TACTILE</div>
          </div>
        </div>
      </div>
    `;
  } else if (cardData.type === "emergency_dashboard") {
    cardViewport.innerHTML = `
      <div class="mcp-card emergency">
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <div>
            <span class="emergency-badge">DISTRESS SIGNAL ACTIVE</span>
            <h2 style="font-size:22px; font-weight:900; margin-top:8px;">EMERGENCY SOS BROADCAST</h2>
          </div>
          <div style="font-size:32px;">🚨</div>
        </div>

        <div style="background:rgba(255,51,75,0.1); border:1px solid var(--danger-crimson); padding:16px; border-radius:14px;">
          <div style="font-size:11px; font-weight:900; color:var(--danger-crimson); letter-spacing:1px;">COORDINATES DISPATCHED</div>
          <div style="font-size:20px; font-weight:900; margin:4px 0;">${cardData.coordinates}</div>
          <p style="font-size:12px; color:var(--text-muted);">Family rescue radar alerted with live GPS track.</p>
        </div>
      </div>
    `;
  } else if (cardData.type === "telemetry_gauge") {
    cardViewport.innerHTML = `
      <div class="mcp-card">
        <h2 style="font-size:20px; font-weight:900;">BEACON DEVICE TELEMETRY</h2>
        <div style="display:flex; align-items:center; gap:20px; margin:10px 0;">
          <div style="font-size:48px; font-weight:900; color:var(--success-green);">${cardData.battery_level}%</div>
          <div>
            <div style="font-size:16px; font-weight:800;">${cardData.profile}</div>
            <div style="font-size:12px; color:var(--text-muted);">${cardData.connection}</div>
          </div>
        </div>
      </div>
    `;
  } else {
    cardViewport.innerHTML = `
      <div class="mcp-card">
        <h2 style="font-size:20px; font-weight:900; color:var(--alexa-cyan);">BEACON AGENDA</h2>
        <p style="font-size:16px; margin-top:10px;">${JSON.stringify(cardData)}</p>
      </div>
    `;
  }
}

// ==============================================================================
// 📋 INSPECTOR LOGGING
// ==============================================================================

function logInspector(type, title, payload) {
  const entry = document.createElement("div");
  entry.className = `log-entry ${type}`;
  const time = new Date().toLocaleTimeString();

  entry.innerHTML = `
    <div class="log-head">
      <span class="log-tag ${type}">[${type.toUpperCase()}] ${title}</span>
      <span class="log-time">${time}</span>
    </div>
    <pre class="json-payload">${typeof payload === 'string' ? payload : JSON.stringify(payload, null, 2)}</pre>
  `;

  logsContainer.appendChild(entry);
  logsContainer.scrollTop = logsContainer.scrollHeight;
}

function clearLogs() {
  logsContainer.innerHTML = "";
}

function sendPreset(text) {
  userInput.value = text;
  processAlexaQuery(text);
}

function handleFormSubmit(e) {
  e.preventDefault();
  const val = userInput.value.trim();
  if (val) processAlexaQuery(val);
}