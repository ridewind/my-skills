# Code Review Orchestrator - 技能选择界面问题分析

**分析日期**: 2026-01-30
**问题版本**: 0.4.0

---

## 问题概述

用户在使用 code-review-orchestrator 时遇到两个关键问题:

1. **"最多4个"限制**: AI发现20+个可用技能,但用户只能看到4个选项
2. **技能组合不透明**: 用户不知道每个"组合"选项具体包含哪些技能

---

## 根本原因分析

### 1. "最多4个"限制的来源

**根本原因**: `AskUserQuestion` 工具的 `options` 参数限制为 2-4 个选项

**工具定义**:
```json
{
  "options": {
    "description": "The available choices for this question. Must have 2-4 options.",
    "type": "array",
    "minItems": 2,
    "maxItems": 4
  }
}
```

**影响**:
- 即使AI发现了20+个技能,AskUserQuestion也只能显示4个选项
- 0.3.2版本优化中采用了"DEBUG显示所有技能 + AskUserQuestion提供4个预设组合"的折中方案

### 2. 当前实现的局限性

**SKILL.md (Step 4) 当前方案**:

```python
# DEBUG输出显示所有技能 (按分类)
print("🔍 根据可用的技能列表,我发现以下适合审查的技能：\n")
print("代码质量与架构审查:")
for skill in code_quality_skills:
    print(f"  - {skill['name']} - {skill['description']}")
# ... 其他分类

# AskUserQuestion只提供4个选项
skill_options = [
    {
        "label": "code-review:code-review",
        "description": "通用代码质量审查 - 代码规范、潜在bug、可维护性"
    },
    {
        "label": "security-scanning:security-auditor",
        "description": "安全漏洞审计 - OWASP Top 10、注入攻击、认证授权"
    },
    # ... 最多4个
]
```

**实际AI执行时的问题**:

AI可能将技能分组为"组合",但没有明确说明组合内容:

```
❯ 1. [ ] 推荐组合
  包含4个核心技能 - 通用代码审查 + 安全审计 + 架构审查 + 测试分析
```

问题:
- ✅ 提到了4个技能类型
- ❌ 没有提供具体的skill名称(如 `code-review:code-review`)
- ❌ 用户无法确定具体会调用哪些技能
- ❌ 无法选择自己想要的特定技能

---

## 解决方案

### 方案1: 透明化技能组合 (推荐)

**核心思路**: 在description中明确列出所有技能名称

**实现示例**:
```python
skill_options = [
    {
        "label": "推荐组合",
        "description": """
包含4个核心技能:
• code-review:code-review (通用代码质量)
• security-scanning:security-auditor (安全漏洞审计)
• comprehensive-review:architect-review (架构审查)
• pr-review-toolkit:pr-test-analyzer (测试质量)

适合: 全面审查,覆盖代码质量、安全、架构、测试
"""
    },
    {
        "label": "语言专家组合",
        "description": """
包含2个专家技能:
• javascript-typescript:javascript-pro (前端JavaScript专家)
• jvm-languages:java-pro (后端Java专家)

适合: 需要语言特定最佳实践和深度优化
"""
    },
    {
        "label": "性能优化组合",
        "description": """
包含3个性能相关技能:
• application-performance:performance-engineer (性能优化)
• codebase-cleanup:code-reviewer (代码清理)
• comprehensive-review:architect-review (架构审查)

适合: 性能瓶颈分析和代码优化
"""
    },
    {
        "label": "使用所有技能",
        "description": "使用所有20+个发现的技能进行全方位审查(耗时较长)"
    }
]
```

**优点**:
- ✅ 用户明确知道每个选项的具体技能
- ✅ 符合AskUserQuestion的4选项限制
- ✅ 保持预设组合的便利性
- ✅ 用户可以根据技能名称做明智选择

**缺点**:
- ⚠️ description会较长
- ⚠️ 仍然无法选择任意技能组合

---

### 方案2: 优先级列表 + Type something

**核心思路**: 提供3个最常用的组合 + 允许自定义

**实现示例**:
```python
skill_options = [
    {
        "label": "code-review:code-review",
        "description": "通用代码质量审查 - 代码规范、潜在bug、可维护性"
    },
    {
        "label": "security-scanning:security-auditor",
        "description": "安全漏洞审计 - OWASP Top 10、注入攻击、认证授权"
    },
    {
        "label": "comprehensive-review:architect-review",
        "description": "架构审查 - 架构完整性、可扩展性、设计模式"
    },
    {
        "label": "Type something",
        "description": "手动输入技能名称,如: pr-review-toolkit:review-pr, javascript-typescript:javascript-pro"
    }
]
```

