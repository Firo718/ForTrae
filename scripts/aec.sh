#!/bin/bash
# Autonomous Evolution Cycle - 主入口脚本
# 整合所有功能，提供统一CLI

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}"
LIB_DIR="${SCRIPTS_DIR}/lib"

# 导入公共库
if [[ -f "${LIB_DIR}/core.sh" ]]; then
    source "${LIB_DIR}/core.sh"
else
    # 备用初始化
    AEC_WORKSPACE="${OPENCLAW_WORKSPACE:-${HOME}/.openclaw/workspace}"
    AEC_LOG_DIR="${HOME}/.openclaw/logs"
    AEC_SCRIPT_NAME="aec"
    mkdir -p "${AEC_WORKSPACE}"/{config,memory/{working,factual,experiential,patterns},logs}
    
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [aec] $1"; }
    log_warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] [aec] $1"; }
    log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [aec] $1"; }
    
    aec_init() { log_info "Autonomous Evolution Cycle initialized"; }
fi

WORKSPACE="${AEC_WORKSPACE}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

#######################################
# 帮助信息
#######################################

show_help() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║          Autonomous Evolution Cycle v2.0                       ║
║          自主演化周期 - OpenClaw AI助手Skill                    ║
╚═══════════════════════════════════════════════════════════════╝

用法: aec <命令> [参数]

📋 核心命令:
  init                    初始化系统环境
  plan [summary]          生成今日任务计划
  status                  显示当前状态
  progress [report]       分析进度偏差

🔄 任务管理:
  task create <标题> <描述> [类型] [优先级]  创建任务
  task activate <ID>      激活任务
  task progress <ID> <进度> [消息]         更新进度
  task complete <ID> [结果]               完成任务
  task list               列出所有任务
  task cancel <ID>        取消任务

📊 分析与报告:
  analyze                 分析进度偏差
  health                  计算健康度评分
  report                  生成完整报告
  heartbeat               执行Heartbeat检查

🧠 知识管理:
  extract                 提取知识
  compost                 生成Compost种子
  patterns                发现模式

🚀 高级命令:
  run                     运行完整演化周期
  monitor [间隔秒]        连续监控模式
  reset                   重置状态

📖 帮助:
  help                    显示此帮助
  version                 显示版本

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

示例:
  aec plan                 # 生成今日任务计划
  aec task create "学习TS" "阅读文档" autonomous 3
  aec task activate abc-123
  aec task progress abc-123 50
  aec heartbeat            # 检查零进度任务
  aec extract              # 提取今日知识
  aec run                  # 运行完整周期

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

技术栈:
  - Shell脚本 (Bash)
  - JSON处理 (jq)
  - 文件系统存储
  - 兼容OpenClaw生态

EOF
}

show_version() {
    cat << 'EOF'
Autonomous Evolution Cycle v2.0.0
Author: xiaomi_cat
License: MIT
Homepage: https://github.com/Firo718/Autonomous-Evolution-Cycle

Powered by OpenClaw 🦞
EOF
}

#######################################
# 核心功能
#######################################

cmd_init() {
    echo -e "${CYAN}初始化 Autonomous Evolution Cycle...${NC}"
    echo ""
    
    # 创建目录结构
    echo "📁 创建目录结构..."
    mkdir -p "${WORKSPACE}"/{config,memory/{working,factual,experiential,patterns},logs}
    
    # 创建默认配置
    echo "⚙️  创建默认配置..."
    cat > "${WORKSPACE}/config/autonomous-evolution-config.json" << 'EOF'
{
  "version": "2.0.0",
  "timeSlots": {
    "freeActivity": {"start": "05:00", "end": "07:00"},
    "planning": {"start": "07:00", "end": "08:00"},
    "deepWork": [{"start": "09:00", "end": "12:00"}, {"start": "14:00", "end": "17:00"}],
    "consolidation": {"start": "21:00", "end": "22:00"}
  },
  "heartbeatInterval": 300,
  "progressCheckInterval": 60,
  "maxTasksPerDay": 10,
  "deviationThresholds": {"minor": 10, "moderate": 25, "severe": 50},
  "enabledFeatures": {
    "autoTaskActivation": true,
    "progressDeviationAlerts": true,
    "automaticRescheduling": true,
    "patternExtraction": true,
    "knowledgeExtraction": true,
    "strategicAlignmentCheck": true
  }
}
EOF
    
    echo -e "${GREEN}✅ 初始化完成！${NC}"
    echo ""
    echo "下一步:"
    echo "  1. 运行 'aec plan' 生成今日任务计划"
    echo "  2. 运行 'aec help' 查看更多命令"
}

