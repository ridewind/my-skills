# My Skills

A monorepo of Claude Code skills for specialized workflows and code review orchestration.

## Skills

### code-review-orchestrator

**Orchestrates comprehensive code reviews by coordinating multiple review skills and subagents in parallel.**

This skill manages the complete code review workflow:
- Collects code content from branches, MRs, or PRs
- Coordinates parallel subagent reviews using different skills
- Consolidates findings into actionable summary reports
- Helps identify and fix issues

**When to use:**
- "Review my code"
- "Review feature/auth branch"
- "Review MR !1234" / "Review PR #567"
- "Review feature/auth vs dev branch"

**Features:**
- Branch comparison with proper merge-base detection
- Support for GitLab MR and GitHub PR reviews
- Multi-skill parallel review execution
- Comprehensive issue categorization (Critical, High, Medium, Low)
- Interactive issue resolution workflow

**Directory:** [skills/code-review-orchestrator/](skills/code-review-orchestrator/)

## Quick Start

### Using code-review-orchestrator

1. **Trigger the skill:**
   ```
   Review the feature/auth branch compared to dev
   ```

2. **The skill will:**
   - Ask for working directory (default: `{project}/reviews/{review-name}`)
   - Collect code diff, commits, and metadata
   - Discover available review skills
   - Launch parallel subagents for review
   - Generate consolidated summary report

3. **Review the output:**
   - Individual skill reports in `{workdir}/reports/`
   - Consolidated summary in `{workdir}/{review-name}-summary.md`

### Scripts

The skill includes utility scripts in `scripts/`:

- **collect-review-data.sh** - Collects code review data from git
- **find-merge-base.sh** - Finds merge base between branches
- **launch-subagents.sh** - Generates Task commands for parallel review

## Project Structure

```
my-skills/
├── skills/
│   └── code-review-orchestrator/
│       ├── SKILL.md                          # Main skill instructions
│       ├── references/                       # Detailed reference docs
│       │   ├── subagent-coordination.md      # Subagent coordination guide
│       │   ├── report-formatting.md          # Report structure standards
│       │   └── issue-categories.md           # Severity classification
│       ├── examples/                         # Working examples
│       │   ├── code-context-example.json     # Sample code context
│       │   └── summary-example.md            # Sample summary report
│       └── scripts/                          # Utility scripts
│           ├── collect-review-data.sh
│           ├── find-merge-base.sh
│           └── launch-subagents.sh
└── README.md
```

## Development

### Adding a New Skill

1. Create skill directory:
   ```bash
   mkdir -p skills/your-skill/{references,examples,scripts}
   touch skills/your-skill/SKILL.md
   ```

2. Write SKILL.md with:
   - YAML frontmatter (name, description with trigger phrases)
   - Skill instructions (1,500-2,000 words)
   - References to supporting files

3. Add supporting resources:
   - `references/` - Detailed documentation
   - `examples/` - Working examples
   - `scripts/` - Utility scripts

4. Test the skill:
   ```bash
   # Test locally with Claude Code
   cc --plugin-dir /path/to/my-skills
   ```

### Best Practices

- **Progressive Disclosure:** Keep SKILL.md lean, move details to references/
- **Imperative Form:** Use verb-first instructions (not "you should")
- **Third-Person Description:** "This skill should be used when..."
- **Specific Triggers:** Include exact user phrases in description
- **Working Examples:** Provide complete, runnable examples

## Contributing

This is a personal skills repository. Contributions are not currently accepted.

## License

See [LICENSE](LICENSE) file for details.
