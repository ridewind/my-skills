# Issue Classification and Severity Guidelines

Comprehensive guide for categorizing and assigning severity levels to code review issues.

## Severity Levels

### Critical (Must Fix Immediately)

**Definition:** Vulnerabilities or defects that pose an immediate risk to security, data integrity, or system stability.

**Response Required:** Block merge until fixed.

**Examples:**

#### Security Vulnerabilities
- **SQL Injection**: User input directly concatenated into queries
  ```javascript
  // Vulnerable
  const query = `SELECT * FROM users WHERE id = ${userId}`;
  ```
- **Cross-Site Scripting (XSS)**: Unescaped user input rendered in HTML
- **Authentication/Authorization Bypass**: Missing permission checks
- **Sensitive Data Exposure**: API keys, passwords in code or logs
- **Insecure Cryptography**: Weak algorithms, hardcoded keys

#### Data Loss Risks
- **Missing Transactions**: Database operations without transactional integrity
- **Uncaught Exceptions**: Crashes that cause data corruption
- **Race Conditions**: Concurrent access without proper locking

#### System Stability
- **Infinite Loops**: Logic that will never terminate
- **Memory Leaks**: Unbounded memory growth
- **Resource Exhaustion**: File handles, connections not released

**Markdown Report Example:**
```markdown
### SQL Injection Vulnerability in User Query

- **Location**: `src/api/users.js:45`
- **Severity**: Critical
- **Category**: Security
- **CWE**: CWE-89

**Description:**
User input from request parameters is directly interpolated into SQL query, allowing attackers to execute arbitrary SQL.

**Current Code:**
```javascript
app.get('/user/:id', (req, res) => {
  const query = `SELECT * FROM users WHERE id = ${req.params.id}`;
  db.query(query, (err, results) => res.json(results));
});
```

**Recommended Fix:**
```javascript
app.get('/user/:id', (req, res) => {
  const query = 'SELECT * FROM users WHERE id = ?';
  db.query(query, [req.params.id], (err, results) => res.json(results));
});
```

**Impact:** Attackers can read, modify, or delete any data in the database.

**Priority:** Fix immediately before merge.
```

---

### High (Fix Before Merge)

**Definition:** Issues that significantly impact functionality, performance, or user experience but don't pose immediate critical risks.

**Response Required:** Fix before merge or document known issue with approval.

**Examples:**

#### Performance Issues
- **N+1 Query Problem**: Query in loop causing database load
  ```javascript
  // Problematic
  for (const user of users) {
    const posts = db.query(`SELECT * FROM posts WHERE user_id = ${user.id}`);
  }
  ```
- **Missing Index**: Query on unindexed column
- **Large Object Cloning**: Unnecessary deep copies
- **Inefficient Algorithms**: O(n²) where O(n) possible

#### Error Handling
- **Unhandled Promise Rejections**: Uncaught async errors
- **Missing Try-Catch**: No error handling for I/O operations
- **Generic Error Messages**: Errors that don't help debugging

#### Breaking Changes
- **API Incompatibility**: Changes that break existing consumers
- **Deprecated Method Usage**: Using soon-to-be-removed APIs
- **Configuration Changes**: Defaults that break existing setups

#### Logic Errors
- **Off-by-One Errors**: Loop boundaries incorrect
- **Null/Undefined Handling**: Missing null checks
- **Type Coercion Bugs**: Unexpected type conversions

**Markdown Report Example:**
```markdown
### N+1 Query Problem in Post Loading

- **Location**: `src/controllers/posts.js:78`
- **Severity**: High
- **Category**: Performance

**Description:**
Loading posts iteratively queries database for each user, causing severe performance degradation with multiple posts.

**Current Code:**
```javascript
async function loadPosts() {
  const posts = await db.query('SELECT * FROM posts');
  for (const post of posts) {
    post.author = await db.query(`SELECT * FROM users WHERE id = ${post.user_id}`);
  }
  return posts;
}
```

**Recommended Fix:**
```javascript
async function loadPosts() {
  const posts = await db.query('SELECT * FROM posts');
  const userIds = posts.map(p => p.user_id);
  const users = await db.query(
    'SELECT * FROM users WHERE id IN (?)',
    [userIds]
  );
  const userMap = new Map(users.map(u => [u.id, u]));
  posts.forEach(post => post.author = userMap.get(post.user_id));
  return posts;
}
```

**Impact:** With 100 posts, this executes 101 database queries instead of 2. Response time grows linearly with post count.

**Priority:** Fix before merge to production.
```

