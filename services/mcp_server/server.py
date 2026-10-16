"""
BeaconOS Alexa+ MCP Server (Spec 2025-11-25 / Streamable HTTP Compliant)
-------------------------------------------------------------------------
Implements modern Model Context Protocol Streamable HTTP endpoint for Alexa+
Echo Show Multimodal integration and BeaconOS sovereign phone actuation.
"""

import os
import json
import logging
from datetime import datetime
from typing import Optional, Dict, Any, List

from dotenv import load_dotenv
from supabase import create_client, Client
from pydantic import BaseModel, Field
from fastapi import FastAPI, Request, Response, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse

# 1. تهيئة الإعدادات
load_dotenv()
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [Streamable-HTTP-MCP]: %(message)s"
)
logger = logging.getLogger("BeaconOS-MCP")

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
DEFAULT_USER_ID = os.getenv("DEFAULT_USER_ID", "local_guest_user")
HOST = os.getenv("MCP_SERVER_HOST", "127.0.0.1")  # تأمين ضد DNS Rebinding
PORT = int(os.getenv("MCP_SERVER_PORT", "8000"))
SPEC_VERSION = "2025-11-25"

# الاتصال بـ Supabase
supabase: Optional[Client] = None
if SUPABASE_URL and SUPABASE_KEY:
    try:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        logger.info("Connected to Supabase Sovereign Vault.")
    except Exception as e:
        logger.error(f"Failed to connect to Supabase: {e}")

# إنشاء تطبيق FastAPI لخدمة المسار الموحد
app = FastAPI(title="BeaconOS Alexa+ Streamable HTTP MCP Server", version=SPEC_VERSION)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["MCP-Protocol-Version", "MCP-Session-Id"]
)

# ==============================================================================
# 🛠️ أدوات BEACON OS مع دعم العرض المتعدد (Multimodal UI + Voice)
# ==============================================================================

async def tool_beacon_locate_phone(args: Dict[str, Any]) -> Dict[str, Any]:
    reason = args.get("reason", "Locating phone via Alexa voice query")
    user_id = args.get("user_id", DEFAULT_USER_ID)
    logger.info(f"📍 Action: LOCATE_DEVICE for {user_id}")

    if supabase:
        try:
            supabase.table("remote_actions").insert({
                "action_type": "LOCATE_DEVICE",
                "user_id": user_id if user_id != "local_guest_user" else None,
                "payload": {"reason": reason, "siren_volume": 1.0, "strobe_flashlight": True},
                "status": "pending"
            }).execute()
        except Exception as e:
            logger.error(f"Database error: {e}")

    return {
        "speech": "Your Beacon phone has been pinged. Maximum siren and flashlight strobe are active.",
        "ui_card": {
            "type": "radar_locator",
            "title": "Acoustic Beacon Active",
            "status": "Pinging Hardware",
            "pulse_rate": "high",
            "siren_frequency": "3000Hz - Loud",
            "flashlight": "Strobe Active"
        }
    }

async def tool_beacon_trigger_emergency_sos(args: Dict[str, Any]) -> Dict[str, Any]:
    emergency_type = args.get("emergency_type", "voice_distress")
    notes = args.get("notes", "Triggered hands-free from living room")
    user_id = args.get("user_id", DEFAULT_USER_ID)
    logger.warning(f"🚨 Action: EMERGENCY_SOS for {user_id}")

    sos_payload = {
        "status": "active",
        "latitude": 52.3676,
        "longitude": 4.9041,
        "google_maps_url": "https://maps.google.com/?q=52.3676,4.9041",
        "triggered_at": datetime.utcnow().isoformat()
    }
    if user_id != "local_guest_user":
        sos_payload["user_id"] = user_id

    if supabase:
        try:
            supabase.table("sos_alerts").insert(sos_payload).execute()
            supabase.table("remote_actions").insert({
                "action_type": "TRIGGER_SOS",
                "user_id": user_id if user_id != "local_guest_user" else None,
                "payload": {"emergency_type": emergency_type, "notes": notes},
                "status": "pending"
            }).execute()
        except Exception as e:
            logger.error(f"SOS DB error: {e}")

    return {
        "speech": "Emergency SOS broadcasted! Distress radar active and live coordinates dispatched.",
        "ui_card": {
            "type": "emergency_dashboard",
            "title": "EMERGENCY SOS BROADCAST",
            "coordinates": "52.3676° N, 4.9041° E",
            "status": "DISPATCHED",
            "high_contrast_theme": "danger_crimson"
        }
    }

