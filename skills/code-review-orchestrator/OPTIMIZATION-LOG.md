# Code Review Orchestrator - 优化日志

**优化日期**: 2026-01-30
**优化版本**: 0.2.1 → 0.3.0
**优化人**: Claude Code

---

## 更新记录

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| 0.4.0 | 2026-01-30 | 添加可配置的debug模式开关功能 |
| 0.3.2 | 2026-01-30 | 修复技能选择界面和总结报告模板 |
| 0.3.1 | 2026-01-30 | 工作目录命名优化（日期+序号），避免重复审查冲突 |
| 0.3.0 | 2026-01-30 | 优化用户确认、技能发现、文件命名、问题标注（完整技能名称） |
| 0.2.1 | 2026-01-29 | 初始版本，支持并行审查 |

---

## 优化概述

根据用户反馈的两个实际使用案例（mr557-aihub-refactor 和 full-project-review），对 code-review-orchestrator 技能进行了全面优化。

---

## 优化内容

### 1. 用户确认流程优化 ✅

**问题**: 两次review的确认方式不一致，mr557使用了友好的交互界面，而bupt那次没有。

**解决方案**:
- 在所有关键确认点使用 `AskUserQuestion` 工具，而不是文本提示
- 提供结构化的选项供用户选择
- 确保用户确认的一致性

**修改位置**: SKILL.md Step 3 和 Step 4

**修改前**:
```text
Proceed with review? (yes/no)
```

**修改后**:
```python
AskUserQuestion(
    questions=[
        {
            "question": "代码审查信息已收集，是否继续？",
            "header": "确认审查",
            "options": [
                {
                    "label": "继续审查",
                    "description": "开始执行代码审查，启动并行子代理"
                },
                {
                    "label": "取消",
                    "description": "取消本次审查，退出技能"
                }
            ],
            "multiSelect": False
        }
    ]
)
```

---

### 2. 技能发现逻辑完善 ✅

**问题**: 两次review时供用户选择的review技能都不全，不如直接打出/review后提示的那么全。

**解决方案**:
- 扩展技能列表，从6个增加到20+个
- 包含更多pr-review-toolkit家族的技能
- 包含comprehensive-review家族的技能
- 包含其他相关review技能

**新增技能列表**:
- `pr-review-toolkit:silent-failure-hunter` - 静默失败检测
- `pr-review-toolkit:code-simplifier` - 代码简化分析
- `pr-review-toolkit:comment-analyzer` - 注释分析
- `pr-review-toolkit:pr-test-analyzer` - PR测试分析
- `pr-review-toolkit:type-design-analyzer` - 类型设计审查
- `comprehensive-review:code-reviewer` - 深度代码分析
- `comprehensive-review:architect-review` - 架构审查
- `comprehensive-review:security-auditor` - 综合安全审计
- `code-review-ai:code-review` - AI驱动代码审查
- `codebase-cleanup:code-reviewer` - 代码清理审查
- `feature-dev:code-reviewer` - 功能开发审查
- `feature-dev:code-explorer` - 代码探索

**修改位置**: SKILL.md Step 4

---

### 3. 文件命名规范统一 ✅

**问题**: 两次review的文件命名不一致
- mr557: `mr557-comprehensive-summary.md`, `debug-session-report.md`
- bupt: `full-project-summary.md`, `DEBUG-SESSION.md`

**解决方案**: 统一文件命名规范

**统一标准**:
```
reviews/{review_name}/
├── code-context.json                     # 元数据（小写+连字符）
├── diff.patch                             # Git diff
├── commits.json                           # 提交历史
├── branch-info.json                       # 分支信息
├── DEBUG-SESSION.md                       # 调试日志（固定大写）
├── {review_name}-comprehensive-summary.md # 综合总结（固定后缀）
└── reports/                               # 子代理报告
    ├── skill-name-report.md               # 技能报告
    └── ...
```

**命名规则**:
1. **Summary文件**: 必须使用 `-comprehensive-summary.md` 后缀
2. **Debug日志**: 必须使用 `DEBUG-SESSION.md`（固定名称，大写）
3. **技能报告**: `{skill-short-name}-report.md`
4. **上下文文件**: 小写加连字符（code-context.json, diff.patch）

**修改位置**: SKILL.md Step 2 和 Step 6

---

### 4. 总结报告技能来源标注 ✅

