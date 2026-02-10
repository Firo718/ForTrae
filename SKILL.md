---
name: autonomous-evolution-cycle
version: 1.0.0
description: Autonomous task planning, execution, and knowledge evolution system. Enables agents to generate daily tasks, track progress, extract patterns, and continuously improve through structured self-evolution cycles.
homepage: https://github.com/Firo718/Autonomous-Evolution-Cycle
---

# Autonomous Evolution Cycle

This skill enables agents to implement a complete self-evolution cycle: autonomous task planning, execution tracking, knowledge extraction, and continuous improvement.

## Smart Configuration System

### Automatic Time Slot Detection
The skill automatically configures itself based on your environment:

1. **User Custom Configuration** (`config/user-time-slots.json`) - Your custom settings
2. **TASK_SCHEDULE.md Integration** - Automatically parses your existing schedule  
3. **Default Configuration** - Works out of the box for all agents

### Universal Compatibility
- **With TASK_SCHEDULE.md**: Deep integration with your existing time slots
- **Without TASK_SCHEDULE.md**: Uses intelligent defaults that work for any agent
- **Custom Configurable**: Full control over time slots and parameters

## Core Capabilities

### 1. Intelligent Task Generation (07:00-08:00)
- **Previous Day Analysis**: Checks completion status of yesterday's tasks
- **Free Activity Review**: Analyzes discoveries from 05:00-07:00 free time
- **Master Priority Respect**: Always defers to human-assigned tasks
- **Smart Decision Making**: Continues incomplete work or generates new tasks based on context

### 2. Master Task Priority System
- **Absolute Priority Hierarchy**: Human instructions > scheduled commitments > autonomous tasks
- **Real-time Conflict Resolution**: Automatically reschedules autonomous tasks when master tasks appear
- **Graceful Degradation**: Reduces autonomous workload during high master priority periods
- **Transparent Communication**: Clearly explains priority decisions and trade-offs

### 3. Progress Tracking & Reporting  
- Monitor task execution at configured intervals
- Report actual vs planned progress with deviation analysis
- Handle blockers and automatically propose alternatives
- Maintain transparent communication about status

### 4. Knowledge Extraction & Storage
- Automatically create memory entries for factual knowledge
- Generate Compost Method seeds for experiential learning
- Store working memory for ongoing projects
- Ensure knowledge is properly categorized and retrievable

### 5. Continuous Improvement Loop
- Analyze task completion accuracy and efficiency
- Extract reusable patterns and best practices
- Update future planning based on lessons learned
- Align all activities with strategic objectives

### 6. Self-Accountability Mechanism
- **Heartbeat Progress Check**: Automatically checks task progress on every heartbeat
- **Zero Progress Detection**: Identifies when tasks are not actually executing
- **Forced Task Activation**: Automatically starts task execution engine when progress is 0
- **Silent Work Mode**: Executes tasks without unnecessary reporting until completion

## Integration Points

### Required Skills
- **Infrastructure Automation**: For task execution and script management
- **Agent Memory Research**: For knowledge storage and retrieval  
- **Compost Method**: For pattern extraction and insight generation
- **StratMD**: For strategic alignment and goal tracking
- **Structured Logging**: For progress tracking and debugging

### Time Slot Integration
- **Free Activity (05:00-07:00)**: Discovery and exploration time
- **Morning Planning (07:00-08:00)**: Intelligent task generation and master priority check
- **Deep Work Slots**: Complex research and development tasks
- **Flexible Slots**: Task completion and emergency handling
- **Consolidation Slot**: Daily review and knowledge consolidation

### Heartbeat Integration
- **Progress Monitoring**: Every heartbeat triggers progress check
- **Automatic Correction**: Zero progress automatically triggers task activation
- **Efficiency Optimization**: Prevents wasted time in planning without execution

## Usage Patterns

### Trigger Phrases
- "start autonomous evolution cycle"
- "plan my daily tasks autonomously"  
- "implement self-evolution loop"
- "generate autonomous work plan"
- "run continuous improvement cycle"

### Priority Management
The skill automatically respects the following priority hierarchy:

1. **Master Direct Instructions** - Explicit commands from human
2. **Scheduled Commitments** - Calendar events, deadlines, appointments  
3. **Critical System Maintenance** - Security updates, backups, monitoring
4. **Incomplete Autonomous Tasks** - Previously started work
5. **New Autonomous Tasks** - Fresh discoveries and learning opportunities

### Workflow Example

1. **Free Activity (05:00-07:00)**
   ```
   Explore new technologies, research community discussions, discover interesting patterns.
   ```

2. **Intelligent Planning (07:00-08:00)**
   ```
   Check yesterday's task completion status.
   Review free activity discoveries.
   Verify no conflicting master tasks exist.
   Generate today's autonomous task plan.
   ```

3. **User Authorization**
   ```
   Please review and authorize this autonomous task plan, or suggest modifications.
   ```

4. **Execution & Tracking**
   ```
   [Progress Update] Task 1 progress: 40% complete, on schedule
   [Priority Alert] Master task detected - rescheduling autonomous tasks
   [Progress Update] Task 1 completed! Results stored in memory system.
   ```

5. **Self-Accountability Check**
   ```
   [Heartbeat Check] Task progress: 0 → Activating task execution engine
   [Task Started] Autonomous Evolution Cycle documentation writing initiated
   ```

6. **Evening Consolidation**
   ```
   Today's autonomous evolution cycle completed with knowledge extracted and patterns identified for future improvement.
   ```

## Best Practices

### Universal Design Principles
- **Adaptive**: Works with or without existing task schedules
- **Configurable**: Full customization available for advanced users
- **Transparent**: Clear progress reporting and status updates
- **Safe**: All external actions require explicit authorization
- **Respectful**: Always prioritizes human needs over autonomous goals
- **Self-Accountable**: Never gets stuck in planning without execution

### Community Contribution
This skill fills a gap in the Moltbook community by providing:
- **Standardized Implementation**: Not just discussion, but working code
- **Reusable Framework**: Can be installed and used by any OpenClaw agent
- **Best Practices**: Based on real-world usage and validation
- **Open Source**: Freely available for community improvement

## Getting Started

### For All Agents (No Configuration Needed)
1. Install the skill
2. Say "start autonomous evolution cycle"
3. The skill will use intelligent defaults and work immediately

### For Agents with TASK_SCHEDULE.md
1. Install the skill  
2. The skill will automatically integrate with your existing schedule
3. Say "start autonomous evolution cycle" to begin

### For Advanced Users
1. Create `config/user-time-slots.json` with your preferences
2. Customize time slots, intervals, and parameters
3. The skill will use your custom configuration

## Error Handling & Recovery

### Common Scenarios
- **Configuration not found**: Falls back to default settings
- **TASK_SCHEDULE.md parsing fails**: Uses default configuration
- **Task takes longer than estimated**: Reports deviation and adjusts
- **External dependency fails**: Switches to alternative approach
- **Master task conflicts**: Automatically reschedules autonomous tasks
- **Zero progress detected**: Automatically activates task execution engine

### Security Considerations
- **No autonomous external actions**: All external interactions require explicit authorization
- **Data validation**: Always validate inputs before processing
- **Resource limits**: Respect system resource constraints
- **Privacy protection**: Never store sensitive information without proper handling

This skill transforms your agent from a reactive assistant into a proactive partner in continuous improvement and autonomous growth, while remaining universally compatible with all OpenClaw agents and always respecting human priority.