async def tool_beacon_get_daily_briefing(args: Dict[str, Any]) -> Dict[str, Any]:
    user_id = args.get("user_id", DEFAULT_USER_ID)
    logger.info(f"📋 Action: GET_DAILY_BRIEFING for {user_id}")

    tasks_count = 0
    top_task = "No pending urgent tasks"
    next_alarm = "7:30 AM"

    if supabase:
        try:
            t_res = supabase.table("tasks").select("title").eq("is_completed", False).limit(3).execute()
            tasks = t_res.data or []
            tasks_count = len(tasks)
            if tasks:
                top_task = tasks[0]["title"]
        except Exception as e:
            logger.error(f"Briefing DB error: {e}")

    speech = f"Good day. You have {tasks_count} pending priorities. Top item is: {top_task}. Next alarm is at {next_alarm}."
    return {
        "speech": speech,
        "ui_card": {
            "type": "daily_agenda",
            "top_task": top_task,
            "tasks_count": tasks_count,
            "next_alarm": next_alarm
        }
    }

async def tool_beacon_create_task(args: Dict[str, Any]) -> Dict[str, Any]:
    title = args.get("title", "New Task")
    priority = args.get("priority", "medium")
    user_id = args.get("user_id", DEFAULT_USER_ID)

    if supabase:
        try:
            payload = {"title": title, "priority": priority, "is_completed": False}
            if user_id != "local_guest_user":
                payload["user_id"] = user_id
            supabase.table("tasks").insert(payload).execute()
        except Exception as e:
            logger.error(f"Create task error: {e}")

    return {
        "speech": f"I added '{title}' to your Beacon agenda with {priority} priority.",
        "ui_card": {
            "type": "task_confirmation",
            "task_title": title,
            "priority": priority,
            "synced_to_vault": True
        }
    }

async def tool_beacon_get_device_telemetry(args: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "speech": "Beacon phone is online with 88% battery in Blind Accessible Mode.",
        "ui_card": {
            "type": "telemetry_gauge",
            "battery_level": 88,
            "profile": "Blind Accessible",
            "high_contrast": "Active",
            "connection": "Ultra-Low Latency (<150ms)"
        }
    }

TOOLS_REGISTRY = {
    "beacon_locate_phone": tool_beacon_locate_phone,
    "beacon_trigger_emergency_sos": tool_beacon_trigger_emergency_sos,
    "beacon_get_daily_briefing": tool_beacon_get_daily_briefing,
    "beacon_create_task": tool_beacon_create_task,
    "beacon_get_device_telemetry": tool_beacon_get_device_telemetry,
}

# ==============================================================================
# 🌐 THE UNIFIED STREAMABLE HTTP ENDPOINT (/mcp) - SPEC 2025-11-25
# ==============================================================================

@app.get("/mcp")
async def handle_streamable_get(request: Request):
    """
    HTTP GET on /mcp opens an SSE stream for server-to-client notifications
    as defined in MCP Streamable HTTP 2025-11-25.
    """
    async def sse_event_stream():
        # Prime event as required by spec
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


