#!/bin/bash
# Autonomous Evolution Cycle - 公共库
# 提供所有shell脚本共享的函数
# 设计原则：DRY、安全、模块化

set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# 日志级别
readonly LOG_DEBUG=0
readonly LOG_INFO=1
readonly LOG_WARN=2
readonly LOG_ERROR=3

# 全局配置
AEC_LOG_LEVEL="${AEC_LOG_LEVEL:-1}"
AEC_LOG_DIR="${HOME}/.openclaw/logs"
AEC_SCRIPT_NAME="aec"
AEC_WORKSPACE="${OPENCLAW_WORKSPACE:-${HOME}/.openclaw/workspace}"

#######################################
# 初始化函数
#######################################

aec_init() {
    local script_name="${1:-unknown}"
    AEC_SCRIPT_NAME="$script_name"
    
    # 创建必要目录
    mkdir -p "${AEC_LOG_DIR}" 2>/dev/null || true
    mkdir -p "${AEC_WORKSPACE}/config" 2>/dev/null || true
    mkdir -p "${AEC_WORKSPACE}/memory/working" 2>/dev/null || true
    mkdir -p "${AEC_WORKSPACE}/memory/factual" 2>/dev/null || true
    mkdir -p "${AEC_WORKSPACE}/memory/experiential" 2>/dev/null || true
    mkdir -p "${AEC_WORKSPACE}/memory/patterns" 2>/dev/null || true
    mkdir -p "${AEC_WORKSPACE}/logs" 2>/dev/null || true
    
    log_info "Autonomous Evolution Cycle initialized"
}

#######################################
# 安全工具函数
#######################################

# 消毒文件名
sanitize_filename() {
    local filename="$1"
    local sanitized
    
    # 移除null字节
    sanitized="${filename//$'\0'/}"
    
    # 移除危险字符
    sanitized="${sanitized//</}"
    sanitized="${sanitized//>/}"
    sanitized="${sanitized//:/}"
    sanitized="${sanitized//\"/}"
    sanitized="${sanitized//\//}"
    sanitized="${sanitized//\\/}"
    sanitized="${sanitized//|/}"
    sanitized="${sanitized//\?/}"
    sanitized="${sanitized//\*/}"
    
    # 移除控制字符
    sanitized=$(printf '%s' "$sanitized" | tr -cd '[:alnum:]_-.\/')
    
    echo "$sanitized"
}

# 验证路径安全性
validate_path() {
    local input_path="$1"
    
    # 空路径检查
    if [[ -z "$input_path" ]]; then
        echo "error: Path cannot be empty" >&2
        return 1
    fi
    
    # 移除null字节
    input_path="${input_path//$'\0'/}"
    
    # 检查路径遍历尝试
    if [[ "$input_path" == *".."* ]]; then
        echo "error: Path traversal attempt detected" >&2
        return 1
    fi
    
    echo "$input_path"
    return 0
}

# 安全读取JSON值
json_get() {
    local file="$1"
    local key="$2"
    
    if [[ ! -f "$file" ]]; then
        echo ""
        return 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo ""
        return 1
    fi
    
    jq -r ".$key // empty" "$file" 2>/dev/null || echo ""
}

# 安全读取JSON数组
json_get_array() {
    local file="$1"
    local key="$2"
    
    if [[ ! -f "$file" ]]; then
        echo "[]"
        return
    fi
    
    jq -r ".$key // []" "$file" 2>/dev/null || echo "[]"
}

# 更新JSON字段
json_update() {
    local file="$1"
    local key="$2"
    local value="$3"
    
    if [[ ! -f "$file" ]]; then
        echo "{\"$key\": \"$value\"}" > "$file"
        return
    fi
    
    local temp_file="${file}.tmp.$$"
    
    # 使用jq安全更新JSON
    if jq "$key = \"$value\"" "$file" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$file"
    else
        rm -f "$temp_file"
        return 1
    fi
}