**问题**: mr557的报告没有明确标注每个问题是由哪个技能发现的，而bupt的报告有标注（🔵 [CR], 🔴 [SA], 🟢 [CVR]）

**解决方案**: 在总结报告模板中明确要求标注每个问题的技能来源

**模板结构**:
```markdown
## 🤖 Review Skills Used

| Skill Name | Focus Area | Key Contributions |
|------------|------------|-------------------|
| code-review:code-review | 代码质量与最佳实践 | 代码规范、潜在bug、可维护性 |
| security-scanning:security-auditor | 安全漏洞审计 | OWASP Top 10、注入攻击、认证授权 |
| pr-review-toolkit:review-pr | 全面PR审查 | 功能完整性、测试覆盖、文档 |

## 🔴 Critical Issues

### 1. SQL Injection Risk in auth/login.js
- **Location**: `src/auth/login.js:45`
- **Severity**: Critical
- **Found by**: code-review:code-review, security-scanning:security-auditor
- **Issue**: User input directly concatenated into SQL query
```

**关键特性**:
- 每个问题在 "Found by" 字段使用**完整技能名称**
- 使用逗号分隔多个技能：`code-review:code-review, security-scanning:security-auditor`
- 不使用简写符号标签
- 提供技能贡献汇总表，说明每个技能的专注领域

**修改位置**: SKILL.md Step 6

---

### 5. 工作目录命名优化（日期+序号） ✅

**问题**: 重复审查同一MR或项目会导致目录冲突
- 例如：`mr557-aihub-refactor` 和 `full-project-review` 重复执行会覆盖数据
- 无法区分同一项目的多次审查

**解决方案**: 工作目录命名增加日期和序号

**命名格式**: `{review_name}-{YYYYMMDD}-{sequence}`

**示例**:
```
第一次审查 (2026-01-30):  mr557-aihub-refactor-20260130-1
第二次审查 (同一天):      mr557-aihub-refactor-20260130-2
第二天第一次审查:        mr557-aihub-refactor-20260131-1
```

**实现逻辑**:
```bash
# 获取当前日期
DATE=$(date +%Y%m%d)

# 基础目录名
BASE_DIR="{review_name}-${DATE}"

# 查找现有目录数量
EXISTING=$(find reviews -maxdepth 1 -name "${BASE_DIR}-*" | wc -l)

# 计算下一个序号
SEQUENCE=$((EXISTING + 1))

# 最终目录名
WORKING_DIR="${BASE_DIR}-${SEQUENCE}"
```

**优势**:
- ✅ 避免目录冲突
- ✅ 可追溯审查时间
- ✅ 保留历史审查记录
- ✅ 便于对比多次审查结果

**修改位置**: SKILL.md Step 2

---

### 6. 技能选择界面优化 ✅

**问题**: 实际使用中发现两个问题
1. 只显示4个技能选项，但DEBUG日志显示发现了20+个技能
2. AskUserQuestion的label使用中文翻译（如"通用代码审查"），而非"技能原名+中文说明"格式

**解决方案**: 完善技能选择界面，确保：
1. 在DEBUG输出中显示所有发现的技能（按分类展示）
2. AskUserQuestion的label使用完整的技能原名
3. Description包含"技能原名+中文说明"格式

**修改前**:
```python
# 只给4个选项，label用中文翻译
skill_options = [
    {"label": "通用代码审查", "description": "代码质量与最佳实践"},
    {"label": "安全审查", "description": "安全漏洞扫描"},
    {"label": "架构审查", "description": "架构和设计模式"},
    {"label": "测试分析", "description": "测试覆盖率分析"}
]
```

**修改后**:
```python
# 先显示所有发现的技能
print("🔍 根据可用的技能列表，我发现以下适合审查的技能：\n")
print("代码质量与架构审查:")
for skill in code_quality_skills:
    print(f"  - {skill['name']} - {skill['description']}")
# ... 其他分类

# AskUserQuestion使用完整技能名
skill_options = [
    {
        "label": "code-review:code-review",  # 完整技能名
        "description": "通用代码质量审查 - 代码规范、潜在bug、可维护性"
    },
    {
        "label": "security-scanning:security-auditor",  # 完整技能名
        "description": "安全漏洞审计 - OWASP Top 10、注入攻击、认证授权"
    },
    # ... 所有发现的技能
]
```

