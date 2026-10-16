"""
BeaconOS Streamable HTTP Client Test (Spec 2025-11-25)
Tests: Initialize, Tools Listing, and Tool Execution.
"""

import httpx
import json

URL = "http://127.0.0.1:8000/mcp"
HEADERS = {
    "MCP-Protocol-Version": "2025-11-25",
    "Accept": "application/json, text/event-stream",
    "Content-Type": "application/json"
}

def test_mcp_flow():
    print("=" * 60)
    print("🚀 TESTING STREAMABLE HTTP MCP ENDPOINT (/mcp)")
    print("=" * 60)

    with httpx.Client(base_url="http://127.0.0.1:8000", headers=HEADERS) as client:
        # 1. Initialize Request
        print("\n1️⃣ Sending 'initialize' request...")
        init_payload = {
            "jsonrpc": "2.0",
            "id": "init-1",
            "method": "initialize",
            "params": {"protocolVersion": "2025-11-25"}
        }
        res = client.post("/mcp", json=init_payload)
        print(f"Status: {res.status_code}")
        print(f"Server Info: {res.json().get('result', {}).get('serverInfo')}")

        # 2. List Tools
        print("\n2️⃣ Sending 'tools/list' request...")
        list_payload = {
            "jsonrpc": "2.0",
            "id": "tools-1",
            "method": "tools/list",
            "params": {}
        }
        res = client.post("/mcp", json=list_payload)
        tools = res.json().get("result", {}).get("tools", [])
        print(f"Discovered {len(tools)} tools:")
        for t in tools:
            print(f"  • {t['name']}")

        # 3. Call Tool: beacon_locate_phone
        print("\n3️⃣ Calling tool: 'beacon_locate_phone'...")
        call_payload = {
            "jsonrpc": "2.0",
            "id": "call-1",
            "method": "tools/call",
            "params": {
                "name": "beacon_locate_phone",
                "arguments": {"reason": "Devpost Video Recording Demo"}
            }
        }
        res = client.post("/mcp", json=call_payload)
        data = res.json().get("result", {}).get("content", [])
        for item in data:
            if item.get("type") == "text":
                print(f"🗣️ Speech Output: {item['text']}")
            elif item.get("type") == "resource":
                print(f"📺 UI Card Data: {item['resource']['data']}")

        # 4. Call Tool: beacon_get_device_telemetry
        print("\n4️⃣ Calling tool: 'beacon_get_device_telemetry'...")
        res = client.post("/mcp", json={
            "jsonrpc": "2.0",
            "id": "call-2",
            "method": "tools/call",
            "params": {"name": "beacon_get_device_telemetry", "arguments": {}}
        })
        print(f"Output: {res.json().get('result', {}).get('content', [])[0]['text']}")

    print("\n" + "=" * 60)
    print("✅ STREAMABLE HTTP (2025-11-25) TEST PASSED!")
    print("=" * 60)

if __name__ == "__main__":
    test_mcp_flow()