# 追加JSON数组元素
json_array_append() {
    local file="$1"
    local key="$2"
    local value="$3"
    
    if [[ ! -f "$file" ]]; then
        echo "{\"$key\": [\"$value\"]}" > "$file"
        return
    fi
    
    local temp_file="${file}.tmp.$$"
    
    if jq "$key += [\"$value\"]" "$file" > "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$file"
    else
        rm -f "$temp_file"
        return 1
    fi
}

#######################################
# 日志函数
#######################################

# 内部日志函数
_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local level_str
    
    case "$level" in
        0) level_str="DEBUG" ;;
        1) level_str="INFO" ;;
        2) level_str="WARN" ;;
        3) level_str="ERROR" ;;
        *) level_str="UNKNOWN" ;;
    esac
    
    # 输出到日志文件
    echo "[${timestamp}] [${level_str}] [${AEC_SCRIPT_NAME}] ${message}" >> "${AEC_LOG_DIR}/automation.log" 2>/dev/null || true
    
    # 输出到控制台
    if [[ $level -ge $AEC_LOG_LEVEL ]]; then
        case "$level" in
            0) echo -e "${CYAN}[${timestamp}] [${level_str}]${NC} $message" ;;
            1) echo -e "${GREEN}[${timestamp}] [${level_str}]${NC} $message" ;;
            2) echo -e "${YELLOW}[${timestamp}] [${level_str}]${NC} $message" ;;
            3) echo -e "${RED}[${timestamp}] [${level_str}]${NC} $message" ;;
            *) echo "[${timestamp}] [${level_str}] $message" ;;
        esac
    fi
}

log_debug() { _log 0 "$1"; }
log_info() { _log 1 "$1"; }
log_warn() { _log 2 "$1"; }
log_error() { _log 3 "$1"; }

#######################################
# 任务相关函数
#######################################

