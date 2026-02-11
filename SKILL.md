module.exports = {
  name: 'skill-extractor',
  description: '🧙‍♂️ 从大模型输出中抽取OpenClaw规范skill的自动化工具。支持从文本、文件、URL和对话历史中提取skill结构，自动生成符合OpenClaw规范的SKILL.md文件。',
  homepage: 'https://github.com/Firo718/Autonomous-Evolution-Cycle',
  version: '1.0.0',

  triggers: [
    'extract skill from {content}',
    '从{content}抽取skill',
    '生成OpenClaw技能 {content}',
    '为{content}创建skill',
    'convert {content} to skill',
    'skill抽取 {content}',
    'create skill from {content}',
    'openclaw skill extract'
  ],

  async handler(args, context) {
    const content = args.content || args._raw || '';
    const options = this.parseOptions(args);

    if (!content || content.trim().length < 10) {
      return `📝 请提供要抽取skill的内容。

支持的输入格式：
- 直接输入内容：extract skill from "我需要一个任务管理技能..."
- 从文件抽取：from-file /path/to/file.md
- 从URL抽取：from-url https://example.com/guide
- 从对话历史抽取：from-conversation /path/to/dialogue.json

示例：
"从以下内容抽取skill：该技能用于管理任务，包括创建、编辑、删除任务功能..."`;
    }

    try {
      const result = await this.extractSkill(content, options, context);

      if (result.success) {
        return this.formatSuccessResponse(result, options);
      } else {
        return this.formatErrorResponse(result);
      }
    } catch (error) {
      return `❌ Skill抽取过程中发生错误：${error.message}

请检查：
1. 输入内容是否完整
2. 文件路径是否正确
3. URL是否可访问

如需帮助，请提供更多上下文信息。`;
    }
  },

  parseOptions(args) {
    return {
      type: this.determineInputType(args),
      outputPath: args.output || args.outputPath || null,
      validate: args.validate !== false,
      template: args.template || null
    };
  },

  determineInputType(args) {
    if (args.fromFile || args.file || args.type === 'file') return 'file';
    if (args.fromUrl || args.url || args.type === 'url') return 'url';
    if (args.fromConversation || args.conversation || args.type === 'conversation') return 'conversation';
    return 'text';
  },

  async extractSkill(content, options, context) {
    const skillsDir = this.getSkillsDirectory();
    const extractedContent = await this.loadContent(content, options.type);
    
    if (!extractedContent) {
      return {
        success: false,
        errors: [`无法加载内容，类型：${options.type}`],
        warnings: []
      };
    }

    const structuredData = await this.structureWithLLM(extractedContent, context);
    
    if (!structuredData) {
      return {
        success: false,
        errors: ['LLM抽取失败'],
        warnings: ['尝试使用启发式方法...'],
        fallbackData: await this.structureWithHeuristics(extractedContent)
      };
    }

    const skillFilePath = this.generateSkillFile(structuredData, skillsDir);
    const validation = this.validateSkill(structuredData);

    return {
      success: true,
      skill: structuredData,
      skillFilePath: skillFilePath,
      validation: validation,
      warnings: validation.warnings
    };
  },

  getSkillsDirectory() {
    const envDir = process.env.OPENCLAW_SKILLS_DIR || 
                   process.env.OPENCLAW_WORKSPACE || 
                   `${process.env.HOME}/.openclaw/workspace/skills`;
    return envDir;
  },

  async loadContent(content, type) {
    const fs = require('fs');
    const path = require('path');

    switch (type) {
      case 'file':
      case 'fromFile':
        if (fs.existsSync(content)) {
          return fs.readFileSync(content, 'utf-8');
        }
        return null;

      case 'url':
      case 'fromUrl':
        try {
          const axios = require('axios');
          const response = await axios.get(content);
          const html = response.data || '';
          return html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').substring(0, 10000);
        } catch (error) {
          return null;
        }

      case 'conversation':
      case 'fromConversation':
        if (fs.existsSync(content)) {
          return fs.readFileSync(content, 'utf-8');
        }
        return null;

      default:
        return content;
    }
  },

  async structureWithLLM(content, context) {
    const prompt = this.buildExtractionPrompt(content);

    try {
      let llmResponse;
      
      if (context && context.openclaw) {
        llmResponse = await context.openclaw.agent(prompt);
      } else if (context && context.tools && context.tools.openai) {
        llmResponse = await context.tools.openai.complete(prompt);
      } else {
        return null;
      }

      return this.parseLLMResponse(llmResponse);
    } catch (error) {
      console.error('LLM抽取失败:', error);
      return null;
    }
  },

  buildExtractionPrompt(content) {
    return `你是一个专业的OpenClaw Skill抽取器。请从以下内容中抽取一个符合OpenClaw规范的skill。

OpenClaw Skill规范要求：
1. 每个skill是Markdown文件，以YAML frontmatter开头
2. YAML必须包含：name（技能名）、version（版本）、description（描述）、homepage（主页）
3. 主体是Markdown格式，包含核心能力、用法模式、最佳实践等

请严格按照以下JSON格式输出抽取结果：

{
  "metadata": {
    "name": "技能名称（小写字母和连字符，如：task-management）",
    "version": "版本号（语义化，如：1.0.0）",
    "description": "一句话描述（50-100字）",
    "homepage": "项目主页URL（可为空字符串）"
  },
  "content": {
    "displayName": "显示名称（如：Task Management）",
    "shortDescription": "简短描述（1-2段）",
    "capabilities": ["能力1", "能力2", "能力3"],
    "triggerPhrases": ["触发短语1", "触发短语2"],
    "basicUsage": "基础用法说明（Markdown格式）",
    "workflowExample": "工作流示例（Markdown格式）",
    "requiredSkills": ["依赖技能1", "依赖技能2"],
    "bestPractices": "最佳实践（Markdown格式）",
    "errorScenarios": "常见错误场景和处理（Markdown格式）",
    "securityConsiderations": "安全考虑（Markdown格式）"
  }
}

内容：
${content.substring(0, 8000)}

请只输出JSON，不要有其他内容。`;
  },

  parseLLMResponse(response) {
    try {
      const jsonMatch = response.match(/\{[\s\S]*\}/);
      if (!jsonMatch) return null;

      const parsed = JSON.parse(jsonMatch[0]);
      
      if (!parsed.metadata || !parsed.content) return null;

      return {
        metadata: {
          name: parsed.metadata.name || 'unknown-skill',
          version: parsed.metadata.version || '1.0.0',
          description: parsed.metadata.description || '',
          homepage: parsed.metadata.homepage || ''
        },
        content: {
          displayName: parsed.content.displayName || parsed.metadata.name,
          shortDescription: parsed.content.shortDescription || '',
          capabilities: parsed.content.capabilities || [],
          triggerPhrases: parsed.content.triggerPhrases || [],
          basicUsage: parsed.content.basicUsage || '',
          workflowExample: parsed.content.workflowExample || '',
          requiredSkills: parsed.content.requiredSkills || [],
          bestPractices: parsed.content.bestPractices || '',
          errorScenarios: parsed.content.errorScenarios || '',
          securityConsiderations: parsed.content.securityConsiderations || ''
        }
      };
    } catch (error) {
      return null;
    }
  },

  structureWithHeuristics(content) {
    const skillName = this.inferSkillName(content);
    
    return {
      metadata: {
        name: skillName,
        version: '1.0.0',
        description: this.extractShortDescription(content).substring(0, 100),
        homepage: ''
      },
      content: {
        displayName: this.toTitleCase(skillName),
        shortDescription: this.extractShortDescription(content),
        capabilities: this.extractCapabilities(content),
        triggerPhrases: this.extractTriggerPhrases(content),
        basicUsage: this.generateBasicUsage(skillName),
        workflowExample: this.generateWorkflowExample(skillName),
        requiredSkills: [],
        bestPractices: this.generateBestPractices(),
        errorScenarios: '- 遵循标准错误处理流程',
        securityConsiderations: '遵循OpenClaw安全最佳实践'
      }
    };
  },

  inferSkillName(content) {
    const titleMatch = content.match(/#\s+(.+)/);
    if (titleMatch) {
      return titleMatch[1].toLowerCase()
        .replace(/[^a-z0-9\s-]/g, '')
        .replace(/\s+/g, '-')
        .substring(0, 50);
    }

    const words = content.split(/\s+/).slice(0, 5).join('-').toLowerCase();
    return `skill-${words}`.substring(0, 50);
  },

  extractCapabilities(content) {
    const capabilities = [];
    const patterns = [
      /功能[:：]\s*([^\n]+)/g,
      /能力[:：]\s*([^\n]+)/g,
      /支持[^\n]+/g
    ];

    for (const pattern of patterns) {
      let match;
      while ((match = pattern.exec(content)) !== null) {
        const capability = match[1].trim();
        if (capability.length > 5 && capability.length < 100) {
          capabilities.push(capability);
        }
      }
    }

    return capabilities.slice(0, 5);
  },

  extractTriggerPhrases(content) {
    const phrases = [];
    const patterns = [
      /触发[^\n]*[:：]\s*([^\n]+)/g,
      /使用[^\n]*[:：]\s*([^\n]+)/g
    ];

    for (const pattern of patterns) {
      let match;
      while ((match = pattern.exec(content)) !== null) {
        const phrase = match[1].trim().toLowerCase();
        if (phrase.length > 2 && phrase.length < 50) {
          phrases.push(phrase);
        }
      }
    }

    return [...new Set(phrases)].slice(0, 5);
  },

  extractShortDescription(content) {
    const lines = content.split('\n').filter(l => l.trim());
    
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.length > 20 && trimmed.length < 200 && !trimmed.startsWith('#')) {
        return trimmed;
      }
    }

    return '一个OpenClaw技能';
  },

  toTitleCase(str) {
    return str.split('-').map(word => 
      word.charAt(0).toUpperCase() + word.slice(1)
    ).join(' ');
  },

  generateBasicUsage(skillName) {
    const displayName = this.toTitleCase(skillName);
    return `### 快速开始

\`\`\`bash
# 启用${displayName}
openclaw skill enable ${skillName}

# 查看帮助
openclaw skill help ${skillName}
\`\`\`

### 基础用法

1. 触发技能：按照上述触发词调用
2. 配置参数：根据需要设置选项
3. 执行任务：技能将自动执行所需操作`;
  },

  generateWorkflowExample(skillName) {
    const displayName = this.toTitleCase(skillName);
    return `### 典型工作流

1. **准备阶段**
   - 确定需要${displayName}的场景
   - 收集必要的输入信息

2. **执行阶段**
   - 使用触发短语激活技能
   - 按照提示提供必要信息
   - 技能自动完成操作

3. **验证阶段**
   - 检查执行结果
   - 如有需要，进行调整和重试`;
  },

  generateBestPractices() {
    return `### 最佳实践

1. **明确目标**：在使用技能前，明确你想要达成的目标
2. **提供完整信息**：尽可能提供完整、准确的输入信息
3. **验证结果**：执行后验证结果是否符合预期
4. **及时反馈**：如遇到问题，及时记录和反馈`;
  },

  generateSkillFile(skill, skillsDir) {
    const fs = require('fs');
    const path = require('path');

    const skillDir = path.join(skillsDir, skill.metadata.name);
    const skillFilePath = path.join(skillDir, 'SKILL.md');

    fs.mkdirSync(skillDir, { recursive: true });

    const yamlFrontmatter = `---
name: ${skill.metadata.name}
version: ${skill.metadata.version}
description: ${skill.metadata.description}
homepage: ${skill.metadata.homepage}
---`;

    const markdownContent = `# ${skill.content.displayName}

${skill.content.shortDescription}

## Core Capabilities

${skill.content.capabilities.map(c => `- ${c}`).join('\n')}

## Usage Patterns

### Trigger Phrases
${skill.content.triggerPhrases.map(t => `- \`${t}\``).join('\n')}

