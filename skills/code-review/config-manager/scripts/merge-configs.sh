#!/bin/bash
# merge-configs.sh - 合并多层级配置文件
#
# 用法: ./merge-config.sh [输出路径]
#
# 如果未指定输出路径，将输出到 stdout

set -euo pipefail

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查 yq 是否安装
check_yq() {
    if ! command -v yq &> /dev/null; then
        echo "错误: 未找到 yq 工具"
        echo "请安装 yq: https://github.com/mikefarah/yq"
        exit 1
    fi
}

# 获取配置文件路径
get_config_paths() {
    # 按优先级从低到高排列
    echo "$HOME/.config/claude/code-review-skills/config.yaml"
    echo "$HOME/.claude/code-review-skills/config.yaml"
    echo ".claude/code-review-skills/config.yaml"
}

# 检查文件是否存在
file_exists() {
    [ -f "$1" ]
}

# 读取字段值
read_field() {
    local file="$1"
    local field="$2"

    if file_exists "$file"; then
        yq eval "$field" "$file" 2>/dev/null || echo "null"
    else
        echo "null"
    fi
}

# 合并 available_skills（取并集）
merge_available_skills() {
    local global="$1"
    local user="$2"
    local project="$3"

    echo "# 合并 available_skills（取并集，去重）"

    # 收集所有 skills
    local all_skills="[]"

    for config in "$global" "$user" "$project"; do
        if file_exists "$config"; then
            local skills
            skills=$(yq eval '.available_skills // []' "$config")

            if [ "$skills" != "[]" ]; then
                all_skills=$(echo "$all_skills" | yq eval ". + $skills")
            fi
        fi
    done

    # 去重（基于 id）
    local unique_skills
    unique_skills=$(echo "$all_skills" | yq eval 'unique_by(.id)')

    echo "$unique_skills"
}

# 合并 presets（按名称覆盖）
merge_presets() {
    local global="$1"
    local user="$2"
    local project="$3"

    echo "# 合并 presets（按名称覆盖，项目 > 用户 > 全局）"

    local merged_presets="[]"

    for config in "$global" "$user" "$project"; do
        if file_exists "$config"; then
            local presets
            presets=$(yq eval '.presets // []' "$config")

            if [ "$presets" != "[]" ]; then
                # 合并，同名的 preset 会被覆盖
                merged_presets=$(echo "$merged_presets" | yq eval ". * $presets")
            fi
        fi
    done

    echo "$merged_presets"
}

# 获取最高优先级的 metadata
get_metadata() {
    local global="$1"
    local user="$2"
    local project="$3"

    # 从高到低查找第一个有效的 metadata
    for config in "$project" "$user" "$global"; do
        if file_exists "$config"; then
            local metadata
            metadata=$(yq eval '.metadata // {}' "$config")

            if [ "$metadata" != "{}" ]; then
                echo "$metadata"
                return
            fi
        fi
    done

    echo "{}"
}

# 主函数
main() {
    local output_path="${1:-}"

    # 检查 yq
    check_yq

    # 获取配置文件路径
    local config_paths
    mapfile -t config_paths < <(get_config_paths)

    local global="${config_paths[0]}"
    local user="${config_paths[1]}"
    local project="${config_paths[2]}"

    echo -e "${BLUE}合并配置文件${NC}"
    echo "================================"

    # 显示找到的配置文件
    if file_exists "$project"; then
        echo -e "${GREEN}✓${NC} 项目配置: $project"
    else
        echo "- 项目配置: 不存在"
    fi

    if file_exists "$user"; then
        echo -e "${GREEN}✓${NC} 用户配置: $user"
    else
        echo "- 用户配置: 不存在"
    fi

    if file_exists "$global"; then
        echo -e "${GREEN}✓${NC} 全局配置: $global"
    else
        echo "- 全局配置: 不存在"
    fi

    # 如果没有任何配置文件
    if ! file_exists "$project" && ! file_exists "$user" && ! file_exists "$global"; then
        echo ""
        echo "警告: 未找到任何配置文件"
        exit 0
    fi

    echo ""

    # 构建合并后的配置
    local metadata
    local available_skills
    local presets

    metadata=$(get_metadata "$global" "$user" "$project")
    available_skills=$(merge_available_skills "$global" "$user" "$project")
    presets=$(merge_presets "$global" "$user" "$project")

    # 生成完整配置
    local merged_config
    merged_config=$(cat <<EOF
metadata:
${metadata}
available_skills:
${available_skills}
presets:
${presets}
EOF
)

    # 输出结果
    if [ -n "$output_path" ]; then
        echo "$merged_config" > "$output_path"
        echo -e "${GREEN}✓${NC} 合并后的配置已保存到: $output_path"
    else
        echo "合并后的配置:"
        echo "================================"
        echo "$merged_config"
    fi
}

# 执行主函数
main "$@"
