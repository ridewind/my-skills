# Code Review Orchestrator - 多轮技能选择示例

**版本**: 0.5.0
**日期**: 2026-01-30

---

## 概述

从 0.5.0 版本开始，code-review-orchestrator 支持通过多轮交互来自由选择审查技能，完全解决了之前4个预设组合的限制。

---

## 使用流程示例

### 场景1：审查前端+后端项目，选择代码质量和安全审计

#### Step 1: 启动审查

```
User: Review my frontend and backend projects
Frontend: Nuxt.js + Vue 2
Backend: Spring Boot + Java 21
```

#### Step 2: AI收集项目信息并确认

```
AI: 🔍 DEBUG [Step 1/7]: Starting - Determine Review Scope

发现2个项目需要审查：

Frontend:
  - Path: /projects/myapp/frontend
  - LOC: ~13,800
  - Tech Stack: Nuxt.js, Vue 2

Backend:
  - Path: /projects/myapp/backend
  - LOC: ~7,000
  - Tech Stack: Spring Boot, Java 21

[确认审查]
```

#### Step 3: AI发现可用技能并显示

```
AI: 🔍 DEBUG [Step 4/7]: Discovering available review skills

═════════════════════════════════════════════════════════
🔍 发现可用的审查技能
═════════════════════════════════════════════════════════

**代码质量** (6个技能):
  • code-review:code-review
  • comprehensive-review:code-reviewer
  • code-review-ai:code-review
  • codebase-cleanup:code-reviewer
  • feature-dev:code-reviewer
  • code-documentation:code-reviewer

**安全审计** (3个技能):
  • security-scanning:security-auditor
  • comprehensive-review:security-auditor
  • security-scanning:threat-modeling-expert

**性能+架构** (4个技能):
  • comprehensive-review:architect-review
  • application-performance:performance-engineer
  • backend-development:backend-architect
  • application-performance:observability-engineer

**测试+清理** (5个技能):
  • pr-review-toolkit:pr-test-analyzer
  • unit-testing:test-automator
  • pr-review-toolkit:code-simplifier
  • pr-review-toolkit:comment-analyzer
  • pr-review-toolkit:type-design-analyzer

═════════════════════════════════════════════════════════
🔍 共发现 18 个审查技能
═════════════════════════════════════════════════════════
```

#### Step 4: 第一轮 - 选择审查类别

```
┌─────────────────────────────────────────────────────────┐
│ 🔍 审查类别                                              │
├─────────────────────────────────────────────────────────┤
│ 请选择审查类别（可多选）:                               │
│                                                         │
│ **代码质量** (6个技能): 代码规范、潜在bug、可维护性    │
│ **安全审计** (3个技能): 安全漏洞、OWASP Top 10          │
│ **性能+架构** (4个技能): 性能优化、架构审查             │
│ **测试+清理** (5个技能): 测试覆盖、代码清理             │
│                                                         │
│ ☐ 代码质量                                              │
│    包含 code-review, comprehensive-reviewer,           │
│    code-review-ai, codebase-cleanup, feature-dev,      │
│    code-documentation                                   │
│                                                         │
│ ☑ 安全审计                                              │
│    包含 security-auditor, comprehensive-security,       │
│    threat-modeling-expert                               │
│                                                         │
│ ☐ 性能+架构                                             │
│                                                         │
│ ☐ 测试+清理                                             │
│                                                         │
│ ✔ Submit                                                │
└─────────────────────────────────────────────────────────┘

User: 选择 "安全审计"
```

#### Step 5: 第二轮 - 选择安全审计类别的具体技能

```
┌─────────────────────────────────────────────────────────┐
│ 🔍 安全审计技能                                         │
├─────────────────────────────────────────────────────────┤
│ 请选择**安全审计**类别的具体技能（可多选）:            │
│                                                         │
│ **安全漏洞**: security-scanning:security-auditor        │
│ **综合安全**: comprehensive-review:security-auditor     │
│ **威胁建模**: security-scanning:threat-modeling-expert  │
│                                                         │
│ ☑ security-scanning:security-auditor                   │
│    安全漏洞 - OWASP Top 10、注入攻击                    │
│                                                         │
│ ☑ comprehensive-review:security-auditor                │
│    综合安全审计 - 全面安全分析                          │
│                                                         │
│ ☐ security-scanning:threat-modeling-expert             │
│    威胁建模 - 安全架构分析                              │
│                                                         │
│ ☐ 使用全部安全审计技能                                  │
│    使用该类别下的所有3个技能                            │
│                                                         │
│ ✔ Submit                                                │
└─────────────────────────────────────────────────────────┘

User: 选择前两个技能
```

