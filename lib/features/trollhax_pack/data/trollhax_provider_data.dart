// TrollHax → Hax 内容包：模型 API 预置供应商。
// 数据来源：trollhax-ios Sources/TrollMCP2/Models.swift（ModelConfig.providerPresets）

/// 一个供应商预设。protocol 决定在 Hax 里落成哪种 ProviderKind。
class TrollHaxProviderPreset {
  const TrollHaxProviderPreset({
    required this.key,
    required this.name,
    required this.baseUrl,
    required this.models,
    required this.description,
    this.protocol = 'openai',
    this.chatPath,
    this.useResponseApi = false,
  });

  /// Hax 的 provider key，已内置的沿用内置 key。
  final String key;
  final String name;
  final String baseUrl;
  final List<String> models;
  final String description;

  /// openai | claude | google
  final String protocol;
  final String? chatPath;
  final bool useResponseApi;
}

const List<TrollHaxProviderPreset> trollHaxProviderPresets =
    <TrollHaxProviderPreset>[
      TrollHaxProviderPreset(
        key: 'OpenAI',
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        models: <String>['gpt-4o-mini', 'gpt-4o'],
        description: 'OpenAI 官方 Chat Completions',
        protocol: 'openai',
        chatPath: '/chat/completions',
      ),
      TrollHaxProviderPreset(
        key: 'DeepSeek',
        name: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com/v1',
        models: <String>['deepseek-chat', 'deepseek-reasoner'],
        description: 'DeepSeek 官方接口',
        protocol: 'openai',
        chatPath: '/chat/completions',
      ),
      TrollHaxProviderPreset(
        key: 'Claude',
        name: 'Anthropic',
        baseUrl: 'https://api.anthropic.com/v1',
        models: <String>['claude-3-5-sonnet-20240620'],
        description: 'Anthropic Messages',
        protocol: 'claude',
      ),
      TrollHaxProviderPreset(
        key: 'Botcf',
        name: 'Botcf',
        baseUrl: 'https://botcf.com/v1',
        models: <String>['gpt-5.6-terra'],
        description: 'TrollHax 默认中转（OpenAI Responses）',
        protocol: 'openai',
        useResponseApi: true,
      ),
      TrollHaxProviderPreset(
        key: 'Zhipu AI',
        name: '智谱GLM',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        models: <String>['glm-4.5'],
        description: '智谱开放平台',
        protocol: 'openai',
        chatPath: '/chat/completions',
      ),
      TrollHaxProviderPreset(
        key: 'Moonshot',
        name: 'Kimi(Moonshot)',
        baseUrl: 'https://api.moonshot.cn/v1',
        models: <String>['kimi-k3'],
        description: '月之暗面 Kimi',
        protocol: 'openai',
        chatPath: '/chat/completions',
      ),
      TrollHaxProviderPreset(
        key: 'Aliyun',
        name: '通义千问(Qwen)',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        models: <String>['qwen3.8-max'],
        description: '阿里云 DashScope 兼容模式',
        protocol: 'openai',
        chatPath: '/chat/completions',
      ),
      TrollHaxProviderPreset(
        key: 'MiniMax',
        name: 'MiniMax',
        baseUrl: 'https://api.minimax.chat/v1',
        models: <String>['MiniMax-Text-01'],
        description: 'MiniMax 开放平台',
        protocol: 'openai',
        chatPath: '/chat/completions',
      ),
      TrollHaxProviderPreset(
        key: 'StepFun',
        name: '阶跃星辰(Step)',
        baseUrl: 'https://api.stepfun.com/v1',
        models: <String>['step-2-mini'],
        description: '阶跃星辰开放平台',
        protocol: 'openai',
        chatPath: '/chat/completions',
      ),
      TrollHaxProviderPreset(
        key: 'ByteDance',
        name: '豆包(火山)',
        baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
        models: <String>['doubao-pro-32k'],
        description: '火山引擎方舟',
        protocol: 'openai',
        chatPath: '/chat/completions',
      ),
    ];
