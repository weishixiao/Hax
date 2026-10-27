import 'package:uuid/uuid.dart';

import '../../core/models/instruction_injection.dart';
import '../../core/models/world_book.dart';
import '../../core/providers/assistant_provider.dart';
import '../../core/providers/instruction_injection_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/world_book_provider.dart';
import '../../core/services/skills/skills_service.dart';
import 'data/trollhax_knowledge_data.dart';
import 'data/trollhax_prompt_data.dart';
import 'data/trollhax_provider_data.dart';
import 'data/trollhax_skill_data.dart';

/// 内容包在 Hax 中落地的分组名。
const String trollHaxModeGroup = 'TrollHax · 模式';
const String trollHaxJailbreakGroup = 'TrollHax · 破甲';
const String trollHaxRouterTitle = '模式自动路由';
const String trollHaxKnowledgeBookName = 'TrollHax 本机知识库';

/// 安装进度快照：已装数量 / 总量。
class TrollHaxPackStatus {
  const TrollHaxPackStatus({
    required this.modes,
    required this.assistants,
    required this.jailbreak,
    required this.skills,
    required this.knowledge,
    required this.providers,
    required this.totalModes,
    required this.totalAssistants,
    required this.totalJailbreak,
    required this.totalSkills,
    required this.totalKnowledge,
    required this.totalProviders,
  });

  final int modes;
  final int assistants;
  final int jailbreak;
  final int skills;
  final int knowledge;
  final int providers;
  final int totalModes;
  final int totalAssistants;
  final int totalJailbreak;
  final int totalSkills;
  final int totalKnowledge;
  final int totalProviders;

  bool get allInstalled =>
      modes >= totalModes &&
      jailbreak >= totalJailbreak &&
      skills >= totalSkills &&
      knowledge >= totalKnowledge;
}

/// 把 TrollHax 的提示词 / 技能 / 知识库 / 模型供应商写入 Hax 的现有存储。
///
/// 全部通过既有 Provider 完成，不新增数据库表：
/// - 模式、破甲提示词、路由 → 指令注入（InstructionInjection）
/// - 技能 → 技能库（SKILL.md）
/// - 知识库 → 世界书（关键词触发的条目）
/// - 供应商 → 模型供应商配置
class TrollHaxPackService {
  TrollHaxPackService({
    required this.injections,
    required this.skills,
    required this.worldBooks,
    required this.settings,
    required this.assistants,
  });

  final InstructionInjectionProvider injections;
  final AssistantProvider assistants;
  final SkillsService skills;
  final WorldBookProvider worldBooks;
  final SettingsProvider settings;

  static const Uuid _uuid = Uuid();

  Set<String> get _injectionTitles =>
      injections.items.map((item) => item.title.trim()).toSet();

  Set<String> get _assistantNames =>
      assistants.assistants.map((a) => a.name.trim()).toSet();

  Set<String> get _skillNames =>
      skills.skills.map((skill) => skill.name.trim()).toSet();

  TrollHaxPackStatus get status {
    final titles = _injectionTitles;
    final names = _skillNames;
    final book = _knowledgeBook;
    return TrollHaxPackStatus(
      modes: trollHaxModes.where((m) => titles.contains(m.name)).length,
      assistants: trollHaxModes
          .where((m) => _assistantNames.contains('TrollHax · ${m.name}'))
          .length,
      jailbreak: trollHaxJailbreakPrompts
          .where((p) => titles.contains(p.title))
          .length,
      skills: trollHaxSkills.where((s) => names.contains(s.name)).length,
      knowledge:
          book?.entries.where((e) => e.name.trim().isNotEmpty).length ?? 0,
      providers: trollHaxProviderPresets
          .where((p) => settings.providerConfigs.containsKey(p.key))
          .length,
      totalModes: trollHaxModes.length,
      totalAssistants: trollHaxModes.length,
      totalJailbreak: trollHaxJailbreakPrompts.length,
      totalSkills: trollHaxSkills.length,
      totalKnowledge: trollHaxKnowledge.length,
      totalProviders: trollHaxProviderPresets.length,
    );
  }

  WorldBook? get _knowledgeBook {
    for (final book in worldBooks.books) {
      if (book.name == trollHaxKnowledgeBookName) return book;
    }
    return null;
  }

  /// 导入六种工作模式 + 自动路由指令，返回新增条数。
  Future<int> installModes() async {
    final existing = _injectionTitles;
    final items = <InstructionInjection>[];
    for (final mode in trollHaxModes) {
      if (existing.contains(mode.name)) continue;
      items.add(
        InstructionInjection(
          id: _uuid.v4(),
          title: mode.name,
          prompt: mode.prompt,
          group: trollHaxModeGroup,
        ),
      );
    }
    if (!existing.contains(trollHaxRouterTitle)) {
      items.add(
        InstructionInjection(
          id: _uuid.v4(),
          title: trollHaxRouterTitle,
          prompt: trollHaxRouterPrompt,
          group: trollHaxModeGroup,
        ),
      );
    }
    await injections.addMany(items);
    return items.length;
  }

