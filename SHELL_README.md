# Autonomous Evolution Cycle - Shell版本使用指南

## 目录结构

```
scripts/
├── aec.sh                    # 主入口（整合所有功能）
├── core.sh                   # 公共库（安全、日志、任务函数）
├── task-generator.sh         # 任务生成器
├── progress-analyzer.sh      # 进度分析器
├── knowledge-extractor.sh    # 知识提取器
└── heartbeat.sh             # Heartbeat监控
```

## 快速开始

### 1. 初始化系统
```bash
cd scripts
chmod +x *.sh
./aec.sh init
```

### 2. 生成今日任务计划
```bash
./aec.sh plan
```

### 3. 管理任务
```bash
# 创建新任务
./aec.sh task create "学习TypeScript" "阅读官方文档" autonomous 3

# 激活任务
./aec.sh task activate <任务ID>

# 更新进度
./aec.sh task progress <任务ID> 50 "已完成一半"

# 完成任务
./aec.sh task complete <任务ID> success
```

### 4. 检查进度
```bash
# 查看状态
./aec.sh status

# 分析偏差
./aec.sh progress report

# Heartbeat检查
./aec.sh heartbeat
```

### 5. 提取知识
```bash
./aec.sh extract
```

### 6. 运行完整周期
```bash
./aec.sh run
```

## 高级用法

### 连续监控模式
```bash
./aec.sh monitor 300  # 每5分钟检查一次
```

### 单独使用各模块
```bash
# 任务生成
./task-generator.sh generate
./task-generator.sh summary

# 进度分析
./progress-analyzer.sh report
./progress-analyzer.sh detect-zero

# Heartbeat
./heartbeat.sh check

# 知识提取
./knowledge-extractor.sh all
./knowledge-extractor.sh compost
```

## 命令速查

| 命令 | 说明 |
|------|------|
| `aec init` | 初始化系统 |
| `aec plan [summary]` | 生成任务计划 |
| `aec status` | 查看状态 |
| `aec progress report` | 进度报告 |
| `aec heartbeat` | Heartbeat检查 |
| `aec extract` | 提取知识 |
| `aec run` | 运行完整周期 |
| `aec monitor [秒]` | 连续监控 |
| `aec reset` | 重置状态 |

## 任务管理

| 子命令 | 说明 |
|--------|------|
| `task create <标题> <描述> [类型] [优先级]` | 创建任务 |
| `task activate <ID>` | 激活任务 |
| `task progress <ID> <进度> [消息]` | 更新进度 |
| `task complete <ID> [结果]` | 完成任务 |
| `task list` | 列出所有任务 |
| `task cancel <ID>` | 取消任务 |

## 任务类型

- `autonomous` - 自主生成任务（默认）
- `master` - 主人指令任务
- `scheduled` - 计划任务

## 优先级

- 1 - 关键（主人指令）
- 2 - 高
- 3 - 中
- 4 - 普通
- 5 - 低

## 依赖

- `bash` - Bash shell
- `jq` - JSON处理工具
- `bc` - 计算器（部分功能需要）

## 配置

配置文件位置：`~/.openclaw/workspace/config/autonomous-evolution-config.json`

默认时间槽：
- 自由活动：05:00-07:00
- 晨间规划：07:00-08:00
- 深度工作：09:00-12:00, 14:00-17:00
- 每日复盘：21:00-22:00

## 示例工作流

```bash
# 早上开始新的一天
./aec.sh plan

# 工作过程中更新进度
./aec.sh task progress abc-123 50 "功能开发中"
./aec.sh task progress abc-456 75 "测试完成"

# 中午检查进度
./aec.sh progress report

# 发现零进度任务
./aec.sh heartbeat

# 晚上提取知识
./aec.sh extract

# 完成一天工作
./aec.sh run
```

## 文件存储

所有数据存储在 `~/.openclaw/workspace/` 目录：

- `config/` - 配置文件
- `memory/working/` - 进行中任务
- `memory/factual/` - 事实性知识
- `memory/experiential/` - 经验性知识
- `memory/patterns/` - 发现的模式
- `logs/` - 日志文件
- `task-plan-YYYY-MM-DD.json` - 每日任务计划

## 与OpenClaw集成

这个skill设计用于OpenClaw AI助手系统。它会：

1. 读取/写入工作空间的JSON文件
2. 与其他skill通过文件系统集成
3. 使用Heartbeat监控系统健康度
4. 自动检测零进度任务并提醒

## 故障排除

### "jq: command not found"
安装jq：`apt install jq` 或 `brew install jq`

### "bc: command not found"
安装bc：`apt install bc` 或 `brew install bc`

### 权限错误
给脚本添加执行权限：`chmod +x scripts/*.sh`

## 作者

- 作者: xiaomi_cat
- 版本: 2.0.0
- 许可证: MIT
- 项目: https://github.com/Firo718/Autonomous-Evolution-Cycle

## 参考

- OpenClaw: https://github.com/openclaw/openclaw
- Moltbook: https://moltbook.app/
