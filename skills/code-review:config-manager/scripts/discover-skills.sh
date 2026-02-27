#!/bin/bash
# discover-skills.sh - 自动发现并更新 code review skills 和 commands
#
# 用法:
#   ./discover-skills.sh [配置文件路径]           # 直接模式：正则过滤后更新配置
#   ./discover-skills.sh --collect-only [输出文件] # 收集模式：输出所有候选项到 JSON
#   ./discover-skills.sh --from-json [JSON文件] [配置文件路径] # JSON模式：从 JSON 更新配置
#
# 搜索范围:
# - SKILL.md 文件 (skills)
# - commands/*.md 文件 (插件命令)
# - 排除自身 (code-review:config-manager, code-review:executor)
#
# 模式说明:
# - 直接模式: 使用正则过滤后直接更新配置文件（原有行为）
# - 收集模式: 收集所有候选项输出到 JSON 文件，供 LLM 判断
# - JSON模式: 从 LLM 判断后的 JSON 文件更新配置

set -euo pipefail

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 自身 ID（需要排除）
SELF_IDS=("code-review:config-manager" "code-review:executor")

# 模式标志
COLLECT_ONLY=false
FROM_JSON=""
OUTPUT_FILE=""

# 查找配置文件
find_config() {
    local custom_path="$1"

    if [ -n "$custom_path" ]; then
        if [ -f "$custom_path" ]; then
            echo "$custom_path"
            return
        else
            echo -e "${RED}错误${NC} 配置文件不存在: $custom_path" >&2
            exit 1
        fi
    fi

    # 按优先级查找：项目 > 用户 > 全局
    if [ -f ".claude/code-review-skills/config.yaml" ]; then
        echo ".claude/code-review-skills/config.yaml"
        return
    fi

    if [ -f "$HOME/.claude/code-review-skills/config.yaml" ]; then
        echo "$HOME/.claude/code-review-skills/config.yaml"
        return
    fi

    if [ -f "$HOME/.config/claude/code-review-skills/config.yaml" ]; then
        echo "$HOME/.config/claude/code-review-skills/config.yaml"
        return
    fi

    echo -e "${RED}错误${NC} 未找到配置文件" >&2
    echo "请先运行 init-config.sh 初始化配置" >&2
    exit 1
}

# 检查是否应该排除（自身）
should_exclude() {
    local id="$1"
    for self_id in "${SELF_IDS[@]}"; do
        if [ "$id" = "$self_id" ]; then
            return 0
        fi
    done
    return 1
}

# 检查是否为 review 相关 skill/command
is_review_skill() {
    local content="$1"
    local keywords="review|auditor|security|threat|test|testing|coverage|performance|optimization|quality|cleanup|lint"

    if echo "$content" | grep -qiE "$keywords"; then
        return 0
    fi
    return 1
}

# 推断分类
infer_category() {
    local content="$1"

    if echo "$content" | grep -qiE "security|audit|threat"; then
        echo "安全审计"
    elif echo "$content" | grep -qiE "test|coverage|tdd"; then
        echo "测试+清理"
    elif echo "$content" | grep -qiE "performance|optimization|database"; then
        echo "性能+架构"
    elif echo "$content" | grep -qiE "quality|lint|cleanup"; then
        echo "代码质量"
    else
        echo "代码质量"
    fi
}