  /// 为每种模式创建一个同名助手（= TrollHax 里切换系统指令），返回新增条数。
  Future<int> installModeAssistants() async {
    final existing = assistants.assistants
        .map((assistant) => assistant.name.trim())
        .toSet();
    var installed = 0;
    for (final mode in trollHaxModes) {
      final name = 'TrollHax · ${mode.name}';
      if (existing.contains(name)) continue;
      final id = await assistants.addAssistant(name: name);
      final created = assistants.getById(id);
      if (created == null) continue;
      await assistants.updateAssistant(
        created.copyWith(systemPrompt: mode.prompt),
      );
      installed++;
    }
    return installed;
  }

  /// 导入破甲提示词，返回新增条数。
  Future<int> installJailbreakPrompts() async {
    final existing = _injectionTitles;
    final items = <InstructionInjection>[];
    for (final prompt in trollHaxJailbreakPrompts) {
      if (existing.contains(prompt.title)) continue;
      items.add(
        InstructionInjection(
          id: _uuid.v4(),
          title: prompt.title,
          prompt: prompt.prompt,
          group: trollHaxJailbreakGroup,
        ),
      );
    }
    await injections.addMany(items);
    return items.length;
  }

  /// 导入内置技能，返回新增条数。
  Future<int> installSkills() async {
    await skills.loaded;
    final existing = _skillNames;
    var installed = 0;
    for (final spec in trollHaxSkills) {
      if (existing.contains(spec.name)) continue;
      await skills.importFromText(spec.toSkillMarkdown());
      installed++;
    }
    return installed;
  }

  /// 导入本机知识库（世界书，按关键词触发），返回条目数。
  Future<int> installKnowledge() async {
    final existing = worldBooks.books
        .where((book) => book.name == trollHaxKnowledgeBookName)
        .toList(growable: false);
    for (final book in existing) {
      await worldBooks.deleteBook(book.id);
    }
    final book = WorldBook(
      id: _uuid.v4(),
      name: trollHaxKnowledgeBookName,
      description: 'TrollHax 内置逆向 / 系统 / 工具链知识条目，按关键词自动注入。',
      entries: <WorldBookEntry>[
        for (final entry in trollHaxKnowledge)
          WorldBookEntry(
            id: _uuid.v4(),
            name: entry.title,
            content: entry.content,
            keywords: entry.keywords,
          ),
      ],
    );
    await worldBooks.addBook(book);
    return trollHaxKnowledge.length;
  }

  /// 写入模型供应商预设（不覆盖已填的 Base URL / 名称，只补模型），返回变更条数。
  Future<int> installProviders() async {
    final order = List<String>.from(settings.providersOrder);
    var changed = 0;
    for (final preset in trollHaxProviderPresets) {
      final kind = switch (preset.protocol) {
        'claude' => ProviderKind.claude,
        'google' => ProviderKind.google,
        _ => ProviderKind.openai,
      };
      if (!settings.providerConfigs.containsKey(preset.key)) {
        final base = ProviderConfig.defaultsFor(
          preset.key,
          displayName: preset.name,
        );
        await settings.setProviderConfig(
          preset.key,
          base.copyWith(
            enabled: true,
            name: preset.name,
            baseUrl: preset.baseUrl,
            providerType: kind,
            models: List<String>.from(preset.models),
            chatPath: preset.chatPath,
            useResponseApi: preset.useResponseApi,
          ),
        );
        changed++;
      } else {
        final current = settings.getProviderConfig(preset.key);
        final models = List<String>.from(current.models);
        var touched = false;
        for (final model in preset.models) {
          if (!models.contains(model)) {
            models.add(model);
            touched = true;
          }
        }
        final baseUrl = current.baseUrl.trim().isEmpty
            ? preset.baseUrl
            : current.baseUrl;
        if (touched || baseUrl != current.baseUrl) {
          await settings.setProviderConfig(
            preset.key,
            current.copyWith(models: models, baseUrl: baseUrl),
          );
          changed++;
        }
      }
      if (!order.contains(preset.key)) order.add(preset.key);
    }
    if (order.length != settings.providersOrder.length) {
      await settings.setProvidersOrder(order);
    }
    return changed;
  }

  /// 一键导入全部内容。
  Future<int> installAll() async {
    var total = 0;
    total += await installModes();
    total += await installModeAssistants();
    total += await installJailbreakPrompts();
    total += await installSkills();
    total += await installKnowledge();
    total += await installProviders();
    return total;
  }
}
