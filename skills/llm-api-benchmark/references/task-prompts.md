# Task Prompts Library

任务提示词库，用于 Agent 模式基准测试。设计目标：**输出长度稳定可预测**。

## Available Tasks

| Task Type | Description | Target Output |
|-----------|-------------|---------------|
| counting | 数字序列生成（最稳定） | ~50 tokens |
| structured-list | 结构化列表输出 | ~100-150 tokens |
| code-review | 代码审查报告 | ~300-400 tokens |
| implementation | 完整代码实现 | ~500-700 tokens |
| comprehensive | 综合分析报告 | ~800-1000 tokens |

## Prompt Details

### counting（最稳定 - 用于快速测试）

```
Output a numbered list counting from 1 to 20, one number per line.
Format: Just the numbers, no other text.

Example output format:
1
2
3
... (continue to 20)
```

**特点**：输出最稳定，几乎精确 20 行，适合测试 TTFT。

---

### structured-list（稳定结构化输出）

```
Generate a list of 15 programming languages with their primary use cases.

Format each entry exactly as:
1. [Language Name]: [Primary Use Case] - [One Sentence Description]

Example:
1. Python: Data Science - Widely used for machine learning and data analysis.

Continue for all 15 languages. Use this exact format.
```

**特点**：强制格式确保稳定输出，每个条目约 10 tokens，总计 ~150 tokens。

---

### code-review（中等输出 - 代码审查）

```
Review the following Python code and provide a detailed analysis:

```python
def process_data(items):
    result = []
    for item in items:
        if item > 0:
            result.append(item * 2)
        else:
            result.append(0)
    return result

def calculate_stats(numbers):
    total = 0
    count = 0
    for n in numbers:
        total += n
        count += 1
    avg = total / count if count > 0 else 0
    return {"sum": total, "count": count, "average": avg}

class DataProcessor:
    def __init__(self):
        self.data = []

    def add(self, item):
        self.data.append(item)

    def process(self):
        return process_data(self.data)

    def get_stats(self):
        return calculate_stats(self.data)
```

Provide a structured review with these 5 sections:

1. **Code Quality Issues** (list at least 3 issues with line numbers)
2. **Performance Concerns** (analyze time/space complexity)
3. **Security Considerations** (identify potential vulnerabilities)
4. **Suggested Improvements** (provide specific refactoring suggestions)
5. **Best Practices** (recommend at least 4 improvements)

Each section must have at least 3 bullet points. Be thorough and specific.
```

**特点**：强制 5 个部分，每部分至少 3 点，输出稳定在 ~300-400 tokens。

---

### implementation（代码实现 - 中长输出）

```
Implement a complete Python class for a thread-safe LRU (Least Recently Used) cache.

Requirements:
1. Use OrderedDict from collections module
2. Implement thread safety with threading.Lock
3. Include these methods:
   - __init__(self, capacity: int) - initialize with max capacity
   - get(self, key: str) -> Optional[Any] - get value, return None if not found
   - put(self, key: str, value: Any) -> None - add/update entry
   - delete(self, key: str) -> bool - remove entry, return success
   - clear(self) -> None - remove all entries
   - size(self) -> int - return current number of entries
   - __len__(self) -> int - same as size()
   - __contains__(self, key: str) -> bool - check if key exists
4. Add comprehensive type hints for all methods
5. Add detailed docstrings with:
   - Brief description
   - Args section
   - Returns section
   - Example usage
6. Include a simple test in __main__ block

Output only the complete Python code. Make it production-ready with error handling.
```

**特点**：强制 8 个方法 + docstrings + 测试代码，输出稳定在 ~500-700 tokens。

---

### comprehensive（长输出 - 吞吐量测试）

```
You are a senior software architect. Provide a comprehensive technical design document for implementing a real-time chat application.

Your document must include ALL of the following 8 sections, with minimum content requirements for each:

## 1. System Architecture (minimum 150 words)
- High-level architecture diagram description
- Component breakdown
- Communication patterns

## 2. Technology Stack (minimum 100 words)
- Frontend framework recommendation with justification
- Backend framework recommendation with justification
- Database choices and reasons
- Real-time communication technology

## 3. Database Schema (minimum 150 words)
- Users table design
- Messages table design
- Rooms/Channels table design
- Indexes and constraints

## 4. API Design (minimum 10 endpoints)
List at least 10 API endpoints with:
- HTTP method and path
- Request body/parameters
- Response format

## 5. Real-time Event Handling (minimum 100 words)
- WebSocket event types
- Message broadcasting strategy
- Connection management

## 6. Security Considerations (minimum 150 words)
- Authentication approach
- Authorization model
- Data encryption
- Rate limiting

## 7. Scalability Strategy (minimum 100 words)
- Horizontal scaling approach
- Load balancing
- Caching strategy
- Message queue integration

## 8. Testing Strategy (minimum 100 words)
- Unit testing approach
- Integration testing approach
- Load testing strategy
- Test coverage goals

Each section header must be present. Each minimum word count must be met.
```

**特点**：8 个强制部分 + 每部分最小字数要求，输出稳定在 ~800-1000 tokens。

---

## 设计原则

1. **强制格式**：使用列表、表格、编号等固定格式
2. **数量要求**：明确"至少 X 个"、"X 个部分"
3. **验证点**：便于检查输出是否符合预期
4. **任务类型多样**：从简单计数到综合分析，覆盖不同测试场景

## 使用建议

| 测试目的 | 推荐任务 | 原因 |
|---------|---------|------|
| TTFT 测试 | counting | 输出最稳定，易于测量首 token 时间 |
| 中等负载 | structured-list, code-review | 稳定的中等输出量 |
| 吞吐量测试 | implementation, comprehensive | 长输出，适合测试 TPS |
| 综合基准 | comprehensive | 最接近真实工作负载 |