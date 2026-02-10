#!/bin/bash
# Autonomous Evolution Cycle - 进度分析器
# 分析任务执行进度，检测偏差，提供自动调整建议

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# 导入公共库
if [[ -f "${LIB_DIR}/core.sh" ]]; then
    source "${LIB_DIR}/core.sh"
else
    # 如果core.sh不存在，使用内联初始化
    AEC_LOG_DIR="${HOME}/.openclaw/logs"
    AEC_WORKSPACE="${OPENCLAW_WORKSPACE:-${HOME}/.openclaw/workspace}"
    AEC_SCRIPT_NAME="progress-analyzer"
    mkdir -p "${AEC_LOG_DIR}" "${AEC_WORKSPACE}/memory/working"
    
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [progress-analyzer] $1"; }
    log_warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] [progress-analyzer] $1"; }
    log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [progress-analyzer] $1"; }
fi

WORKSPACE="${AEC_WORKSPACE}"
TASK_PLAN_FILE="${WORKSPACE}/task-plan-$(date +%Y-%m-%d).json"

# 偏差阈值
MINOR_THRESHOLD=10
MODERATE_THRESHOLD=25
SEVERE_THRESHOLD=50
ZERO_PROGRESS_MINUTES=30

#######################################
# 核心分析函数
#######################################

# 分析所有任务的进度偏差
analyze_all_deviations() {
    local plan_file="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$plan_file" ]]; then
        log_warn "计划文件不存在: $plan_file"
        echo "[]"
        return
    fi
    
    log_info "开始分析进度偏差..."
    
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # 分析每个进行中的任务
    jq -c ".tasks[] | select(.status == \"in_progress\") | 
        {taskId: .id, title: .title, 
         expectedProgress: (((\"$now\" | fromdateiso8601) - (.startedAt | fromdateiso8601)) / 60.0 / .estimatedDuration * 100 | floor // 0),
         actualProgress: .progress,
         startedAt: .startedAt,
         estimatedDuration: .estimatedDuration}" "$plan_file" 2>/dev/null | while read -r task; do
        
        # 计算偏差
        local expected actual deviation severity causes
        expected=$(echo "$task" | jq -r '.expectedProgress')
        actual=$(echo "$task" | jq -r '.actualProgress')
        
        deviation=$((actual - expected))
        
        # 判断严重程度
        if [[ $deviation -le -$SEVERE_THRESHOLD ]]; then
            severity="severe"
        elif [[ $deviation -le -$MODERATE_THRESHOLD ]]; then
            severity="moderate"
        elif [[ $deviation -le -$MINOR_THRESHOLD ]]; then
            severity="minor"
        elif [[ $deviation -ge $SEVERE_THRESHOLD ]]; then
            severity="severe"  # 提前太多也算严重
        else
            continue  # 偏差不显著，跳过
        fi
        
        # 分析原因
        causes=$(analyze_deviation_causes "$task" "$deviation")
        
        # 输出结果
        echo "$task" | jq --argjson deviation "$deviation" \
            --arg severity "$severity" \
            --arg causes "$causes" \
            '{deviation: $deviation, severity: $severity, causes: $causes, taskInfo: .}'
    done | jq -s '.'
}

# 分析偏差原因
analyze_deviation_causes() {
    local task="$1"
    local deviation="$2"
    
    local causes="[]"
    
    if [[ $deviation -lt 0 ]]; then
        # 进度落后
        local started_at estimated
        started_at=$(echo "$task" | jq -r '.startedAt')
        estimated=$(echo "$task" | jq -r '.estimatedDuration')
        
        # 检查是否超时
        if [[ -n "$started_at" && "$started_at" != "null" ]]; then
            causes=$(echo "$causes" | jq '. += ["任务执行时间超出预期"]')
        fi
        
        # 检查是否刚开始
        local actual
        actual=$(echo "$task" | jq -r '.actualProgress')
        if [[ "$actual" == "0" ]]; then
            causes=$(echo "$causes" | jq '. += ["任务尚未开始执行"]')
        fi
    else
        # 进度超前
        causes=$(echo "$causes" | jq '. += ["高效完成任务"]')
    fi
    
    echo "$causes"
}

# 检测零进度任务
detect_zero_progress_tasks() {
    local plan_file="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$plan_file" ]]; then
        echo "[]"
        return
    fi
    
    local threshold_time
    threshold_time=$(date -d "$ZERO_PROGRESS_MINUTES minutes ago" -u +%Y-%m-%dT%H:%M:%SZ)
    
    log_info "检测零进度任务（阈值: ${ZERO_PROGRESS_MINUTES}分钟）..."
    
    # 查找零进度任务
    jq -c ".tasks[] | select(.status == \"in_progress\" and .progress == 0 and (.startedAt // .createdAt) < \"$threshold_time\") | {id: .id, title: .title, startedAt: (.startedAt // .createdAt)}" "$plan_file" 2>/dev/null | while read -r task; do
        local started_at title id
        id=$(echo "$task" | jq -r '.id')
        title=$(echo "$task" | jq -r '.title')
        started_at=$(echo "$task" | jq -r '.startedAt')
        
        log_warn "检测到零进度任务: $title (ID: $id, 开始于: $started_at)"
        echo "$task"
    done | jq -s '.'
}

