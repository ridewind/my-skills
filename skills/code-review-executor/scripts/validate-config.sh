#!/bin/bash
# validate-config.sh - 验证配置文件的正确性
#
# 用法: ./validate-config.sh [配置文件路径]
#
# 如果未指定路径，将按优先级查找配置文件

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 yq 是否安装
check_yq() {
    if ! command -v yq &> /dev/null; then
        echo -e "${RED}错误: 未找到 yq 工具${NC}"
        echo "请安装 yq: https://github.com/mikefarah/yq"
        exit 1
    fi
}

# 查找配置文件
find_config_file() {
    local specified_path="$1"

    if [ -n "$specified_path" ]; then
        if [ -f "$specified_path" ]; then
            echo "$specified_path"
            return 0
        else
            echo -e "${RED}错误: 指定的配置文件不存在: $specified_path${NC}"
            exit 1
        fi
    fi

    # 按优先级查找
    local config_paths=(
        ".claude/code-review-skills/config.yaml"
        "$HOME/.claude/code-review-skills/config.yaml"
        "$HOME/.config/claude/code-review-skills/config.yaml"
    )

    for path in "${config_paths[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    echo -e "${YELLOW}未找到配置文件${NC}"
    return 1
}

# 验证 YAML 语法
validate_yaml_syntax() {
    local config_file="$1"

    if ! yq eval '.' "$config_file" > /dev/null 2>&1; then
        echo -e "${RED}✗ YAML 语法错误${NC}"
        return 1
    else
        echo -e "${GREEN}✓ YAML 语法正确${NC}"
        return 0
    fi
}

# 验证必需字段
validate_required_fields() {
    local config_file="$1"
    local has_errors=0

    # 检查 metadata
    if ! yq eval '.metadata' "$config_file" > /dev/null 2>&1; then
        echo -e "${RED}✗ 缺少 metadata 字段${NC}"
        has_errors=1
    else
        echo -e "${GREEN}✓ metadata 字段存在${NC}"
    fi

    # 检查 available_skills
    if ! yq eval '.available_skills' "$config_file" > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ available_skills 字段缺失（将在首次运行时自动填充）${NC}"
    else
        echo -e "${GREEN}✓ available_skills 字段存在${NC}"
    fi

    # 检查 skills_directories（可选）
    if ! yq eval '.skills_directories' "$config_file" > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ skills_directories 字段缺失（将使用默认搜索策略）${NC}"
    else
        echo -e "${GREEN}✓ skills_directories 字段存在${NC}"

        # 验证目录是否存在
        local dir_count
        dir_count=$(yq eval '.skills_directories | length' "$config_file")
        echo -e "${GREEN}  配置了 $dir_count 个 skills 搜索目录${NC}"
    fi

    # 检查 presets
    if ! yq eval '.presets' "$config_file" > /dev/null 2>&1; then
        echo -e "${RED}✗ 缺少 presets 字段${NC}"
        has_errors=1
    else
        echo -e "${GREEN}✓ presets 字段存在${NC}"
    fi

    return $has_errors
}

# 验证 presets 结构
validate_presets() {
    local config_file="$1"
    local has_errors=0

    local preset_count
    preset_count=$(yq eval '.presets | length' "$config_file")

    if [ "$preset_count" -eq 0 ]; then
        echo -e "${YELLOW}⚠ 没有定义任何 preset${NC}"
        return 0
    fi

    echo -e "${GREEN}发现 $preset_count 个 preset(s)${NC}"

    # 检查每个 preset
    for ((i=0; i<preset_count; i++)); do
        local name
        name=$(yq eval ".presets[$i].name" "$config_file")

        if [ "$name" = "null" ] || [ -z "$name" ]; then
            echo -e "${RED}✗ preset[$i] 缺少 name 字段${NC}"
            has_errors=1
            continue
        fi

        # 检查 skills 字段
        if ! yq eval ".presets[$i].skills" "$config_file" > /dev/null 2>&1; then
            echo -e "${RED}✗ preset '$name' 缺少 skills 字段${NC}"
            has_errors=1
        else
            local skill_count
            skill_count=$(yq eval ".presets[$i].skills | length" "$config_file")
            echo -e "${GREEN}✓ preset '$name' 包含 $skill_count 个 skill(s)${NC}"
        fi
    done

    return $has_errors
}

# 验证 skill ID 格式
validate_skill_ids() {
    local config_file="$1"
    local has_errors=0

    # 提取所有 preset 中的 skill ID
    local skill_ids
    skill_ids=$(yq eval '.presets[].skills[]' "$config_file" 2>/dev/null | tr -d '"')

    if [ -z "$skill_ids" ]; then
        return 0
    fi

    echo ""
    echo "验证 skill ID 格式:"

    while IFS= read -r skill_id; do
        if [ -z "$skill_id" ]; then
            continue
        fi

        # 检查格式：应该包含冒号（如 code-review:code-review）
        if [[ ! "$skill_id" =~ ^[a-zA-Z0-9_-]+:[a-zA-Z0-9_-]+$ ]]; then
            echo -e "${YELLOW}⚠ skill ID 格式可能不正确: $skill_id${NC}"
        fi
    done <<< "$skill_ids"

    return $has_errors
}

# 主函数
main() {
    local config_file
    config_file=$(find_config_file "${1:-}")

    if [ $? -ne 0 ]; then
        exit 1
    fi

    echo "验证配置文件: $config_file"
    echo "================================"

    # 检查 yq
    check_yq

    # 验证 YAML 语法
    echo ""
    validate_yaml_syntax "$config_file" || exit 1

    # 验证必需字段
    echo ""
    validate_required_fields "$config_file"

    # 验证 presets
    echo ""
    validate_presets "$config_file"

    # 验证 skill ID 格式
    validate_skill_ids "$config_file"

    echo ""
    echo -e "${GREEN}验证完成${NC}"
}

# 执行主函数
main "$@"
