#!/bin/bash
F=/root/chat-queue-service/server.js
echo "=== line numbers for key handlers ==="
grep -nE "internal/fire|internal/status-by-uuid|conversation_id|conv|recent|active|last_active|enqueue|/v3/chat|/api/chat|createConversation|create_conversation" "$F" | head -60
echo "[DONE]"
