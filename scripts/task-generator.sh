#!/bin/bash
# Autonomous Evolution Cycle - 任务生成器
# 合并版：自主能力 + 简化语法 + 实际任务模板

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# 导入公共库
if [[ -f "${LIB_DIR}/core.sh" ]]; then
    source "${LIB_DIR}/core.sh"
else
    # 备用初始化
    AEC_WORKSPACE="${OPENCLAW_WORKSPACE:-${HOME}/.openclaw/workspace}"
    AEC_SCRIPT_NAME="task-generator"
    
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [task-generator] $1"; }
    aec_init() { log_info "Task generator initialized"; }
fi

WORKSPACE="${AEC_WORKSPACE}"
TASK_PLAN_FILE="${WORKSPACE}/task-plan-$(date +%Y-%m-%d).json"

#######################################
# 核心函数
#######################################

# 获取当前时间槽
time_get_current_slot() {
    local current_time
    current_time=$(date '+%H:%M')
    
    # 检查各个时间槽
    if [[ "$current_time" >= "05:00" && "$current_time" <= "07:00" ]]; then
        echo "freeActivity"
    elif [[ "$current_time" >= "07:00" && "$current_time" <= "08:00" ]]; then
        echo "planning"
    elif [[ "$current_time" >= "09:00" && "$current_time" <= "12:00" ]]; then
        echo "deepWork"
    elif [[ "$current_time" >= "14:00" && "$current_time" <= "17:00" ]]; then
        echo "deepWork"
    elif [[ "$current_time" >= "21:00" && "$current_time" <= "22:00" ]]; then
        echo "consolidation"
    else
        echo "none"
    fi
}

# 获取昨日完成率
get_yesterday_completion() {
    local yesterday_plan="${WORKSPACE}/task-plan-$(date -d 'yesterday' +%Y-%m-%d).json"
    
    if [[ -f "$yesterday_plan" ]]; then
        local total completed
        total=$(jq '.tasks | length' "$yesterday_plan" 2>/dev/null || echo "0")
        completed=$(jq '[.tasks[] | select(.status == "completed")] | length' "$yesterday_plan" 2>/dev/null || echo "0")
        
        if [[ "$total" -gt 0 ]]; then
            echo "scale=2; $completed / $total" | bc
        else
            echo "0.75"
        fi
    else
        echo "0.75"
    fi
}