cmd_plan() {
    local show_summary="${1:-}"
    
    echo -e "${CYAN}📋 生成今日任务计划...${NC}"
    echo ""
    
    # 检查是否有bash
    if ! command -v bash &> /dev/null; then
        log_error "需要bash环境"
        return 1
    fi
    
    # 检查jq
    if ! command -v jq &> /dev/null; then
        log_error "需要jq工具"
        return 1
    fi
    
    # 检查任务生成脚本
    local generator_script="${SCRIPTS_DIR}/task-generator.sh"
    if [[ -f "$generator_script" ]]; then
        bash "$generator_script" generate
    else
        log_error "任务生成脚本不存在: $generator_script"
        return 1
    fi
    
    # 显示摘要
    if [[ "$show_summary" == "summary" ]]; then
        echo ""
        bash "${SCRIPTS_DIR}/task-generator.sh" summary
    fi
}

cmd_status() {
    echo -e "${CYAN}📊 当前状态${NC}"
    echo ""
    
    local today_plan="${WORKSPACE}/task-plan-$(date +%Y-%m-%d).json"
    
    if [[ ! -f "$today_plan" ]]; then
        echo -e "${YELLOW}⚠️  今日任务计划不存在${NC}"
        echo "运行 'aec plan' 生成任务计划"
        return
    fi
    
    local total completed in_progress pending
    total=$(jq '.tasks | length' "$today_plan")
    completed=$(jq '[.tasks[] | select(.status == "completed")] | length' "$today_plan")
    in_progress=$(jq '[.tasks[] | select(.status == "in_progress")] | length' "$today_plan")
    pending=$(jq '[.tasks[] | select(.status == "pending")] | length' "$today_plan")
    
    local completion_rate="0"
    if [[ "$total" -gt 0 ]]; then
        completion_rate=$(echo "scale=1; $completed * 100 / $total" | bc)
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  总任务:    %d\n" "$total"
    printf "  已完成:    %d\n" "$completed"
    printf "  进行中:    %d\n" "$in_progress"
    printf "  待执行:    %d\n" "$pending"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  完成率:    %s%%\n" "$completion_rate"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 显示主人指令任务
    local master_count
    master_count=$(jq '[.tasks[] | select(.type == "master")] | length' "$today_plan")
    if [[ "$master_count" -gt 0 ]]; then
        echo ""
        echo -e "${RED}⚡ 主人指令任务 ($master_count):${NC}"
        jq -r '.tasks[] | select(.type == "master") | "  - [\( .priority )] \( .title )"' "$today_plan" 2>/dev/null | head -5
    fi
    
    # 显示进行中任务
    if [[ "$in_progress" -gt 0 ]]; then
        echo ""
        echo -e "${GREEN}🔄 进行中任务:${NC}"
        jq -r '.tasks[] | select(.status == "in_progress") | "  - [\( .progress )%%] \( .title )"' "$today_plan" 2>/dev/null | head -5
    fi
}

cmd_progress() {
    local subcommand="${1:-report}"
    shift || true
    
    case "$subcommand" in
        "report")
            bash "${SCRIPTS_DIR}/progress-analyzer.sh" report
            ;;
        "analyze")
            bash "${SCRIPTS_DIR}/progress-analyzer.sh" analyze "$@"
            ;;
        "health")
            bash "${SCRIPTS_DIR}/progress-analyzer.sh" health
            ;;
        "detect-zero")
            bash "${SCRIPTS_DIR}/progress-analyzer.sh" detect-zero
            ;;
        *)
            echo "用法: aec progress [report|analyze|health|detect-zero]"
            ;;
    esac
}

cmd_analyze() {
    bash "${SCRIPTS_DIR}/progress-analyzer.sh" report
}

cmd_health() {
    bash "${SCRIPTS_DIR}/progress-analyzer.sh" health
}

cmd_heartbeat() {
    echo -e "${CYAN}💓 执行Heartbeat检查...${NC}"
    echo ""
    bash "${SCRIPTS_DIR}/heartbeat.sh" check
}

#######################################
# 任务管理
#######################################