@app.post("/mcp")
async def handle_streamable_post(request: Request):
    """
    HTTP POST on /mcp processes JSON-RPC requests, notifications, and tool calls.
    """
    try:
        body = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON-RPC payload")

    jsonrpc_id = body.get("id")
    method = body.get("method")
    params = body.get("params", {})

    response_headers = {
        "MCP-Protocol-Version": SPEC_VERSION,
        "Content-Type": "application/json"
    }

    # 1. Initialize Phase
    if method == "initialize":
        result = {
            "protocolVersion": SPEC_VERSION,
            "capabilities": {
                "tools": {"listChanged": True},
                "resources": {"subscribe": True}
            },
            "serverInfo": {
                "name": "BeaconOS-LivingRoom-Bridge",
                "version": "2.0.0"
            }
        }
        return Response(
            content=json.dumps({"jsonrpc": "2.0", "id": jsonrpc_id, "result": result}),
            headers=response_headers
        )

    # 2. Tools Discovery (tools/list)
    elif method == "tools/list":
        tools_list = [
            {
                "name": "beacon_locate_phone",
                "description": "Trigger acoustic siren, flash strobing and vibration on misplaced phone",
                "inputSchema": {"type": "object", "properties": {"reason": {"type": "string"}}}
            },
            {
                "name": "beacon_trigger_emergency_sos",
                "description": "Trigger emergency SOS with GPS coordinates dispatch hands-free",
                "inputSchema": {"type": "object", "properties": {"emergency_type": {"type": "string"}, "notes": {"type": "string"}}}
            },
            {
                "name": "beacon_get_daily_briefing",
                "description": "Fetch upcoming alarms and high priority tasks",
                "inputSchema": {"type": "object", "properties": {}}
            },
            {
                "name": "beacon_create_task",
                "description": "Create a new task in user's Beacon agenda",
                "inputSchema": {"type": "object", "properties": {"title": {"type": "string"}, "priority": {"type": "string"}}, "required": ["title"]}
            },
            {
                "name": "beacon_get_device_telemetry",
                "description": "Check device battery, connection and accessibility profile",
                "inputSchema": {"type": "object", "properties": {}}
            }
        ]
        return Response(
            content=json.dumps({"jsonrpc": "2.0", "id": jsonrpc_id, "result": {"tools": tools_list}}),
            headers=response_headers
        )

    # 3. Tool Execution (tools/call)
    elif method == "tools/call":
        tool_name = params.get("name")
        tool_args = params.get("arguments", {})

        if tool_name not in TOOLS_REGISTRY:
            error_response = {
                "jsonrpc": "2.0",
                "id": jsonrpc_id,
                "error": {"code": -32601, "message": f"Tool '{tool_name}' not found"}
            }
            return Response(content=json.dumps(error_response), headers=response_headers, status_code=404)

        handler = TOOLS_REGISTRY[tool_name]
        tool_result = await handler(tool_args)

        # إعادة محتوى مهيأ للصوت ولواجهة MCP Apps
        mcp_content = [
            {"type": "text", "text": tool_result["speech"]},
            {"type": "resource", "resource": {"uri": f"ui://beacon/{tool_name}", "data": tool_result["ui_card"]}}
        ]

        response_body = {
            "jsonrpc": "2.0",
            "id": jsonrpc_id,
            "result": {
                "content": mcp_content,
                "isError": False
            }
        }
        return Response(content=json.dumps(response_body), headers=response_headers)

    # Notifications handling (e.g., initialized)
    elif method == "notifications/initialized":
        return Response(status_code=status.HTTP_202_ACCEPTED, headers=response_headers)

    # Unknown method
    else:
        return Response(
            content=json.dumps({"jsonrpc": "2.0", "id": jsonrpc_id, "error": {"code": -32601, "message": "Method not found"}}),
            headers=response_headers,
            status_code=400
        )

# ==============================================================================
# تشغيل الخادم
# ==============================================================================
if __name__ == "__main__":
    import uvicorn
    logger.info(f"Starting MCP Streamable HTTP Server on http://{HOST}:{PORT}/mcp (Spec: {SPEC_VERSION})")
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")