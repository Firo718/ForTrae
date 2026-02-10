#!/bin/bash
# Autonomous Evolution Cycle - 知识提取器
# 从任务执行中提取结构化知识，生成Compost Method种子

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

if [[ -f "${LIB_DIR}/core.sh" ]]; then
    source "${LIB_DIR}/core.sh"
else
    AEC_WORKSPACE="${OPENCLAW_WORKSPACE:-${HOME}/.openclaw/workspace}"
    AEC_SCRIPT_NAME="knowledge-extractor"
    mkdir -p "${AEC_WORKSPACE}/memory/"{factual,experiential,patterns}
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [knowledge-extractor] $1"; }
fi

WORKSPACE="${AEC_WORKSPACE}"
TASK_PLAN_FILE="${WORKSPACE}/task-plan-$(date +%Y-%m-%d).json"

#######################################
# 知识提取核心函数
#######################################

# 从完成任务中提取事实性知识
extract_factual_knowledge() {
    local plan_file="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$plan_file" ]]; then
        log_warn "计划文件不存在，跳过事实性知识提取"
        return
    fi
    
    log_info "提取事实性知识..."
    
    local extracted_count=0
    
    # 获取完成的任务
    jq -c ".tasks[] | select(.status == \"completed\")" "$plan_file" 2>/dev/null | while read -r task; do
        local task_id title description result
        task_id=$(echo "$task" | jq -r '.id')
        title=$(echo "$task" | jq -r '.title')
        description=$(echo "$task" | jq -r '.description')
        result=$(echo "$task" | jq -r '(.result // "成功完成")')
        
        # 构建知识内容
        local content="任务完成报告\n\n"
        content="${content}标题: ${title}\n"
        content="${content}描述: ${description}\n"
        content="${content}结果: ${result}\n"
        
        # 添加时间信息
        local completed_at estimated_duration actual_duration
        completed_at=$(echo "$task" | jq -r '(.completedAt // "unknown")')
        estimated_duration=$(echo "$task" | jq -r '(.estimatedDuration // 60)')
        actual_duration=$(echo "$task" | jq -r '(.actualDuration // $estimated_duration)')
        
        content="${content}预计时长: ${estimated_duration}分钟\n"
        content="${content}实际时长: ${actual_duration}分钟\n"
        
        # 计算效率
        local efficiency
        if [[ "$actual_duration" -gt 0 ]]; then
            efficiency=$(echo "scale=2; $estimated_duration / $actual_duration" | bc)
            content="${content}效率比: ${efficiency}x\n"
        fi
        
        # 保存知识
        knowledge_save "factual" "完成: $title" "$content" "task,completion,$(date +%Y-%m-%d)"
        ((extracted_count++))
    done
    
    log_info "已提取 $extracted_count 条事实性知识"
}

