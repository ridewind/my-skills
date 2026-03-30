#!/bin/bash
# init-config.sh - 初始化配置文件
#
# 用法: ./init-config.sh [--global|--user|--project|--force] [路径]
#
# 选项:
#   --global   创建全局配置 (~/.config/claude/code-review-skills/config.yaml)
#   --user     创建用户配置 (~/.claude/code-review-skills/config.yaml)
#   --project  创建项目配置 (.claude/code-review-skills/config.yaml)
#   --force    强制覆盖已存在的配置文件，无需确认
#   --skip-discover 跳过自动发现 skills 步骤
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
    local force_mode="${FORCE_MODE:-false}"
    local skip_discover="${SKIP_DISCOVER:-false}"
    dir=$(dirname "$path")

    # 创建目录
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "${GREEN}✓${NC} 创建目录: $dir"
    fi

    # 检查文件是否已存在
    if [ -f "$path" ]; then
        echo -e "${YELLOW}⚠${NC} 配置文件已存在: $path"
        if [ "$force_mode" = "true" ]; then
            echo -e "${YELLOW}⚠${NC} 使用 --force 模式，将覆盖现有配置"
        else
            # 检查是否在交互式终端
            if [ -t 0 ]; then
                read -p "是否覆盖? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "操作已取消"
                    exit 0
                fi
            else
                echo -e "${YELLOW}⚠${NC} 非交互式环境，使用 --force 选项覆盖"
                echo "操作已取消（使用 --force 强制覆盖）"
                exit 1
            fi
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

# Skills 搜索目录配置
# 支持相对路径（相对于配置文件所在目录）和绝对路径
skills_directories:
  - "skills"           # 默认：项目内的 skills 目录
  # - ".skills"          # 可选：隐藏的 skills 目录
  # - "../other-skills"  # 可选：其他项目的 skills 目录
  # - "~/.claude/skills" # 可选：用户级 skills 目录

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

    # 询问是否立即运行 discover-skills.sh
    echo ""
    if [ "$skip_discover" = "true" ]; then
        echo -e "${BLUE}ℹ${NC} 跳过自动发现 skills"
    elif [ -t 0 ]; then
        read -p "是否立即自动发现 skills? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            local script_dir
            script_dir=$(dirname "${BASH_SOURCE[0]}")
            if [ -f "$script_dir/discover-skills.sh" ]; then
                bash "$script_dir/discover-skills.sh" "$path"
            else
                echo -e "${YELLOW}⚠${NC} discover-skills.sh 未找到，请稍后手动运行"
            fi
        fi
    else
        echo -e "${BLUE}ℹ${NC} 非交互式环境，跳过自动发现"
        echo "   （使用 --skip-discover 跳过或手动运行 discover-skills.sh）"
    fi
}

# 主函数
main() {
    local option=""
    local custom_path=""
    local force=false
    local skip_discover=false

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --global|--user|--project)
                option="$1"
                shift
                ;;
            --force|-f)
                force=true
                shift
                ;;
            --skip-discover|-s)
                skip_discover=true
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
    export FORCE_MODE="$force"
    export SKIP_DISCOVER="$skip_discover"

    echo -e "${BLUE}初始化 Code Review 配置${NC}"
    echo "================================"

    # 创建默认配置
    create_default_config "$config_path"
}

# 执行主函数
main "$@"
