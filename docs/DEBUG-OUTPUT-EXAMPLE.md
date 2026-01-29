# Debug 输出示例

当 `code-review-orchestrator` skill 运行时，调试输出会显示如下：

## 执行流程示例

```
═════════════════════════════════════════════════════════
🔍 DEBUG [Step 1/6]: Starting - Determine Review Scope
═════════════════════════════════════════════════════════

User request: "review整个项目"

Detected review type: Full Project Review
Projects to review: 2
- eduiot-lab at /projects/bupt/eduiot-lab
- space-server at /projects/bupt/space-server
```

---

```
═════════════════════════════════════════════════════════
🔍 DEBUG [Step 3/6]: Collecting Code Context and Metadata
═════════════════════════════════════════════════════════

Collecting project metadata...

Frontend (eduiot-lab):
  ✓ Path: /projects/bupt/eduiot-lab
  ✓ Language: javascript
  ✓ Files: 119 Vue/JS files
  ✓ LOC: ~19,145
  ✓ Tech Stack: Nuxt.js 2.17.0, Vue 2.7.16, Element UI 2.15.13

Backend (space-server):
  ✓ Path: /projects/bupt/space-server
  ✓ Language: java
  ✓ Files: 104 Java files
  ✓ LOC: ~7,062
  ✓ Tech Stack: Spring Boot 3.5.9, MyBatis Plus 3.5.15

Saved to: /projects/bupt/reviews/full-project-review/code-context.json
```

---

```
═════════════════════════════════════════════════════════
🔍 DEBUG [Checkpoint 1]: Code Context Collected
═════════════════════════════════════════════════════════

📊 Code Review Information Collected
═════════════════════════════════════════════════════════

Review Type: Full project review
Projects: 2 projects (frontend, backend)

Frontend:
  - Path: /projects/bupt/eduiot-lab
  - LOC: ~19,145
  - Tech Stack: Nuxt.js, Vue 2, Element UI

Backend:
  - Path: /projects/bupt/space-server
  - LOC: ~7,062
  - Tech Stack: Spring Boot, MyBatis, MySQL

Working Directory: /projects/bupt/reviews/full-project-review
═════════════════════════════════════════════════════════

Proceed with review? (yes/no)
```

---

```
═════════════════════════════════════════════════════════
🔍 DEBUG [Step 4/6]: Discovering Available Review Skills
═════════════════════════════════════════════════════════

🔍 Checking system-reminder for available skills...
Found 25 skills total
Filtering for code review skills...
Found 4 matching skills:
  1. code-review:code-review
  2. pr-review-toolkit:review-pr
  3. security-scanning:security-auditor
  4. superpowers:code-reviewer
```

---

```
═════════════════════════════════════════════════════════
🔍 DEBUG [Checkpoint 2]: Skill Selection
═════════════════════════════════════════════════════════

🔍 Available Review Skills Discovered
═════════════════════════════════════════════════════════

Found 4 review skills:
1. code-review:code-review - General quality review
2. pr-review-toolkit:review-pr - Comprehensive PR review
3. security-scanning:security-auditor - Security vulnerability check
4. superpowers:code-reviewer - Post-development review

Projects to review:
- Frontend (Nuxt.js) - 119 files, ~19,145 LOC
- Backend (Spring Boot) - 104 files, ~7,062 LOC

Which skills would you like to use for review? (Select multiple)
Recommended: Use 2-4 different skills for comprehensive coverage
═════════════════════════════════════════════════════════

User selected: [code-review:code-review, security-scanning:security-auditor, pr-review-toolkit:review-pr]
```

---

```
═════════════════════════════════════════════════════════
🔍 DEBUG [Step 5/6]: Launching Parallel Subagents
═════════════════════════════════════════════════════════

🚀 Launching Parallel Subagents
═════════════════════════════════════════════════════════

Subagent 1: code-review:code-review
  - Review scope: Frontend (Nuxt.js)
  - Output: reports/code-review-report.md

Subagent 2: security-scanning:security-auditor
  - Review scope: Both projects
  - Output: reports/security-report.md

Subagent 3: pr-review-toolkit:review-pr
  - Review scope: All files
  - Output: reports/pr-review-report.md
═════════════════════════════════════════════════════════

Agent 1 (code-review): ⏳ Starting...
Agent 2 (security):    ⏳ Starting...
Agent 3 (pr-review):    ⏳ Starting...
```

---

```
🔍 DEBUG: Subagent Status Update

Agent 1 (code-review): ✅ Complete - Report saved
Agent 2 (security):    ⏳ Running... (45% complete)
Agent 3 (pr-review):    ⏳ Running... (30% complete)

Waiting for all agents to complete...
```

---

```
🔍 DEBUG: All Subagents Complete

Agent 1 (code-review): ✅ Complete
Agent 2 (security):    ✅ Complete
Agent 3 (pr-review):    ✅ Complete

All reports generated successfully!
```

---

```
═════════════════════════════════════════════════════════
🔍 DEBUG [Step 6/6]: Generating Consolidated Summary
═════════════════════════════════════════════════════════

📊 Collecting Reports from Subagents
═════════════════════════════════════════════════════════

Found 3 reports in reports/ directory:
✓ code-review-report.md (32 issues found)
✓ security-report.md (19 issues found)
✓ pr-review-report.md (25 issues found)

Total issues to consolidate: 76 issues
═════════════════════════════════════════════════════════

Categorizing issues by severity...
- Critical: 3 issues
- High: 13 issues
- Medium: 31 issues
- Low: 29 issues

Generating consolidated summary...
Saved to: /projects/bupt/reviews/full-project-review/summary.md
═════════════════════════════════════════════════════════

✅ Review Complete!
```

## 调试输出的作用

### 1. 进度追踪
- 知道当前执行到哪一步 `[Step X/6]`
- 了解每个步骤的状态

### 2. 数据验证
- 确认收集到的项目信息正确
- 验证选中的skills符合预期
- 检查子代理配置

### 3. 问题定位
- 如果skill卡住，可以看到卡在哪一步
- 如果子代理失败，可以看到是哪个agent失败
- 如果文件没生成，可以看到是否成功启动

### 4. 执行理解
- 理解skill的工作流程
- 了解每个步骤做什么
- 学习如何使用skill

## 禁用调试模式

当你不需要调试输出时，可以删除SKILL.md中所有带有 🔍 标记的行：

```bash
# 方法1: 手动删除
vim skills/code-review-orchestrator/SKILL.md
# 删除所有包含 🔍 的行

# 方法2: 使用sed删除
sed -i '/🔍/d' skills/code-review-orchestrator/SKILL.md
```

或者保留调试输出，只在生产环境中设置环境变量来控制是否显示。

## 自定义调试输出

你可以根据自己的需要添加更多调试输出：

```markdown
**🔍 DEBUG**: 你的调试信息

使用Bash工具执行调试命令:
```bash
echo "🔍 DEBUG: 当前工作目录: $(pwd)"
echo "🔍 DEBUG: 文件列表:"
ls -lh
```
```
