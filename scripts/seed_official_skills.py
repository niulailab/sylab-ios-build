#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""官方预置技能幂等种子。技能存进记忆服务：layer=long_term, category=skill。
重跑不重复插入（按 metadata.skill_id + scope=official 判定）。"""
import json, time, urllib.request

BASE = "http://127.0.0.1:8900"
AGENT = "sylab-ai"

def post(path, payload):
    req = urllib.request.Request(
        BASE + path, data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        body = json.loads(r.read().decode("utf-8"))
    # 统一解包：data 可能是 JSON 字符串或对象
    data = body.get("data", body)
    if isinstance(data, str):
        try: data = json.loads(data)
        except Exception: pass
    return data

def get_existing_ids():
    data = post("/memory/search", {
        "agent_id": AGENT, "category": "skill",
        "tags": ["skill", "official"], "limit": 200
    })
    ids = set()
    for m in (data.get("memories", []) if isinstance(data, dict) else []):
        try:
            meta = m.get("metadata", {})
            if isinstance(meta, str): meta = json.loads(meta)
            if meta.get("scope") == "official" and meta.get("skill_id"):
                ids.add(meta["skill_id"])
        except Exception:
            pass
    return ids

# ─────────────────────── 预置技能定义 ───────────────────────
SKILLS = [
    {
        "skill_id": "official-wechat-cover-pack",
        "name": "公众号爆款配图包",
        "icon": "📰",
        "cat": "公众号",
        "trigger": "需要给公众号文章配封面/插图",
        "tools": ["web_search", "laneai"],
        "est_credits": [200, 600],
        "params": [
            {"name": "主题", "required": True, "desc": "文章主题", "example": "AI副业避坑"},
            {"name": "风格", "required": False, "desc": "视觉风格", "example": "商务扁平"},
            {"name": "数量", "required": False, "desc": "配图数量", "example": "3"},
        ],
        "content": """# 公众号爆款配图包

## 目标
围绕主题产出可直接用于公众号的封面图 + 文中配图，每张配一句可用标题。

## 输入参数
- 主题：{主题}
- 风格：{风格}（默认：商务扁平、高对比）
- 数量：{数量}（默认 3）

## 步骤
1. 用 web_search 搜索「{主题}」，整理 3 个切入角度与高点击关键词。
2. 用 laneai 按风格生成封面图，尺寸 16:9，主体清晰、留白放标题；共 {数量} 张。
3. 每张图配一句不超过 15 字、带钩子的标题。

## 输出
- 图片（按顺序）
- 标题列表，与图片一一对应

## 约束
- 单张成本不超过 150 积分；生图失败自动降级免费通道并重试一次。
- 图中不出现错别字、不出现第三方品牌 logo。""",
    },
    {
        "skill_id": "official-h3-comic-storyboard",
        "name": "H3 漫剧分镜成片",
        "icon": "🎬",
        "cat": "漫剧",
        "trigger": "把剧本/小说片段做成漫剧分镜视频",
        "tools": ["anime-storyboard", "laneai", "video-gen"],
        "est_credits": [800, 2500],
        "params": [
            {"name": "原文", "required": True, "desc": "剧本或小说片段", "example": "（粘贴片段）"},
            {"name": "画风", "required": False, "desc": "动漫画风", "example": "日系赛璐璐"},
            {"name": "镜数", "required": False, "desc": "分镜数量", "example": "6"},
        ],
        "content": """# H3 漫剧分镜成片

## 目标
把「{原文}」拆成 {镜数} 个分镜，产出角色/场景提示词并逐镜生成漫剧画面。

## 输入参数
- 原文：{原文}
- 画风：{画风}（默认：日系赛璐璐）
- 镜数：{镜数}（默认 6）

## 步骤
1. 用 anime-storyboard 将原文拆为分镜：每镜含景别、动作、台词/旁白。
2. 抽取并统一角色形象提示词、场景提示词，保证跨镜角色一致。
3. 为每镜生成 Sora/视频提示词，用 laneai 出关键帧。
4. 需要动态时用 video-gen 按镜生成短视频片段。

## 输出
- 分镜表（景别/动作/台词）
- 角色与场景提示词
- 各镜画面/视频，按顺序编号

