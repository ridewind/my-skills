---
name: llm-api-benchmark
description: This skill should be used when the user wants to "test API speed", "benchmark LLM", "check API latency", "measure response time", "test TPS", "benchmark endpoint performance", "测试当前端点性能", "测试LLM速度", "对比端点性能", or wants to evaluate multiple LLM API endpoints' performance.
---

# LLM API Benchmark

LLM API 端点性能测试工具，支持两种测试模式：Agent 模式（测试真实工作负载）和 HTTP 模式（精确性能指标）。

## 用户触发词

- "测试当前端点性能"
- "测试LLM速度"
- "基准测试当前端点"
- "Benchmark current endpoint"
- "对比端点性能"
- "Compare endpoint performance"

## 工作流程

### 第一步：确认测试方案

在执行测试前，**必须**与用户确认测试方案：

```
📊 LLM API Benchmark 测试方案

**当前端点**: {从 ANTHROPIC_BASE_URL 读取}

**测试参数**:
- 测试类型: Agent 模式（测试真实 Agent 响应时间）
- 迭代次数: 5（默认）
- 任务类型: algorithm-analysis（默认）
- 预计耗时: ~2-3 分钟

**可选任务类型**:
1. algorithm-analysis - 算法复杂度分析（推荐）
2. code-generation - 代码生成测试
3. documentation - 文档撰写测试

**是否开始测试？**
- 确认开始
- 修改参数（如：迭代次数改为 3）
- 切换到 HTTP 模式（获取精确 TTFT/TPS 指标）
```

**确认要点**：
1. 显示当前端点（从 `ANTHROPIC_BASE_URL` 环境变量读取）
2. 列出测试参数和默认值
3. 提供可选项供用户选择
4. 用户确认后才执行

### 第二步：执行测试

用户确认后，使用 **orchestrator 模式** 执行完整测试流程：

#### Agent 模式（推荐）

启动一个 orchestrator subagent 执行整个测试流程，只需一次确认即可完成所有迭代：

**Orchestrator 提示词**：
```
你是 LLM API Benchmark 执行器。请执行以下任务：

**任务**：执行 {iterations} 次基准测试

**测试参数**：
- 迭代次数: {iterations}
- 任务类型: {task_type}
- 任务提示词: {task_prompt}
- 输出目录: reports/llm-benchmark-subagent/

**执行步骤**：

1. 记录当前端点（从 ANTHROPIC_BASE_URL 环境变量）
2. 串行执行 {iterations} 次测试迭代：
   - 每次使用 Agent 工具执行任务
   - 记录每次的响应时间
   - 每次迭代后等待 1.5 秒避免速率限制
3. 计算统计数据（avg, min, max）
4. 保存结果到 reports/llm-benchmark-subagent/benchmark-{timestamp}.json

**重要**：
- 必须串行执行，不能并行
- 每次迭代后必须等待 1.5 秒
- 任务提示词必须在 /tmp/ 目录下工作

**结果格式**：
```json
{
  "timestamp": "2026-03-05T10:30:45",
  "endpoint": "https://...",
  "task": "algorithm-analysis",
  "iterations": 5,
  "avg_time": 1.23,
  "min_time": 1.15,
  "max_time": 1.31,
  "times": [1.23, 1.15, 1.31, 1.18, 1.25]
}
```

请开始执行测试。
```

**任务提示词库**：

| 任务类型 | 描述 | 提示词 |
|---------|------|--------|
| algorithm-analysis | 算法复杂度分析（推荐） | 见下方 |
| code-generation | 代码生成测试 | 见下方 |
| documentation | 文档撰写测试 | 见下方 |

**algorithm-analysis 提示词**：
```
Analyze the time complexity of the following algorithm and explain how to optimize it:

```python
def find_duplicates(arr):
    duplicates = []
    for i in range(len(arr)):
        for j in range(i+1, len(arr)):
            if arr[i] == arr[j] and arr[i] not in duplicates:
                duplicates.append(arr[i])
    return duplicates
```

Please provide:
1. Current time complexity with explanation
2. Space complexity analysis
3. Optimization approach with code example
4. Trade-offs of the optimized version

Work in /tmp/benchmark-test/ directory for any files you need to create.
```

**code-generation 提示词**：
```
Please write a complete, production-ready Python implementation of a binary search algorithm.

Requirements:
1. Include proper error handling
2. Add type hints
3. Write comprehensive docstrings
4. Include usage examples
5. Make it efficient and readable

Work in /tmp/benchmark-test/ directory for any files you need to create.
Return your implementation in a code block.
```

**documentation 提示词**：
```
Please write a technical documentation explaining how REST APIs work.

Cover:
1. What is REST
2. HTTP methods (GET, POST, PUT, DELETE)
3. Status codes
4. Authentication methods
5. Best practices

Write at least 300 words.
```

#### HTTP 模式（精确指标）

如需精确的 TTFT 和 TPS 指标，使用 HTTP 模式：

```bash
python skills/llm-api-benchmark/scripts/benchmark.py --preset code --iterations 5
```

### 第三步：显示结果

测试完成后，显示结果摘要：

```
✅ 测试完成！

📊 结果摘要：
- 端点: {endpoint}
- 迭代次数: {iterations}
- 平均响应时间: {avg_time:.2f}s
- 最小: {min_time:.2f}s | 最大: {max_time:.2f}s

📁 详细报告: reports/llm-benchmark-subagent/benchmark-{timestamp}.json
```

