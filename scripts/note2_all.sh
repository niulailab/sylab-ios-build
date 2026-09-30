#!/usr/bin/env bash
set +e
A=/root/coze-studio/ADMIN_NOTES.md
MARK="2026-09-30 App灰块+文件大小修复(v132)"
if grep -qF "$MARK" "$A" 2>/dev/null; then echo ALREADY; else
cat >> "$A" <<'ENTRY'

## 2026-09-30 App灰块+文件大小修复(v132)
- 现象：回复结束瞬间，含 .md 链接的消息变无文字灰块卡(显示 MD·31B)，重进页面恢复。
- 根因(纯前端)：①fetchFileSize 用 HEAD 探测，file_service 不支持 HEAD(405+31字节错误体)，错误体 Content-Length 被误当文件大小→"31B"(真实5851字节)；②流结束 footer 卸载→400ms 后历史合并在 FlatList 同位置重挂 FileDownloadCard，RN 偶发丢首次绘制→灰骨架。
- 修复(src)：fileOpen.ts fetchFileSize 改为 GET Range 优先(200带完整Content-Length)、仅接受 res.ok、HEAD 降为兜底；MarkdownRenderer.tsx FileDownloadCard 加首帧 requestAnimationFrame 挂载门，首帧渲染等底色占位(高92)，下一帧再上完整卡片。
- 发版：app.json 1.0.32/build32(android versionCode30)；build-ios 成功→deploy-ios tag v132。包 /var/www/sylab-ios/sylab-unsigned.ipa(8217685字节)，Content-Disposition sylab-v132.ipa。
ENTRY
echo APPENDED
fi
tail -n 2 "$A"