**优点**:
- ✅ 用户可以选择最常用的技能
- ✅ Type something允许自定义技能组合
- ✅ 符合AskUserQuestion限制
- ✅ 灵活性最高

**缺点**:
- ⚠️ 用户需要知道准确的技能名称
- ⚠️ Type something需要用户手动输入多个技能(可能很麻烦)

---

### 方案3: 两步选择 (最优但复杂)

**核心思路**: 第一步选择类别,第二步选择具体技能

**实现示例**:

**Step 4.1: 选择审查类别**
```python
AskUserQuestion(
    questions=[{
        "question": "请选择审查类别:",
        "header": "审查类别",
        "options": [
            {
                "label": "代码质量",
                "description": "代码规范、潜在bug、可维护性分析"
            },
            {
                "label": "安全审计",
                "description": "安全漏洞、OWASP Top 10、注入攻击"
            },
            {
                "label": "架构审查",
                "description": "架构完整性、设计模式、可扩展性"
            },
            {
                "label": "全面审查",
                "description": "使用所有类别的技能进行全方位审查"
            }
        ],
        "multiSelect": True
    }]
)
```

**Step 4.2: 根据类别显示具体技能**
```python
# 根据用户选择的类别,构建具体的技能列表
# 但这里仍然受到AskUserQuestion的4选项限制
```

**问题**:
- ❌ 两步选择仍然受限于4选项
- ❌ 实现复杂度高
- ❌ 用户体验可能不如单步选择

---

## 推荐方案: 混合方案 (方案1 + 优化)

结合方案1的优点,提供更清晰的技能组合说明:

### 实现模板

```python
# Step 4: Discover Available Review Skills

# 1. 首先在DEBUG输出中显示所有发现的技能(按分类)
print("🔍 DEBUG [Step 4/7]: 发现可用的审查技能\n")
print("让我检查可用的技能列表:\n")

print("=" * 70)
print("可用的审查技能列表")
print("=" * 70)

print("\n**代码质量与架构审查**:")
code_quality_skills = [
    ("code-review:code-review", "通用代码质量审查"),
    ("comprehensive-review:code-reviewer", "深度代码分析和架构审查"),
    ("comprehensive-review:architect-review", "架构和设计模式审查"),
    ("codebase-cleanup:code-reviewer", "代码库清理和优化审查"),
]
for name, desc in code_quality_skills:
    print(f"  • {name}")
    print(f"    {desc}")

print("\n**安全审查**:")
security_skills = [
    ("security-scanning:security-auditor", "安全漏洞审计 (OWASP Top 10)"),
    ("comprehensive-review:security-auditor", "综合安全审计"),
    ("security-scanning:threat-modeling-expert", "威胁建模和安全分析"),
]
for name, desc in security_skills:
    print(f"  • {name}")
    print(f"    {desc}")

print("\n**语言专家**:")
language_skills = [
    ("javascript-typescript:javascript-pro", "JavaScript专家审查 (前端)"),
    ("jvm-languages:java-pro", "Java专家审查 (后端)"),
    ("backend-development:backend-architect", "后端架构专家"),
]
for name, desc in language_skills:
    print(f"  • {name}")
    print(f"    {desc}")

print("\n**性能优化**:")
performance_skills = [
    ("application-performance:performance-engineer", "性能优化审查"),
    ("codebase-cleanup:code-reviewer", "代码清理和优化"),
]
for name, desc in performance_skills:
    print(f"  • {name}")
    print(f"    {desc}")

print("\n**测试和质量**:")
test_skills = [
    ("pr-review-toolkit:pr-test-analyzer", "测试覆盖率和质量分析"),
    ("unit-testing:test-automator", "测试自动化和质量工程"),
]
for name, desc in test_skills:
    print(f"  • {name}")
    print(f"    {desc}")

print("\n**PR/MR特定审查**:")
pr_skills = [
    ("pr-review-toolkit:review-pr", "全面PR审查 (多维度分析)"),
    ("pr-review-toolkit:silent-failure-hunter", "静默失败和错误处理检测"),
    ("pr-review-toolkit:code-simplifier", "代码简化和清晰度分析"),
]
for name, desc in pr_skills:
    print(f"  • {name}")
    print(f"    {desc}")

print("=" * 70)
print(f"🔍 DEBUG [Checkpoint 2]: 已发现 {len(all_skills)} 个适合审查的技能\n")

# 2. 然后使用AskUserQuestion提供4个组合选项
print("现在向用户展示技能选择选项:\n")

AskUserQuestion(
    questions=[
        {
            "question": f"""
**发现 {len(all_skills)} 个可用审查技能**

**待审查项目**:
- 前端: Nuxt.js + Vue 2 (~118 文件)
- 后端: Spring Boot + Java 21 (~107 Java文件)

**核心技能**:
{chr(10).join([f"• {name} ({desc})" for name, desc in selected_skills])}

请选择审查组合:
""",
            "header": "选择审查技能",
            "options": [
                {
                    "label": "推荐组合",
                    "description": """
包含4个核心技能,提供全面覆盖:
• code-review:code-review - 通用代码质量
• security-scanning:security-auditor - 安全漏洞审计
• comprehensive-review:architect-review - 架构审查
• pr-review-toolkit:pr-test-analyzer - 测试质量

适合: 全面审查,覆盖代码质量、安全、架构、测试
""".strip()
                },
                {
                    "label": "语言专家组合",
                    "description": """
包含2个语言专家技能,深度优化:
• javascript-typescript:javascript-pro - JavaScript前端专家
• jvm-languages:java-pro - Java后端专家

适合: 需要语言特定的最佳实践和深度优化
""".strip()
                },
                {
                    "label": "安全+性能组合",
                    "description": """
包含3个技能,专注安全和性能:
• security-scanning:security-auditor - 安全漏洞审计
• application-performance:performance-engineer - 性能优化
• codebase-cleanup:code-reviewer - 代码清理

适合: 安全加固和性能优化场景
""".strip()
                },
                {
                    "label": "使用所有技能",
                    "description": f"""
使用所有{len(all_skills)}个发现的技能进行全方位审查

包含: 代码质量、安全审计、架构审查、语言专家、性能优化、测试分析、PR审查等

⚠️ 注意: 耗时较长,但覆盖最全面
""".strip()
                }
            ],
            "multiSelect": False
        }
    ]
)
```