### Basic Usage

${skill.content.basicUsage}

### Workflow Example

${skill.content.workflowExample}

## Integration Points

### Required Skills
${skill.content.requiredSkills.length > 0 
  ? skill.content.requiredSkills.map(s => `- ${s}`).join('\n') 
  : '- 无（独立技能）'}

## Best Practices

${skill.content.bestPractices}

## Error Handling & Recovery

### Common Scenarios
${skill.content.errorScenarios}

### Security Considerations
${skill.content.securityConsiderations}`;

    fs.writeFileSync(skillFilePath, `${yamlFrontmatter}\n\n${markdownContent}`, 'utf-8');

    return skillFilePath;
  },

  validateSkill(skill) {
    const errors = [];
    const warnings = [];

    if (!skill.metadata.name || skill.metadata.name.trim() === '') {
      errors.push('缺少name字段');
    } else if (!/^[a-z][a-z0-9-]*$/.test(skill.metadata.name)) {
      errors.push('name必须是小写字母、数字和连字符，且以字母开头');
    }

    if (!skill.metadata.version) {
      errors.push('缺少version字段');
    }

    if (!skill.metadata.description) {
      errors.push('缺少description字段');
    }

    if (skill.content.capabilities.length === 0) {
      warnings.push('未定义capabilities，建议至少添加一项能力描述');
    }

    if (skill.content.triggerPhrases.length === 0) {
      warnings.push('未定义triggerPhrases，建议添加触发短语以便于使用');
    }

    return {
      isValid: errors.length === 0,
      errors,
      warnings
    };
  },

  formatSuccessResponse(result, options) {
    const lines = [
      `✅ **Skill抽取成功！**`,
      ``,
      `📁 **文件位置**: ${result.skillFilePath}`,
      ``
    ];

    if (result.warnings && result.warnings.length > 0) {
      lines.push(`⚠️ **警告**:`);
      result.warnings.forEach(w => lines.push(`  - ${w}`));
      lines.push(``);
    }

    lines.push(`📝 **Skill信息**:`);
    lines.push(`- 名称: ${result.skill.metadata.name}`);
    lines.push(`- 版本: ${result.skill.metadata.version}`);
    lines.push(`- 描述: ${result.skill.metadata.description}`);
    lines.push(``);

    if (result.skill.content.capabilities.length > 0) {
      lines.push(`🎯 **核心能力**:`);
      result.skill.content.capabilities.forEach(c => lines.push(`  - ${c}`));
      lines.push(``);
    }

    lines.push(`📌 **触发词示例**:`);
    result.skill.content.triggerPhrases.slice(0, 3).forEach(t => lines.push(`  - \`${t}\``));
    lines.push(``);

    lines.push(`🔗 **使用方法**:直接将生成的SKILL.md文件复制到OpenClaw skills目录即可使用。`);
    lines.push(``);
    lines.push(`目录路径: ~/.openclaw/workspace/skills/${result.skill.metadata.name}/`);

    return lines.join('\n');
  },

  formatErrorResponse(result) {
    const lines = [
      `❌ **Skill抽取失败**`,
      ``
    ];

    if (result.errors && result.errors.length > 0) {
      lines.push(`**错误原因**:`, ...result.errors.map(e => `  - ${e}`));
      lines.push(``);
    }

    if (result.warnings && result.warnings.includes('尝试使用启发式方法...')) {
      lines.push(`💡 **提示**: LLM抽取失败，已尝试使用启发式方法。请检查生成的结果是否符合预期。`);
      lines.push(``);
    }

    lines.push(`**建议**:`);
    lines.push(`1. 检查输入内容是否完整`);
    lines.push(`2. 尝试提供更详细的需求描述`);
    lines.push(`3. 或手动编辑生成的SKILL.md文件`);

    return lines.join('\n');
  }
};
