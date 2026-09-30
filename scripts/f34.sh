#!/bin/bash
P=/root/coze-studio/ADMIN_NOTES.md
cp "$P" "${P}.bak_rootfix_20260930"
cat >> "$P" <<'ENTRY'
- 2026-09-30：**根治 sylab AI 自查报告全部问题**。先逐项核查（证伪问题1/6；问题2/3真根因与报告不同；问题4部分；问题5部分），再落地修复：①tool-proxy server.py 三处补丁——新增 `POST /browser/content` 转发 browser-service（原 tool 注册的是 tool-proxy 上不存在的404死链，非反爬，直连browser-service抓取正常、截断上限20000）、web_search 失败回传 `bocha_error` 不再静默、/screenshot 加一次自动重试；另修 /notifications/list 的 datetime 序列化500（created_at转str）。②博查真根因=运行容器是9-24旧环境（compose后来才加BOCHA key，但`docker restart`不重读env）；用镜像1.3-filepath（已内置BOCHA/minio/GITHUB全部env）`docker run` 重建到网络 coze-studio_coze-network、挂载server.py；实测 /v1/web-search 返回 source=bocha。③补注册+绑定当前版本(95→106)：直绑 video_generate/video_status/git_operation；新建插件 sylab_extra(id 7668000000000000999) 含 publish_web、notifications create/list/mark-read/delete、schedule_toggle、bigmodel_proxy、get_video_content 共8工具。④干净重启 coze-server（Up20s）刷新工具缓存。实测：视频两阶段报价正常、publish_web verified=true、通知create(id30)/list正常、schedule/git返回明确错误。备份 /root/backup_rootfix_20260930_080441/（server.py+compose+8表mysqldump）。
ENTRY
echo "appended; new lines=$(wc -l < $P)"
tail -2 "$P" | cut -c1-60
echo "[DONE]"