## 约束
- 角色外貌在所有镜头保持一致；每镜时长固定。
- 单镜生成失败重试一次，仍失败则标注并继续，不阻塞整体。""",
    },
    {
        "skill_id": "official-hit-video-teardown",
        "name": "爆款视频拆解",
        "icon": "🔍",
        "cat": "选题",
        "trigger": "分析一条爆款视频为什么火、如何复刻",
        "tools": ["web_search", "video-understand"],
        "est_credits": [50, 200],
        "params": [
            {"name": "视频链接", "required": True, "desc": "爆款视频链接", "example": "https://..."},
        ],
        "content": """# 爆款视频拆解

## 目标
拆解「{视频链接}」的爆款要素，给出可复刻的结构模板。

## 输入参数
- 视频链接：{视频链接}

## 步骤
1. 获取视频文案/字幕与画面信息（必要时 web_search 找同款选题数据）。
2. 按 7 步拆解：选题钩子 / 前3秒 / 节奏 / 情绪曲线 / 信息密度 / 结尾引导 / 标题封面。
3. 提炼成可套用的分镜结构模板与改写要点。

## 输出
- 7 项逐条分析
- 一份可直接复用的脚本结构模板
- 3 个同主题差异化选题建议

## 约束
- 结论必须基于视频实际内容，不臆测数据；拿不到字幕时明确说明。""",
    },
    {
        "skill_id": "official-serial-drama-workshop",
        "name": "连续剧分集生成",
        "icon": "📺",
        "cat": "漫剧",
        "trigger": "持续生成多集连续剧剧本与分镜",
        "tools": ["anime-storyboard", "laneai"],
        "est_credits": [600, 2000],
        "params": [
            {"name": "设定", "required": True, "desc": "世界观/人物设定", "example": "（设定）"},
            {"name": "上一集梗概", "required": False, "desc": "衔接用", "example": "（梗概）"},
            {"name": "本集数", "required": False, "desc": "本集分镜数", "example": "8"},
        ],
        "content": """# 连续剧分集生成

## 目标
在固定世界观下生成新一集，保证人物、伏笔、时间线连贯。

## 输入参数
- 设定：{设定}
- 上一集梗概：{上一集梗概}
- 本集数：{本集数}（默认 8）

## 步骤
1. 对照设定与上一集梗概，确定本集主线、冲突与一个钩子结尾。
2. 拆为 {本集数} 个分镜，标注承接的伏笔与新埋伏笔。
3. 复用既定角色/场景提示词，生成本集关键帧。

## 输出
- 本集剧情梗概 + 分镜表
- 伏笔对照表（承接/新增/待回收）
- 关键帧

## 约束
- 人物性格与设定一致，不新增矛盾设定；每集结尾必须留悬念。""",
    },
    {
        "skill_id": "official-xhs-hit-note",
        "name": "小红书爆款笔记",
        "icon": "📔",
        "cat": "自媒体",
        "trigger": "写一篇高互动小红书笔记",
        "tools": ["web_search", "laneai"],
        "est_credits": [100, 400],
        "params": [
            {"name": "主题", "required": True, "desc": "笔记主题", "example": "在家搞定AI生图"},
            {"name": "人设", "required": False, "desc": "作者人设语气", "example": "踩坑过来人"},
        ],
        "content": """# 小红书爆款笔记

## 目标
产出一篇结构完整、带封面建议、合规的小红书笔记。

## 输入参数
- 主题：{主题}
- 人设：{人设}（默认：真实分享的踩坑过来人）

## 步骤
1. web_search 收集该主题的高赞选题、痛点与违禁词风险。
2. 写 3 个备选标题（带数字/反差/利益点），正文用「痛点-方法-步骤-总结」结构，多用短句和分段。
3. 给封面文案与配图建议（需要时用 laneai 出图）。
4. 末尾引导互动，并加精准标签。

## 输出
- 3 个标题 + 成稿正文
- 封面/配图建议
- 标签列表与合规提示

## 约束
- 不夸大、不写违禁词、不硬广；全篇口语化、像真人分享。""",
    },
    {
        "skill_id": "official-ai-portrait-pack",
        "name": "写实人像出图包",
        "icon": "🖼️",
        "cat": "生图",
        "trigger": "批量生成写实风格人像",
        "tools": ["laneai"],
        "est_credits": [100, 500],
        "params": [
            {"name": "人物描述", "required": True, "desc": "外貌/气质", "example": "25岁亚洲女性，自然光"},
            {"name": "场景", "required": False, "desc": "背景环境", "example": "城市街头黄昏"},
            {"name": "数量", "required": False, "desc": "张数", "example": "4"},
        ],
        "content": """# 写实人像出图包

