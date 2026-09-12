#!/usr/bin/env python3
"""
sylab 项目文件服务 - 按会话隔离的文件存储
端口: 9093
每个会话(conversation)有独立的文件目录
CORS 由 Nginx 统一处理，此服务不发送 CORS 头
"""

import shutil
import http.server
import json
import os
import time
import urllib.parse
from pathlib import Path
from datetime import datetime, timedelta

BASE_DIR = Path("/root/sylab-app-data/project-files")
PORT = 9093
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB
FILE_EXPIRE_DAYS = 7

def get_conv_dir(conversation_id: str) -> Path:
    safe_id = "".join(c for c in conversation_id if c.isalnum() or c in "-_")
    if not safe_id:
        return None
    d = BASE_DIR / safe_id
    d.mkdir(parents=True, exist_ok=True)
    return d

class FileHandler(http.server.BaseHTTPRequestHandler):
    def _json(self, code, data):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        # CORS 预检由 Nginx 处理，直连时返回 204
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)

        if parsed.path == "/health":
            self._json(200, {"status": "ok", "service": "project-files"})
            return

        if parsed.path == "/api/files/all-stats":
            conversations = {}
            if BASE_DIR.exists():
                for conv_dir in BASE_DIR.iterdir():
                    if conv_dir.is_dir():
                        file_count = 0
                        total_size = 0
                        for f in conv_dir.iterdir():
                            if f.is_file():
                                file_count += 1
                                total_size += f.stat().st_size
                        conversations[conv_dir.name] = {
                            "file_count": file_count,
                            "total_size": total_size
                        }
            self._json(200, {
                "code": 0,
                "data": {
                    "conversations": conversations
                }
            })
            return

        if parsed.path == "/api/files":
            conv_id = self.headers.get("X-Conversation-Id") or params.get("conversation_id", [None])[0]
            if not conv_id:
                self._json(400, {"code": 400, "msg": "缺少 conversation_id"})
                return

            conv_dir = get_conv_dir(conv_id)
            if conv_dir is None:
                self._json(400, {"code": 400, "msg": "无效的 conversation_id"})
                return

            files = []
            for f in sorted(conv_dir.iterdir(), key=lambda x: x.stat().st_mtime, reverse=True):
                if f.is_file():
                    stat = f.stat()
                    ext = f.suffix.lower()
                    if ext in (".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg"):
                        ftype = "image"
                    elif ext in (".pdf", ".doc", ".docx", ".txt", ".md", ".csv", ".xlsx"):
                        ftype = "document"
                    elif ext in (".py", ".js", ".ts", ".tsx", ".jsx", ".json", ".html", ".css"):
                        ftype = "code"
                    elif ext in (".mp3", ".wav", ".ogg", ".m4a"):
                        ftype = "audio"
                    elif ext in (".mp4", ".mov", ".avi", ".webm"):
                        ftype = "video"
                    else:
                        ftype = "other"

                    created_dt = datetime.fromtimestamp(stat.st_ctime)
                    expires_dt = created_dt + timedelta(days=FILE_EXPIRE_DAYS)

                    files.append({
                        "name": f.name,
                        "type": ftype,
                        "size": stat.st_size,
                        "created_at": created_dt.isoformat(),
                        "expires_at": expires_dt.isoformat(),
                        "url": f"/api/files/{conv_id}/{f.name}",
                        "source": "user_upload" if f.name.startswith("upload_") else "ai_generated",
                    })

            self._json(200, {
                "code": 0,
                "data": {
                    "conversation_id": conv_id,
                    "files": files,
                    "total": len(files),
                }
            })
            return

        # 下载文件: /api/files/{conv_id}/{filename}
        path_parts = parsed.path.strip("/").split("/")
        if len(path_parts) == 4 and path_parts[0] == "api" and path_parts[1] == "files":
            conv_id = path_parts[2]
            filename = path_parts[3]
            conv_dir = get_conv_dir(conv_id)
            if conv_dir is None:
                self._json(400, {"code": 400, "msg": "无效"})
                return
            filepath = conv_dir / filename
            if not filepath.exists() or not filepath.is_file():
                self._json(404, {"code": 404, "msg": "文件不存在"})
                return
            if not filepath.resolve().is_relative_to(conv_dir.resolve()):
                self._json(403, {"code": 403, "msg": "禁止访问"})
                return

            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
            self.send_header("Content-Length", str(filepath.stat().st_size))
            self.end_headers()
            with open(filepath, "rb") as fh:
                while True:
                    chunk = fh.read(8192)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
            return

        self._json(404, {"code": 404, "msg": "Not Found"})

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == "/api/files/upload":
            conv_id = self.headers.get("X-Conversation-Id")
            if not conv_id:
                self._json(400, {"code": 400, "msg": "缺少 X-Conversation-Id 请求头"})
                return

            conv_dir = get_conv_dir(conv_id)
            if conv_dir is None:
                self._json(400, {"code": 400, "msg": "无效的 conversation_id"})
                return

            content_length = int(self.headers.get("Content-Length", 0))

            if content_length > MAX_FILE_SIZE:
                self._json(413, {"code": 413, "msg": f"文件过大，最大 {MAX_FILE_SIZE // 1024 // 1024}MB"})
                return

            original_name = self.headers.get("X-File-Name", "unknown_file")
            safe_name = "upload_" + "".join(c for c in original_name if c.isalnum() or c in "-_. ")
            if not safe_name or safe_name == "upload_":
                safe_name = f"upload_file_{int(time.time())}"

            body = self.rfile.read(content_length)

            filepath = conv_dir / safe_name
            if filepath.exists():
                stem = filepath.stem
                suffix = filepath.suffix
                filepath = conv_dir / f"{stem}_{int(time.time())}{suffix}"

            with open(filepath, "wb") as f:
                f.write(body)

            self._json(200, {
                "code": 0,
                "data": {
                    "name": filepath.name,
                    "size": len(body),
                    "conversation_id": conv_id,
                    "url": f"/api/files/{conv_id}/{filepath.name}",
                    "source": "user_upload",
                }
            })
            self.log_message(f"文件上传成功: {filepath.name} ({len(body)} bytes) -> conv {conv_id}")
            return

        
        if parsed.path == "/api/files/save-chat-log":
            conv_id = self.headers.get("X-Conversation-Id")
            if not conv_id:
                self._json(400, {"code": 400, "msg": "缺少 X-Conversation-Id 请求头"})
                return

            conv_dir = get_conv_dir(conv_id)
            if conv_dir is None:
                self._json(400, {"code": 400, "msg": "无效的 conversation_id"})
                return

            content_length = int(self.headers.get("Content-Length", 0))
            if content_length == 0:
                self._json(400, {"code": 400, "msg": "缺少请求体"})
                return

            body = self.rfile.read(content_length)
            data = json.loads(body)
            messages = data.get("messages", [])

            # 格式化聊天记录为文本
            lines = []
            lines.append(f"会话 {conv_id} 聊天记录")
            lines.append(f"导出时间: {datetime.now().strftime(chr(37) + chr(89) + chr(45) + chr(37) + chr(109) + chr(45) + chr(37) + chr(100) + chr(32) + chr(37) + chr(72) + chr(58) + chr(37) + chr(77) + chr(58) + chr(37) + chr(83))}")
            lines.append("=" * 50)
            for msg in messages:
                role = msg.get("role", "unknown")
                content_text = msg.get("content", "")
                ts = msg.get("created_at", "")
                if ts:
                    try:
                        ts_num = int(float(ts))
                        if ts_num > 1e12:
                            ts_num = ts_num // 1000
                        dt = datetime.fromtimestamp(ts_num)
                        ts_str = dt.strftime(chr(37) + chr(89) + chr(45) + chr(37) + chr(109) + chr(45) + chr(37) + chr(100) + chr(32) + chr(37) + chr(72) + chr(58) + chr(37) + chr(77) + chr(58) + chr(37) + chr(83))
                    except:
                        ts_str = str(ts)
                else:
                    ts_str = "unknown"
                role_label = "用户" if role == "user" else "AI助手" if role == "assistant" else role
                lines.append("")
                lines.append(f"[{ts_str}] {role_label}:")
                lines.append(content_text)
            lines.append("")
            lines.append("=" * 50)

            text_content = chr(10).join(lines)
            filepath = conv_dir / "chat_history.txt"
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(text_content)

            self._json(200, {
                "code": 0,
                "data": {
                    "saved": True,
                    "file": "chat_history.txt",
                    "message_count": len(messages)
                }
            })
            self.log_message(f"聊天记录已保存: conv {conv_id}, {len(messages)} 条消息")
            return

        self._json(404, {"code": 404, "msg": "Not Found"})


    def do_PUT(self):
        """Sync files from source conversation to target conversation"""
        parsed = urllib.parse.urlparse(self.path)
        
        if parsed.path.startswith("/api/files/sync"):
            params = urllib.parse.parse_qs(parsed.query)
            source_id = params.get("from", [None])[0]
            target_id = params.get("to", [None])[0]
            
            if not source_id or not target_id:
                self._json(400, {"code": 400, "msg": "Missing from/to parameters"})
                return
            
            source_dir = get_conv_dir(source_id)
            target_dir = get_conv_dir(target_id)
            
            if source_dir is None or target_dir is None:
                self._json(400, {"code": 400, "msg": "Invalid conversation ID"})
                return
            
            if not source_dir.exists():
                self._json(200, {"code": 0, "data": {"synced": 0, "msg": "Source directory empty"}})
                return
            
            synced = 0
            for f in source_dir.iterdir():
                if f.is_file():
                    dest = target_dir / f.name
                    if not dest.exists():
                        shutil.copy2(str(f), str(dest))
                        synced += 1
            
            self._json(200, {"code": 0, "data": {"synced": synced, "source": source_id, "target": target_id}})
            self.log_message(f"Synced {synced} files from {source_id} to {target_id}")
            return
        
        self._json(404, {"code": 404, "msg": "Not Found"})

    def do_DELETE(self):
        parsed = urllib.parse.urlparse(self.path)
        parts = parsed.path.strip("/").split("/")

        if len(parts) == 4 and parts[0] == "api" and parts[1] == "files":
            conv_id = parts[2]
            filename = parts[3]
            conv_dir = get_conv_dir(conv_id)
            if conv_dir is None:
                self._json(400, {"code": 400, "msg": "无效"})
                return
            filepath = conv_dir / filename
            if not filepath.exists():
                self._json(404, {"code": 404, "msg": "文件不存在"})
                return
            filepath.unlink()
            self._json(200, {"code": 0, "msg": "已删除"})
            return

        self._json(404, {"code": 404, "msg": "Not Found"})

    def log_message(self, format, *args):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {format % args}")


if __name__ == "__main__":
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    server = http.server.HTTPServer(("0.0.0.0", PORT), FileHandler)
    server.socket.setsockopt(__import__('socket').SOL_SOCKET, __import__('socket').SO_REUSEADDR, 1)
    print(f"项目文件服务启动: 0.0.0.0:{PORT}")
    print(f"文件存储目录: {BASE_DIR}")
    print(f"文件过期时间: {FILE_EXPIRE_DAYS} 天")
    print("CORS 由 Nginx 统一处理")
    server.serve_forever()