# 推断标签
infer_tags() {
    local content="$1"
    local tags=()

    if echo "$content" | grep -qiE "review|code-review"; then
        tags+=("review")
    fi
    if echo "$content" | grep -qiE "security|audit"; then
        tags+=("security")
    fi
    if echo "$content" | grep -qiE "test|testing|tdd"; then
        tags+=("testing")
    fi
    if echo "$content" | grep -qiE "performance|optimization"; then
        tags+=("performance")
    fi

    # 转换为 JSON 数组格式
    if [ ${#tags[@]} -eq 0 ]; then
        echo "[]"
    elif [ ${#tags[@]} -eq 1 ]; then
        echo "[\"${tags[0]}\"]"
    else
        # 多个元素：用逗号连接
        local result
        result=$(printf '"%s",' "${tags[@]}")
        # 移除末尾的逗号并加上方括号
        echo "[${result%,}]"
    fi
}

# 搜索 SKILL.md 文件
find_skill_files() {
    local config_dir="$1"
    local search_paths=()

    # 从配置文件读取 skills_directories
    # 只提取 skills_directories 和 available_skills 之间的条目
    local skills_dirs
    skills_dirs=$(awk '/^skills_directories:/,/^available_skills:/ { if (/^  - /) print }' "$CONFIG_FILE" 2>/dev/null | sed 's/^  - //' | sed 's/^[[:space:]]*["'\'']\([^"'\'']*\)["'\''].*/\1/' || true)

    if [ -n "$skills_dirs" ]; then
        # 使用配置文件中指定的目录
        # 需要相对于配置文件所在目录解析路径
        # 配置文件通常在 .claude/code-review-skills/config.yaml
        # 所以相对路径需要向上两层到达项目根目录
        local base_dir
        base_dir=$(cd "$config_dir/../.." 2>/dev/null && pwd || echo "$config_dir/../..")

        while IFS= read -r dir; do
            [ -n "$dir" ] || continue

            # 解析路径
            if [[ "$dir" =~ ^~/ ]]; then
                # 展开 ~
                dir="$HOME/${dir#~/}"
            elif [[ "$dir" != /* ]]; then
                # 相对路径，相对于项目根目录
                dir="$base_dir/$dir"
            fi

            # 规范化路径（处理 ../ 等）
            if [ -d "$dir" ]; then
                dir=$(cd "$dir" 2>/dev/null && pwd || echo "$dir")
                search_paths+=("$dir")
            fi
        done <<< "$skills_dirs"
    else
        # 使用默认目录：项目根目录下的 skills
        local project_root
        project_root=$(cd "$config_dir/../.." 2>/dev/null && pwd || echo "$config_dir/../..")
        if [ -d "$project_root/skills" ]; then
            search_paths+=("$project_root/skills")
        fi
    fi

    # 排除的目录模式
    local exclude_pattern="-name node_modules -o -name .git -o -name vendor -o -name dist -o -name build -o -name target -o -name __pycache__ -o -name .venv -o -name .claude"

    # 搜索 SKILL.md 文件
    local skill_files=()
    for search_path in "${search_paths[@]}"; do
        if [ -d "$search_path" ]; then
            while IFS= read -r file; do
                skill_files+=("$file")
            done < <(eval "find \"$search_path\" -type d \( $exclude_pattern \) -prune -o -name 'SKILL.md' -type f -print" 2>/dev/null || true)
        fi
    done

    printf '%s\n' "${skill_files[@]}"
}

# 搜索插件 commands 目录
find_command_files() {
    local plugin_cache="$HOME/.claude/plugins/cache"
    local command_files=()

    if [ -d "$plugin_cache" ]; then
        # 搜索所有 commands 目录下的 .md 文件
        # 排除 temp_git 和 orphaned 缓存目录
        while IFS= read -r file; do
            command_files+=("$file")
        done < <(find "$plugin_cache" -path "*/commands/*.md" -type f ! -path "*/temp_git*" ! -path "*/*/.orphaned_at" 2>/dev/null || true)
    fi

    printf '%s\n' "${command_files[@]}"
}

# 去重命令 ID（保留最新版本的命令）
deduplicate_commands() {
    local ids="$1"
    # 使用 awk 去重，保留最后出现的（通常是最新版本）
    echo "$ids" | awk '!seen[$0]++' | sort -u
}

# 提取 skill 信息（返回 JSON 格式）
# 参数: $1 = skill_file, $2 = output_format (yaml/json)
extract_skill_info() {
    local skill_file="$1"
    local output_format="${2:-yaml}"

    # 读取 frontmatter (--- 之间的内容)
    local frontmatter
    frontmatter=$(awk 'BEGIN{flag=0} /^---$/{if(++flag==2)exit;next} flag==1' "$skill_file" 2>/dev/null || echo "")

    if [ -z "$frontmatter" ]; then
        return 1
    fi

    # 提取 name 和 description
    local name description
    name=$(echo "$frontmatter" | grep "^name:" | head -1 | sed 's/^name:[[:space:]]*//' | tr -d '"' | tr -d "'" || echo "")
    description=$(echo "$frontmatter" | grep "^description:" | head -1 | sed 's/^description:[[:space:]]*//' | tr -d '"' | tr -d "'" || echo "")

    if [ -z "$name" ]; then
        return 1
    fi

    # 排除自身
    if should_exclude "$name"; then
        return 1
    fi

    # 获取文件路径（相对于项目根目录或绝对路径）
    local rel_path="$skill_file"

    if [ "$output_format" = "json" ]; then
        # JSON 格式输出（用于 LLM 判断）
        # 转义 description 中的特殊字符
        local escaped_desc
        escaped_desc=$(echo "$description" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ' | sed 's/  */ /g')
        cat <<EOF
{
  "id": "$name",
  "name": "$name",
  "type": "skill",
  "source_file": "$rel_path",
  "description": "$escaped_desc"
}
EOF
    else
        # YAML 格式输出（原有行为，带正则过滤）
        if ! is_review_skill "$frontmatter"; then
            return 1
        fi

        local category tags
        category=$(infer_category "$frontmatter")
        tags=$(infer_tags "$frontmatter")

        cat <<EOF
  - id: "$name"
    name: "$name"
    type: "skill"
    category: "$category"
    description: "$description"
    tags: $tags
    recommended_for: ["所有项目"]
EOF
    fi
}

# 从路径提取插件名和命令名
extract_command_id() {
    local file_path="$1"

    # 从路径中提取插件名和命令名
    # 路径格式: ~/.claude/plugins/cache/{provider}/{plugin_name}/{version}/commands/{command_name}.md
    # 或: ~/.claude/plugins/cache/{provider}/{plugin_name}/{hash}/commands/{command_name}.md
    local plugin_name command_name

    # 提取命令名（文件名去掉 .md）
    command_name=$(basename "$file_path" .md)

    # 提取插件名 - 从 commands 目录向上两级
    # 路径结构: .../{plugin_name}/{version_or_hash}/commands/{command}.md
    plugin_name=$(echo "$file_path" | sed -n 's|.*/\([^/]*\)/[^/]*/commands/[^/]*\.md$|\1|p' | head -1)

    if [ -n "$plugin_name" ] && [ -n "$command_name" ]; then
        echo "${plugin_name}:${command_name}"
    else
        return 1
    fi
}

# 提取 command 信息（返回 JSON 或 YAML 格式）
# 参数: $1 = command_file, $2 = output_format (yaml/json)
extract_command_info() {
    local command_file="$1"
    local output_format="${2:-yaml}"

    # 读取文件内容
    local content
    content=$(cat "$command_file" 2>/dev/null || echo "")

    if [ -z "$content" ]; then
        return 1
    fi

    # 提取 frontmatter
    local frontmatter
    frontmatter=$(awk 'BEGIN{flag=0} /^---$/{if(++flag==2)exit;next} flag==1' "$command_file" 2>/dev/null || echo "")

    # 提取命令 ID
    local cmd_id
    cmd_id=$(extract_command_id "$command_file")

    if [ -z "$cmd_id" ]; then
        return 1
    fi

    # 排除自身
    if should_exclude "$cmd_id"; then
        return 1
    fi

    # 提取 description（从 frontmatter 或文件开头）
    local description
    description=$(echo "$frontmatter" | grep "^description:" | head -1 | sed 's/^description:[[:space:]]*//' | tr -d '"' | tr -d "'" || echo "")

    if [ -z "$description" ]; then
        # 尝试从文件内容中提取第一行标题
        description=$(grep "^#" "$command_file" | head -1 | sed 's/^#[[:space:]]*//' | head -c 100 || echo "Code review command")
    fi

    if [ "$output_format" = "json" ]; then
        # JSON 格式输出（用于 LLM 判断）
        local escaped_desc
        escaped_desc=$(echo "$description" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ' | sed 's/  */ /g')
        cat <<EOF
{
  "id": "$cmd_id",
  "name": "$cmd_id",
  "type": "command",
  "source_file": "$command_file",
  "description": "$escaped_desc"
}
EOF
    else
        # YAML 格式输出（原有行为，带正则过滤）
        # 检查是否为 review 相关 command
        if ! is_review_skill "$frontmatter" && ! is_review_skill "$content"; then
            return 1
        fi

        local category tags
        category=$(infer_category "$frontmatter$content")
        tags=$(infer_tags "$frontmatter$content")

        cat <<EOF
  - id: "$cmd_id"
    name: "$cmd_id"
    type: "command"
    category: "$category"
    description: "$description"
    tags: $tags
    recommended_for: ["所有项目"]
EOF
    fi
}

# 显示使用帮助
show_help() {
    cat <<EOF
用法:
  $(basename "$0") [配置文件路径]                    # 直接模式：正则过滤后更新配置
  $(basename "$0") --collect-only [输出文件]         # 收集模式：输出所有候选项到 JSON
  $(basename "$0") --from-json [JSON文件] [配置文件] # JSON模式：从 JSON 更新配置

模式说明:
  直接模式:    使用正则表达式过滤后直接更新配置文件（原有行为）
  收集模式:    收集所有 skills 和 commands 到 JSON 文件，供 LLM 判断筛选
  JSON模式:    从 LLM 判断后的 JSON 文件更新配置

示例:
  # 直接模式
  $(basename "$0") .claude/code-review-skills/config.yaml

  # 收集模式（输出到临时文件）
  $(basename "$0") --collect-only /tmp/candidates.json

  # JSON模式（从 LLM 筛选后的文件更新配置）
  $(basename "$0") --from-json /tmp/filtered.json .claude/code-review-skills/config.yaml
EOF
}

# 收集所有候选项到 JSON 文件
collect_to_json() {
    local output_file="$1"
    local config_path="${2:-}"

    # 如果指定了配置文件，使用它来确定搜索目录
    if [ -n "$config_path" ]; then
        CONFIG_FILE="$config_path"
    else
        # 尝试查找配置文件（可选）
        CONFIG_FILE=$(find_config "$config_path" 2>/dev/null || echo "")
    fi

    # 获取配置目录（用于解析相对路径）
    local config_dir=""
    if [ -n "$CONFIG_FILE" ]; then
        config_dir=$(dirname "$CONFIG_FILE")
    fi

    echo -e "${BLUE}收集所有 Skills 和 Commands 候选项${NC}"
    echo "=========================================="
    echo ""

    # 搜索 SKILL.md 文件
    local skill_files=()
    if [ -n "$config_dir" ]; then
        while IFS= read -r file; do
            [ -n "$file" ] && skill_files+=("$file")
        done < <(find_skill_files "$config_dir")
    else
        # 没有配置文件，使用默认搜索
        while IFS= read -r file; do
            [ -n "$file" ] && skill_files+=("$file")
        done < <(find . -name "SKILL.md" -type f 2>/dev/null || true)
    fi

    echo -e "找到 ${GREEN}${#skill_files[@]}${NC} 个 SKILL.md 文件"

    # 搜索插件 commands
    local command_files=()
    while IFS= read -r file; do
        [ -n "$file" ] && command_files+=("$file")
    done < <(find_command_files)

    echo -e "找到 ${GREEN}${#command_files[@]}${NC} 个 command 文件"
    echo ""

    # 收集所有候选项（JSON 格式）
    local candidates=()
    local seen_ids=()

    # 收集 skills
    for skill_file in "${skill_files[@]}"; do
        local skill_json
        if skill_json=$(extract_skill_info "$skill_file" "json"); then
            local skill_id
            skill_id=$(echo "$skill_json" | grep '"id":' | head -1 | sed 's/.*"id": *"\([^"]*\)".*/\1/')
            if [[ ! " ${seen_ids[*]} " =~ " ${skill_id} " ]]; then
                candidates+=("$skill_json")
                seen_ids+=("$skill_id")
            fi
        fi
    done

    # 收集 commands（去重）
    for command_file in "${command_files[@]}"; do
        local cmd_json
        if cmd_json=$(extract_command_info "$command_file" "json"); then
            local cmd_id
            cmd_id=$(echo "$cmd_json" | grep '"id":' | head -1 | sed 's/.*"id": *"\([^"]*\)".*/\1/')
            if [[ ! " ${seen_ids[*]} " =~ " ${cmd_id} " ]]; then
                candidates+=("$cmd_json")
                seen_ids+=("$cmd_id")
            fi
        fi
    done

    echo -e "收集到 ${GREEN}${#candidates[@]}${NC} 个候选项"

    # 输出 JSON 文件
    local json_content
    json_content=$(printf '%s,\n' "${candidates[@]}" | sed '$ s/,$//')

    cat > "$output_file" <<EOF
{
  "collected_at": "$(date -Iseconds)",
  "total_candidates": ${#candidates[@]},
  "candidates": [
$json_content
  ]
}
EOF

    echo -e "${GREEN}✓${NC} 候选项已保存到: $output_file"
    echo ""
    echo "下一步:"
    echo "1. 使用 LLM 判断哪些候选项是 code review 相关的"
    echo "2. LLM 应输出筛选后的 JSON 文件，格式与输入相同"
    echo "3. 使用 --from-json 参数更新配置文件"
}

# 从 JSON 文件更新配置
update_from_json() {
    local json_file="$1"
    local config_path="$2"

    if [ ! -f "$json_file" ]; then
        echo -e "${RED}错误${NC} JSON 文件不存在: $json_file" >&2
        exit 1
    fi

    # 查找配置文件
    CONFIG_FILE=$(find_config "$config_path")

    echo -e "${BLUE}从 JSON 文件更新配置${NC}"
    echo "=========================================="
    echo -e "JSON 文件: ${GREEN}$json_file${NC}"
    echo -e "配置文件: ${GREEN}$CONFIG_FILE${NC}"
    echo ""

    # 解析 JSON 并生成 YAML
    local yaml_entries=()
    local count=0

    # 使用 jq 或简单的文本处理解析 JSON
    if command -v jq &>/dev/null; then
        # 使用 jq 解析（推荐）
        local total
        total=$(jq '.total_candidates // 0' "$json_file" 2>/dev/null || echo "0")
        echo -e "JSON 中包含 ${GREEN}${total}${NC} 个候选项"

        # 读取 candidates 数组
        while IFS= read -r candidate; do
            [ -z "$candidate" ] && continue

            local id name type category tags description
            id=$(echo "$candidate" | jq -r '.id // empty')
            name=$(echo "$candidate" | jq -r '.name // .id // empty')
            type=$(echo "$candidate" | jq -r '.type // "skill"')
            description=$(echo "$candidate" | jq -r '.description // ""' | head -c 200)

            # 从 description 推断 category 和 tags
            category=$(infer_category_from_text "$description")
            tags=$(infer_tags_from_text "$description")

            if [ -n "$id" ]; then
                yaml_entries+=("  - id: \"$id\"
    name: \"$name\"
    type: \"$type\"
    category: \"$category\"
    description: \"$description\"
    tags: $tags
    recommended_for: [\"所有项目\"]")
                count=$((count + 1))
            fi
        done < <(jq -c '.candidates[] // empty' "$json_file" 2>/dev/null)
    else
        # 简单文本解析（备用）
        echo -e "${YELLOW}警告${NC} 未找到 jq 命令，使用简单文本解析"
        while IFS= read -r line; do
            if [[ "$line" =~ '"id":'* ]]; then
                local id
                id=$(echo "$line" | sed 's/.*"id": *"\([^"]*\)".*/\1/')
                # ... 简单解析
            fi
        done < "$json_file"
    fi

    echo -e "处理了 ${GREEN}${count}${NC} 个候选项"

    if [ ${#yaml_entries[@]} -eq 0 ]; then
        echo -e "${YELLOW}警告${NC} JSON 文件中没有有效的候选项"
        exit 1
    fi

    # 保留原有的 presets 部分
    local presets_section
    presets_section=$(sed -n '/^presets:/,$p' "$CONFIG_FILE" 2>/dev/null || echo "")

    # 生成新的配置内容
    local current_date
    current_date=$(date +%Y-%m-%d)

    {
        echo "# Code Review Skills 配置文件"
        echo "# 此文件由 code-review:config-manager 管理"
        echo "#"
        echo "# 能力类型说明:"
        echo "# - skill: SKILL.md 格式的技能"
        echo "# - command: 插件中的命令"
        echo ""
        echo "metadata:"
        echo "  version: \"0.1.0\""
        echo "  last_updated: \"$current_date\""
        echo "  auto_sync: true     # 是否自动同步 skills"
        echo ""
        echo "# Skills 搜索目录配置"
        echo "# 支持相对路径（相对于配置文件所在目录）和绝对路径"
        echo "skills_directories:"
        echo "  - \"skills\"           # 默认：项目内的 skills 目录"
        echo "  # - \".skills\"          # 可选：隐藏的 skills 目录"
        echo "  # - \"../other-skills\"  # 可选：其他项目的 skills 目录"
        echo "  # - \"~/.claude/skills\" # 可选：用户级 skills 目录"
        echo ""
        echo "# 可用的 code review skills 和 commands"
        echo "# 此列表由 discover-skills.sh 生成，并由 LLM 判断筛选"
        echo "# 已排除自身 (code-review:config-manager, code-review:executor)"
        echo "available_skills:"
        printf '%s\n' "${yaml_entries[@]}"
        echo ""
        echo "$presets_section"
    } > "$CONFIG_FILE"

    echo -e "${GREEN}✓${NC} 配置文件已更新: $CONFIG_FILE"
}

# 从文本推断分类
infer_category_from_text() {
    local text="$1"

    if echo "$text" | grep -qiE "security|audit|threat"; then
        echo "安全审计"
    elif echo "$text" | grep -qiE "test|coverage|tdd"; then
        echo "测试+清理"
    elif echo "$text" | grep -qiE "performance|optimization|database"; then
        echo "性能+架构"
    elif echo "$text" | grep -qiE "quality|lint|cleanup"; then
        echo "代码质量"
    else
        echo "代码质量"
    fi
}

# 从文本推断标签
infer_tags_from_text() {
    local text="$1"
    local tags=()

    if echo "$text" | grep -qiE "review|code-review"; then
        tags+=("review")
    fi
    if echo "$text" | grep -qiE "security|audit"; then
        tags+=("security")
    fi
    if echo "$text" | grep -qiE "test|testing|tdd"; then
        tags+=("testing")
    fi
    if echo "$text" | grep -qiE "performance|optimization"; then
        tags+=("performance")
    fi

    # 转换为 JSON 数组格式
    if [ ${#tags[@]} -eq 0 ]; then
        echo "[]"
    elif [ ${#tags[@]} -eq 1 ]; then
        echo "[\"${tags[0]}\"]"
    else
        local result
        result=$(printf '"%s",' "${tags[@]}")
        echo "[${result%,}]"
    fi
}

# 原有的主函数（直接模式）
main_direct() {
    local config_path="${1:-}"

    # 查找配置文件
    CONFIG_FILE=$(find_config "$config_path")

    echo -e "${BLUE}自动发现 Code Review Skills 和 Commands${NC}"
    echo "=========================================="
    echo -e "配置文件: ${GREEN}$CONFIG_FILE${NC}"
    echo ""

    # 获取配置文件所在目录
    local config_dir
    config_dir=$(dirname "$CONFIG_FILE")

    # 搜索 SKILL.md 文件
    echo -e "${BLUE}搜索 SKILL.md 文件...${NC}"
    local skill_files=()
    while IFS= read -r file; do
        [ -n "$file" ] && skill_files+=("$file")
    done < <(find_skill_files "$config_dir")

    echo -e "找到 ${GREEN}${#skill_files[@]}${NC} 个 SKILL.md 文件"

    # 搜索插件 commands
    echo -e "${BLUE}搜索插件 commands...${NC}"
    local command_files=()
    while IFS= read -r file; do
        [ -n "$file" ] && command_files+=("$file")
    done < <(find_command_files)

    echo -e "找到 ${GREEN}${#command_files[@]}${NC} 个 command 文件"
    echo ""

    # 提取 skill 信息
    echo -e "${BLUE}提取 review 能力信息...${NC}"
    local skills_output=()
    local found_skills=0
    local found_commands=0
    local seen_ids=()

    for skill_file in "${skill_files[@]}"; do
        local skill_info
        if skill_info=$(extract_skill_info "$skill_file" "yaml"); then
            local skill_id
            skill_id=$(echo "$skill_info" | grep "^  - id:" | sed 's/.*id: "\([^"]*\)".*/\1/')
            # 检查是否已存在
            if [[ ! " ${seen_ids[*]} " =~ " ${skill_id} " ]]; then
                skills_output+=("$skill_info")
                found_skills=$((found_skills + 1))
                seen_ids+=("$skill_id")
            fi
        fi
    done

    # 提取 command 信息（去重）
    for command_file in "${command_files[@]}"; do
        local cmd_info
        if cmd_info=$(extract_command_info "$command_file" "yaml"); then
            local cmd_id
            cmd_id=$(echo "$cmd_info" | grep "^  - id:" | sed 's/.*id: "\([^"]*\)".*/\1/')
            # 检查是否已存在
            if [[ ! " ${seen_ids[*]} " =~ " ${cmd_id} " ]]; then
                skills_output+=("$cmd_info")
                found_commands=$((found_commands + 1))
                seen_ids+=("$cmd_id")
            fi
        fi
    done

    echo -e "识别出 ${GREEN}${found_skills}${NC} 个 skills, ${GREEN}${found_commands}${NC} 个 commands"
    echo ""

    if [ ${#skills_output[@]} -eq 0 ]; then
        echo -e "${YELLOW}警告${NC} 未找到任何 review 相关的 skills 或 commands"
        echo "请检查 skills_directories 配置或确保 skills 目录存在"
        exit 1
    fi

    # 显示按分类分组的 skills/commands
    echo -e "${BLUE}发现的 Review 能力:${NC}"
    echo ""

    # 临时存储以便后续使用
    local temp_skills
    temp_skills=$(printf '%s\n' "${skills_output[@]}")

    # 按分类显示
    for category in "代码质量" "安全审计" "测试+清理" "性能+架构"; do
        local category_skills
        category_skills=$(echo "$temp_skills" | grep "category: \"$category\"" || echo "")

        if [ -n "$category_skills" ]; then
            echo -e "${YELLOW}$category${NC}:"
            # 从 skills_output 中提取该分类的 skill id
            for skill_entry in "${skills_output[@]}"; do
                if echo "$skill_entry" | grep -q "category: \"$category\""; then
                    local skill_id skill_type
                    skill_id=$(echo "$skill_entry" | grep "^  - id:" | sed 's/.*id: "\([^"]*\)".*/\1/')
                    skill_type=$(echo "$skill_entry" | grep "^    type:" | sed 's/.*type: "\([^"]*\)".*/\1/' || echo "skill")
                    if [ -n "$skill_id" ]; then
                        echo "  - $skill_id [$skill_type]"
                    fi
                fi
            done
            echo ""
        fi
    done

    # 更新配置文件
    echo -e "${BLUE}更新配置文件...${NC}"

    # 保留原有的 presets 部分
    local presets_section
    presets_section=$(sed -n '/^presets:/,$p' "$CONFIG_FILE" 2>/dev/null || echo "")

    # 生成新的配置内容
    local current_date
    current_date=$(date +%Y-%m-%d)

    cat > "$CONFIG_FILE" <<EOF
# Code Review Skills 配置文件
# 此文件由 code-review:config-manager 管理
#
# 能力类型说明:
# - skill: SKILL.md 格式的技能
# - command: 插件中的命令

metadata:
  version: "0.1.0"
  last_updated: "$current_date"
  auto_sync: true     # 是否自动同步 skills

# Skills 搜索目录配置
# 支持相对路径（相对于配置文件所在目录）和绝对路径
skills_directories:
  - "skills"           # 默认：项目内的 skills 目录
  # - ".skills"          # 可选：隐藏的 skills 目录
  # - "../other-skills"  # 可选：其他项目的 skills 目录
  # - "~/.claude/skills" # 可选：用户级 skills 目录

# 可用的 code review skills 和 commands
# 此列表由 discover-skills.sh 自动生成和更新
# 已排除自身 (code-review:config-manager, code-review:executor)
available_skills:
$(printf '%s\n' "${skills_output[@]}")

$presets_section
EOF

    echo -e "${GREEN}✓${NC} 配置文件已更新: $CONFIG_FILE"
    echo ""
    echo "下一步:"
    echo "- 运行 validate-config.sh 验证配置"
    echo "- 编辑 presets 配置你常用的 skill/command 组合"
}

# 主入口
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --collect-only)
                COLLECT_ONLY=true
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --from-json)
                FROM_JSON="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                # 位置参数：配置文件路径
                break
                ;;
        esac
    done

    local config_path="${1:-}"

    # 根据模式执行
    if [ "$COLLECT_ONLY" = true ]; then
        collect_to_json "$OUTPUT_FILE" "$config_path"
    elif [ -n "$FROM_JSON" ]; then
        update_from_json "$FROM_JSON" "$config_path"
    else
        main_direct "$config_path"
    fi
}

# 执行主函数
main "$@"
