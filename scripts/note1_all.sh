#!/usr/bin/env bash
exec > /var/www/sylab-ios/note1_0930.txt 2>&1
set +e
A=/root/coze-studio/ADMIN_NOTES.md
echo "##### ADMIN_NOTES 现状"
ls -la "$A" && tail -n 4 "$A"
echo
MARK="2026-09-30 定时任务只回一半根治(DNS)"
if grep -qF "$MARK" "$A" 2>/dev/null; then
  echo "ALREADY_LOGGED"
else
cat >> "$A" <<'ENTRY'

## 2026-09-30 定时任务只回一半根治(DNS)
- 现象：每日教程08:30在原会话触发，流式开场白后首个 run_command 报错中断(前端只见半段)；公众号09:00 failed。
- 真因：coze-server 调 http://tool-proxy:9092 依赖 Docker 内嵌DNS(127.0.0.11)，偶发 `server misbehaving`(SERVFAIL) 致工具调用失败、run带错结束；调度状态卡 running(任务12)，任务11由补偿重试(+15min)但同因失败。非"跨会话路由漂移"。
- 改动(docker/docker-compose.yml)：tool-proxy 固定 ipv4 172.18.0.10；coze-server 加 extra_hosts tool-proxy:172.18.0.10，绕开内嵌DNS。compose config 校验OK，up -d 重建 coze-server+tool-proxy(依赖容器随之recreate)。
- 复位：任务11/12 last_status=NULL, consecutive_failures=0，next_run_at 不变(10-01 09:00/08:30)。
- 备份：docker-compose.yml.bak_dnsfix_20260930_115237。实测 coze-server 内 run_command 直连返回 STATIC_OK。
- 回滚：用上述 bak 覆盖 compose 后 docker compose up -d coze-server tool-proxy。
ENTRY
echo "APPENDED"
fi
echo
echo "##### 更新后末尾"
tail -n 12 "$A"