# 从经验中提取教训
extract_experiential_knowledge() {
    local plan_file="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$plan_file" ]]; then
        log_warn "计划文件不存在，跳过经验性知识提取"
        return
    fi
    
    log_info "提取经验性知识..."
    
    local extracted_count=0
    
    # 分析完成的任务效率
    local completed_tasks
    completed_tasks=$(jq '[.tasks[] | select(.status == "completed")] | length' "$plan_file")
    
    if [[ "$completed_tasks" -gt 0 ]]; then
        # 计算平均效率
        local efficiency_sum=0
        local task_count=0
        
        jq -c ".tasks[] | select(.status == \"completed\" and .actualDuration != null)" "$plan_file" 2>/dev/null | while read -r task; do
            local estimated actual
            estimated=$(echo "$task" | jq -r '.estimatedDuration')
            actual=$(echo "$task" | jq -r '.actualDuration')
            
            if [[ "$actual" -gt 0 ]]; then
                local efficiency
                efficiency=$(echo "scale=2; $estimated / $actual" | bc)
                efficiency_sum=$(echo "$efficiency_sum + $efficiency" | bc)
                ((task_count++))
            fi
        done
        
        if [[ "$task_count" -gt 0 ]]; then
            local avg_efficiency
            avg_efficiency=$(echo "scale=2; $efficiency_sum / $task_count" | bc)
            
            local title="任务执行效率分析"
            local content="今日任务执行效率总结\n\n"
            content="${content}完成任务数: ${completed_tasks}\n"
            content="${content}分析任务数: ${task_count}\n"
            content="${content}平均效率: ${avg_efficiency}x\n"
            
            if (( $(echo "$avg_efficiency >= 1" | bc -l) )); then
                content="${content}评价: 效率良好\n"
            else
                content="${content}评价: 效率偏低，建议优化\n"
            fi
            
            knowledge_save "experiential" "$title" "$content" "experience,efficiency,$(date +%Y-%m-%d)"
            ((extracted_count++))
        fi
    fi
    
    # 处理失败的任务
    jq -c ".tasks[] | select(.status == \"failed\")" "$plan_file" 2>/dev/null | while read -r task; do
        local task_id title
        task_id=$(echo "$task" | jq -r '.id')
        title=$(echo "$task" | jq -r '.title')
        local progress=$(echo "$task" | jq -r '.progress')
        
        local content="任务失败分析\n\n"
        content="${content}标题: ${title}\n"
        content="${content}失败时进度: ${progress}%\n"
        content="${content}改进建议:\n"
        
        if [[ "$progress" -lt 30 ]]; then
            content="${content}- 任务可行性需要重新评估\n"
            content="${content}- 考虑拆分为更小的子任务\n"
        elif [[ "$progress" -lt 70 ]]; then
            content="${content}- 继续推进完成任务\n"
            content="${content}- 解决遇到的阻塞因素\n"
        else
            content="${content}- 集中精力完成最后阶段\n"
        fi
        
        knowledge_save "experiential" "教训: $title" "$content" "lesson,failure,$(date +%Y-%m-%d)"
        ((extracted_count++))
    done
    
    log_info "已提取 $extracted_count 条经验性知识"
}

# 生成Compost Method种子
generate_compost_seeds() {
    local plan_file="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$plan_file" ]]; then
        log_warn "计划文件不存在，跳过Compost种子生成"
        return
    fi
    
    log_info "生成Compost Method种子..."
    
    # 分析完成率
    local total completed
    total=$(jq '.tasks | length' "$plan_file")
    completed=$(jq '[.tasks[] | select(.status == "completed")] | length' "$plan_file")
    
    local completion_rate="0"
    if [[ "$total" -gt 0 ]]; then
        completion_rate=$(echo "scale=2; $completed * 100 / $total" | bc)
    fi
    
    # 生成完成率种子
    local seed_id
    seed_id=$(aec_uuidgen)
    
    local content="今日任务完成情况\n\n"
    content="${content}总任务数: ${total}\n"
    content="${content}已完成: ${completed}\n"
    content="${content}完成率: ${completion_rate}%\n\n"
    
    content="${content}模式分析:\n"
    
    if (( $(echo "$completion_rate >= 80" | bc -l) )); then
        content="${content}- 高完成率，可能任务量偏少\n"
    elif (( $(echo "$completion_rate >= 50" | bc -l) ]]; then
        content="${content}- 中等完成率，工作节奏良好\n"
    else
        content="${content}- 低完成率，需要优化工作方法\n"
    fi
    
    knowledge_save "experiential" "Compost种子-$(date +%Y-%m-%d): 完成率 ${completion_rate}%" "$content" "compost,completion-rate,$(date +%Y-%m-%d)"
    
    log_info "Compost种子已生成"
}