### 关键改进点

1. **DEBUG输出**: 完整列出所有技能名称和描述
2. **Question description**: 包含核心技能列表(所有技能的名称)
3. **Option description**: 明确列出每个组合包含的所有技能名称
4. **格式统一**: 使用 `• skill-name - description` 格式

---

## 实施建议

### 立即修复 (高优先级)

1. **修改 SKILL.md Step 4**:
   - 在DEBUG输出中完整列出所有技能(使用 `• skill-name` 格式)
   - 在AskUserQuestion的question description中列出核心技能
   - 在每个option的description中明确列出包含的所有技能名称

2. **添加示例**:
   - 在 examples/ 目录中添加技能选择的完整示例
   - 展示DEBUG输出和AskUserQuestion的实际格式

3. **更新版本号**:
   - 版本: 0.4.0 → 0.4.1
   - 在OPTIMIZATION-LOG.md中记录此次修复

### 长期改进 (中优先级)

1. **技能能力索引**:
   - 为每个技能添加标签(如 frontend, backend, security, performance)
   - 根据项目类型自动推荐技能组合

2. **技能依赖检测**:
   - 检测某些技能之间的依赖关系
   - 提示用户相关技能

3. **自定义组合界面**:
   - 如果未来工具支持,实现两步选择或多选功能
   - 允许用户自由组合技能

---

## 测试验证

### 测试用例1: 前端+后端项目

**输入**:
```
Review my frontend and backend projects
Frontend: Nuxt.js + Vue 2
Backend: Spring Boot + Java 21
```

**预期行为**:
1. DEBUG输出显示所有20+个技能
2. AskUserQuestion显示4个组合选项
3. 每个option的description明确列出技能名称
4. 用户选择"推荐组合"后,实际使用description中列出的4个技能

### 测试用例2: 用户选择特定组合

**输入**: 用户选择"语言专家组合"

**预期行为**:
1. 实际使用 `javascript-typescript:javascript-pro`
2. 实际使用 `jvm-languages:java-pro`
3. 不使用其他技能
4. 报告中标注问题来源

### 测试用例3: 用户选择"使用所有技能"

**输入**: 用户选择"使用所有技能"

**预期行为**:
1. 启动所有20+个技能的子代理
2. 并行执行
3. 汇总所有报告
4. 去重问题并标注来源

---

## 总结

**问题根源**: AskUserQuestion的4选项限制 + 技能组合不透明

**推荐方案**:
- 在DEBUG输出中完整列出所有技能
- 在AskUserQuestion的description中明确列出技能名称
- 在每个option的description中列出该组合包含的所有技能

**实施优先级**: 高 - 影响用户体验,急需修复

**预计工作量**: 1-2小时
- 修改SKILL.md Step 4: 30分钟
- 添加示例: 20分钟
- 测试验证: 30分钟
- 更新文档: 10分钟
