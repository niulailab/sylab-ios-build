#!/bin/bash

echo "### 1. MaxStep 200 二进制验证 ###"
docker exec coze-server sh -c "strings /app/opencoze 2>/dev/null | grep -iE 'max.?step|max.?iteration|reached max' | head -10"
echo ""
echo "--- 环境变量中的step限制 ---"
docker exec coze-server sh -c "env | grep -iE 'step|iter|turn' " 2>&1 | head -10

echo ""
echo "### 2. 实际run表统计（找高步数任务）###"
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -N -e "
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='opencoze' AND table_name LIKE '%run%';" 2>/dev/null

echo ""
echo "### 3. 并发视频生成实测 ###"
# 拷贝测试脚本到容器可访问位置（/tmp挂载为/host-tmp）
cp /host-tmp/conc_test.py /tmp/conc_test.py 2>/dev/null
docker exec tool-proxy python3 /host-tmp/conc_test.py 2>&1

echo ""
echo "### 4. submit日志确认4条 ###"
docker logs tool-proxy --since 3m 2>&1 | grep "\[VID\] submit" | tail -6

echo "[DONE]"