# 生成UUID
aec_uuidgen() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif [[ -f /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        # 备用方案
        echo "$(date +%s)-$$-$(head -c 4 /dev/urandom 2>/dev/null | xxd -p || echo "$$")"
    fi
}

# 创建任务
task_create() {
    local title="$1"
    local description="$2"
    local task_type="${3:-autonomous}"
    local priority="${4:-4}"
    
    local task_id
    task_id=$(aec_uuidgen)
    
    local task_file="${AEC_WORKSPACE}/memory/working/${task_id}.json"
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    cat > "$task_file" << EOF
{
  "id": "$task_id",
  "title": "$title",
  "description": "$description",
  "type": "$task_type",
  "priority": $priority,
  "status": "pending",
  "estimatedDuration": 60,
  "progress": 0,
  "createdAt": "$timestamp",
  "updatedAt": "$timestamp"
}
EOF
    
    log_info "任务已创建: $task_id - $title"
    echo "$task_id"
}

# 激活任务
task_activate() {
    local task_id="$1"
    local task_file="${AEC_WORKSPACE}/memory/working/${task_id}.json"
    
    if [[ ! -f "$task_file" ]]; then
        log_error "任务文件不存在: $task_id"
        return 1
    fi
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # 更新状态
    jq ".status = \"in_progress\" | .startedAt = \"$timestamp\" | .updatedAt = \"$timestamp\" | .progress = (if .progress == 0 then 5 else .progress end)" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
    
    log_info "任务已激活: $task_id"
    log_task_event "task_started" "$task_id" 5
}

# 更新进度
task_update_progress() {
    local task_id="$1"
    local progress="$2"
    local message="${3:-}"
    
    local task_file="${AEC_WORKSPACE}/memory/working/${task_id}.json"
    
    if [[ ! -f "$task_file" ]]; then
        log_error "任务文件不存在: $task_id"
        return 1
    fi
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # 限制进度在0-100之间
    progress=$((progress > 100 ? 100 : progress))
    progress=$((progress < 0 ? 0 : progress))
    
    jq ".progress = $progress | .updatedAt = \"$timestamp\" | .result = \"${message:-}\"" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
    
    log_info "进度更新: $task_id - $progress%"
    log_task_event "progress_update" "$task_id" "$progress" "\"$message\""
}

# 完成任务
task_complete() {
    local task_id="$1"
    local result="${2:-success}"
    
    local task_file="${AEC_WORKSPACE}/memory/working/${task_id}.json"
    
    if [[ ! -f "$task_file" ]]; then
        log_error "任务文件不存在: $task_id"
        return 1
    fi
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    local status
    if [[ "$result" == "success" ]]; then
        status="completed"
    else
        status="failed"
    fi
    
    jq ".status = \"$status\" | .progress = ($result == \"success\" ? 100 : .progress) | .completedAt = \"$timestamp\" | .updatedAt = \"$timestamp\"" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
    
    log_info "任务完成: $task_id - $status"
    log_task_event "task_completed" "$task_id" 100 "{\"status\": \"$status\"}"
}

# 获取任务状态
task_get_status() {
    local task_id="$1"
    local task_file="${AEC_WORKSPACE}/memory/working/${task_id}.json"
    
    if [[ -f "$task_file" ]]; then
        jq -r '.status' "$task_file"
    else
        echo "not_found"
    fi
}

#######################################
# 任务计划函数
#######################################

# 加载配置
config_load() {
    local config_file="${AEC_WORKSPACE}/config/autonomous-evolution-config.json"
    
    if [[ -f "$config_file" ]]; then
        cat "$config_file"
    else
        # 返回默认配置
        cat << 'EOF'
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
    fi
}

# 获取当前时间槽
time_get_current_slot() {
    local current_time
    current_time=$(date '+%H:%M')
    local config
    config=$(config_load)
    
    # 检查各个时间槽
    local slots=("freeActivity" "planning" "deepWork" "consolidation")
    
    for slot in "${slots[@]}"; do
        local start end
        start=$(echo "$config" | jq -r ".timeSlots.${slot}.start // \"null\"" | head -1)
        end=$(echo "$config" | jq -r ".timeSlots.${slot}.end // \"null\"" | head -1)
        
        if [[ "$start" != "null" && "$end" != "null" ]]; then
            if [[ "$current_time" >= "$start" && "$current_time" <= "$end" ]]; then
                echo "$slot"
                return 0
            fi
        fi
    done
    
    echo "none"
}

#######################################
# 结构化日志函数
#######################################

# 记录结构化日志到JSONL文件
log_task_event() {
    local event_type="$1"
    local task_id="$2"
    local progress="${3:-0}"
    local details="${4:-}"
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    local agent="${OPENCLAW_AGENT_NAME:-aec}"
    
    # 构建JSON
    local json="{\"timestamp\":\"$timestamp\",\"level\":\"info\",\"agent\":\"$agent\",\"event\":\"$event_type\",\"taskId\":\"$task_id\",\"progress\":$progress"
    
    if [[ -n "$details" ]]; then
        json="$json,\"details\":$details"
    fi
    
    json="$json}"
    
    echo "$json" >> "${AEC_WORKSPACE}/logs/tasks.jsonl" 2>/dev/null || true
}

#######################################
# 知识提取函数
#######################################

# 保存知识条目
knowledge_save() {
    local type="$1"
    local title="$2"
    local content="$3"
    local tags="$4"
    
    local knowledge_id
    knowledge_id=$(aec_uuidgen)
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    local dir="${AEC_WORKSPACE}/memory/${type}"
    mkdir -p "$dir"
    
    local tags_json
    tags_json=$(echo "$tags" | jq -R -s 'split(",") | map(select(length > 0))')
    
    cat > "${dir}/${knowledge_id}.json" << EOF
{
  "id": "$knowledge_id",
  "type": "$type",
  "title": "$title",
  "content": "$content",
  "tags": $tags_json,
  "confidence": 0.9,
  "source": "autonomous-evolution-cycle",
  "createdAt": "$timestamp"
}
EOF
    
    log_info "知识已保存: $type - $title"
    echo "$knowledge_id"
}

#######################################
# Heartbeat函数
#######################################

# Heartbeat检查
heartbeat_check() {
    log_info "执行Heartbeat检查..."
    
    local current_time
    current_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    local zero_progress_count=0
    
    # 检查所有进行中的任务
    for task_file in "${AEC_WORKSPACE}/memory/working"/*.json; do
        [[ -f "$task_file" ]] || continue
        
        local status progress started_at
        status=$(jq -r '.status' "$task_file")
        progress=$(jq -r '.progress' "$task_file")
        started_at=$(jq -r '(.startedAt // .createdAt)' "$task_file")
        
        if [[ "$status" == "in_progress" && "$progress" == "0" ]]; then
            # 检查是否超时30分钟
            local started_ts started_sec current_ts
            started_ts=$(date -d "$started_at" -u +%s 2>/dev/null || echo "0")
            current_ts=$(date -d "$current_time" -u +%s 2>/dev/null || echo "0")
            local diff=$((current_ts - started_ts))
            
            if [[ $diff -gt 1800 ]]; then  # 30分钟 = 1800秒
                log_warn "检测到零进度任务: $(jq -r '.title' "$task_file")"
                ((zero_progress_count++))
                
                # 检查是否启用自动激活
                local auto_activate
                auto_activate=$(config_load | jq -r '.enabledFeatures.autoTaskActivation // true')
                
                if [[ "$auto_activate" == "true" ]]; then
                    log_info "自动激活任务..."
                    # 重新设置startedAt触发任务引擎
                    local new_ts
                    new_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                    jq ".startedAt = \"$new_ts\" | .updatedAt = \"$new_ts\"" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
                fi
            fi
        fi
    done
    
    # 记录Heartbeat
    local heartbeat_file="${AEC_WORKSPACE}/logs/heartbeat-$(date +%Y-%m-%d).jsonl"
    mkdir -p "$(dirname "$heartbeat_file")"
    
    cat >> "$heartbeat_file" << EOF
{"timestamp":"$current_time","zeroProgressTasks":$zero_progress_count}
EOF
    
    log_info "Heartbeat检查完成: $zero_progress_count 个零进度任务"
}

#######################################
# 主命令
#######################################

aec_main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        "init")
            aec_init "$1"
            ;;
        "task:create")
            task_create "$1" "$2" "${3:-autonomous}" "${4:-4}"
            ;;
        "task:activate")
            task_activate "$1"
            ;;
        "task:progress")
            task_update_progress "$1" "$2" "${3:-}"
            ;;
        "task:complete")
            task_complete "$1" "${2:-success}"
            ;;
        "task:status")
            task_get_status "$1"
            ;;
        "config:load")
            config_load
            ;;
        "time:slot")
            time_get_current_slot
            ;;
        "heartbeat")
            heartbeat_check
            ;;
        "knowledge:save")
            knowledge_save "$1" "$2" "$3" "$4"
            ;;
        "uuidgen")
            aec_uuidgen
            ;;
        "help"|"")
            cat << 'EOF'
Autonomous Evolution Cycle - CLI工具

用法: aec <命令> [参数]

命令:
  init <名称>              初始化系统
  task:create <标题> <描述> [类型] [优先级]  创建任务
  task:activate <任务ID>  激活任务
  task:progress <ID> <进度> [消息]           更新进度
  task:complete <任务ID> [结果]              完成任务
  task:status <任务ID>                       获取状态
  config:load                               加载配置
  time:slot                                 获取当前时间槽
  heartbeat                                 执行Heartbeat检查
  knowledge:save <类型> <标题> <内容> <标签> 保存知识
  uuidgen                                   生成UUID
  help                                      显示帮助

示例:
  aec task:create "学习TypeScript" "阅读官方文档" autonomous 3
  aec task:activate abc-123
  aec task:progress abc-123 50 "已完成一半"
  aec task:complete abc-123 success
  aec heartbeat
EOF
            ;;
        *)
            log_error "未知命令: $command"
            echo "使用 'aec help' 查看帮助"
            exit 1
            ;;
    esac
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    aec_main "$@"
fi
