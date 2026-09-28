#!/bin/bash
F=/root/coze-studio/browser-service/browser_service.py
wc -l "$F"
echo "=== grep screenshot/playwright/screenshot_base64 ==="
grep -nE "screenshot|playwright|async_playwright|base64|launch|chromium|def |route|goto" "$F" | head -50
