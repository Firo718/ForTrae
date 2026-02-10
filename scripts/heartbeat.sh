#!/bin/bash
# Autonomous Evolution Cycle - Heartbeat集成
# 实现与OpenClaw heartbeat系统的集成

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

if [[ -f "${LIB_DIR}/core.sh" ]]; then
    source "${LIB_DIR}/core.sh"
else
    AEC_WORKSPACE="${OPENCLAW_WORKSPACE:-${HOME}/.openclaw/workspace}"
    AEC_LOG_DIR="${HOME}/.openclaw/logs"
    AEC_SCRIPT_NAME="heartbeat"
    mkdir -p "${AEC_WORKSPACE}/memory/working" "${AEC_LOG_DIR}"
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [heartbeat] $1"; }
fi

WORKSPACE="${AEC_WORKSPACE}"
CONFIG_FILE="${WORKSPACE}/config/autonomous-evolution-config.json"

# 默认配置
ZERO_PROGRESS_THRESHOLD_MINUTES=30
HEARTBEAT_INTERVAL=300  # 5分钟
AUTO_ACTIVATION=true

#######################################
# Heartbeat核心函数
#######################################

# 加载配置
load_heartbeat_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE" | jq '
            {
                zeroProgressThresholdMinutes: (.heartbeatInterval // 300),
                heartbeatInterval: (.progressCheckInterval // 300),
                autoActivation: (.enabledFeatures.autoTaskActivation // true)
            }
        '
    else
        echo "{\"zeroProgressThresholdMinutes\":30,\"heartbeatInterval\":300,\"autoActivation\":true}"
    fi
}

# 执行Heartbeat检查
perform_heartbeat_check() {
    log_info "执行Heartbeat检查..."
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # 加载配置
    local config
    config=$(load_heartbeat_config)
    local threshold_minutes
    threshold_minutes=$(echo "$config" | jq -r '.zeroProgressThresholdMinutes')
    local auto_activate
    auto_activate=$(echo "$config" | jq -r '.autoActivation')
    
    # 计算阈值时间
    local threshold_time
    threshold_time=$(date -d "$threshold_minutes minutes ago" -u +%Y-%m-%dT%H:%M:%SZ)
    
    local zero_progress_tasks=()
    local tasks_needing_attention=0
    
    log_info "检测阈值: ${threshold_minutes}分钟"
    
    # 检查所有进行中的任务
    for task_file in "${WORKSPACE}/memory/working"/*.json; do
        [[ -f "$task_file" ]] || continue
        
        local status progress started_at title task_id
        status=$(jq -r '.status' "$task_file")
        progress=$(jq -r '.progress' "$task_file")
        started_at=$(jq -r '(.startedAt // .createdAt)' "$task_file")
        title=$(jq -r '.title' "$task_file")
        task_id=$(jq -r '.id' "$task_file")
        
        if [[ "$status" == "in_progress" ]]; then
            # 检查零进度
            if [[ "$progress" == "0" ]]; then
                if [[ "$started_at" < "$threshold_time" ]]; then
                    log_warn "检测到零进度任务: $title (开始于: $started_at)"
                    zero_progress_tasks+=("$task_id")
                    
                    # 自动激活
                    if [[ "$auto_activate" == "true" ]]; then
                        log_info "自动激活任务: $title"
                        
                        # 更新startedAt触发任务引擎重新激活
                        local new_ts
                        new_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                        jq ".startedAt = \"$new_ts\" | .updatedAt = \"$new_ts\" | .heartbeatTriggered = true" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
                        
                        # 记录事件
                        log_task_event "auto_activated" "$task_id" "$progress" "\"$title\""
                    fi
                fi
            fi
            
            # 检查进度是否显著落后
            local expected
            expected=$(calculate_expected_progress "$task_file")
            if [[ -n "$expected" ]]; then
                local deviation
                deviation=$(echo "$progress - $expected" | bc)
                
                if [[ $(echo "$deviation < -25" | bc -l) -eq 1 ]]; then
                    log_warn "任务进度显著落后: $title (期望: ${expected}%, 实际: ${progress}%)"
                    ((tasks_needing_attention++))
                    
                    # 记录偏差
                    log_task_event "progress_deviation" "$task_id" "$progress" "\"期望: ${expected}%, 实际: ${progress}%, 偏差: ${deviation}%\""
                fi
            fi
        fi
    done
    
    # 计算平均进度
    local avg_progress
    avg_progress=$(calculate_average_progress)
    
    # 计算健康度
    local health_score
    health_score=$(calculate_health_score "${#zero_progress_tasks[@]}" "$tasks_needing_attention")
    
    # 生成检查结果
    jq -n \
        --arg timestamp "$timestamp" \
        --argjson zero_count "${#zero_progress_tasks[@]}" \
        --argjson attention "$tasks_needing_attention" \
        --argjson avg_progress "$avg_progress" \
        --argjson health "$health_score" \
        '{
            timestamp: $timestamp,
            zeroProgressTasksCount: $zero_count,
            tasksNeedingAttention: $attention,
            averageProgress: $avg_progress,
            healthScore: $health_score,
            status: (if $health >= 70 then "healthy" elif $health >= 50 then "warning" else "critical" end)
        }'
    
    # 记录Heartbeat日志
    local heartbeat_log="${WORKSPACE}/logs/heartbeat-$(date +%Y-%m-%d).jsonl"
    mkdir -p "$(dirname "$heartbeat_log")"
    
    jq -n \
        --arg timestamp "$timestamp" \
        --argjson zero_count "${#zero_progress_tasks[@]}" \
        --argjson avg "$avg_progress" \
        --argjson health "$health_score" \
        '{"timestamp": $timestamp, "zeroProgressTasks": $zero_count, "averageProgress": $avg, "healthScore": $health}' >> "$heartbeat_log" 2>/dev/null || true
    
    # 生成建议
    generate_heartbeat_recommendations "$health_score" "${#zero_progress_tasks[@]}" "$tasks_needing_attention"
    
    log_info "Heartbeat检查完成"
}

# 计算期望进度
calculate_expected_progress() {
    local task_file="$1"
    
    local started_at estimated_duration
    started_at=$(jq -r '(.startedAt // .createdAt)' "$task_file")
    estimated_duration=$(jq -r '.estimatedDuration' "$task_file")
    
    if [[ -z "$started_at" || "$started_at" == "null" ]]; then
        echo ""
        return
    fi
    
    # 计算经过的分钟数
    local started_ts current_ts elapsed_minutes
    started_ts=$(date -d "$started_at" -u +%s 2>/dev/null)
    current_ts=$(date -u +%s)
    
    if [[ -z "$started_ts" ]]; then
        echo ""
        return
    fi
    
    elapsed_minutes=$((current_ts - started_ts))
    
    # 计算期望进度
    local expected
    expected=$(echo "scale=0; ($elapsed_minutes * 100) / ($estimated_duration * 60)" | bc)
    
    # 限制在0-100之间
    if [[ "$expected" -gt 100 ]]; then
        expected=100
    fi
    
    echo "$expected"
}

# 计算平均进度
calculate_average_progress() {
    local total_progress=0
    local task_count=0
    
    for task_file in "${WORKSPACE}/memory/working"/*.json; do
        [[ -f "$task_file" ]] || continue
        
        local status progress
        status=$(jq -r '.status' "$task_file")
        progress=$(jq -r '.progress' "$task_file")
        
        if [[ "$status" == "in_progress" || "$status" == "completed" ]]; then
            total_progress=$((total_progress + progress))
            ((task_count++))
        fi
    done
    
    if [[ "$task_count" -gt 0 ]]; then
        echo "$((total_progress / task_count))"
    else
        echo "0"
    fi
}

# 计算健康度评分
calculate_health_score() {
    local zero_count="$1"
    local attention_count="$2"
    
    local score=100
    
    # 零进度任务扣分
    score=$((score - zero_count * 15))
    
    # 需要关注的任务扣分
    score=$((score - attention_count * 10))
    
    # 确保在0-100之间
    if [[ "$score" -lt 0 ]]; then
        score=0
    fi
    
    echo "$score"
}

# 生成Heartbeat建议
generate_heartbeat_recommendations() {
    local health="$1"
    local zero_count="$2"
    local attention_count="$3"
    
    echo ""
    echo "=========================================="
    echo "         Heartbeat 建议"
    echo "=========================================="
    
    if [[ "$health" -ge 90 ]]; then
        echo "✅ 系统健康度优秀"
        echo "   - 继续保持当前工作节奏"
        echo "   - 所有任务正常执行中"
    elif [[ "$health" -ge 70 ]]; then
        echo "✅ 系统健康度良好"
        echo "   - 整体运行正常"
        if [[ "$zero_count" -gt 0 ]]; then
            echo "   - 关注 $zero_count 个零进度任务"
        fi
    elif [[ "$health" -ge 50 ]]; then
        echo "⚠️ 系统健康度一般"
        echo "   - 需要关注进度落后任务"
        if [[ "$attention_count" -gt 0 ]]; then
            echo "   - $attention_count 个任务需要调整"
        fi
    else
        echo "❌ 系统健康度偏低"
        echo "   - 建议重新评估今日任务安排"
        echo "   - 检查阻塞因素"
    fi
    
    if [[ "$zero_count" -gt 0 ]]; then
        echo ""
        echo "💡 零进度任务处理建议:"
        echo "   - 检查任务是否需要拆分"
        echo "   - 评估任务优先级"
        echo "   - 确认是否有依赖阻塞"
    fi
    
    echo "=========================================="
}

# 连续运行Heartbeat监控
run_continuous_monitor() {
    local interval="${1:-300}"  # 默认5分钟
    
    log_info "启动连续Heartbeat监控..."
    log_info "检查间隔: ${interval}秒"
    
    while true; do
        perform_heartbeat_check
        echo ""
        log_info "等待下一次检查..."
        sleep "$interval"
    done
}

#######################################
# 主命令处理
#######################################

main() {
    local command="${1:-check}"
    shift || true
    
    aec_init "heartbeat"
    
    case "$command" in
        "check")
            perform_heartbeat_check
            ;;
        "monitor")
            run_continuous_monitor "${1:-300}"
            ;;
        "config")
            load_heartbeat_config
            ;;
        "help"|"")
            cat << 'EOF'
Autonomous Evolution Cycle - Heartbeat集成

用法: heartbeat.sh <命令> [参数]

命令:
  check              执行单次Heartbeat检查
  monitor [间隔秒]   连续运行Heartbeat监控
  config             显示Heartbeat配置
  help               显示帮助

示例:
  ./heartbeat.sh check
  ./heartbeat.sh monitor 300
EOF
            ;;
        *)
            log_error "未知命令: $command"
            exit 1
            ;;
    esac
}

main "$@"
