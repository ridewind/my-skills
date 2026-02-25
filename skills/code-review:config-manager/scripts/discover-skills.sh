#!/bin/bash
# discover-skills.sh - 自动发现并更新 code review skills
#
# 用法: ./discover-skills.sh [配置文件路径]
#
# 如果未指定配置文件路径，自动查找项目、用户、全局配置

set -euo pipefail

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# 检查是否为 review 相关 skill
is_review_skill() {
    local content="$1"
    local keywords="review|auditor|auditor|security|threat|test|testing|coverage|performance|optimization|quality|cleanup|lint"

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
    local result=$(printf '"%s"' "${tags[@]}" | tr ' ' ',' | sed 's/,$//')
    if [ -z "$result" ]; then
        echo "[]"
    else
        echo "[$result]"
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

# 提取 skill 信息
extract_skill_info() {
    local skill_file="$1"

    # 读取 frontmatter (--- 之间的内容)
    # 使用 awk 更可靠地提取第一个和第二个 --- 之间的内容
    local frontmatter
    frontmatter=$(awk 'BEGIN{flag=0} /^---$/{if(++flag==2)exit;next} flag==1' "$skill_file" 2>/dev/null || echo "")

    if [ -z "$frontmatter" ]; then
        return 1
    fi

    # 检查是否为 review 相关 skill
    if ! is_review_skill "$frontmatter"; then
        return 1
    fi

    # 提取 name 和 description
    local name description
    name=$(echo "$frontmatter" | grep "^name:" | head -1 | sed 's/^name:[[:space:]]*//' | tr -d '"' | tr -d "'" || echo "")
    description=$(echo "$frontmatter" | grep "^description:" | head -1 | sed 's/^description:[[:space:]]*//' | tr -d '"' | tr -d "'" || echo "")

    if [ -z "$name" ]; then
        return 1
    fi

    # 推断分类和标签
    local category tags
    category=$(infer_category "$frontmatter")
    tags=$(infer_tags "$frontmatter")

    # 输出 YAML 格式
    cat <<EOF
  - id: "$name"
    name: "$name"
    category: "$category"
    description: "$description"
    tags: $tags
    recommended_for: ["所有项目"]
EOF
}

# 主函数
main() {
    local config_path="${1:-}"

    # 查找配置文件
    CONFIG_FILE=$(find_config "$config_path")

    echo -e "${BLUE}自动发现 Code Review Skills${NC}"
    echo "================================"
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

    if [ ${#skill_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}警告${NC} 未找到任何 SKILL.md 文件"
        echo "请检查 skills_directories 配置或确保 skills 目录存在"
        exit 1
    fi

    echo -e "找到 ${GREEN}${#skill_files[@]}${NC} 个 SKILL.md 文件"
    echo ""

    # 提取 skill 信息
    echo -e "${BLUE}提取 skill 信息...${NC}"
    local skills_output=()
    local found_count=0

    for skill_file in "${skill_files[@]}"; do
        local skill_info
        if skill_info=$(extract_skill_info "$skill_file"); then
            skills_output+=("$skill_info")
            ((found_count++))
        fi
    done

    echo -e "识别出 ${GREEN}${found_count}${NC} 个 review 相关 skills"
    echo ""

    # 显示按分类分组的 skills
    echo -e "${BLUE}发现的 Skills:${NC}"
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
            echo "$category_skills" | while IFS= read -r line; do
                if [[ $line =~ id:\ ([^\"]+) ]]; then
                    local id="${BASH_REMATCH[1]}"
                    local name=$(echo "$line" | grep "name:" | sed 's/.*name: "\([^"]*\)".*/\1/')
                    echo "  - $id"
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

# 可用的 code review skills
# 此列表由 discover-skills.sh 自动生成和更新
available_skills:
$(printf '%s\n' "${skills_output[@]}")

$presets_section
EOF

    echo -e "${GREEN}✓${NC} 配置文件已更新: $CONFIG_FILE"
    echo ""
    echo "下一步:"
    echo "- 运行 validate-config.sh 验证配置"
    echo "- 编辑 presets 配置你常用的 skill 组合"
}

# 执行主函数
main "$@"
