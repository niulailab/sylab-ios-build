#!/bin/bash
echo "### 1. model_instance 表里100015现行配置 ###"
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "
SELECT * FROM model_instance WHERE id=100015 OR model_id='100015'\G" 2>/dev/null | head -30
echo ""
echo "### 2. model_entity / model_meta 相关100015 ###"
docker exec coze-mysql mysql -uroot -p"$MP" opencoze -e "
SELECT id, LEFT(COALESCE(name,''),30) name FROM model_entity WHERE id=100015;
SELECT id, LEFT(COALESCE(name,''),30) name FROM model_meta WHERE id=100015;" 2>/dev/null
echo ""
echo "### 3. 全盘轻量找含thinking_type的当前配置(排除_old) ###"
timeout 40 grep -rliE "glm-5.3|thinking_type" /root --include=*.json 2>/dev/null | grep -viE "node_modules|sylab-app|_expo|\.skills" | head -8
echo "[DONE]"
