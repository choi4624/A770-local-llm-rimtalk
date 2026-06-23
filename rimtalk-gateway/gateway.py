#!/usr/bin/env python3
"""RimTalk / RimWorld LLM gateway -> Ollama.

Injects RimWorld-friendly defaults (e.g. reasoning_effort=none) and forwards
OpenAI-compatible requests to Ollama. Extend config/rimtalk-gateway.json.
"""

from __future__ import annotations

import json
import logging
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG = REPO_ROOT / "config" / "rimtalk-gateway.json"

HOP_BY_HOP = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
}


def load_config() -> tuple[dict[str, Any], Path]:
    config_path = Path(os.environ.get("RIMGATEWAY_CONFIG", DEFAULT_CONFIG))
    with config_path.open(encoding="utf-8") as f:
        cfg = json.load(f)

    if v := os.environ.get("RIMGATEWAY_UPSTREAM"):
        cfg["upstream"] = v
    if v := os.environ.get("RIMGATEWAY_LISTEN_HOST"):
        cfg["listen_host"] = v
    if v := os.environ.get("RIMGATEWAY_LISTEN_PORT"):
        cfg["listen_port"] = int(v)

    return cfg, config_path


def transform_body(path: str, body: dict[str, Any], cfg: dict[str, Any]) -> dict[str, Any]:
    inject = cfg.get("inject", {})
    paths = cfg.get("paths", {})

    chat_paths = ("/v1/chat/completions", "/chat/completions")
    response_paths = ("/v1/responses", "/responses")

    should_transform = False
    if any(path.endswith(p) for p in chat_paths) and paths.get("transform_chat_completions", True):
        should_transform = True
    if any(path.endswith(p) for p in response_paths) and paths.get("transform_responses", True):
        should_transform = True

    if not should_transform:
        return body

    if inject.get("trim_model_name", True) and isinstance(body.get("model"), str):
        body["model"] = body["model"].strip()

    force_model = inject.get("force_model")
    if force_model:
        body["model"] = force_model

    effort = inject.get("reasoning_effort")
    if effort:
        body["reasoning_effort"] = effort

    max_tokens = inject.get("max_tokens")
    if max_tokens is not None and "max_tokens" not in body:
        body["max_tokens"] = max_tokens

    return body


class GatewayHandler(BaseHTTPRequestHandler):
    config: dict[str, Any] = {}
    upstream_base: str = ""

    def log_message(self, fmt: str, *args: Any) -> None:
        if self.config.get("logging", True):
            logging.info("%s - %s", self.address_string(), fmt % args)

    def _read_body(self) -> bytes:
        length = int(self.headers.get("Content-Length", "0") or 0)
        return self.rfile.read(length) if length else b""

    def _forward(self) -> None:
        path = self.path
        upstream_url = urljoin(self.upstream_base.rstrip("/") + "/", path.lstrip("/"))

        raw = self._read_body()
        headers = {
            k: v
            for k, v in self.headers.items()
            if k.lower() not in HOP_BY_HOP and k.lower() != "host"
        }

        if raw and self.headers.get("Content-Type", "").startswith("application/json"):
            try:
                body = json.loads(raw.decode("utf-8"))
                if isinstance(body, dict):
                    body = transform_body(path, body, self.config)
                    raw = json.dumps(body, ensure_ascii=False).encode("utf-8")
                    headers["Content-Type"] = "application/json"
                    headers["Content-Length"] = str(len(raw))
                    if self.config.get("logging", True):
                        model = body.get("model", "?")
                        effort = body.get("reasoning_effort", "-")
                        logging.info("[RimGateway] %s model=%s reasoning_effort=%s", path, model, effort)
            except json.JSONDecodeError:
                logging.warning("[RimGateway] invalid JSON body, forwarding as-is")

        req = Request(upstream_url, data=raw if raw else None, method=self.command, headers=headers)

        try:
            with urlopen(req, timeout=600) as resp:
                self.send_response(resp.status)
                for key, value in resp.headers.items():
                    if key.lower() not in HOP_BY_HOP:
                        self.send_header(key, value)
                self.end_headers()

                while True:
                    chunk = resp.read(64 * 1024)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
        except HTTPError as e:
            self.send_response(e.code)
            for key, value in e.headers.items():
                if key.lower() not in HOP_BY_HOP:
                    self.send_header(key, value)
            self.end_headers()
            self.wfile.write(e.read())
        except URLError as e:
            logging.error("[RimGateway] upstream error: %s", e)
            payload = json.dumps({"error": {"message": str(e), "type": "gateway_error"}}).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    def do_GET(self) -> None:
        self._forward()

    def do_POST(self) -> None:
        self._forward()

    def do_PUT(self) -> None:
        self._forward()

    def do_DELETE(self) -> None:
        self._forward()

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()


def main() -> int:
    cfg, config_path = load_config()
    host = cfg.get("listen_host", "127.0.0.1")
    port = int(cfg.get("listen_port", 11435))
    upstream = cfg.get("upstream", "http://127.0.0.1:11434")

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%H:%M:%S",
    )

    GatewayHandler.config = cfg
    GatewayHandler.upstream_base = upstream

    server = ThreadingHTTPServer((host, port), GatewayHandler)
    logging.info("[RimGateway] listening on http://%s:%s -> %s", host, port, upstream)
    logging.info("[RimGateway] config: %s", config_path)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logging.info("[RimGateway] stopped")
        return 0


if __name__ == "__main__":
    sys.exit(main())
