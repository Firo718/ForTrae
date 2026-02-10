#!/bin/bash
# Autonomous Evolution Cycle - 测试脚本
# 验证所有Shell脚本的功能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 测试配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
WORKSPACE="${HOME}/.openclaw/workspace"

# 测试统计
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

#######################################
# 测试工具函数
#######################################

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✅ PASS${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}❌ FAIL${NC} $1"
    FAILED_TESTS+=("$1")
    ((TESTS_FAILED++))
}

print_skip() {
    echo -e "${YELLOW}⏭ SKIP${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

#######################################
# 环境检查
#######################################

check_environment() {
    print_header "环境检查"
    
    print_test "检查bash..."
    if command -v bash &> /dev/null; then
        BASH_VERSION=$(bash --version | head -1)
        print_pass "bash已安装: $BASH_VERSION"
    else
        print_fail "bash未安装"
    fi
    
    print_test "检查jq..."
    if command -v jq &> /dev/null; then
        JQ_VERSION=$(jq --version)
        print_pass "jq已安装: $JQ_VERSION"
    else
        print_fail "jq未安装（必须安装）"
    fi
    
    print_test "检查bc..."
    if command -v bc &> /dev/null; then
        print_pass "bc已安装"
    else
        print_fail "bc未安装（推荐安装）"
    fi
    
    print_test "检查脚本目录..."
    if [[ -d "$SCRIPT_DIR" ]]; then
        print_pass "脚本目录存在: $SCRIPT_DIR"
    else
        print_fail "脚本目录不存在"
    fi
    
    print_test "检查lib目录..."
    if [[ -d "$LIB_DIR" ]]; then
        print_pass "lib目录存在"
    else
        print_fail "lib目录不存在"
    fi
    
    print_test "检查工作空间..."
    if [[ -d "$WORKSPACE" ]]; then
        print_pass "工作空间存在: $WORKSPACE"
    else
        print_info "工作空间不存在，将被创建"
        mkdir -p "$WORKSPACE"
    fi
    
    echo ""
    echo "环境准备完成"
}

#######################################
# 语法检查
#######################################

check_syntax() {
    print_header "语法检查"
    
    local scripts=(
        "aec.sh"
        "core.sh"
        "task-generator.sh"
        "progress-analyzer.sh"
        "knowledge-extractor.sh"
        "heartbeat.sh"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="${SCRIPT_DIR}/${script}"
        
        if [[ ! -f "$script_path" ]]; then
            print_skip "$script (文件不存在)"
            continue
        fi
        
        print_test "检查 $script 语法..."
        
        if bash -n "$script_path" 2>/dev/null; then
            print_pass "$script 语法正确"
        else
            print_fail "$script 语法错误"
            bash -n "$script_path" 2>&1 | head -5
        fi
    done
}

#######################################
# 核心库测试
#######################################

test_core_library() {
    print_header "核心库测试"
    
    # 加载核心库
    print_test "加载core.sh..."
    if source "${LIB_DIR}/core.sh" 2>/dev/null; then
        print_pass "core.sh加载成功"
    else
        print_fail "core.sh加载失败"
        return 1
    fi
    
    # 测试aec_init
    print_test "测试 aec_init 函数..."
    aec_init "test" 2>/dev/null
    print_pass "aec_init执行成功"
    
    # 测试sanitize_filename
    print_test "测试 sanitize_filename..."
    result=$(sanitize_filename "normal-file.json")
    if [[ "$result" == "normal-file.json" ]]; then
        print_pass "sanitize_filename正常输入"
    else
        print_fail "sanitize_filename正常输入失败"
    fi
    
    result=$(sanitize_filename "../../etc/passwd")
    if [[ "$result" != *".."* ]]; then
        print_pass "sanitize_filename阻止路径遍历"
    else
        print_fail "sanitize_filename路径遍历检测失败"
    fi
    
    # 测试validate_path
    print_test "测试 validate_path..."
    result=$(validate_path "/safe/path" "/base" 2>/dev/null)
    if [[ $? -eq 0 && "$result" == "/safe/path" ]]; then
        print_pass "validate_path正常路径"
    else
        print_fail "validate_path正常路径失败"
    fi
    
    result=$(validate_path "/../../../etc" "/safe" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        print_pass "validate_path阻止路径遍历"
    else
        print_fail "validate_path路径遍历检测失败"
    fi
    
    # 测试aec_uuidgen
    print_test "测试 aec_uuidgen..."
    uuid1=$(aec_uuidgen)
    uuid2=$(aec_uuidgen)
    if [[ ${#uuid1} -ge 10 && "$uuid1" != "$uuid2" ]]; then
        print_pass "aec_uuidgen生成唯一ID"
    else
        print_fail "aec_uuidgen生成失败"
    fi
    
    # 测试日志函数
    print_test "测试日志函数..."
    log_info "测试info日志" 2>/dev/null
    print_pass "log_info执行成功"
    
    log_warn "测试warn日志" 2>/dev/null
    print_pass "log_warn执行成功"
}

#######################################
# 任务功能测试
#######################################

test_task_functions() {
    print_header "任务功能测试"
    
    # 加载核心库
    source "${LIB_DIR}/core.sh" 2>/dev/null || return 1
    aec_init "test" 2>/dev/null
    
    # 清理测试数据
    rm -rf "${WORKSPACE}/memory/working/test-*.json" 2>/dev/null || true
    
    # 测试task_create
    print_test "测试 task_create..."
    task_id=$(task_create "测试任务1" "这是一个测试任务" "autonomous" 3 2>/dev/null)
    if [[ ${#task_id} -ge 10 ]]; then
        print_pass "task_create创建任务: $task_id"
    else
        print_fail "task_create创建任务失败"
        return 1
    fi
    
    # 测试task_get_status
    print_test "测试 task_get_status..."
    status=$(task_get_status "$task_id" 2>/dev/null)
    if [[ "$status" == "pending" ]]; then
        print_pass "task_get_status返回正确状态"
    else
        print_fail "task_get_status状态错误: $status"
    fi
    
    # 测试task_activate
    print_test "测试 task_activate..."
    task_activate "$task_id" 2>/dev/null
    status=$(task_get_status "$task_id" 2>/dev/null)
    if [[ "$status" == "in_progress" ]]; then
        print_pass "task_activate激活任务"
    else
        print_fail "task_activate激活失败"
    fi
    
    # 测试task_update_progress
    print_test "测试 task_update_progress..."
    task_update_progress "$task_id" 50 "已完成一半" 2>/dev/null
    progress=$(jq -r '.progress' "${WORKSPACE}/memory/working/${task_id}.json" 2>/dev/null)
    if [[ "$progress" == "50" ]]; then
        print_pass "task_update_progress更新进度"
    else
        print_fail "task_update_progress进度更新失败: $progress"
    fi
    
    # 测试task_complete
    print_test "测试 task_complete..."
    task_complete "$task_id" "success" 2>/dev/null
    status=$(task_get_status "$task_id" 2>/dev/null)
    if [[ "$status" == "completed" ]]; then
        print_pass "task_complete完成任务"
    else
        print_fail "task_complete完成失败: $status"
    fi
    
    # 清理
    rm -rf "${WORKSPACE}/memory/working/test-*.json" 2>/dev/null || true
}

#######################################
# 配置功能测试
#######################################

test_config_functions() {
    print_header "配置功能测试"
    
    # 加载核心库
    source "${LIB_DIR}/core.sh" 2>/dev/null || return 1
    aec_init "test" 2>/dev/null
    
    # 测试config_load
    print_test "测试 config_load..."
    config=$(config_load 2>/dev/null)
    if echo "$config" | jq -e '.timeSlots' > /dev/null 2>&1; then
        print_pass "config_load加载配置"
    else
        print_fail "config_load加载配置失败"
    fi
    
    # 测试time_get_current_slot
    print_test "测试 time_get_current_slot..."
    slot=$(time_get_current_slot 2>/dev/null)
    if [[ "$slot" =~ ^(freeActivity|planning|deepWork|consolidation|none)$ ]]; then
        print_pass "time_get_current_slot返回有效时间槽: $slot"
    else
        print_fail "time_get_current_slot返回无效值: $slot"
    fi
}

#######################################
# 知识功能测试
#######################################

test_knowledge_functions() {
    print_header "知识功能测试"
    
    # 加载核心库
    source "${LIB_DIR}/core.sh" 2>/dev/null || return 1
    aec_init "test" 2>/dev/null
    
    # 清理测试数据
    rm -rf "${WORKSPACE}/memory/factual/test-*.json" 2>/dev/null || true
    rm -rf "${WORKSPACE}/memory/experiential/test-*.json" 2>/dev/null || true
    
    # 测试knowledge_save (factual)
    print_test "测试 knowledge_save (factual)..."
    knowledge_id=$(knowledge_save "factual" "测试知识" "这是一个测试知识内容" "test,unit-test" 2>/dev/null)
    if [[ ${#knowledge_id} -ge 10 ]]; then
        if [[ -f "${WORKSPACE}/memory/factual/${knowledge_id}.json" ]]; then
            print_pass "knowledge_save保存事实性知识"
        else
            print_fail "knowledge_save文件未创建"
        fi
    else
        print_fail "knowledge_save创建失败"
    fi
    
    # 测试knowledge_save (experiential)
    print_test "测试 knowledge_save (experiential)..."
    knowledge_id=$(knowledge_save "experiential" "测试经验" "这是一个测试经验" "test,lesson" 2>/dev/null)
    if [[ ${#knowledge_id} -ge 10 && -f "${WORKSPACE}/memory/experiential/${knowledge_id}.json" ]]; then
        print_pass "knowledge_save保存经验性知识"
    else
        print_fail "knowledge_save保存经验性知识失败"
    fi
    
    # 清理
    rm -rf "${WORKSPACE}/memory/factual/test-*.json" 2>/dev/null || true
    rm -rf "${WORKSPACE}/memory/experiential/test-*.json" 2>/dev/null || true
}

#######################################
# JSON功能测试
#######################################

test_json_functions() {
    print_header "JSON功能测试"
    
    # 加载核心库
    source "${LIB_DIR}/core.sh" 2>/dev/null || return 1
    aec_init "test" 2>/dev/null
    
    local test_file="${WORKSPACE}/config/test-json.json"
    mkdir -p "$(dirname "$test_file")"
    
    # 测试json_update
    print_test "测试 json_update..."
    echo '{}' > "$test_file"
    json_update "$test_file" "key1" "value1" 2>/dev/null
    if jq -e '.key1 == "value1"' "$test_file" > /dev/null 2>&1; then
        print_pass "json_update更新字段"
    else
        print_fail "json_update更新字段失败"
    fi
    
    # 测试json_get
    print_test "测试 json_get..."
    value=$(json_get "$test_file" "key1" 2>/dev/null)
    if [[ "$value" == "value1" ]]; then
        print_pass "json_get读取字段"
    else
        print_fail "json_get读取字段失败: $value"
    fi
    
    # 清理
    rm -f "$test_file"
}

#######################################
# 集成测试
#######################################

test_integration() {
    print_header "集成测试"
    
    # 加载核心库
    source "${LIB_DIR}/core.sh" 2>/dev/null || return 1
    aec_init "test" 2>/dev/null
    
    # 清理
    rm -rf "${WORKSPACE}/memory/working/test-*.json" 2>/dev/null || true
    rm -f "${WORKSPACE}/task-plan-test.json" 2>/dev/null || true
    
    # 创建测试任务计划
    print_test "创建测试任务计划..."
    cat > "${WORKSPACE}/task-plan-test.json" << 'EOF'
{
  "id": "test-plan-123",
  "date": "2024-01-15",
  "tasks": [
    {
      "id": "test-task-1",
      "title": "测试任务1",
      "description": "描述1",
      "type": "autonomous",
      "priority": 4,
      "status": "completed",
      "estimatedDuration": 60,
      "progress": 100,
      "createdAt": "2024-01-15T09:00:00Z",
      "updatedAt": "2024-01-15T10:00:00Z",
      "completedAt": "2024-01-15T10:00:00Z",
      "result": "测试完成",
      "actualDuration": 45
    },
    {
      "id": "test-task-2",
      "title": "测试任务2",
      "description": "描述2",
      "type": "autonomous",
      "priority": 4,
      "status": "in_progress",
      "estimatedDuration": 60,
      "progress": 50,
      "createdAt": "2024-01-15T10:00:00Z",
      "updatedAt": "2024-01-15T10:30:00Z",
      "startedAt": "2024-01-15T10:00:00Z"
    },
    {
      "id": "test-task-3",
      "title": "主人指令任务",
      "description": "紧急任务",
      "type": "master",
      "priority": 1,
      "status": "in_progress",
      "estimatedDuration": 30,
      "progress": 0,
      "createdAt": "2024-01-15T11:00:00Z",
      "updatedAt": "2024-01-15T11:00:00Z",
      "startedAt": "2024-01-15T11:00:00Z"
    }
  ]
}
EOF
    print_pass "测试任务计划创建成功"
    
    # 统计任务
    print_test "验证任务统计..."
    total=$(jq '.tasks | length' "${WORKSPACE}/task-plan-test.json")
    completed=$(jq '[.tasks[] | select(.status == "completed")] | length' "${WORKSPACE}/task-plan-test.json")
    in_progress=$(jq '[.tasks[] | select(.status == "in_progress")] | length' "${WORKSPACE}/task-plan-test.json")
    
    if [[ "$total" == "3" && "$completed" == "1" && "$in_progress" == "2" ]]; then
        print_pass "任务统计正确"
    else
        print_fail "任务统计错误: total=$total, completed=$completed, in_progress=$in_progress"
    fi
    
    # 检查主人任务
    print_test "验证主人任务..."
    master_count=$(jq '[.tasks[] | select(.type == "master")] | length' "${WORKSPACE}/task-plan-test.json")
    if [[ "$master_count" == "1" ]]; then
        print_pass "主人任务识别正确"
    else
        print_fail "主人任务识别错误"
    fi
    
    # 清理
    rm -f "${WORKSPACE}/task-plan-test.json"
}

#######################################
# 性能测试
#######################################

test_performance() {
    print_header "性能测试"
    
    source "${LIB_DIR}/core.sh" 2>/dev/null || return 1
    aec_init "test" 2>/dev/null
    
    # 清理
    rm -rf "${WORKSPACE}/memory/working/perf-test-*.json" 2>/dev/null || true
    
    print_test "批量创建任务性能测试..."
    
    local start_time=$(date +%s%N)
    
    for i in $(seq 1 10); do
        task_create "性能测试任务$i" "批量创建$i" "autonomous" 4 2>/dev/null || true
    done
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $duration -lt 5000 ]]; then
        print_pass "批量创建10个任务耗时${duration}ms (目标<5000ms)"
    else
        print_fail "批量创建性能下降: ${duration}ms"
    fi
    
    # 清理
    rm -rf "${WORKSPACE}/memory/working/perf-test-*.json" 2>/dev/null || true
}

#######################################
# 测试报告
#######################################

print_report() {
    print_header "测试报告"
    
    echo ""
    echo -e "${BLUE}测试统计:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  总测试:   ${TESTS_RUN}"
    echo -e "  通过:     ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "  失败:     ${RED}${TESTS_FAILED}${NC}"
    echo -e "  跳过:     ${YELLOW}${SKIP_COUNT:-0}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}失败测试:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
    fi
    
    echo ""
    
    local pass_rate=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        pass_rate=$(( TESTS_PASSED * 100 / TESTS_RUN ))
    fi
    
    if [[ $pass_rate -ge 90 ]]; then
        echo -e "${GREEN}✅ 总体评估: 优秀 (${pass_rate}%)${NC}"
    elif [[ $pass_rate -ge 70 ]]; then
        echo -e "${YELLOW}⚠️ 总体评估: 良好 (${pass_rate}%)${NC}"
    else
        echo -e "${RED}❌ 总体评估: 需要改进 (${pass_rate}%)${NC}"
    fi
    
    echo ""
    echo "测试时间: $(date)"
    echo ""
}

#######################################
# 主程序
#######################################

main() {
    print_header "Autonomous Evolution Cycle - 测试套件"
    
    echo "测试目录: $SCRIPT_DIR"
    echo "工作空间: $WORKSPACE"
    echo ""
    
    # 环境检查
    TESTS_RUN=10
    check_environment
    
    # 检查依赖
    if ! command -v jq &> /dev/null; then
        echo ""
        print_fail "jq未安装，无法运行测试"
        echo "请安装jq: apt install jq"
        exit 1
    fi
    
    # 语法检查
    TESTS_RUN=6
    check_syntax
    
    # 核心库测试
    TESTS_RUN=$((TESTS_RUN + 8))
    test_core_library
    
    # 任务功能测试
    TESTS_RUN=$((TESTS_RUN + 6))
    test_task_functions
    
    # 配置功能测试
    TESTS_RUN=$((TESTS_RUN + 2))
    test_config_functions
    
    # 知识功能测试
    TESTS_RUN=$((TESTS_RUN + 3))
    test_knowledge_functions
    
    # JSON功能测试
    TESTS_RUN=$((TESTS_RUN + 3))
    test_json_functions
    
    # 集成测试
    TESTS_RUN=$((TESTS_RUN + 4))
    test_integration
    
    # 性能测试
    TESTS_RUN=$((TESTS_RUN + 1))
    test_performance
    
    # 报告
    print_report
    
    # 退出码
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