## 目标
生成 {数量} 张高真实感、五官稳定的写实人像。

## 输入参数
- 人物描述：{人物描述}
- 场景：{场景}（默认：简洁自然背景）
- 数量：{数量}（默认 4）

## 步骤
1. 组合人物 + 场景 + 光线 + 镜头语言，写完整写实提示词。
2. 用 laneai 按竖版 3:4 生成 {数量} 张，保持同一人物特征。
3. 检查手部/五官，不达标局部重生成。

## 输出
- {数量} 张人像图，按顺序编号
- 所用提示词

## 约束
- 写实真人风格、不卡通化；不生成公众人物脸。""",
    },
    {
        "skill_id": "official-topic-research-brief",
        "name": "选题调研简报",
        "icon": "📊",
        "cat": "选题",
        "trigger": "快速摸清一个选题/赛道值不值得做",
        "tools": ["web_search"],
        "est_credits": [20, 100],
        "params": [
            {"name": "选题", "required": True, "desc": "要调研的选题/赛道", "example": "AI漫剧带货"},
        ],
        "content": """# 选题调研简报

## 目标
快速判断「{选题}」的热度、竞争与切入点。

## 输入参数
- 选题：{选题}

## 步骤
1. web_search 收集：热度趋势、主要玩家、内容形态、用户痛点、变现方式。
2. 做一个简单 SWOT（优势/劣势/机会/风险）。
3. 给出 3 个差异化切入点与所需成本评估。

## 输出
- 一页简报：热度/竞争/变现/SWOT
- 3 个切入点建议与优先级

## 约束
- 关键数据标注来源；信息不足处明确写「待验证」，不编造。""",
    },
    {
        "skill_id": "official-ai-product-copy",
        "name": "AI产品详情文案",
        "icon": "🛒",
        "cat": "自媒体",
        "trigger": "给文件包/数字产品写售卖详情页文案",
        "tools": [],
        "est_credits": [0, 50],
        "params": [
            {"name": "产品", "required": True, "desc": "产品名称与内容", "example": "AI生图工作流文件包"},
            {"name": "卖点", "required": False, "desc": "核心卖点", "example": "一键跑通/免部署"},
        ],
        "content": """# AI产品详情文案

## 目标
为「{产品}」写一段高转化、零人工维护友好的详情页文案。

## 输入参数
- 产品：{产品}
- 卖点：{卖点}

## 步骤
1. 明确目标用户与使用结果（强调拿到就能用、省时间）。
2. 按「结果-内容清单-适合谁-如何交付-常见问题」结构写文案。
3. 不承诺1对1答疑/教程，符合文件包被动交付模式。

## 输出
- 标题 + 详情正文
- 内容清单与FAQ

## 约束
- 真实描述、不夸大效果；不出现承诺人工服务的表述。""",
    },
]

def main():
    existing = get_existing_ids()
    print("existing official skill ids:", len(existing))
    now = time.time()
    inserted, skipped = 0, 0
    for s in SKILLS:
        if s["skill_id"] in existing:
            skipped += 1
            print("skip (exists):", s["skill_id"])
            continue
        meta = {
            "skill_id": s["skill_id"],
            "scope": "official",
            "icon": s["icon"],
            "version": 1,
            "status": "active",
            "source": "official",
            "params_schema": s["params"],
            "trigger": s["trigger"],
            "tools": s["tools"],
            "call_count": 0,
            "success_count": 0,
            "est_credits": s["est_credits"],
            "category_label": s["cat"],
        }
        payload = {
            "agent_id": AGENT,
            "user_id": "",
            "layer": "long_term",
            "category": "skill",
            "tags": ["skill", "official", s["cat"]],
            "title": s["name"],
            "content": s["content"],
            "importance": 4,
            "metadata": meta,
        }
        try:
            res = post("/memory/save", payload)
            print("inserted:", s["skill_id"], "->", res.get("id") if isinstance(res, dict) else res)
            inserted += 1
        except Exception as e:
            print("ERROR inserting", s["skill_id"], e)
    print(f"DONE inserted={inserted} skipped={skipped}")

if __name__ == "__main__":
    main()
