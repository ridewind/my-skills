#!/bin/bash
# init-config.sh - 初始化配置文件
#
# 用法: ./init-config.sh [--global|--user|--project] [路径]
#
# 选项:
#   --global   创建全局配置 (~/.config/claude/code-review-skills/config.yaml)
#   --user     创建用户配置 (~/.claude/code-review-skills/config.yaml)
#   --project  创建项目配置 (.claude/code-review-skills/config.yaml)
#
# 如果未指定选项，默认创建项目配置

set -euo pipefail

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 确定配置路径
determine_path() {
    local option="$1"
    local custom_path="$2"

    if [ -n "$custom_path" ]; then
        echo "$custom_path"
        return
    fi

    case "$option" in
        --global)
            echo "$HOME/.config/claude/code-review-skills/config.yaml"
            ;;
        --user)
            echo "$HOME/.claude/code-review-skills/config.yaml"
            ;;
        --project|"")
            echo ".claude/code-review-skills/config.yaml"
            ;;
        *)
            echo "未知选项: $option" >&2
            exit 1
            ;;
    esac
}

# 创建默认配置
create_default_config() {
    local path="$1"
    local dir
    dir=$(dirname "$path")

    # 创建目录
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "${GREEN}✓${NC} 创建目录: $dir"
    fi

    # 检查文件是否已存在
    if [ -f "$path" ]; then
        echo -e "${YELLOW}⚠${NC} 配置文件已存在: $path"
        read -p "是否覆盖? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "操作已取消"
            exit 0
        fi
    fi

    # 生成默认配置
    cat > "$path" <<'EOF'
# Code Review Skills 配置文件
# 此文件由 code-review:config-manager 管理

metadata:
  version: "0.1.0"
  last_updated: null  # 将在首次更新时设置
  auto_sync: true     # 是否自动同步 skills

# 可用的 code review skills
# 此列表由 discover-skills.sh 自动生成和更新
available_skills: []

# 预设配置
# 定义常用的 skill 组合
presets:
  - name: "快速审查"
    description: "轻量级快速审查，适用于日常开发"
    skills:
      - "code-review:code-review"

  - name: "全面审查"
    description: "包含所有维度的深度审查"
    skills:
      - "code-review:code-review"
      - "security-scanning:security-auditor"
      - "application-performance:performance-engineer"

  - name: "安全优先"
    description: "重点关注安全问题的审查"
    skills:
      - "security-scanning:security-auditor"
      - "security-scanning:threat-modeling-expert"

  - name: "性能优化"
    description: "关注性能和架构的审查"
    skills:
      - "application-performance:performance-engineer"
      - "backend-development:backend-architect"
EOF

    echo -e "${GREEN}✓${NC} 创建配置文件: $path"
    echo ""
    echo "下一步:"
    echo "1. 运行 discover-skills.sh 自动发现并更新 available_skills"
    echo "2. 编辑 presets 配置你常用的 skill 组合"
    echo "3. 运行 validate-config.sh 验证配置"
}

# 主函数
main() {
    local option=""
    local custom_path=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --global|--user|--project)
                option="$1"
                shift
                ;;
            *)
                custom_path="$1"
                shift
                ;;
        esac
    done

    # 确定路径
    local config_path
    config_path=$(determine_path "$option" "$custom_path")

    echo -e "${BLUE}初始化 Code Review 配置${NC}"
    echo "================================"

    # 创建默认配置
    create_default_config "$config_path"
}

# 执行主函数
main "$@"
