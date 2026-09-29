# sylab 运维手册（权威 · 每次改动必须更新）

> **铁律**：小小酥每次 SSH 上服务器，**第一件事读本文件**；每次运维改动完成后，**必须同步更新本文件**（服务器版 + 项目云盘版）。
> 本文件不依赖任何会话记忆，换会话/上下文丢失后读本文件即可恢复全部关键信息。
>
> - 服务器版（现场，优先）：`/root/coze-studio/ADMIN_NOTES.md`
> - 项目云盘版（副本，用户可见）：项目目录 `ADMIN_NOTES.md`
> - 最后更新：2026-09-29

---

## 0. 系统身份（重要，别再搞错）

- **sylab 是用户（卡尔）自研的 AI 漫剧制作系统**，所有前后端源码都在自己服务器上，不是任何官方产品。
- 服务器：`36.137.84.216`，全 Docker 容器运行。
- 代码主目录：`/root/coze-studio/`（历史目录名，勿与"官方产品"混淆）。

## 1. 操作铁律（重启 vs 重建，最关键）

- **`docker restart <容器>` 只重启进程，不丢任何补丁**（bind mount 文件 / 已编译镜像 / 数据库 / 卷都不受影响）。
- **`docker build` 重建镜像才有丢补丁风险**：
  - 重建 `tool-proxy` 镜像 → 必须先确认当前 `/root/coze-studio/tool-proxy/server.py` 已含全部改动并打进镜像（当前是 bind mount，重建后若不继续 mount 会回退到镜像内旧版）。
  - 重建 `coze-server` 镜像 → 必须把 MaxStep 200 等编译期改动带进源码再编译。
- **不私自降配、不用替代方案、功能完整验证不做空壳。**
- **禁止私自 rm 文件/目录**；删除前必须征得卡尔同意并备份。

## 2. 关键容器（2026-09-29 盘点均 Up/healthy）

| 容器 | 镜像 | 作用 | 备注 |
|---|---|---|---|
| coze-server | cozedev/coze-studio-server:**coderunner-0923** | sylab 后端主服务 | MaxStep/隔离等编译于此镜像（09-23构建） |
| tool-proxy | tool-proxy:1.2-flutter | 工具代理（图/视频/搜索/代码执行等） | **bind mount `server.py`，改文件+重启即生效** |
| coze-mysql | mysql:8.4.5 | 数据库 opencoze | 见第5节自建表铁律 |
| coze-minio / coze-redis / coze-milvus / coze-elasticsearch / coze-etcd | - | 存储/缓存/向量/检索 | |
| llm-proxy | llm-proxy:probe | LLM 中转 | |
| 其他 | browser-service / security-tools / coze-loop-* / promtail / loki / filebrowser 等 | | |

查看全部：`docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'`

## 3. 补丁清单（每项：是什么 / 在哪 / 如何验证）

| # | 补丁 | 位置 | 验证方法 |
|---|---|---|---|
| 1 | **视频/状态工具 data 字段→JSON string**（修复返回空 `{}`，根因：response schema `data` 为 string，返回 dict 会被框架丢弃） | tool-proxy `server.py` 的 `video_generate_v2`/`video_status_v2` 全部 8 个 return | `awk 'NR>=5432 && NR<=5590 && /"data":json\.dumps/' server.py \| wc -l` 应=8；`awk 'NR>=5432 && NR<=5590 && /"data":\{/ && !/json\.dumps/' \| wc -l` 应=0 |
| 2 | **MaxStep 30→200** | 编译进 coze-server `coderunner-0923` 镜像 | 用该镜像即生效；重建镜像需带源码改动 |
| 3 | **消息分页 PageNum/PageSize** | tool-proxy server.py（~3584行） | grep `page_num` |
| 4 | **coderunner 代码执行隔离**（封内网/只读rootfs/限内存） | coze-server 镜像 + tool-proxy execute_code/run_command | coze-server 跑 coderunner-0923 |
| 5 | **web-search 博查优先、360 兜底，支持 freshness** | tool-proxy `_search_bocha`/`_search_360`（~2830-2904） | grep `bocha` |
| 6 | **upload 容错 base64 解码** | tool-proxy（~458行） | grep 容错 base64 |
| 7 | **MySQL 自建表 HCL 同步** | `/root/coze-studio/docker/atlas/opencoze_latest_schema.hcl` | 见第5节 |

## 4. tool-proxy 关键信息

- 代码：`/root/coze-studio/tool-proxy/server.py`（bind mount → 容器内 `/app/server.py`）。
- 端口：容器内 **9092**（不是 5435）；宿主机映射 `0.0.0.0:9092`。
- 改代码流程：改 `server.py` → `docker restart tool-proxy` → 看日志确认 `[PATCHv2] ... active`。
- 视频链路：`/video/generate` → RunningHub H3；轮询 `_poll_and_callback`；成片 `/video/content/{tid}.mp4`。
- 视频报价/生成两段式：先 `action=quote`，用户确认后 `action=generate`（QUOTE_RECORDS 限时）。
- 测试用户必须有积分，否则扣费失败 balance=0（这是正常拦截，不是 bug）。

## 5. MySQL 自建表铁律（重启会 DROP 外表！）

- **MySQL 启动时 Atlas 自动同步会 DROP 基线外的自建表。**
- 凡新建自建表，**必须**把表定义加进：
  `/root/coze-studio/docker/atlas/opencoze_latest_schema.hcl`
  否则 MySQL 容器一重启，表就丢。
- 已登记：`token_accounts`（积分账户）等。
- 视频任务记录靠 tool-proxy 内部存储（`_rh_save/_rh_load`），不完全依赖 MySQL。

## 6. 常用排障入口

- tool-proxy 日志：`docker logs tool-proxy --since 30m`
- coze-server 日志：`docker logs coze-server --since 30m`
- 视频提交确认：日志 grep `[VID] submit`（含 tid/cost/user）
- 消息"未送达"先查 message/run_record 表，别急着改客户端。
- 容器起不来：先 `docker logs <容器>` 看是否 Python 语法错误。

## 7. 备份

- 全量备份（09-23，9G：源码+45镜像+MySQL全库+配置）：`/data/archive/sylab_full_20260923_002830`
- tool-proxy 历史备份：`server.py.bak.*`（同目录）。

## 8. 变更日志（倒序，每次改动追加一行）

- 2026-09-29：修复 video_generate/video_status 返回空 `{}`（8处 data→json.dumps）；建立本运维手册；并发4路实测通过（4/4 唯一 tid）。
