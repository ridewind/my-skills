# Code Review Orchestrator - Quick Start Guide

## 🎉 Skill Created Successfully!

Your first skill **code-review-orchestrator** has been created in the my-skills monorepo.

## 📁 Project Structure

```
my-skills/
└── skills/
    └── code-review-orchestrator/
        ├── SKILL.md                          # Main skill file (3,023 words)
        ├── references/                       # Detailed documentation (3 files)
        │   ├── subagent-coordination.md      # Subagent coordination guide
        │   ├── report-formatting.md          # Report structure standards
        │   └── issue-categories.md           # Severity classification
        ├── examples/                         # Working examples (2 files)
        │   ├── code-context-example.json     # Sample metadata
        │   └── summary-example.md            # Sample summary report
        └── scripts/                          # Utility scripts (3 files)
            ├── collect-review-data.sh        # Data collection
            ├── find-merge-base.sh            # Merge base detection
            └── launch-subagents.sh           # Subagent launcher reference
```

## 🚀 How to Use

### Option 1: Use as a Plugin Skill

If you're using Claude Code with plugins, add this as a plugin skill:

1. **Create plugin structure:**
   ```bash
   # In your plugin directory
   mkdir -p .claude-plugin
   touch .claude-plugin/plugin.json
   ```

2. **Configure plugin.json:**
   ```json
   {
     "name": "my-skills",
     "description": "My custom skills",
     "skills": ["skills/code-review-orchestrator"]
   }
   ```

3. **Test with Claude Code:**
   ```bash
   cc --plugin-dir /path/to/my-skills
   ```

4. **Trigger the skill:**
   ```
   Review the feature/auth branch compared to dev
   ```

### Option 2: Use Directly (Development)

During development, you can reference the skill content directly:

1. **Read SKILL.md** to understand the workflow
2. **Use the scripts** in `scripts/` to automate tasks
3. **Follow the workflow** outlined in SKILL.md

## 📚 What's Included

### SKILL.md (Main File)
- Complete workflow for orchestrating code reviews
- Branch comparison, MR/PR review support
- Subagent coordination instructions
- Issue resolution workflow
- Links to all supporting resources

### References (Detailed Documentation)
- **subagent-coordination.md**: How to launch and manage parallel subagents
- **report-formatting.md**: Standards for individual and summary reports
- **issue-categories.md**: Severity classification with examples

### Examples (Working Samples)
- **code-context-example.json**: Sample review metadata structure
- **summary-example.md**: Complete consolidated summary with 18 sample issues

### Scripts (Utility Tools)
- **collect-review-data.sh**: Automates data collection from git
- **find-merge-base.sh**: Finds common ancestor for branch comparison
- **launch-subagents.sh**: Generates Task commands for parallel review

## 🎯 Key Features

✅ **Multiple Review Sources**
- Single branch review
- Branch comparison (with proper merge-base detection)
- GitLab MR and GitHub PR support
- Monorepo subproject support

✅ **Parallel Review Execution**
- Coordinates multiple subagents
- Each uses different review skills
- Runs in parallel for efficiency
- Consolidates results automatically

✅ **Comprehensive Reporting**
- Individual skill reports
- Consolidated summary with severity levels
- Actionable recommendations
- Interactive issue resolution

✅ **Best Practices Built-in**
- Proper git diff formats (three-dot for branch comparison)
- Progressive disclosure (lean SKILL.md, detailed references)
- Imperative writing style
- Working examples and utilities

## 📝 Example Usage

### Scenario: Review Feature Branch

**User input:**
```
Review the feature/auth branch compared to dev
```

**Skill execution:**
1. Asks for working directory (default: `{project}/reviews/auth-feature`)
2. Collects code data (diff, commits, branch info)
3. Discovers available review skills
4. Launches parallel subagents (e.g., security-analyzer, code-review, performance-checker)
5. Consolidates reports into summary
6. Presents issues by severity
7. Helps fix selected issues

**Output:**
```
reviews/auth-feature/
├── code-context.json
├── diff.patch
├── commits.json
├── branch-info.json
├── reports/
│   ├── security-analyzer-report.md
│   ├── code-review-report.md
│   └── performance-checker-report.md
└── auth-feature-summary.md  ← Consolidated summary
```

## 🛠️ Using the Scripts

### collect-review-data.sh

Collect review data from git repository:

```bash
# Compare feature/auth to dev
./scripts/collect-review-data.sh \
  -s feature/auth \
  -t dev \
  -o ./reviews/auth-feature

# Review single branch
./scripts/collect-review-data.sh \
  -s feature/auth \
  -o ./reviews/auth-review
```

### find-merge-base.sh

Find common ancestor between branches:

```bash
./scripts/find-merge-base.sh feature/auth dev
# Output: abc123def456... (merge base commit)
```

### launch-subagents.sh

Generate Task commands for parallel review:

```bash
./scripts/launch-subagents.sh \
  -w ./reviews/auth-feature \
  -s "security-analyzer,code-review,performance-checker"
```

## 🎓 Skill Development Best Practices

Your new skill follows all best practices:

✅ **Third-person description** with specific trigger phrases
✅ **Progressive disclosure** - SKILL.md is lean, details in references/
✅ **Imperative form** - Verb-first instructions throughout
✅ **Working examples** - Complete, runnable samples
✅ **Utility scripts** - Executable and well-documented
✅ **Resource references** - All supporting files linked from SKILL.md

## 🔄 Next Steps

1. **Test the skill** with real code reviews
2. **Iterate** based on usage experience
3. **Add more skills** to the monorepo
4. **Share** with your team

## 📖 Additional Resources

- **Skill Development Guide**: Study the plugin-dev skill-development skill
- **Reference Examples**: Check plugin-dev's skills for more patterns
- **Claude Code Docs**: https://docs.anthropic.com/claude-code

## 🤝 Contributing

This is a personal skills repository. Feel free to customize the skill for your needs!

## 📄 License

See LICENSE file in project root.

---

**Created:** 2025-01-28
**Version:** 0.1.0
**Status:** Ready to use ✅