# 发现模式
discover_patterns() {
    local plan_file="${1:-$TASK_PLAN_FILE}"
    
    if [[ ! -f "$plan_file" ]]; then
        log_warn "计划文件不存在，跳过模式发现"
        return
    fi
    
    log_info "发现模式..."
    
    local patterns_dir="${WORKSPACE}/memory/patterns"
    mkdir -p "$patterns_dir"
    
    # 分析任务类型分布
    local autonomous_count master_count
    autonomous_count=$(jq '[.tasks[] | select(.type == "autonomous")] | length' "$plan_file")
    master_count=$(jq '[.tasks[] | select(.type == "master")] | length' "$plan_file")
    
    if [[ "$master_count" -gt 0 ]]; then
        local content="任务类型分布分析\n\n"
        content="${content}自主任务: ${autonomous_count}\n"
        content="${content}主人指令: ${master_count}\n"
        content="${content}主人任务占比: $(echo "scale=2; $master_count * 100 / ($autonomous_count + $master_count)" | bc)%\n\n"
        
        if [[ "$master_count" -gt "$autonomous_count" ]]; then
            content="${content}发现: 主人指令任务较多，自主工作时间减少\n"
            content="${content}建议: 在主人任务较少时增加自主任务安排\n"
        else
            content="${content}发现: 自主任务与主人任务保持平衡\n"
        fi
        
        local pattern_id
        pattern_id=$(aec_uuidgen)
        
        cat > "${patterns_dir}/${pattern_id}.json" << EOF
{
  "id": "$pattern_id",
  "pattern": "任务类型分布",
  "frequency": 1,
  "successRate": 0.8,
  "context": "自主任务: $autonomous_count, 主人任务: $master_count",
  "recommendation": "$content",
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
        
        log_info "模式发现已保存: ${patterns_dir}/${pattern_id}.json"
    fi
}

# 执行完整的知识提取流程
extract_all() {
    local plan_file="${1:-$TASK_PLAN_FILE}"
    
    log_info "开始完整的知识提取流程..."
    
    # 提取各类知识
    extract_factual_knowledge "$plan_file"
    extract_experiential_knowledge "$plan_file"
    generate_compost_seeds "$plan_file"
    discover_patterns "$plan_file"
    
    log_info "知识提取完成！"
    
    # 统计知识库
    local factual_count experiential_count pattern_count
    factual_count=$(ls -1 "${WORKSPACE}/memory/factual/"*.json 2>/dev/null | wc -l)
    experiential_count=$(ls -1 "${WORKSPACE}/memory/experiential/"*.json 2>/dev/null | wc -l)
    pattern_count=$(ls -1 "${WORKSPACE}/memory/patterns/"*.json 2>/dev/null | wc -l)
    
    echo ""
    echo "=========================================="
    echo "         知识提取完成统计"
    echo "=========================================="
    echo "事实性知识: $factual_count 条"
    echo "经验性知识: $experiential_count 条"
    echo "模式发现:   $pattern_count 条"
    echo "=========================================="
}

#######################################
# 主命令处理
#######################################

main() {
    local command="${1:-all}"
    shift || true
    
    aec_init "knowledge-extractor"
    
    case "$command" in
        "factual")
            extract_factual_knowledge "$@"
            ;;
        "experiential")
            extract_experiential_knowledge "$@"
            ;;
        "compost")
            generate_compost_seeds "$@"
            ;;
        "patterns")
            discover_patterns "$@"
            ;;
        "all"|"")
            extract_all "$@"
            ;;
        "help"|"")
            cat << 'EOF'
Autonomous Evolution Cycle - 知识提取器

用法: knowledge-extractor.sh <命令> [参数]

命令:
  factual [计划文件]   提取事实性知识
  experiential [文件]   提取经验性知识
  compost [计划文件]   生成Compost种子
  patterns [计划文件]  发现模式
  all [计划文件]       执行完整提取流程
  help                显示帮助

示例:
  ./knowledge-extractor.sh all
  ./knowledge-extractor.sh compost
EOF
            ;;
        *)
            log_error "未知命令: $command"
            exit 1
            ;;
    esac
}

main "$@"
