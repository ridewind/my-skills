---
name: llm-api-benchmark
description: This skill should be used when the user wants to "test API speed", "benchmark LLM", "check API latency", "measure response time", "test TPS", "benchmark endpoint performance", "测试当前端点性能", "测试LLM速度", "对比端点性能", or wants to evaluate multiple LLM API endpoints' performance.
---

# LLM API Benchmark

LLM API 端点性能测试工具，使用当前会话的 Agent 工具进行测试。

## 用户触发词

- "测试当前端点性能"
- "测试LLM速度"
- "基准测试当前端点"
- "Benchmark current endpoint"
- "对比端点性能"
- "Compare endpoint performance"

## 工作流程

### 测试单个端点

当用户要求测试当前端点时，使用以下步骤：

1. 获取当前端点配置（从 `ANTHROPIC_BASE_URL` 环境变量）
2. 使用 Agent 工具启动 general-purpose subagent 执行 benchmark 任务
3. 测量 Agent 执行时间
4. 重复多次（默认 5 次）获取统计数据
5. 保存结果到 `reports/llm-benchmark-subagent/`

**Benchmark 任务提示词**（代码生成任务）：
```
Generate a complete, production-ready Python implementation of an LRU cache with type hints, docstrings, and comprehensive error handling.
```

**执行方式**：

对每个迭代：
```python
import time
from pathlib import Path
import json
import os

# 获取当前端点
endpoint = os.environ.get('ANTHROPIC_BASE_URL', 'unknown')

# 任务提示词
task_prompt = "Generate a complete, production-ready Python implementation of an LRU cache with type hints, docstrings, and comprehensive error handling."

# 执行 benchmark
start_time = time.time()

# 使用 Agent 工具启动 subagent
result = Agent(
    subagent_type="general-purpose",
    description="Execute LRU cache generation task",
    prompt=task_prompt,
    run_in_background=False
)

elapsed_time = time.time() - start_time
print(f"Response time: {elapsed_time:.2f}s")
```

### 对比多个端点

当用户要求对比端点性能时：

1. 读取 `reports/llm-benchmark-subagent/` 中的所有 JSON 结果
2. 按端点分组，保留每个端点的最新结果
3. 按平均时间排序
4. 显示对比表

**对比脚本**：
```bash
python skills/llm-api-benchmark/scripts/compare-results.py
```

## 输出格式

### 结果文件结构

```json
{
  "timestamp": "2026-03-05T10:30:45",
  "endpoint": "https://localhost:8080",
  "task": "code",
  "iterations": 5,
  "avg_time": 1.23,
  "min_time": 1.15,
  "max_time": 1.31,
  "times": [1.23, 1.15, 1.31, 1.18, 1.25]
}
```

### 对比输出示例

```
==========================================================================
                    LLM API ENDPOINT COMPARISON
==========================================================================
Endpoint                                         Avg        Min        Max        Relative
--------------------------------------------------------------------------
localhost:8080                                   0.82s      0.78s      0.89s      ⚡ baseline
api.anthropic.com                                1.23s      1.15s      1.31s      1.5× slower
192.168.1.100:8080                               2.45s      2.30s      2.60s      3.0× slower
==========================================================================
```

## 典型使用流程

```bash
# 1. 切换到本地代理端点
cc-switch local-proxy

# 2. 在 Claude Code 中触发测试
用户: 测试当前端点性能

# 3. 切换到另一个端点
cc-switch openai-proxy

# 4. 再次测试
用户: 测试当前端点性能

# 5. 对比结果
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

**缺点**：
- 需要设置 API 密钥环境变量
- 不使用 cc-switch 配置

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
| 适用场景 | 相对性能对比 | 精确性能测量 |

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
