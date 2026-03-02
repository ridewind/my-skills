#!/usr/bin/env python3
"""
Benchmark Subagent - Execute benchmark task and return results

This script is designed to be called by the main Claude session via Task tool.
It executes a real-world task (code generation, documentation, etc.) that triggers
LLM calls, allowing the parent session to measure response time.

Usage:
    python benchmark-subagent.py --task code --iterations 5
    python benchmark-subagent.py --task doc --preset quick
"""

import argparse
import json
import sys
from pathlib import Path

# Task definitions that trigger LLM calls
TASKS = {
    "code": {
        "name": "Code Generation",
        "description": "Generate a Python implementation",
        "prompt": """Please write a complete, production-ready Python implementation of a binary search algorithm.

Requirements:
1. Include proper error handling
2. Add type hints
3. Write comprehensive docstrings
4. Include usage examples
5. Make it efficient and readable

Return your implementation in a code block."""
    },
    "doc": {
        "name": "Documentation",
        "description": "Write technical documentation",
        "prompt": """Please write a technical documentation explaining how REST APIs work.

Cover:
1. What is REST
2. HTTP methods (GET, POST, PUT, DELETE)
3. Status codes
4. Authentication methods
5. Best practices

Write at least 300 words."""
    },
    "analysis": {
        "name": "Code Analysis",
        "description": "Analyze and explain code",
        "prompt": """Please analyze the following Python code and explain what it does, its time complexity, and potential improvements:

```python
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
```

Provide a detailed analysis."""
    },
    "refactor": {
        "name": "Code Refactoring",
        "description": "Refactor code to improve quality",
        "prompt": """Please refactor the following code to improve its quality:

```python
def process(items):
    result = []
    for i in range(len(items)):
        if items[i] % 2 == 0:
            result.append(items[i] * 2)
    return result
```

Make it more Pythonic, efficient, and readable."""
    }
}


def main():
    parser = argparse.ArgumentParser(
        description="Benchmark subagent - Execute tasks that trigger LLM calls"
    )
    parser.add_argument(
        "--task",
        choices=list(TASKS.keys()),
        default="code",
        help="Task type to execute (default: code)"
    )
    parser.add_argument(
        "--iterations",
        type=int,
        default=1,
        help="Number of iterations (parent session will handle multiple calls)"
    )
    parser.add_argument(
        "--output",
        type=str,
        help="Output file path for results"
    )

    args = parser.parse_args()

    task = TASKS[args.task]

    # The parent session will:
    # 1. Call this script multiple times
    # 2. Measure time for each execution
    # 3. Collect statistics

    result = {
        "task": args.task,
        "task_name": task["name"],
        "prompt": task["prompt"],
        "status": "ready"
    }

    # Print result as JSON for parent session to capture
    output = json.dumps(result, indent=2)

    if args.output:
        Path(args.output).write_text(output)
    else:
        print(output)

    return 0


if __name__ == "__main__":
    sys.exit(main())