### 对比多个端点

当用户要求对比端点性能时：

```bash
python skills/llm-api-benchmark/scripts/compare-results.py
```

## 输出格式

### 结果文件结构

```json
{
  "timestamp": "2026-03-05T10:30:45",
  "endpoint": "https://localhost:8080",
  "task": "algorithm-analysis",
  "iterations": 5,
  "avg_time": 1.23,
  "min_time": 1.15,
  "max_time": 1.31,
  "times": [1.23, 1.15, 1.31, 1.18, 1.25]
}
```

### 对比输出示例

```
=====================================================================================
                    LLM API ENDPOINT COMPARISON
=====================================================================================

Endpoint                                         Avg        Min        Max        Relative
-------------------------------------------------------------------------------------
localhost:8080                                   0.82s      0.78s      0.89s      ⚡ baseline
api.anthropic.com                                1.23s      1.15s      1.31s      1.5× slower
192.168.1.100:8080                               2.45s      2.30s      2.60s      3.0× slower
-------------------------------------------------------------------------------------
Total endpoints tested: 3

Notes:
  - 'Avg' is the average response time across all iterations
  - Relative speed compares each endpoint to the fastest (baseline)
```

## 典型使用流程

```bash
# 1. 切换到本地代理端点
cc-switch local-proxy

# 2. 在 Claude Code 中触发测试
用户: 测试当前端点性能

# 3. 确认测试方案
Claude: 显示测试方案，用户确认

# 4. 自动执行所有迭代（只需一次确认）

# 5. 切换到另一个端点
cc-switch openai-proxy

# 6. 再次测试
用户: 测试当前端点性能

# 7. 对比结果
用户: 对比端点性能
```

## 方法 2：直接 API 调用（精确指标）

如需精确的 TTFT 和 TPS 指标，使用 HTTP 模式：

```bash
python skills/llm-api-benchmark/scripts/benchmark.py
```

## 脚本说明

### benchmark.py

直接调用 LLM API 进行基准测试。

**优点**：
- 精确的 TTFT（Time To First Token）
- 精确的 TPS（Tokens Per Second）
- 支持多种预设（quick, standard, long, throughput, code, json）

**预设列表**：

| 预设 | 描述 | 预期输出 |
|-----|------|---------|
| quick | 快速测试 | ~10 tokens |
| standard | 中等长度 | ~20 tokens |
| long | 长输出测试 | ~100+ tokens |
| throughput | 高吞吐测试 | ~300-500 tokens |
| code | 代码生成（默认） | ~500-1000 tokens |
| json | JSON 输出测试 | ~30 tokens |

### compare-results.py

对比所有已保存的基准测试结果。

## 命令参考

### benchmark.py

```bash
python benchmark.py [OPTIONS]

Options:
  --iterations, -i N              迭代次数（默认：5）
  --preset NAME                   预设名称（quick/standard/long/throughput/code/json）
  --prompt TEXT                   自定义提示词
  --model MODEL                   模型名称
  --output-dir DIR                输出目录（默认：reports）
  --quiet, -q                     静默模式
```

## 与 HTTP 模式的区别

| 特性 | Agent 模式 | HTTP 模式 |
|------|-----------|-----------|
| 触发方式 | Agent 工具 | Python 脚本 |
| 配置方式 | cc-switch | 环境变量 |
| 测量内容 | Agent 执行时间 | HTTP 响应 + TTFT + TPS |
| 权限确认 | 一次确认完成所有迭代 | 无需确认 |
| 适用场景 | 相对性能对比 | 精确性能测量 |

## 注意事项

### Orchestrator 模式的优势

使用 orchestrator 模式执行测试的优势：

1. **单次确认**：整个测试流程只需一次权限确认
2. **自动串行**：orchestrator 内部自动串行执行，避免并发问题
3. **结果一致**：所有迭代在相同上下文中执行，结果更可靠
4. **避免打断**：测试过程中无需用户交互

### 串行执行的重要性

**必须串行执行**，原因如下：

1. **测试数据准确性**：
   - 并发请求会相互干扰，影响响应时间测量
   - 端点可能对并发请求进行队列处理，导致数据失真

2. **避免速率限制**：
   - 大多数 API 端点都有速率限制（RPM/TPM）
   - 并发请求容易触发 429 错误，导致测试失败

3. **避免副作用影响**：
   - 使用临时目录（`/tmp/`）避免文件写入影响项目
   - 选择无状态任务（如算法分析）而非代码生成

## 故障排除

### Agent 工具不可用

如果提示 Agent 工具不可用，说明当前环境不支持 subagent 模式。请使用 HTTP 模式：

```bash
python skills/llm-api-benchmark/scripts/benchmark.py
```

### 端点配置问题

```
Endpoint: unknown
```

**解决方案**：
- 使用 cc-switch 配置：`cc-switch <endpoint-name>`
- 或设置环境变量：`export ANTHROPIC_BASE_URL=https://your-endpoint`

### API 调用失败

**解决方案**：
1. 检查 API 密钥是否正确设置
2. 验证端点 URL 是否可访问
3. 使用 HTTP 模式进行诊断