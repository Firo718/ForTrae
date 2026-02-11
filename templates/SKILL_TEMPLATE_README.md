---
name: {{SKILL_NAME}}
version: {{VERSION}}
description: {{DESCRIPTION}}
homepage: {{HOMEPAGE}}
---

# {{DISPLAY_NAME}}

{{SHORT_DESCRIPTION}}

## Core Capabilities

{{CAPABILITIES}}

## Usage Patterns

### Trigger Phrases

{{TRIGGER_PHRASES}}

### Basic Usage

{{BASIC_USAGE}}

### Workflow Example

{{WORKFLOW_EXAMPLE}}

## Integration Points

### Required Skills

{{REQUIRED_SKILLS}}

### Time Slot Integration

{{TIME_SLOT_INTEGRATION}}

## Best Practices

{{BEST_PRACTICES}}

## Error Handling & Recovery

### Common Scenarios

{{ERROR_SCENARIOS}}

### Security Considerations

{{SECURITY_CONSIDERATIONS}}

{{ADDITIONAL_CONTENT}}

---

## 模板使用说明

本模板用于生成符合OpenClaw规范的Skill文件。模板中的占位符说明：

| 占位符 | 说明 | 示例值 |
|--------|------|--------|
| `{{SKILL_NAME}}` | 技能名称（小写字母和连字符） | `task-management` |
| `{{VERSION}}` | 版本号（语义化版本） | `1.0.0` |
| `{{DESCRIPTION}}` | 一句话描述（50-100字） | `帮助用户管理日常任务的技能` |
| `{{HOMEPAGE}}` | 项目主页URL | `https://github.com/...` |
| `{{DISPLAY_NAME}}` | 显示名称（首字母大写） | `Task Management` |
| `{{SHORT_DESCRIPTION}}` | 简短描述（1-2段） | `这个技能帮助用户...` |
| `{{CAPABILITIES}}` | 核心能力列表 | `- 创建任务\n- 编辑任务` |
| `{{TRIGGER_PHRASES}}` | 触发短语列表 | `- `管理任务`\n- `创建任务 {name}` |
| `{{BASIC_USAGE}}` | 基础用法说明（Markdown） | 快速开始、使用示例等 |
| `{{WORKFLOW_EXAMPLE}}` | 工作流示例（Markdown） | 典型使用流程 |
| `{{REQUIRED_SKILLS}}` | 依赖技能列表 | `- agent-memory` |
| `{{TIME_SLOT_INTEGRATION}}` | 时间槽集成说明 | `可在任意时间使用` |
| `{{BEST_PRACTICES}}` | 最佳实践（Markdown） | 使用建议、性能优化等 |
| `{{ERROR_SCENARIOS}}` | 错误场景处理（Markdown） | 常见错误和解决方案 |
| `{{SECURITY_CONSIDERATIONS}}` | 安全考虑（Markdown） | 安全使用建议 |
| `{{ADDITIONAL_CONTENT}}` | 其他补充内容（可选） | 进阶用法、FAQ等 |