---

### Medium (Technical Debt)

**Definition:** Issues that impact code maintainability, readability, or technical quality but don't affect immediate functionality.

**Response Required:** Add to backlog, address within 1-2 sprints.

**Examples:**

#### Code Smells
- **Long Methods**: Functions >50 lines
- **Large Classes**: Classes >500 lines
- **Deep Nesting**: >4 levels of indentation
- **God Objects**: Classes doing too much

#### Maintainability
- **Code Duplication**: Same logic in multiple places
- **Magic Numbers**: Unnamed constants
- **Poor Naming**: Unclear variable/function names
- **Missing Documentation**: Complex functions without comments

#### Testing
- **Missing Unit Tests**: New code without test coverage
- **Fragile Tests**: Tests that break easily
- **Slow Tests**: Tests that take too long

#### Design
- **Tight Coupling**: Hard-to-change dependencies
- **Violating SRP**: Functions doing multiple things
- **Global State**: Mutable global variables

**Markdown Report Example:**
```markdown
### Code Duplication in Validation Logic

- **Location**: `src/validators/user.js`, `src/validators/admin.js`
- **Severity**: Medium
- **Category**: Maintainability

**Description:**
Email validation logic is duplicated across multiple validators. Any change requires updating multiple files.

**Current Code:**
```javascript
// In src/validators/user.js
function validateEmail(email) {
  const re = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  return re.test(email);
}

// In src/validators/admin.js (identical)
function validateEmail(email) {
  const re = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  return re.test(email);
}
```

**Recommended Fix:**
```javascript
// In src/utils/validation.js (new shared file)
export function validateEmail(email) {
  const re = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  return re.test(email);
}

// In both validators
import { validateEmail } from '../utils/validation.js';
```

**Impact:** Higher maintenance burden, risk of inconsistencies when fixing bugs.

**Priority:** Refactor within next sprint.
```

---

### Low (Nice to Have)

**Definition:** Minor issues that don't impact functionality but could improve code quality.

**Response Required:** Fix in future cleanup, optional.

**Examples:**

#### Style Issues
- **Inconsistent Naming**: Mix of camelCase/snake_case
- **Inconsistent Quotes**: Mix of single/double quotes
- **Trailing Whitespace**: Extra whitespace at line ends
- **Missing Semicolons**: In JS where optional

#### Minor Optimizations
- **Unused Variables**: Imports or variables not used
- **Redundant Conditions**: Always true/false checks
- **Inefficient String Concatenation**: Minor performance impact

#### Documentation
- **Missing JSDoc**: Functions without type documentation
- **Outdated Comments**: Comments that don't match code
- **Typo in Comments**: Spelling errors

#### Minor Issues
- **Console.log Left in Code**: Debug statements not removed
- **TODO Comments**: Unresolved TODOs
- **Long Lines**: Lines >120 characters

**Markdown Report Example:**
```markdown
### Unused Import in Utility Module

- **Location**: `src/utils/helpers.js:3`
- **Severity**: Low
- **Category**: Code Quality

**Description:**
The `lodash` library is imported but not used in this file.

**Current Code:**
```javascript
import { format } from './format.js';
import _ from 'lodash';  // Unused

export function formatDate(date) {
  return format(date, 'YYYY-MM-DD');
}
```

**Recommended Fix:**
```javascript
import { format } from './format.js';

export function formatDate(date) {
  return format(date, 'YYYY-MM-DD');
}
```

**Impact:** Slightly larger bundle size, minor performance impact from unused import.

**Priority:** Clean up in next code maintenance session.
```

---

## Issue Categories

### Security

**Focus:** Vulnerabilities that could be exploited by attackers.

