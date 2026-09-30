#!/bin/bash
echo "===== coze-mysql 内 python/pymysql ====="
docker exec coze-mysql sh -c 'command -v python3 || command -v python || echo NO_PY'
docker exec coze-mysql sh -c 'python3 -c "import pymysql;print(\"pymysql\",pymysql.__version__)" 2>/dev/null || python3 -c "import MySQLdb;print(\"MySQLdb ok\")" 2>/dev/null || echo NO_DRIVER'
echo "===== 容器内 mysql client(可用bash生成SQL宿主执行) ====="
docker exec coze-mysql sh -c 'command -v mysql'
echo "[DONE]"
