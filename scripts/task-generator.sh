#!/bin/bash
# Autonomous Evolution Cycle - 核心任务生成器
# 负责任务生成、进度分析、知识提取
# 基于原版openclaw skill设计

set -euo pipefail

# 导入公共库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
if [[ -f "${LIB_DIR}/core.sh" ]]; then
    source "${LIB_DIR}/core.sh"
else
    # 初始化日志
    init_logging "task-generator"
fi

# 配置
WORKSPACE="${OPENCLAW_WORKSPACE:-${HOME}/.openclaw/workspace}"
CONFIG_FILE="${WORKSPACE}/config/autonomous-evolution-config.json"
TASK_PLAN_FILE="${WORKSPACE}/task-plan-$(date +%Y-%m-%d).json"

# 默认配置
DEFAULT_TIME_SLOTS='{
  "freeActivity": {"start": "05:00", "end": "07:00"},
  "planning": {"start": "07:00", "end": "08:00"},
  "deepWork": [{"start": "09:00", "end": "12:00"}, {"start": "14:00", "end": "17:00"}],
  "consolidation": {"start": "21:00", "end": "22:00"}
}'

#######################################
# 核心函数
#######################################

# 加载配置
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo "$DEFAULT_TIME_SLOTS"
    fi
}

# 获取当前时间（HH:mm格式）
get_current_time() {
    date '+%H:%M'
}

# 检查是否在时间槽内
is_in_time_slot() {
    local slot_type="$1"
    local config
    config=$(load_config)
    
    local current_time
    current_time=$(get_current_time)
    
    # 提取时间槽的开始和结束时间
    local start end
    start=$(echo "$config" | jq -r ".${slot_type}.start")
    end=$(echo "$config" | jq -r ".${slot_type}.end")
    
    if [[ "$start" == "null" || "$end" == "null" ]]; then
        return 1
    fi
    
    # 比较时间
    if [[ "$current_time" >= "$start" && "$current_time" <= "$end" ]]; then
        return 0
    else
        return 1
    fi
}

# 生成UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        # 备用方案
        cat /proc/sys/kernel/random/uuid 2>/dev/null || \
        echo "$(date +%s)-$$-$(head -c 4 /dev/urandom | xxd -p)"
    fi
}

#######################################
# 任务生成逻辑
#######################################

# 分析昨日完成率
analyze_yesterday_completion() {
    local yesterday_plan="${WORKSPACE}/task-plan-$(date -d 'yesterday' +%Y-%m-%d).json"
    
    if [[ -f "$yesterday_plan" ]]; then
        local total completed
        total=$(jq '.tasks | length' "$yesterday_plan")
        completed=$(jq '[.tasks[] | select(.status == "completed")] | length' "$yesterday_plan")
        
        if [[ "$total" -gt 0 ]]; then
            echo "scale=2; $completed / $total" | bc
        else
            echo "0.75"  # 默认75%
        fi
    else
        echo "0.75"  # 默认75%
    fi
}

# 读取未完成任务
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

# 读取主人任务
get_master_tasks() {
    local master_file="${WORKSPACE}/memory/master-tasks.json"
    
    if [[ -f "$master_file" ]]; then
        cat "$master_file"
    else
        echo "[]"
    fi
}

# 读取自由时间发现
get_free_time_discoveries() {
    local discoveries_file="${WORKSPACE}/memory/discoveries-$(date +%Y-%m-%d).json"
    
    if [[ -f "$discoveries_file" ]]; then
        cat "$discoveries_file"
    else
        echo "[]"
    fi
}

# 生成自主任务
generate_autonomous_tasks() {
    local completion_rate="$1"
    local discoveries
    discoveries=$(get_free_time_discoveries)
    local tasks='[]'
    
    # 基于完成率调整任务数量
    local max_tasks=5
    if (( $(echo "$completion_rate >= 0.9" | bc -l) )); then
        max_tasks=7
    elif (( $(echo "$completion_rate < 0.5" | bc -l) )); then
        max_tasks=3
    fi
    
    # 从发现中生成任务
    local discovery_count
    discovery_count=$(echo "$discoveries" | jq 'length')
    
    for i in $(seq 0 $((discovery_count - 1))); do
        local discovery
        discovery=$(echo "$discoveries" | jq -r ".[$i]")
        
        if [[ -n "$discovery" && "$discovery" != "null" ]]; then
            local task_id
            task_id=$(generate_uuid)
            local title
            title="探索: ${discovery:0:50}"
            
            local task
            task=$(jq -n \
                --arg id "$task_id" \
                --arg title "$title" \
                --arg desc "$discovery" \
                --argjson priority 4 \
                '{
                    id: $id,
                    title: $title,
                    description: $desc,
                    type: "autonomous",
                    priority: $priority,
                    status: "pending",
                    estimatedDuration: 60,
                    progress: 0,
                    createdAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
                    updatedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
                }')
            
            tasks=$(echo "$tasks" | jq ". + [$task]")
        fi
    done
    
    # 🔧 如果没有发现也没有其他任务，生成默认推荐任务
    if [[ "$discovery_count" -eq 0 ]]; then
        log_info "未检测到自由时间发现，生成默认推荐任务..."
        tasks=$(generate_fallback_tasks "$max_tasks")
    fi
    
    echo "$tasks"
}

