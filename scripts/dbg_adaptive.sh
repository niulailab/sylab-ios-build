#!/bin/bash
echo "=== tool-proxy recent ==="
docker logs --tail 50 tool-proxy 2>&1 | grep -aE 'zhipu-proxy|replay|refus|HTTP/1.1|strip|FINISH|error|Error|400' | tail -30
echo DONE
