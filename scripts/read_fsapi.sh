#!/bin/bash
echo "lines: $(wc -l < /root/sylab-app/file_service.py)"
grep -nE "@app|route|def |api/files|add_url|/list|/download|upload" /root/sylab-app/file_service.py | head -50
echo "[DONE]"