cmd_task() {
    local command="${1:-list}"
    shift || true
    
    case "$command" in
        "create")
            local title="$1"
            local description="$2"
            local task_type="${3:-autonomous}"
            local priority="${4:-4}"
            
            if [[ -z "$title" || -z "$description" ]]; then
                echo "用法: aec task create <标题> <描述> [类型] [优先级]"
                return 1
            fi
            
            bash "${SCRIPTS_DIR}/task-generator.sh" task:create "$title" "$description" "$task_type" "$priority"
            ;;
        "activate")
            local task_id="$1"
            
            if [[ -z "$task_id" ]]; then
                echo "用法: aec task activate <任务ID>"
                return 1
            fi
            
            bash "${SCRIPTS_DIR}/task-generator.sh" task:activate "$task_id"
            ;;
        "progress")
            local task_id="$1"
            local progress="$2"
            local message="${3:-}"
            
            if [[ -z "$task_id" || -z "$progress" ]]; then
                echo "用法: aec task progress <ID> <进度> [消息]"
                return 1
            fi
            
            bash "${SCRIPTS_DIR}/task-generator.sh" task:progress "$task_id" "$progress" "$message"
            ;;
        "complete")
            local task_id="$1"
            local result="${2:-success}"
            
            if [[ -z "$task_id" ]]; then
                echo "用法: aec task complete <任务ID> [结果]"
                return 1
            fi
            
            bash "${SCRIPTS_DIR}/task-generator.sh" task:complete "$task_id" "$result"
            ;;
        "list")
            echo -e "${CYAN}📋 任务列表${NC}"
            echo ""
            
            local count=0
            for task_file in "${WORKSPACE}/memory/working"/*.json; do
                [[ -f "$task_file" ]] || continue
                ((count++))
                
                local title status progress
                title=$(jq -r '.title' "$task_file")
                status=$(jq -r '.status' "$task_file")
                progress=$(jq -r '.progress' "$task_file")
                
                local status_icon="  "
                case "$status" in
                    "completed") status_icon="✅" ;;
                    "in_progress") status_icon="🔄" ;;
                    "pending") status_icon="📝" ;;
                    "failed") status_icon="❌" ;;
                    *) status_icon="  " ;;
                esac
                
                printf "  %s [%-3s] %s (%s%%)\n" "$status_icon" "$status" "$title" "$progress"
            done
            
            if [[ "$count" -eq 0 ]]; then
                echo "  没有任务"
            fi
            ;;
        "cancel")
            local task_id="$1"
            
            if [[ -z "$task_id" ]]; then
                echo "用法: aec task cancel <任务ID>"
                return 1
            fi
            
            bash "${SCRIPTS_DIR}/task-generator.sh" task:cancel "$task_id"
            ;;
        *)
            echo "用法: aec task [create|activate|progress|complete|list|cancel]"
            ;;
    esac
}

#######################################
# 知识管理
#######################################

cmd_extract() {
    bash "${SCRIPTS_DIR}/knowledge-extractor.sh" all
}

cmd_compost() {
    bash "${SCRIPTS_DIR}/knowledge-extractor.sh" compost
}

cmd_patterns() {
    bash "${SCRIPTS_DIR}/knowledge-extractor.sh" patterns
}

#######################################
# 高级功能
#######################################

cmd_run() {
    echo -e "${CYAN}🚀 运行完整演化周期...${NC}"
    echo ""
    
    echo "步骤 1: 生成任务计划"
    cmd_plan
    
    echo ""
    echo "步骤 2: 分析进度"
    cmd_analyze
    
    echo ""
    echo "步骤 3: 执行Heartbeat检查"
    cmd_heartbeat
    
    echo ""
    echo "步骤 4: 提取知识"
    cmd_extract
    
    echo ""
    echo -e "${GREEN}✅ 演化周期完成！${NC}"
}

cmd_monitor() {
    local interval="${1:-300}"
    
    echo -e "${CYAN}👁️  启动监控模式...${NC}"
    echo "检查间隔: ${interval}秒"
    echo "按 Ctrl+C 停止"
    echo ""
    
    bash "${SCRIPTS_DIR}/heartbeat.sh" monitor "$interval"
}

cmd_reset() {
    echo -e "${YELLOW}⚠️  重置系统状态${NC}"
    echo ""
    echo "这将清除:"
    echo "  - 今日任务计划"
    echo "  - 进行中的任务状态"
    echo "  - 不会清除历史知识"
    echo ""
    read -p "确认重置? (y/N): " confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        rm -f "${WORKSPACE}/task-plan-$(date +%Y-%m-%d).json" 2>/dev/null || true
        
        for task_file in "${WORKSPACE}/memory/working"/*.json; do
            [[ -f "$task_file" ]] || continue
            local status
            status=$(jq -r '.status' "$task_file")
            if [[ "$status" != "completed" && "$status" != "failed" ]]; then
                rm -f "$task_file"
            fi
        done
        
        echo -e "${GREEN}✅ 重置完成${NC}"
    else
        echo "已取消"
    fi
}

#######################################
# 主入口
#######################################

main() {
    local command="${1:-help}"
    shift || true
    
    # 初始化
    aec_init "main"
    
    case "$command" in
        "init")              cmd_init ;;
        "plan")              cmd_plan "$@" ;;
        "status")            cmd_status ;;
        "progress")          cmd_progress "$@" ;;
        "analyze")           cmd_analyze ;;
        "health")            cmd_health ;;
        "heartbeat")         cmd_heartbeat ;;
        "task")              cmd_task "$@" ;;
        "extract")           cmd_extract ;;
        "compost")           cmd_compost ;;
        "patterns")          cmd_patterns ;;
        "run")               cmd_run ;;
        "monitor")           cmd_monitor "$@" ;;
        "reset")             cmd_reset ;;
        "version"|"--version") show_version ;;
        "help"|"--help"|"")   show_help ;;
        *)
            log_error "未知命令: $command"
            echo "运行 'aec help' 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"
