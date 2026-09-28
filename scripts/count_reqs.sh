#!/bin/bash
echo "=== 最近 chat/completions 请求序列（含replay标记） ==="
docker logs tool-proxy 2>&1 | grep -aE 'adaptive|replay low|POST https://open.bigmodel' | tail -40
echo "=== 看是否有 image/understand 之外的异常 ==="
docker logs --tail 200 tool-proxy 2>&1 | grep -aiE 'streamconsumed|runtimeerror|exception|traceback' | tail -10
echo DONE
