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

2. 串行执行 {iterations} 次测试迭代，每次迭代：

   a. **记录开始时间**（使用 Bash 运行：`date -u +"%Y-%m-%dT%H:%M:%S.%3N"` 获取 ISO 格式时间戳）

   b. **调用 LLM 端点回答任务**：
      - 在你的回复中直接写出对任务提示词的答案
      - 这会触发对 LLM 端点的 API 调用
      - 例如：如果任务提示词是 "Implement a Python LRU cache"，你就应该直接输出完整的 Python 代码实现

   c. **记录结束时间**（使用 Bash 运行同样的 date 命令）

   d. **保存本次迭代的数据**：
      - 保存你刚才输出的完整内容（这就是端点的输出）
      - 估算输出的 token 数量（按 1 token ≈ 4 字符）
      - 计算响应时间 = 结束时间 - 开始时间
      - 计算 TPS = token 数量 / 响应时间

   e. **等待 1.5 秒**（使用 Bash 运行：`sleep 1.5`）

3. 所有迭代完成后，计算统计数据（avg, min, max, avg_tps）

4. 使用 Write 工具保存结果到 reports/llm-benchmark-subagent/benchmark-{timestamp}.json

**重要**：
- **每次迭代必须先用 Bash 记录时间，然后输出你的答案，最后再记录结束时间**
- 答案内容必须直接写在你的回复中（不要用代码块、不要用 Write 工具），这样才能触发 LLM 端点调用
- 必须串行执行，不能并行
- 每次迭代后必须等待 1.5 秒
- TPS = 输出 token 数量 / 响应时间
- 必须记录每次迭代的开始/结束时间和输出内容

**执行示例**（假设任务提示词是 "输出斐波那契数列前10项"）：

```
迭代 1 开始...
【Bash 记录开始时间：2026-03-05T10:30:45.123】

【现在输出答案：】
斐波那契数列前10项是：0, 1, 1, 2, 3, 5, 8, 13, 21, 34

【Bash 记录结束时间：2026-03-05T10:30:46.353】
【Bash 执行 sleep 1.5】

迭代 2 开始...
【重复上述步骤】
```

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
      "output": "这里保存你这次迭代输出的完整文本内容（就是你对任务提示词的回答）"
    },
    {
      "iteration": 2,
      "start_time": "2026-03-05T10:30:47.853",
      "end_time": "2026-03-05T10:30:49.003",
      "response_time": 1.15,
      "tokens": 52,
      "tps": 45.2,
      "output": "这里保存第二次迭代输出的完整文本内容"
    }
  ]
}
```

**字段说明**：
- `start_time` / `end_time`：使用 `date -u +"%Y-%m-%dT%H:%M:%S.%3N"` 获取的时间戳
- `response_time`：end_time - start_time 的差值（秒）
- `tokens`：output 字段的字符数 ÷ 4
- `tps`：tokens ÷ response_time
- `output`：**你在本次迭代中输出的完整内容**（就是你作为 LLM 对任务提示词的回答）
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