**Common Patterns:**
- Injection flaws (SQL, NoSQL, OS command)
- Authentication/authorization issues
- Cryptographic weaknesses
- Sensitive data exposure
- XXE (XML External Entity)
- Broken access control
- Security misconfiguration

**Reference Standards:**
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE/SANS Top 25](https://cwe.mitre.org/top25/)

### Performance

**Focus:** Code that executes slowly or inefficiently.

**Common Patterns:**
- N+1 queries
- Missing caching
- Inefficient algorithms
- Unnecessary database calls
- Large object copying
- Blocking I/O in async contexts
- Memory leaks

**Metrics:**
- Response time >500ms (web)
- Memory usage >1GB (simple apps)
- CPU usage >80% (sustained)

### Correctness

**Focus:** Logic errors that produce incorrect results.

**Common Patterns:**
- Off-by-one errors
- Null/undefined handling
- Type coercion issues
- Incorrect conditions
- Race conditions
- Boundary condition errors
- Floating-point precision

### Maintainability

**Focus:** Code that's hard to understand or modify.

**Common Patterns:**
- Code duplication
- Long functions/classes
- Deep nesting
- Poor naming
- Missing documentation
- Tight coupling
- Violated design principles

**Metrics:**
- Cyclomatic complexity >10
- Function length >50 lines
- Class length >500 lines
- Nesting depth >4

### Style

**Focus:** Code formatting and conventions.

**Common Patterns:**
- Inconsistent naming
- Mixed conventions
- Missing linting rules
- Formatting inconsistencies
- Unused code

**Tools:**
- ESLint (JavaScript/TypeScript)
- Pylint (Python)
- RuboCop (Ruby)
- Checkstyle (Java)

### Documentation

**Focus:** Missing or unclear documentation.

**Common Patterns:**
- Missing function documentation
- Unclear parameter descriptions
- Missing return type documentation
- Outdated comments
- No README for complex modules

## Severity Assignment Decision Tree

Use this decision tree to assign severity:

```
Is it a security vulnerability?
├─ Yes → Can it be exploited easily?
│   ├─ Yes → CRITICAL
│   └─ No → HIGH
└─ No → Does it cause data loss or crashes?
    ├─ Yes → CRITICAL
    └─ No → Does it significantly impact performance?
        ├─ Yes → HIGH
        └─ No → Is it a logic error?
            ├─ Yes → HIGH
            └─ No → Does it impact maintainability?
                ├─ Yes → MEDIUM
                └─ No → LOW
```

## Special Cases

### Context-Dependent Severity

Some issues vary in severity based on context:

**Example: Missing Error Handling**
- **High**: Missing error handling in payment processing
- **Medium**: Missing error handling in logging
- **Low**: Missing error handling in non-critical utility

**Example: Performance Issue**
- **High**: Query in hot path (executed on every request)
- **Medium**: Query in admin function (rarely used)
- **Low**: Query in one-time migration script

### Multi-Language Considerations

**JavaScript/TypeScript:**
- Critical: XSS, prototype pollution, async errors
- High: Memory leaks, race conditions in promises

**Python:**
- Critical: Pickle deserialization, eval usage
- High: Global interpreter lock issues

**Java:**
- Critical: Deserialization vulnerabilities, SQL injection
- High: Memory leaks, thread safety issues

**Go:**
- Critical: Goroutine leaks, race conditions
- High: Context not propagated properly

## Reporting Tips

### Be Specific

**✓ Good:**
```markdown
SQL injection in user login allows authentication bypass.
```

**✗ Bad:**
```markdown
Security issue found.
```

### Provide Context

**✓ Good:**
```markdown
This function is called on every login attempt, making it a high-risk target for brute force attacks.
```

**✗ Bad:**
```markdown
Function has a problem.
```

### Include Evidence

**✓ Good:**
```markdown
Benchmark shows 1000ms → 50ms improvement after fix.
```

**✗ Bad:**
```markdown
Performance will improve.
```

### Make Recommendations Actionable

**✓ Good:**
```markdown
Replace raw SQL with parameterized query using pg library's prepared statements.
```

**✗ Bad:**
```markdown
Fix the SQL query.
```
