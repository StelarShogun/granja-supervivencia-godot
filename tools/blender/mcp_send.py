#!/usr/bin/env python3
"""Client for the in-Blender MCP addon socket (127.0.0.1:9876).

Protocol (from mcp_to_blender_server.py):
  request:  JSON {"type":"execute","code":<str>,"strict_json":<bool>} + "\\0"
  response: JSON {"status":"ok","result":{...}} | {"status":"error",...} + "\\0"

Reads Blender Python from stdin. The code must assign a dict to `result`.
"""
import json
import socket
import sys

HOST = "127.0.0.1"
PORT = 9876


def send(code: str, strict_json: bool = False, timeout: float = 180.0) -> dict:
    req = json.dumps({"type": "execute", "code": code, "strict_json": strict_json})
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect((HOST, PORT))
    try:
        s.sendall(req.encode("utf-8") + b"\0")
        buf = bytearray()
        while b"\0" not in buf:
            data = s.recv(8192)
            if not data:
                break
            buf.extend(data)
        text = buf.split(b"\0", 1)[0].decode("utf-8", "replace")
        return json.loads(text) if text else {"status": "error", "message": "no data"}
    finally:
        s.close()


if __name__ == "__main__":
    strict = "--strict" in sys.argv
    print(json.dumps(send(sys.stdin.read(), strict_json=strict), indent=2))
