#!/bin/bash
echo "===== build log tail ====="
tail -25 /tmp/sylab_web_build.log
echo "===== web-build dir ====="
ls -la /root/sylab-app/web-build 2>/dev/null | head
