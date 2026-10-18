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
  if (echoClock) echoClock.textContent = timeStr;
  if (bigTime) bigTime.textContent = timeStr;
  if (bigDate) bigDate.textContent = dateStr;
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
    if (micBtn) micBtn.classList.add("listening");
    if (lightBar) lightBar.classList.add("active");
  };

  speechRecognizer.onresult = (event) => {
    const transcript = event.results[0][0].transcript;
    if (userInput) userInput.value = transcript;
    processAlexaQuery(transcript);
  };

  speechRecognizer.onend = () => {
    isListening = false;
    if (micBtn) micBtn.classList.remove("listening");
  };

  speechRecognizer.onerror = (e) => {
    console.error("Speech Recognition Error:", e);
    isListening = false;
    if (micBtn) micBtn.classList.remove("listening");
    if (lightBar) lightBar.classList.remove("active");
  };
}

if (micBtn) {
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
}

function speakWithAlexaVoice(text) {
  if ('speechSynthesis' in window) {
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 1.05;
    utterance.pitch = 1.1;
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
  if (lightBar) lightBar.classList.add("active");

  showAlexaSpeech("Analyzing living room request...");

  let toolName = "beacon_get_daily_briefing";
  let toolArgs = {};

  // 1. فحص الهاتف والصفارة
  if (query.includes("find") || query.includes("locate") || query.includes("where is my phone")) {
    toolName = "beacon_locate_phone";
    toolArgs = { reason: "Alexa living room query: " + rawQuery };
  }
  // 2. استغاثة الطوارئ SOS
  else if (query.includes("sos") || query.includes("emergency") || query.includes("help")) {
    toolName = "beacon_trigger_emergency_sos";
    toolArgs = { emergency_type: "hands_free_living_room", notes: rawQuery };
  }
  // 3. حالة البطارية والعتاد
  else if (query.includes("battery") || query.includes("telemetry") || query.includes("power")) {
    toolName = "beacon_get_device_telemetry";
    toolArgs = {};
  }
  // 4. محاكاة سيناريوهات كاميرات Ring
  else if (query.includes("simulate") || query.includes("courier") || query.includes("package") || query.includes("prowler") || query.includes("intruder") || query.includes("baby") || query.includes("neighbor")) {
    toolName = "beacon_simulate_ring_scenario";
    let scenario = "courier_delivery";
    if (query.includes("prowler") || query.includes("cat") || query.includes("intruder") || query.includes("night")) {
      scenario = "night_prowler";
    } else if (query.includes("baby") || query.includes("crying") || query.includes("nursery")) {
      scenario = "baby_crying";
    } else if (query.includes("car") || query.includes("driveway") || query.includes("garage")) {
      scenario = "car_arriving";
    } else if (query.includes("neighbor") || query.includes("sarah")) {
      scenario = "friendly_neighbor";
    }
    toolArgs = { scenario: scenario };
  }
  // 5. فحص كاميرات Ring المحيطية المباشر
  else if (query.includes("camera") || query.includes("doorbell") || query.includes("front door") || query.includes("porch") || query.includes("who is at")) {
    toolName = "beacon_inspect_ring_camera";
    let cam = "Front Door";
    if (query.includes("backyard") || query.includes("garden")) cam = "Backyard";
    if (query.includes("nursery") || query.includes("crib")) cam = "Nursery";
    if (query.includes("garage") || query.includes("driveway")) cam = "Garage Driveway";
    toolArgs = { camera_name: cam };
  }
  // 6. إضافة مهمة جديدة للأجندة
  else if (query.includes("task") || query.includes("remind") || query.includes("add")) {
    toolName = "beacon_create_task";
    const cleanTitle = rawQuery.replace(/alexa,?\s*(add task|remind me to|create task|add)/i, "").trim() || "Living Room Task";
    toolArgs = { title: cleanTitle, priority: "high" };
  }
  // 7. الملخص الصباحي الشامل
  else if (query.includes("briefing") || query.includes("agenda") || query.includes("schedule") || query.includes("overview")) {
    toolName = "beacon_get_daily_briefing";
    toolArgs = {};
  }

  try {
    // استدعاء الأداة عبر مواصفة Streamable HTTP
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

    showAlexaSpeech(speech);
    speakWithAlexaVoice(speech);

    renderMcpAppCard(uiCard, toolName);

  } catch (err) {
    showAlexaSpeech("Could not connect to the Beacon MCP server. Check endpoint.");
  } finally {
    setTimeout(() => {
      if (lightBar) lightBar.classList.remove("active");
    }, 2500);
  }
}

function showAlexaSpeech(text) {
  if (speechOverlay) speechOverlay.style.display = "flex";
  if (alexaSpeechText) alexaSpeechText.textContent = text;
}

// ==============================================================================
// 📺 MULTIMODAL UI CARD RENDERING (ECHO SHOW CANVAS)
// ==============================================================================

function renderMcpAppCard(cardData, toolName) {
  if (!cardData) return;

  if (idleView) idleView.style.display = "none";
  if (cardViewport) cardViewport.style.display = "block";

  // 1. بطاقة رادار العثور على الهاتف
  if (cardData.type === "radar_locator") {
    cardViewport.innerHTML = `
      <div class="mcp-card">
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <div>
            <h2 style="font-size:20px; font-weight:900; color:var(--alexa-cyan);">ACOUSTIC BEACON LOCATOR</h2>
            <p style="color:var(--text-muted); font-size:12px;">Active ping dispatched to BeaconOS hardware</p>
          </div>
          <span style="background:rgba(0,210,255,0.15); color:var(--alexa-cyan); padding:4px 10px; border-radius:12px; font-weight:800; font-size:11px;">
            HARDWARE DISPATCHED
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
  }
  // 2. بطاقة طوارئ SOS الرادارية
  else if (cardData.type === "emergency_dashboard") {
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
          <p style="font-size:12px; color:var(--text-muted);">Family rescue radar alerted with tamper-proof GPS beacon on Arbitrum Sepolia ledger.</p>
        </div>
      </div>
    `;
  }
  // 3. بطاقة مقياس البطارية والعتاد
  else if (cardData.type === "telemetry_gauge") {
    cardViewport.innerHTML = `
      <div class="mcp-card">
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <div>
            <h2 style="font-size:20px; font-weight:900;">BEACON DEVICE TELEMETRY</h2>
            <p style="color:var(--text-muted); font-size:12px;">Real-time hardware status via P2P relay</p>
          </div>
          <span style="background:rgba(0,230,118,0.15); color:var(--success-green); padding:4px 10px; border-radius:12px; font-weight:800; font-size:11px;">
            ONLINE
          </span>
        </div>

        <div style="display:flex; align-items:center; gap:20px; margin:14px 0;">
          <div style="font-size:52px; font-weight:900; color:var(--success-green); line-height:1;">${cardData.battery_level}%</div>
          <div>
            <div style="font-size:17px; font-weight:800;">${cardData.profile}</div>
            <div style="font-size:12px; color:var(--text-muted); margin-top:2px;">Display: ${cardData.high_contrast}</div>
          </div>
        </div>

        <div class="mcp-meta-grid">
          <div class="meta-cell">
            <div class="meta-title">LATENCY</div>
            <div class="meta-val" style="color:var(--success-green);">&lt; 2ms (LAN)</div>
          </div>
          <div class="meta-cell">
            <div class="meta-title">TRANSPORT</div>
            <div class="meta-val">HYBRID P2P</div>
          </div>
          <div class="meta-cell">
            <div class="meta-title">VAULT</div>
            <div class="meta-val">ENCRYPTED</div>
          </div>
        </div>
      </div>
    `;
  }
  // 4. بطاقة الأجندة والملخص الصباحي
  else if (cardData.type === "daily_agenda") {
    const tasks = cardData.tasks || [];
    cardViewport.innerHTML = `
      <div class="mcp-card">
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <div>
            <h2 style="font-size:20px; font-weight:900; color:var(--alexa-cyan);">TODAY AGENDA & PRIORITIES</h2>
            <p style="color:var(--text-muted); font-size:12px;">Real-time sync with BeaconOS phone vault</p>
          </div>
          <span style="background:rgba(0,210,255,0.15); color:var(--alexa-cyan); padding:4px 10px; border-radius:12px; font-weight:800; font-size:11px;">
            ${cardData.tasks_count || 0} PENDING
          </span>
        </div>

        <div style="background:rgba(255,255,255,0.03); border:1px solid var(--card-border); padding:12px 16px; border-radius:14px; display:flex; align-items:center; gap:12px;">
          <div style="font-size:22px;">⏰</div>
          <div>
            <div style="font-size:10px; font-weight:800; color:var(--text-muted); letter-spacing:0.8px;">NEXT ALARM</div>
            <div style="font-size:14px; font-weight:800; color:var(--text-main);">${cardData.next_alarm || "No active alarms"}</div>
          </div>
        </div>

        <div style="display:flex; flex-direction:column; gap:8px;">
          ${tasks.length > 0 ? tasks.map(t => `
            <div style="background:rgba(255,255,255,0.02); border:1px solid rgba(255,255,255,0.05); padding:10px 14px; border-radius:10px; display:flex; justify-content:space-between; align-items:center;">
              <span style="font-size:14px; font-weight:700; color:var(--text-main);">${t.title}</span>
              <span style="font-size:10px; font-weight:900; color:${t.priority === 'high' ? 'var(--danger-crimson)' : 'var(--warning-yellow)'}; background:rgba(255,255,255,0.05); padding:2px 8px; border-radius:6px;">${(t.priority || 'medium').toUpperCase()}</span>
            </div>
          `).join('') : `
            <div style="padding:14px; text-align:center; color:var(--text-muted); font-size:13px;">Zero pending priorities! Agenda is completely clear.</div>
          `}
        </div>
      </div>
    `;
  }
  // 5. بطاقة تأكيد إضافة المهمة
  else if (cardData.type === "task_confirmation") {
    cardViewport.innerHTML = `
      <div class="mcp-card">
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <div>
            <span style="background:rgba(0,230,118,0.15); color:var(--success-green); padding:4px 10px; border-radius:12px; font-weight:800; font-size:11px;">
              SAVED TO BEACON VAULT
            </span>
            <h2 style="font-size:22px; font-weight:900; margin-top:8px;">${cardData.task_title}</h2>
          </div>
          <div style="font-size:36px; color:var(--success-green);">✅</div>
        </div>

        <div class="mcp-meta-grid" style="margin-top:10px;">
          <div class="meta-cell">
            <div class="meta-title">PRIORITY</div>
            <div class="meta-val" style="color:${cardData.priority === 'high' ? 'var(--danger-crimson)' : 'var(--warning-yellow)'};">${(cardData.priority || 'medium').toUpperCase()}</div>
          </div>
          <div class="meta-cell">
            <div class="meta-title">SYNC STATUS</div>
            <div class="meta-val" style="color:var(--success-green);">INSTANT DRIFT &amp; CLOUD</div>
          </div>
          <div class="meta-cell">
            <div class="meta-title">CHANNEL</div>
            <div class="meta-val">ALEXA+ LIVING ROOM</div>
          </div>
        </div>
      </div>
    `;
  }
  // 6. بطاقة بث كاميرا Ring المباشر
  else if (cardData.type === "ring_camera_feed") {
    cardViewport.innerHTML = `
      <div class="mcp-card">
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <div>
            <span style="background:rgba(0,210,255,0.15); color:var(--alexa-cyan); padding:4px 10px; border-radius:12px; font-weight:800; font-size:11px;">
              ${cardData.status || "LIVE • GEMINI 2.0 INSPECTED"}
            </span>
            <h2 style="font-size:22px; font-weight:900; margin-top:8px;">${cardData.title || cardData.camera_name}</h2>
          </div>
          <div style="font-size:32px;">📹</div>
        </div>

        <div style="background:rgba(0,0,0,0.5); border:1px solid var(--card-border); padding:18px; border-radius:16px;">
          <div style="display:flex; align-items:center; gap:8px; margin-bottom:8px;">
            <div style="width:10px; height:10px; border-radius:50%; background:var(--success-green); box-shadow:0 0 8px var(--success-green);"></div>
            <span style="font-size:11px; font-weight:800; color:var(--text-muted);">PERIMETER CLEAR</span>
          </div>
          <p style="font-size:15px; font-weight:600; line-height:1.45; color:var(--text-main);">${cardData.description}</p>
        </div>

        <div class="mcp-meta-grid">
          <div class="meta-cell">
            <div class="meta-title">CAMERA SENSOR</div>
            <div class="meta-val">RING HD VIDEO</div>
          </div>
          <div class="meta-cell">
            <div class="meta-title">AI ENGINE</div>
            <div class="meta-val" style="color:var(--alexa-cyan);">GEMINI 2.0 FLASH</div>
          </div>
          <div class="meta-cell">
            <div class="meta-title">AREA HAZARDS</div>
            <div class="meta-val" style="color:var(--success-green);">ZERO DETECTED</div>
          </div>
        </div>
      </div>
    `;
  }
  // 7. بطاقة محاكاة أحداث Ring ووصول الطرود
  else if (cardData.type === "ring_event_simulation") {
    cardViewport.innerHTML = `
      <div class="mcp-card" style="border-color:var(--warning-yellow); box-shadow:0 0 35px rgba(255,214,0,0.15);">
        <div style="display:flex; justify-content:space-between; align-items:center;">
          <div>
            <span style="background:rgba(255,214,0,0.15); color:var(--warning-yellow); padding:4px 10px; border-radius:12px; font-weight:900; font-size:11px;">
              RING EVENT DISPATCHED
            </span>
            <h2 style="font-size:22px; font-weight:900; margin-top:8px;">${cardData.title || "DOORBELL ALERT"}</h2>
          </div>
          <div style="font-size:36px;">🔔</div>
        </div>

        <div style="background:rgba(255,214,0,0.06); border:1px solid rgba(255,214,0,0.3); padding:18px; border-radius:16px;">
          <div style="font-size:11px; font-weight:900; color:var(--warning-yellow); letter-spacing:1px; margin-bottom:4px;">SCENARIO • ${(cardData.scenario || 'ACTIVITY').toUpperCase()}</div>
          <p style="font-size:15px; font-weight:700; color:var(--text-main); line-height:1.4;">${cardData.description}</p>
          <div style="margin-top:10px; font-size:12px; color:var(--text-muted); display:flex; align-items:center; gap:6px;">
            <span>📺</span> Alert banner &amp; audio chime dispatched to Beacon phone &amp; Fire TV.
          </div>
        </div>
      </div>
    `;
  }
  // 8. الحالة العامة الاحتياطية
  else {
    cardViewport.innerHTML = `
      <div class="mcp-card">
        <h2 style="font-size:20px; font-weight:900; color:var(--alexa-cyan);">${cardData.title || "BEACON RESPONSE"}</h2>
        <p style="font-size:15px; margin-top:10px; color:var(--text-main);">${cardData.description || "Action executed successfully on BeaconOS."}</p>
      </div>
    `;
  }
}

// ==============================================================================
// 📋 INSPECTOR LOGGING
// ==============================================================================

function logInspector(type, title, payload) {
  if (!logsContainer) return;
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
  if (logsContainer) logsContainer.innerHTML = "";
}

function sendPreset(text) {
  if (userInput) userInput.value = text;
  processAlexaQuery(text);
}

function handleFormSubmit(e) {
  e.preventDefault();
  if (!userInput) return;
  const val = userInput.value.trim();
  if (val) processAlexaQuery(val);
}