**关键规则**:
- DEBUG输出: 使用 "技能原名: 中文说明" 格式
- AskUserQuestion label: 必须是完整技能名（如"code-review:code-review"）
- AskUserQuestion description: 包含技能名+中文说明，便于理解

**修改位置**: SKILL.md Step 4

---

### 7. 总结报告问题标注强制化 ✅

**问题**: 实际使用中发现
- mr557报告有标注（"security-auditor发现"），但使用的是简称
- full-project报告完全缺少"Found by"字段
- 技能表格存在，但具体问题没有标注来源

**解决方案**: 在模板中添加强制规则，确保每个问题都有"Found by"字段

**模板规则**:
```markdown
### 1. SQL Injection Risk in auth/login.js
- **Location**: `src/auth/login.js:45`
- **Severity**: Critical
- **Found by**: code-review:code-review, security-scanning:security-auditor
- **Issue**: User input directly concatenated into SQL query
- **Recommendation**: Use parameterized queries
```

**强制规则**:
1. **每个问题必须包含 "Found by" 字段**
2. 使用**完整技能名称**（如"code-review:code-review"）
3. 多个技能用**逗号分隔**
4. **不使用简写符号**（如[CR]、[SA]）
5. 如果不确定，检查各个技能的单独报告

**修改位置**: SKILL.md Step 6

---

### 8. 可配置的Debug模式开关 ✅

**用户需求**: 在开始审查时，希望通过某种开关（人工确认或提示词包含特定内容）来开启debug记录，自动将整个session的所有对话和交互输出到DEBUG-SESSION.md中。

**解决方案**: 添加Step 0来检测和确认debug模式，并在Step 7生成完整的DEBUG-SESSION.md文件。

**实现方式**:

**1. 自动检测关键词**:
```python
# 检测用户输入中的debug关键词
debug_keywords = [
    'debug', 'verbose', 'detail', 'log', 'trace',
    '--debug', '-v', '--verbose',
    '调试', '详细', '日志', '记录'
]

debug_mode = any(keyword in user_input.lower() for keyword in debug_keywords)
```

**2. 交互式确认**:
```python
# 如果没有检测到关键词，询问用户
AskUserQuestion(
    questions=[
        {
            "question": "是否启用详细调试日志？\n\n启用后会记录完整的审查过程，包括：\n- 所有决策点和选择\n- 子代理启动和完成状态\n- 时间戳和进度信息\n- 完整的交互历史\n\n生成的日志将保存到 DEBUG-SESSION.md 文件中。",
            "header": "调试模式",
            "options": [
                {"label": "启用调试", "description": "记录完整审查过程到DEBUG-SESSION.md"},
                {"label": "不启用", "description": "仅显示基本进度信息，不生成详细日志"}
            ],
            "multiSelect": False
        }
    ]
)
```

**3. DEBUG-SESSION.md内容**:
记录完整的审查会话信息，包括：
- 会话配置（用户输入、项目信息、工作目录）
- 执行时间线（每个步骤的开始和结束时间）
- 文件生成列表
- 关键决策和理由
- 遇到的问题和解决方案
- 性能指标（执行时间、资源使用）
- 发现的问题汇总
- 技术细节和环境信息
- 错误日志（如果有）

**使用方式**:

**方式1 - 自动触发**:
```
用户: "Review my code with debug"
结果: 自动启用debug模式
```

**方式2 - 交互式选择**:
```
用户: "Review my code"
AI: 弹出确认对话框询问是否启用debug模式
用户: 选择"启用调试"
结果: 启用debug模式
```

**方式3 - 强制开启**:
如果希望每次都启用debug模式，可以修改Step 0为：
```python
debug_mode = True  # 强制开启
```

**优势**:
- ✅ 用户可选择是否需要详细日志
- ✅ 支持关键词自动触发
- ✅ 完整记录审查过程，便于追溯
- ✅ 包含时间戳和性能指标
- ✅ 结构化的markdown格式
- ✅ 不影响正常使用体验

**修改位置**: SKILL.md Step 0, Step 7

**版本**: 0.3.2 → 0.4.0

---

## 对比分析

### 优化前 vs 优化后

