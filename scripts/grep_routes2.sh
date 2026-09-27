#!/bin/bash
docker exec tool-proxy sh -lc 'grep -nE "bigmodel/v1|@app\.(post|get|api_route)\(\"/(bigmodel|rjk|relay|llm)" /app/server.py'
echo "=== all @app routes after line 2010 ==="
docker exec tool-proxy sh -lc 'grep -nE "@app\.(post|get|api_route)" /app/server.py | awk -F: "\$1>2010"'
echo DONE