# 计算健康度评分
calculate_health_score() {
    local plan_file="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$plan_file" ]]; then
        echo "100"
        return
    fi
    
    local score=100
    
    # 检测零进度任务扣分
    local zero_count
    zero_count=$(detect_zero_progress_tasks "$plan_file" | jq 'length')
    score=$((score - zero_count * 15))
    
    # 检测严重偏差扣分
    local deviations
    deviations=$(analyze_all_deviations "$plan_file")
    local severe_count
    severe_count=$(echo "$deviations" | jq '[.[] | select(.severity == "severe")] | length')
    local moderate_count
    moderate_count=$(echo "$deviations" | jq '[.[] | select(.severity == "moderate")] | length')
    local minor_count
    minor_count=$(echo "$deviations" | jq '[.[] | select(.severity == "minor")] | length')
    
    score=$((score - severe_count * 20))
    score=$((score - moderate_count * 10))
    score=$((score - minor_count * 5))
    
    # 确保分数在0-100之间
    score=$((score < 0 ? 0 : score))
    score=$((score > 100 ? 100 : score))
    
    echo "$score"
}

# 生成进度报告
generate_progress_report() {
    local plan_file="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$plan_file" ]]; then
        log_error "计划文件不存在"
        return 1
    fi
    
    local health_score
    health_score=$(calculate_health_score "$plan_file")
    
    local deviations
    deviations=$(analyze_all_deviations "$plan_file")
    
    local zero_tasks
    zero_tasks=$(detect_zero_progress_tasks "$plan_file")
    
    local total_tasks completed in_progress pending
    total_tasks=$(jq '.tasks | length' "$plan_file")
    completed=$(jq '[.tasks[] | select(.status == "completed")] | length' "$plan_file")
    in_progress=$(jq '[.tasks[] | select(.status == "in_progress")] | length' "$plan_file")
    pending=$(jq '[.tasks[] | select(.status == "pending")] | length' "$plan_file")
    
    # 生成报告
    jq -n \
        --argjson health "$health_score" \
        --argjson total "$total_tasks" \
        --argjson completed "$completed" \
        --argjson in_progress "$in_progress" \
        --argjson pending "$pending" \
        --argjson deviations "$deviations" \
        --argjson zero_tasks "$zero_tasks" \
        '{
            timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            healthScore: $health,
            summary: ("健康度: " + ($health | tostring) + "% - 已完成: " + ($completed | tostring) + ", 进行中: " + ($in_progress | tostring) + ", 待执行: " + ($pending | tostring)),
            stats: {
                totalTasks: $total,
                completed: $completed,
                inProgress: $in_progress,
                pending: $pending
            },
            deviations: $deviations,
            zeroProgressTasks: $zero_tasks,
            recommendations: []
        }'
}

# 建议自动调整
suggest_adjustments() {
    local plan_file="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$plan_file" ]]; then
        echo "[]"
        return
    fi
    
    local adjustments='[]'
    
    # 检测零进度任务
    local zero_tasks
    zero_tasks=$(detect_zero_progress_tasks "$plan_file")
    
    if [[ $(echo "$zero_tasks" | jq 'length') -gt 0 ]]; then
        # 建议取消或重新评估
        adjustments=$(echo "$adjustments" | jq '. += [{"type": "cancel", "reason": "Zero progress tasks detected", "tasks": (. + ['"$(echo "$zero_tasks" | jq -c '.[] | {id: .id, title: .title}')"'])}]')
    fi
    
    # 检测严重偏差
    local deviations
    deviations=$(analyze_all_deviations "$plan_file")
    local severe_deviations
    severe_deviations=$(echo "$deviations" | jq '[.[] | select(.severity == "severe")]')
    
    if [[ $(echo "$severe_deviations" | jq 'length') -gt 0 ]]; then
        adjustments=$(echo "$adjustments" | jq '. += [{"type": "reschedule", "reason": "Severe deviations detected", "tasks": ('"$(echo "$severe_deviations" | jq -c '.[] | {id: .taskInfo.id, title: .taskInfo.title}')"')}]')
    fi
    
    echo "$adjustments"
}

#######################################
# 主命令处理
#######################################

main() {
    local command="${1:-report}"
    shift || true
    
    # 初始化
    aec_init "progress-analyzer"
    
    case "$command" in
        "analyze")
            analyze_all_deviations "$@"
            ;;
        "detect-zero")
            detect_zero_progress_tasks "$@"
            ;;
        "health")
            calculate_health_score "$@"
            ;;
        "report")
            generate_progress_report "$@" | jq '.'
            ;;
        "suggest")
            suggest_adjustments "$@"
            ;;
        "help"|"")
            cat << 'EOF'
Autonomous Evolution Cycle - 进度分析器

用法: progress-analyzer.sh <命令> [参数]

命令:
  analyze [计划文件]     分析所有进度偏差
  detect-zero [计划文件] 检测零进度任务
  health [计划文件]      计算健康度评分
  report [计划文件]      生成完整进度报告
  suggest [计划文件]     建议自动调整
  help                  显示帮助

示例:
  ./progress-analyzer.sh report
  ./progress-analyzer.sh detect-zero
  ./progress-analyzer.sh health
EOF
            ;;
        *)
            log_error "未知命令: $command"
            exit 1
            ;;
    esac
}

main "$@"