| 维度 | 0.3.2 | 0.4.0 |
|------|------|------|
| Debug模式 | 硬编码开启，所有输出都用🔍标记 | 可配置开关，支持关键词或交互确认 |
| 日志记录 | 混在正常输出中 | 独立保存到DEBUG-SESSION.md |
| 时间记录 | 部分步骤有 | 完整的时间线记录 |
| 性能指标 | 无 | 包含执行时间、资源使用统计 |
| 错误追踪 | 分散在各处 | 集中在错误日志部分 |
| 用户选择 | 无法控制 | 用户可选择是否启用debug |

### 历史版本对比

| 维度 | 优化前 (0.3.1) | 优化后 (0.3.2) |
|------|--------|--------|
| 用户确认 | AskUserQuestion结构化选项 | AskUserQuestion结构化选项 |
| 技能发现显示 | 20+个技能，但只显示4个选项 | DEBUG显示所有技能，完整展示 |
| 技能选择格式 | 中文翻译（"通用代码审查"） | 技能原名+说明（"code-review:code-review"） |
| 问题标注 | 可选/简写符号/缺失 | 强制标注完整技能名称 |
| 总结报告 | 部分报告缺少"Found by" | 每个问题都有"Found by"字段 |
| 用户体验 | 一致的友好交互 | 更清晰、更完整的信息展示 |

### 历史版本对比

| 版本 | 主要改进 |
|------|----------|
| 0.2.1 → 0.3.0 | 用户确认AskUserQuestion、技能发现扩展到20+、文件命名统一、问题标注完整技能名称 |
| 0.3.0 → 0.3.1 | 工作目录命名优化（日期+序号），避免重复审查冲突 |
| 0.3.1 → 0.3.2 | 技能选择界面优化（显示所有技能、原名格式）、总结报告问题标注强制化 |
| 0.3.2 → 0.4.0 | 添加可配置的debug模式开关（关键词检测+交互确认）、独立DEBUG-SESSION.md日志文件 |

---

## 测试验证

### 测试用例

**测试1: MR审查**
- 项目: aihub-parent
- MR: 557
- 预期文件名: `mr557-aihub-refactor-comprehensive-summary.md`
- 预期交互: AskUserQuestion两次（确认信息、选择技能）

**测试2: 全项目审查**
- 项目: frontend + backend
- 预期文件名: `full-project-comprehensive-summary.md`
- 预期交互: AskUserQuestion两次（确认信息、选择技能）
- 预期标注: 每个问题都有技能标签

---

## 向后兼容性

**版本**: 0.3.0
**破坏性变更**: 无
**兼容性**: 完全向后兼容

**说明**:
- 新的AskUserQuestion用法不影响旧版本生成的报告
- 文件命名规范变更仅为推荐，不强制
- 技能标注为新增要求，不影响旧报告

---

## 使用建议

### 用户使用优化后的技能时:

1. **享受更好的交互体验**
   - 使用结构化的选择界面
   - 清晰的选项说明
   - 一致的操作流程

2. **利用扩展的技能库**
   - 根据项目类型选择合适的技能组合
   - 尝试新的专项审查技能（如silent-failure-hunter）
   - 使用推荐组合快速开始

3. **参考统一的报告格式**
   - 技能标签帮助快速定位问题来源
   - 技能贡献统计了解各技能特点
   - 标准化的文件命名便于管理

4. **提供反馈**
   - 如果发现某些技能未包含，请告知
   - 如果交互体验需要改进，请提出建议
   - 继续优化技能库

---

## 未来改进方向

1. **技能自动发现**
   - 自动扫描系统中的所有review技能
   - 根据项目类型推荐最佳技能组合
   - 技能能力索引

2. **模板化报告**
   - 支持自定义报告格式
   - 导出为JSON、HTML等格式
   - 集成到CI/CD流程

3. **历史记录管理**
   - 保存审查历史
   - 对比不同版本的审查结果
   - 跟踪问题修复状态

4. **智能去重**
   - 自动识别重复问题
   - 合并相似问题
   - 优先级智能排序

---

## 相关文件

- **主技能文件**: [SKILL.md](SKILL.md)
- **优化日志**: 本文件
- **参考文档**:
  - [references/subagent-coordination.md](references/subagent-coordination.md)
  - [references/report-formatting.md](references/report-formatting.md)
  - [references/issue-categories.md](references/issue-categories.md)

---

**优化完成** ✅
**状态**: 已测试，可供使用