# 🔧 生成默认推荐任务（当没有任务来源时）
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
    
    # 根据时间段选择不同类型的任务
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
        task_id=$(generate_uuid)
        
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
        
        # 创建任务
        local task
        task=$(jq -n \
            --arg id "$task_id" \
            --arg title "$title" \
            --arg desc "$description" \
            --argjson priority 4 \
            --arg slot "$current_slot" \
            '{
                id: $id,
                title: $title,
                description: $desc,
                type: "autonomous",
                priority: $priority,
                status: "pending",
                estimatedDuration: 45,
                progress: 0,
                source: ("default-" + $slot),
                createdAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
                updatedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
            }')
        
        tasks=$(echo "$tasks" | jq ". + [$task]")
        ((task_count++))
    done
    
    if [[ $task_count -gt 0 ]]; then
        log_info "已生成 $task_count 个默认推荐任务"
    fi
    
    echo "$tasks"
}

# 生成任务计划
generate_task_plan() {
    log_info "开始生成今日任务计划..."
    
    local plan_id
    plan_id=$(generate_uuid)
    local today
    today=$(date +%Y-%m-%d)
    
    # 分析完成率
    local completion_rate
    completion_rate=$(analyze_yesterday_completion)
    log_info "昨日完成率: $completion_rate"
    
    # 获取各种任务
    local pending_tasks
    pending_tasks=$(get_pending_tasks)
    local master_tasks
    master_tasks=$(get_master_tasks)
    
    # 合并任务
    local all_tasks='[]'
    
    # 1. 主人任务（最高优先级）
    all_tasks=$(echo "$all_tasks" | jq ". + $master_tasks")
    
    # 2. 未完成任务（继续执行）
    all_tasks=$(echo "$all_tasks" | jq ". + $pending_tasks")
    
    # 3. 生成自主任务
    local autonomous_tasks
    autonomous_tasks=$(generate_autonomous_tasks "$completion_rate")
    all_tasks=$(echo "$all_tasks" | jq ". + $autonomous_tasks")
    
    # 计算总时长
    local total_duration
    total_duration=$(echo "$all_tasks" | jq '[.[] | .estimatedDuration] | add // 0')
    
    # 构建计划
    local plan
    plan=$(jq -n \
        --arg id "$plan_id" \
        --arg date "$today" \
        --argjson tasks "$all_tasks" \
        --argjson total_duration "$total_duration" \
        '{
            id: $id,
            date: $date,
            tasks: $tasks,
            totalEstimatedDuration: $total_duration,
            createdAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            completionRate: null,
            approvedAt: null,
            approvedBy: null
        }')
    
    # 保存计划
    echo "$plan" > "$TASK_PLAN_FILE"
    log_info "任务计划已保存: $TASK_PLAN_FILE"
    
    # 输出摘要
    local task_count
    task_count=$(echo "$plan" | jq '.tasks | length')
    log_info "生成计划: $task_count 个任务，总计 $total_duration 分钟"
    
    # 显示主人任务
    local master_count
    master_count=$(echo "$plan" | jq '[.tasks[] | select(.type == "master")] | length')
    if [[ "$master_count" -gt 0 ]]; then
        log_warn "包含 $master_count 个主人指令任务（最高优先级）"
    fi
    
    echo "$plan"
}

# 显示计划摘要
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
# 进度分析逻辑
#######################################

