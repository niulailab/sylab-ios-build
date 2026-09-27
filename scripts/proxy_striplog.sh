#!/bin/bash
docker logs --tail 20 tool-proxy 2>&1 | grep -E 'zhipu-strip|zhipu-proxy|HTTP/1.1' | tail -15
echo DONE
