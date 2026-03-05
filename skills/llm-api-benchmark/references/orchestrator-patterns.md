# Orchestrator Workflow Patterns

Patterns for running benchmark tests with orchestrator subagents.

## Subagent Prompt Template

```
你是 LLM API Benchmark 执行器。请执行以下任务：

**任务**：执行 {iterations} 次基准测试

**测试参数**：
- 迭代次数: {iterations}
- 任务类型: {task_type}
- 任务提示词: {task_prompt}
- 输出目录: reports/llm-benchmark-subagent/

**执行步骤**：

1. 记录当前端点（从 ANTHROPIC_BASE_URL 环境变量读取，用 Bash 运行 echo $ANTHROPIC_BASE_URL）
2. 串行执行 {iterations} 次测试迭代：
   - 直接回答用户的任务提示词（不要调用其他 Agent）
   - 记录每次的开始时间（ISO 格式，如 2026-03-05T10:30:45.123）
   - 记录每次的结束时间（ISO 格式）
   - 保存每次端点输出的完整内容
   - 估算每次输出的 token 数量（按 1 token ≈ 4 字符估算）
   - 每次迭代后等待 1.5 秒避免速率限制（用 sleep 1.5）
3. 计算统计数据（avg, min, max, avg_tps）
4. 使用 Write 工具保存结果到 reports/llm-benchmark-subagent/benchmark-{timestamp}.json

**重要**：
- 必须串行执行，不能并行
- 直接回答任务，不要调用其他 Agent
- 每次迭代后必须等待 1.5 秒
- 任务提示词必须在 /tmp/ 目录下工作
- TPS = 输出 token 数量 / 响应时间
- 必须记录每次迭代的开始/结束时间和输出内容

**结果格式**：
```json
{
  "timestamp": "2026-03-05T10:30:45",
  "endpoint": "https://...",
  "task": "implementation",
  "iterations": 5,
  "avg_time": 1.23,
  "min_time": 1.15,
  "max_time": 1.31,
  "avg_tps": 45.2,
  "total_tokens": 275,
  "details": [
    {
      "iteration": 1,
      "start_time": "2026-03-05T10:30:45.123",
      "end_time": "2026-03-05T10:30:46.353",
      "response_time": 1.23,
      "tokens": 56,
      "tps": 45.5,
      "output": "完整的端点输出内容..."
    },
    {
      "iteration": 2,
      "start_time": "2026-03-05T10:30:47.853",
      "end_time": "2026-03-05T10:30:49.003",
      "response_time": 1.15,
      "tokens": 52,
      "tps": 45.2,
      "output": "完整的端点输出内容..."
    }
  ]
}
```

**注意**：details 数组包含每次迭代的完整记录，output 字段保存端点的原始输出。
```

## Orchestrator Advantages

1. **单次确认**：整个测试流程只需一次权限确认
2. **自动串行**：orchestrator 内部自动串行执行，避免并发问题
3. **结果一致**：所有迭代在相同上下文中执行，结果更可靠
4. **避免打断**：测试过程中无需用户交互

## Why Serial Execution is Required

1. **测试数据准确性**：
   - 并发请求会相互干扰，影响响应时间测量
   - 端点可能对并发请求进行队列处理，导致数据失真

2. **避免速率限制**：
   - 大多数 API 端点都有速率限制（RPM/TPM）
   - 并发请求容易触发 429 错误，导致测试失败

3. **避免副作用影响**：
   - 使用临时目录（`/tmp/`）避免文件写入影响项目
   - 选择无状态任务（如算法分析）而非代码生成