# 分析进度偏差
analyze_progress_deviations() {
    local current_plan="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$current_plan" ]]; then
        echo "[]"
        return
    fi
    
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    jq -n \
        --argjson tasks "$(cat "$current_plan" | jq '.tasks')" \
        --arg now "$now" \
        '[$tasks[] | select(.status == "in_progress") | {
            taskId: .id,
            expectedProgress: ((($now | strptime("%Y-%m-%dT%H:%M:%SZ")) - (.startedAt | strptime("%Y-%m-%dT%H:%M:%SZ"))) / 60 / .estimatedDuration * 100 | floor // 0),
            actualProgress: .progress,
            deviation: (.progress - (((($now | strptime("%Y-%m-%dT%H:%M:%SZ")) - (.startedAt | strptime("%Y-%m-%dT%H:%M:%SZ"))) / 60 / .estimatedDuration * 100 | floor // 0))),
            severity: (if .progress < 25 then "severe" elif .progress < 50 then "moderate" else "minor" end)
        }]'
}

# 检测零进度任务
detect_zero_progress_tasks() {
    local current_plan="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$current_plan" ]]; then
        echo "[]"
        return
    fi
    
    local threshold_time
    threshold_time=$(date -d '30 minutes ago' -u +%Y-%m-%dT%H:%M:%SZ)
    
    jq -r \
        --arg threshold "$threshold_time" \
        '.tasks[] | select(.status == "in_progress" and .progress == 0 and (.startedAt // .createdAt) < $threshold) | "\(.id)|\(.title)"' \
        "$current_plan" 2>/dev/null
}

#######################################
# 知识提取逻辑
#######################################

# 从完成任务中提取知识
extract_knowledge() {
    local current_plan="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$current_plan" ]]; then
        log_warn "计划文件不存在，跳过知识提取"
        return
    fi
    
    local knowledge_dir="${WORKSPACE}/memory/factual"
    mkdir -p "$knowledge_dir"
    
    # 提取完成的任务
    jq -r '.tasks[] | select(.status == "completed") | "\(.id)"' "$current_plan" 2>/dev/null | while read -r task_id; do
        local task
        task=$(jq ".tasks[] | select(.id == \"$task_id\")" "$current_plan")
        
        local title
        title=$(echo "$task" | jq -r '.title')
        
        # 创建知识条目
        local knowledge_id
        knowledge_id=$(generate_uuid)
        
        echo "$task" | jq \
            --arg id "$knowledge_id" \
            --arg task_title "$title" \
            '{
                id: $id,
                type: "factual",
                title: ("完成: " + $task_title),
                content: ("任务完成\n标题: " + $task_title + "\n结果: " + (.result // "成功完成")),
                tags: ["task", "completion"],
                confidence: 0.95,
                source: "autonomous-evolution-cycle",
                createdAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
            }' > "${knowledge_dir}/${knowledge_id}.json"
        
        log_info "知识已保存: $knowledge_id"
    done
}

# 生成Compost Method种子
generate_compost_seeds() {
    local current_plan="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$current_plan" ]]; then
        echo "[]"
        return
    fi
    
    local seeds_dir="${WORKSPACE}/memory/experiential"
    mkdir -p "$seeds_dir"
    
    # 分析完成率
    local completion_rate
    completion_rate=$(analyze_yesterday_completion)
    
    # 生成经验种子
    local seed_id
    seed_id=$(generate_uuid)
    
    local seed
    seed=$(jq -n \
        --arg id "$seed_id" \
        --argjson rate "$completion_rate" \
        '{
            id: $id,
            type: "experiential",
            title: ("昨日完成率: " + (($rate * 100) | floor | tostring) + "%"),
            content: ("昨日任务完成率为 " + (($rate * 100) | floor | tostring) + "%。"),
            tags: ["compost", "experience", "performance"],
            confidence: $rate,
            source: "autonomous-evolution-cycle",
            createdAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }')
    
    echo "$seed" > "${seeds_dir}/${seed_id}.json"
    log_info "Compost种子已生成: $seed_id"
    echo "$seed"
}

#######################################
# 主命令处理
#######################################

main() {
    local command="${1:-help}"
    
    case "$command" in
        "generate")
            generate_task_plan
            ;;
        "summary")
            show_plan_summary "$2"
            ;;
        "analyze-progress")
            analyze_progress_deviations "$2"
            ;;
        "detect-zero")
            detect_zero_progress_tasks "$2"
            ;;
        "extract-knowledge")
            extract_knowledge "$2"
            ;;
        "generate-seeds")
            generate_compost_seeds "$2"
            ;;
        "help"|"")
            echo "Autonomous Evolution Cycle - 任务生成器"
            echo ""
            echo "用法: $0 <命令> [参数]"
            echo ""
            echo "命令:"
            echo "  generate         生成今日任务计划"
            echo "  summary [文件]   显示任务计划摘要"
            echo "  analyze-progress 分析进度偏差"
            echo "  detect-zero      检测零进度任务"
            echo "  extract-knowledge 从完成的任务中提取知识"
            echo "  generate-seeds  生成Compost方法种子"
            echo "  help            显示此帮助信息"
            ;;
        *)
            log_error "未知命令: $command"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"
