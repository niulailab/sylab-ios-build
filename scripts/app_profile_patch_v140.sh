#!/bin/bash
# ============================================================================
# app profile v140：在「我的-创作工具」组新增「定时任务」入口 + 路由映射
# 纯增量；先备份；替换断言唯一
# ============================================================================
set -euo pipefail
F=/root/sylab-app/app/\(tabs\)/profile.tsx
TS=$(date +%Y%m%d_%H%M%S)
BAK="$F.bak_v140_$TS"
cp -a "$F" "$BAK"
echo "[backup] $BAK"

python3 - "$F" <<'PYEOF'
import sys
f = sys.argv[1]
s = open(f, encoding='utf-8').read()

# 1) 路由映射
old_map = """const ROUTE_MAP: Record<string, string> = {
  '工具中心': '/(tabs)/schedule',
  '积分明细': '/credits',
  '应用设置': '/settings',
  '帮助与反馈': '/help',
};"""
new_map = """const ROUTE_MAP: Record<string, string> = {
  '工具中心': '/(tabs)/schedule',
  '定时任务': '/scheduled-tasks',
  '积分明细': '/credits',
  '应用设置': '/settings',
  '帮助与反馈': '/help',
};"""

n = s.count(old_map)
if n != 1:
    sys.exit(f"[FAIL] route map anchor={n}")
s = s.replace(old_map, new_map)
print("[ok] route map")

# 2) 菜单项（创作工具组）
old_item = """  {
    title: '创作工具',
    items: [
      { icon: 'apps-outline', label: '工具中心', desc: 'AI生图/视频/浏览器等快捷工具' },
    ],
  },"""
new_item = """  {
    title: '创作工具',
    items: [
      { icon: 'apps-outline', label: '工具中心', desc: 'AI生图/视频/浏览器等快捷工具' },
      { icon: 'alarm-outline', label: '定时任务', desc: '查看并管理你的定时任务' },
    ],
  },"""

n = s.count(old_item)
if n != 1:
    sys.exit(f"[FAIL] menu anchor={n}")
s = s.replace(old_item, new_item)
print("[ok] menu item")

open(f, 'w', encoding='utf-8').write(s)
print("[written] profile.tsx")
PYEOF

echo "[DONE]"