# 获取未完成任务
get_pending_tasks() {
    local pending_dir="${WORKSPACE}/memory/working"
    
    if [[ -d "$pending_dir" ]]; then
        ls -1 "$pending_dir"/*.json 2>/dev/null | while read -r file; do
            local status
            status=$(jq -r '.status' "$file" 2>/dev/null)
            if [[ "$status" == "in_progress" || "$status" == "pending" ]]; then
                cat "$file"
            fi
        done | jq -s '.'
    else
        echo "[]"
    fi
}

# 获取主人任务
get_master_tasks() {
    local master_file="${WORKSPACE}/memory/master-tasks.json"
    
    if [[ -f "$master_file" ]]; then
        cat "$master_file"
    else
        echo "[]"
    fi
}

# 获取自由时间发现
get_discoveries() {
    local discoveries_file="${WORKSPACE}/memory/discoveries-$(date +%Y-%m-%d).json"
    
    if [[ -f "$discoveries_file" ]]; then
        cat "$discoveries_file"
    else
        echo "[]"
    fi
}

#######################################
# 核心功能：生成默认推荐任务（我的自主能力）
#######################################

generate_fallback_tasks() {
    local max_tasks="${1:-5}"
    local tasks='[]'
    local current_slot
    current_slot=$(time_get_current_slot)
    
    # 通用技能提升任务
    local default_tasks=(
        "技术学习:复习本周学到的AI相关知识"
        "代码练习:编写一个小型自动化脚本"
        "知识整理:整理近期的笔记和文档"
        "工具优化:改进工作效率工具"
        "阅读提升:阅读技术文章或文档"
        "知识探索:研究新的AI工具或框架"
        "流程优化:分析和优化现有工作流程"
        "技能评估:评估当前技能差距"
    )
    
    # 根据时间段选择不同类型的任务（小咪的实际模板）
    local time_based_tasks=()
    
    case "$current_slot" in
        "planning")
            time_based_tasks=("晨间规划:回顾本周目标" "任务分解:将大任务拆分为小任务" "优先级排序:重新评估任务优先级")
            ;;
        "deepWork")
            time_based_tasks=("深度工作:专注完成重要任务" "项目推进:推动核心项目进展" "代码开发:实现功能模块")
            ;;
        "consolidation")
            time_based_tasks=("每日复盘:总结今天的工作" "知识归档:整理今日学习内容" "明日规划:准备明天的工作计划")
            ;;
        *)
            time_based_tasks=("任务回顾:检查待办事项" "进度更新:更新任务状态" "知识积累:记录学习心得")
            ;;
    esac
    
    # 合并任务池
    local all_task_pool=("${default_tasks[@]}" "${time_based_tasks[@]}")
    
    # 选择任务
    local task_count=0
    for task_template in "${all_task_pool[@]}"; do
        [[ $task_count -ge $max_tasks ]] && break
        
        IFS=':' read -r type title <<< "$task_template"
        
        local task_id
        task_id=$(aec_uuidgen 2>/dev/null || echo "fallback-$(date +%s)-$$")
        
        local description=""
        case "$type" in
            "技术学习")
                description="复习和巩固本周学到的AI、编程、工具使用等相关知识，查漏补缺。"
                ;;
            "代码练习")
                description="选择一个小型项目或练习题进行编码实践，提升编程熟练度。"
                ;;
            "知识整理")
                description="整理近期的学习笔记、项目文档，结构化存储便于日后查阅。"
                ;;
            "工具优化")
                description="分析当前工作效率，识别可以自动化的环节，编写或改进脚本。"
                ;;
            "阅读提升")
                description="阅读AI领域的技术文章、论文摘要、工具文档等，保持知识更新。"
                ;;
            "知识探索")
                description="主动探索新的AI工具、框架、方法，拓展技术视野。"
                ;;
            "流程优化")
                description="分析现有工作流程，找出瓶颈和低效环节，提出改进方案。"
                ;;
            "技能评估")
                description="评估当前技能水平，识别需要加强的领域，制定学习计划。"
                ;;
            "晨间规划")
                description="回顾本周目标，评估进度，调整本周工作计划。"
                ;;
            "任务分解")
                description="将大任务拆分为可执行的小任务，便于跟踪和管理。"
                ;;
            "优先级排序")
                description="根据重要性和紧急程度重新评估任务优先级。"
                ;;
            "深度工作")
                description="排除干扰，专注完成高价值的核心任务。"
                ;;
            "项目推进")
                description="推进核心项目，解决关键问题，取得实质性进展。"
                ;;
            "代码开发")
                description="实现功能模块，编写高质量代码，进行测试验证。"
                ;;
            "每日复盘")
                description="总结今天的工作完成情况，分析得失，记录经验教训。"
                ;;
            "知识归档")
                description="将今日学习的内容整理归档，更新知识库。"
                ;;
            "明日规划")
                description="根据今日进展和整体目标，准备明天的工作计划。"
                ;;
            "任务回顾")
                description="检查待办事项列表，更新任务状态和优先级。"
                ;;
            "进度更新")
                description="更新进行中任务的进度，记录当前状态。"
                ;;
            "知识积累")
                description="记录今日学习心得、解决问题的方法、新的认知等。"
                ;;
            *)
                description="执行日常任务，保持工作连贯性。"
                ;;
        esac
        
        # 使用heredoc创建任务（小咪的简化语法）
        local task_file="${WORKSPACE}/memory/working/${task_id}.json"
        cat > "$task_file" << EOF
{
  "id": "$task_id",
  "title": "$title",
  "description": "$description",
  "type": "autonomous",
  "priority": 4,
  "status": "pending",
  "estimatedDuration": 45,
  "progress": 0,
  "source": "default-$current_slot",
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
        
        ((task_count++))
        log_info "生成默认任务: $title"
    done
    
    if [[ $task_count -gt 0 ]]; then
        log_info "已生成 $task_count 个默认推荐任务"
    fi
    
    echo "$tasks"
}

#######################################
# 核心功能：生成任务计划
#######################################

generate_task_plan() {
    log_info "开始生成今日任务计划..."
    
    local plan_id
    plan_id=$(aec_uuidgen 2>/dev/null || echo "plan-$(date +%s)")
    local today
    today=$(date +%Y-%m-%d)
    
    # 分析完成率（自适应学习）
    local completion_rate
    completion_rate=$(get_yesterday_completion)
    log_info "昨日完成率: $completion_rate"
    
    # 获取各种任务
    local pending_tasks
    pending_tasks=$(get_pending_tasks)
    local master_tasks
    master_tasks=$(get_master_tasks)
    local discoveries
    discoveries=$(get_discoveries)
    
    # 构建任务数组（使用heredoc简化语法）
    local tasks_json="[]"
    local total_duration=0
    
    # 1. 主人任务（最高优先级）
    if [[ -n "$master_tasks" && "$master_tasks" != "[]" ]]; then
        log_info "添加主人指令任务"
        # 将master_tasks合并到计划
    fi
    
    # 2. 未完成任务（继续执行）
    if [[ -n "$pending_tasks" && "$pending_tasks" != "[]" ]]; then
        log_info "添加未完成任务"
    fi
    
    # 3. 从发现中生成任务（学习能力）
    local discovery_count
    discovery_count=$(echo "$discoveries" | jq 'length' 2>/dev/null || echo "0")
    
    if [[ "$discovery_count" -gt 0 ]]; then
        log_info "从$discovery_count个发现中生成任务"
    fi
    
    # 4. 如果没有任务来源，生成默认推荐任务（自主能力）
    if [[ -z "$pending_tasks" || "$pending_tasks" == "[]" ]] && \
       [[ -z "$master_tasks" || "$master_tasks" == "[]" ]] && \
       [[ "$discovery_count" -eq 0 ]]; then
        log_info "未检测到任务来源，生成默认推荐任务..."
        generate_fallback_tasks 5
    fi
    
    # 获取所有任务计算总时长
    if [[ -d "${WORKSPACE}/memory/working" ]]; then
        for task_file in "${WORKSPACE}/memory/working"/*.json; do
            [[ -f "$task_file" ]] || continue
            local duration
            duration=$(jq -r '.estimatedDuration' "$task_file" 2>/dev/null || echo "45")
            total_duration=$((total_duration + duration))
        done
    fi
    
    # 创建任务计划文件
    local plan_json
    plan_json=$(cat << EOF
{
  "id": "$plan_id",
  "date": "$today",
  "tasks": [],
  "totalEstimatedDuration": $total_duration,
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "completionRate": $completion_rate,
  "approvedAt": null,
  "approvedBy": null
}
EOF
)
    
    # 如果有未完成任务，添加到计划
    if [[ -d "${WORKSPACE}/memory/working" ]]; then
        local tasks_array="[]"
        for task_file in "${WORKSPACE}/memory/working"/*.json; do
            [[ -f "$task_file" ]] || continue
            local task_content
            task_content=$(cat "$task_file")
            tasks_array=$(echo "$tasks_array" | jq ". + [$task_content]" 2>/dev/null || echo "$tasks_array")
        done
        
        # 更新计划的tasks字段
        plan_json=$(echo "$plan_json" | jq ".tasks = $tasks_array" 2>/dev/null || echo "$plan_json")
    fi
    
    # 保存计划
    echo "$plan_json" > "$TASK_PLAN_FILE"
    log_info "任务计划已保存: $TASK_PLAN_FILE"
    
    # 输出摘要
    local task_count
    task_count=$(jq '.tasks | length' "$TASK_PLAN_FILE" 2>/dev/null || echo "0")
    log_info "生成计划: $task_count 个任务，总计 $total_duration 分钟"
    
    # 显示主人任务
    local master_count
    master_count=$(jq '[.tasks[] | select(.type == "master")] | length' "$TASK_PLAN_FILE" 2>/dev/null || echo "0")
    if [[ "$master_count" -gt 0 ]]; then
        log_warn "包含 $master_count 个主人指令任务（最高优先级）"
    fi
    
    echo "$plan_json"
}

#######################################
# 任务管理命令
#######################################

task_create() {
    local title="$1"
    local description="$2"
    local task_type="${3:-autonomous}"
    local priority="${4:-4}"
    
    local task_id
    task_id=$(aec_uuidgen 2>/dev/null || echo "task-$(date +%s)")
    
    # 使用heredoc创建任务（小咪的简化语法）
    cat > "${WORKSPACE}/memory/working/${task_id}.json" << EOF
{
  "id": "$task_id",
  "title": "$title",
  "description": "$description",
  "type": "$task_type",
  "priority": $priority,
  "status": "pending",
  "estimatedDuration": 60,
  "progress": 0,
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_info "任务已创建: $task_id - $title"
    echo "$task_id"
}

task_activate() {
    local task_id="$1"
    local task_file="${WORKSPACE}/memory/working/${task_id}.json"
    
    if [[ ! -f "$task_file" ]]; then
        log_error "任务文件不存在: $task_id"
        return 1
    fi
    
    # 使用jq更新状态
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq ".status = \"in_progress\" | .startedAt = \"$timestamp\" | .updatedAt = \"$timestamp\" | .progress = (if .progress == 0 then 5 else .progress end)" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
    
    log_info "任务已激活: $task_id"
}

task_update_progress() {
    local task_id="$1"
    local progress="$2"
    local message="${3:-}"
    
    local task_file="${WORKSPACE}/memory/working/${task_id}.json"
    
    if [[ ! -f "$task_file" ]]; then
        log_error "任务文件不存在: $task_id"
        return 1
    fi
    
    # 限制进度在0-100之间
    progress=$((progress > 100 ? 100 : progress))
    progress=$((progress < 0 ? 0 : progress))
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq ".progress = $progress | .updatedAt = \"$timestamp\" | .result = \"${message:-}\"" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
    
    log_info "进度更新: $task_id - $progress%"
}

task_complete() {
    local task_id="$1"
    local result="${2:-success}"
    
    local task_file="${WORKSPACE}/memory/working/${task_id}.json"
    
    if [[ ! -f "$task_file" ]]; then
        log_error "任务文件不存在: $task_id"
        return 1
    fi
    
    local status
    if [[ "$result" == "success" ]]; then
        status="completed"
    else
        status="failed"
    fi
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq ".status = \"$status\" | .progress = ($result == \"success\" ? 100 : .progress) | .completedAt = \"$timestamp\" | .updatedAt = \"$timestamp\"" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
    
    log_info "任务完成: $task_id - $status"
}

task_cancel() {
    local task_id="$1"
    local task_file="${WORKSPACE}/memory/working/${task_id}.json"
    
    if [[ ! -f "$task_file" ]]; then
        log_error "任务文件不存在: $task_id"
        return 1
    fi
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq ".status = \"cancelled\" | .updatedAt = \"$timestamp\" | .completedAt = \"$timestamp\"" "$task_file" > "${task_file}.tmp" && mv "${task_file}.tmp" "$task_file"
    
    log_info "任务已取消: $task_id"
}

#######################################
# 显示计划摘要
#######################################

show_plan_summary() {
    local plan="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$plan" ]]; then
        log_error "计划文件不存在: $plan"
        return 1
    fi
    
    echo "=========================================="
    echo "    今日自主演化任务计划"
    echo "=========================================="
    echo ""
    
    local total
    total=$(jq '.tasks | length' "$plan")
    echo "总任务数: $total"
    echo ""
    
    echo "主人指令任务:"
    jq -r '.tasks[] | select(.type == "master") | "  - [\( .priority )] \( .title ) (\(.estimatedDuration)分钟)"' "$plan" 2>/dev/null || echo "  无"
    echo ""
    
    echo "待完成任务:"
    jq -r '.tasks[] | select(.status == "pending" and .type != "master") | "  - [\( .priority )] \( .title ) (\(.estimatedDuration)分钟)"' "$plan" 2>/dev/null || echo "  无"
    echo ""
    
    echo "=========================================="
}

#######################################
# 主命令处理
#######################################

main() {
    local command="${1:-help}"
    shift || true
    
    aec_init "task-generator"
    
    case "$command" in
        "generate"|"")
            generate_task_plan
            ;;
        "summary")
            show_plan_summary "$2"
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
        "task:cancel")
            task_cancel "$1"
            ;;
        "help"|"")
            cat << 'EOF'
Autonomous Evolution Cycle - 任务生成器

用法: task-generator.sh <命令> [参数]

命令:
  generate              生成今日任务计划
  summary [文件]        显示任务计划摘要
  task:create <标题> <描述> [类型] [优先级]  创建任务
  task:activate <ID>   激活任务
  task:progress <ID> <进度> [消息]           更新进度
  task:complete <ID> [结果]                 完成任务
  task:cancel <ID>    取消任务
  help                显示此帮助

示例:
  ./task-generator.sh generate
  ./task-generator.sh summary
  ./task-generator.sh task:create "学习TS" "阅读官方文档" autonomous 3
EOF
            ;;
        *)
            log_error "未知命令: $command"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"
