#!/bin/bash
KEY="674ea22cd4af46508ab1baa22d3a6fc6.mSy1BrBipXy3pnoG"
curl -s -m 20 "https://open.bigmodel.cn/api/paas/v4/models" -H "Authorization: Bearer $KEY" | head -c 4000
echo
echo DONE
