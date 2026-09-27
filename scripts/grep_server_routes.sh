#!/bin/bash
echo "=== route/path refs in server.py ==="
docker exec tool-proxy sh -lc 'grep -nE "bigmodel|rjk66|@app|route|proxy|upstream|UPSTREAM|base_url|/v1|add_route|aiohttp|fastapi|flask" /app/server.py | head -60'
echo DONE