#### Step 6: AI汇总选择并启动审查

```
AI: 🔍 DEBUG [Checkpoint 2.3]: User's skill selection

选中的技能:
1. security-scanning:security-auditor
2. comprehensive-review:security-auditor

🚀 启动2个子代理进行并行审查...

═════════════════════════════════════════════
Subagent 1: security-scanning:security-auditor
  - Review scope: Both projects (frontend + backend)
  - Output: reports/security-auditor-report.md

Subagent 2: comprehensive-review:security-auditor
  - Review scope: Both projects (frontend + backend)
  - Output: reports/comprehensive-security-report.md
═════════════════════════════════════════════
```

---

## 场景2：选择多个类别

### Step 4: 第一轮 - 选择多个类别

```
User: 选择 "代码质量" + "安全审计" + "性能+架构"
```

### Step 5: 第二轮 - 逐个选择具体技能

#### 5.1: 代码质量技能

```
User: 选择 "code-review:code-review" + "comprehensive-review:code-reviewer"
```

#### 5.2: 安全审计技能

```
User: 选择 "使用全部安全审计技能"
```

#### 5.3: 性能+架构技能

```
User: 选择 "comprehensive-review:architect-review"
```

### 最终选择的技能

```
AI: 🔍 DEBUG: Final skill selection

选中的技能 (共4个):
1. code-review:code-review (代码质量)
2. comprehensive-review:code-reviewer (代码质量)
3. security-scanning:security-auditor (安全审计)
4. comprehensive-review:security-auditor (安全审计)
5. security-scanning:threat-modeling-expert (安全审计)
6. comprehensive-review:architect-review (性能+架构)

🚀 启动6个子代理进行并行审查...
```

---

## 场景3：使用"全部技能"快捷选项

### 第一轮: 选择类别

```
User: 选择 "代码质量"
```

### 第二轮: 使用快捷选项

```
User: 选择 "使用全部代码质量技能"

AI: 自动选中该类别下的所有6个技能:
  - code-review:code-review
  - comprehensive-review:code-reviewer
  - code-review-ai:code-review
  - codebase-cleanup:code-reviewer
  - feature-dev:code-reviewer
  - code-documentation:code-reviewer
```

---

## 技能分类参考

| 类别 | 技能数量 | 包含技能 |
|------|---------|----------|
| **代码质量** | 6个 | code-review, comprehensive-reviewer, code-review-ai, codebase-cleanup, feature-dev, code-documentation |
| **安全审计** | 3个 | security-auditor, comprehensive-security, threat-modeling-expert |
| **性能+架构** | 4个 | architect-review, performance-engineer, backend-architect, observability-engineer |
| **测试+清理** | 5个 | pr-test-analyzer, test-automator, code-simplifier, comment-analyzer, type-design-analyzer |

**总计**: 18个审查技能

---

## 关键改进

### 0.4.0 vs 0.5.0

| 维度 | 0.4.0 (旧版本) | 0.5.0 (新版本) |
|------|---------------|---------------|
| 选择方式 | 单轮选择，4个预设组合 | 多轮选择，类别→具体技能 |
| 自由度 | 只能选择预设组合 | 完全自由选择任何技能 |
| 透明度 | 组合描述不够具体 | 每个技能都清晰列出 |
| 灵活性 | 低 | 高 |
| 用户体验 | 受限 | 完全控制 |

---

## 总结

**0.5.0 版本的核心改进**:
- ✅ 通过多轮选择突破了4选项限制
- ✅ 用户可以自由选择任何技能组合
- ✅ 支持多选，可以一次选择多个类别和技能
- ✅ 提供"使用全部技能"快捷选项
- ✅ 清晰的技能分类和组织
- ✅ 完全透明的技能列表

**适用场景**:
- 需要特定技能组合的审查
- 希望自由控制审查范围
- 需要针对性审查（如安全专项、性能专项）
- 想要全面审查但想了解具体使用了哪些技能
