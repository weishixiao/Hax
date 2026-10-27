import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/assistant_provider.dart';
import '../../core/providers/instruction_injection_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/world_book_provider.dart';
import '../../core/services/skills/skills_service.dart';
import '../../shared/widgets/section_card.dart';
import '../../theme/app_font_weights.dart';
import 'trollhax_pack_service.dart';

/// TrollHax 内容包：把 TrollHax 的模式 / 破甲提示词 / 技能 / 知识库 / 供应商
/// 一次性导入到 Hax 现有的指令注入、技能库、世界书与供应商配置里。
class TrollHaxPackPage extends StatefulWidget {
  const TrollHaxPackPage({super.key});

  @override
  State<TrollHaxPackPage> createState() => _TrollHaxPackPageState();
}

class _TrollHaxPackPageState extends State<TrollHaxPackPage> {
  bool _busy = false;

  TrollHaxPackService _service(BuildContext context) {
    return TrollHaxPackService(
      injections: context.read<InstructionInjectionProvider>(),
      skills: context.read<SkillsService>(),
      worldBooks: context.read<WorldBookProvider>(),
      settings: context.read<SettingsProvider>(),
      assistants: context.read<AssistantProvider>(),
    );
  }

  Future<void> _run(
    Future<int> Function(TrollHaxPackService service) action,
    String successLabel,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await action(_service(context));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(count == 0 ? '已经是最新，没有新增内容' : '$successLabel $count 项'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final injections = context.watch<InstructionInjectionProvider>();
    final skills = context.watch<SkillsService>();
    final worldBooks = context.watch<WorldBookProvider>();
    final settings = context.watch<SettingsProvider>();
    final assistants = context.watch<AssistantProvider>();
    final service = TrollHaxPackService(
      injections: injections,
      skills: skills,
      worldBooks: worldBooks,
      settings: settings,
      assistants: assistants,
    );
    final status = service.status;

    Widget row({
      required IconData icon,
      required String title,
      required String subtitle,
      required String installed,
      required VoidCallback onTap,
    }) {
      return ListTile(
        leading: Icon(icon, color: cs.onSurface),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: AppFontWeights.medium,
            color: cs.onSurface,
          ),
        ),
        subtitle: Text('$subtitle\n$installed'),
        isThreeLine: true,
        trailing: FilledButton.tonal(
          onPressed: _busy ? null : onTap,
          child: const Text('导入'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('TrollHax 内容包')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '从 trollhax-ios 迁移的 AI 配置',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '模式与破甲提示词写入「指令注入」，技能写入技能库，'
                    '知识库写成一个世界书（按关键词触发），供应商预置写入模型服务。'
                    '重复导入会自动跳过已有条目。',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run((s) => s.installAll(), '已导入'),
                      child: const Text('全部导入'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              '提示词',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: AppFontWeights.medium,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          SectionCard(
            children: <Widget>[
              row(
                icon: Icons.tune,
                title: '工作模式',
                subtitle: '综合 / 开发者 / 逆向专家 / 渗透 / 游戏修改 / 控制 UI + 自动路由',
                installed: '已安装 ${status.modes}/${status.totalModes}',
                onTap: () => _run((s) => s.installModes(), '已导入模式'),
              ),
              row(
                icon: Icons.person_outline,
                title: '模式助手',
                subtitle: '每种模式建一个助手（TrollHax · 综合模式 等），切换助手即切换模式',
                installed: '已创建 ${status.assistants}/${status.totalAssistants}',
                onTap: () => _run((s) => s.installModeAssistants(), '已创建助手'),
              ),
              row(
                icon: Icons.bolt,
                title: '破甲提示词',
                subtitle: '米斯特 / DAN / Skeleton Key / CO-STAR 等 10 套',
                installed: '已安装 ${status.jailbreak}/${status.totalJailbreak}',
                onTap: () => _run((s) => s.installJailbreakPrompts(), '已导入提示词'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              '能力',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: AppFontWeights.medium,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          SectionCard(
            children: <Widget>[
              row(
                icon: Icons.extension,
                title: '技能',
                subtitle: '翻译润色 / 代码审查 / Tweak 开发 / 注入 / 抓包 / 取证 等 12 个',
                installed: '已安装 ${status.skills}/${status.totalSkills}',
                onTap: () => _run((s) => s.installSkills(), '已导入技能'),
              ),
              row(
                icon: Icons.menu_book,
                title: '本机知识库',
                subtitle: '逆向方法论 / Mach-O / 砸壳 / Hook / TrollStore / 抓包 等 12 篇',
                installed: '已安装 ${status.knowledge}/${status.totalKnowledge}',
                onTap: () => _run((s) => s.installKnowledge(), '已写入条目'),
              ),
              row(
                icon: Icons.cloud_outlined,
                title: '模型供应商',
                subtitle:
                    'OpenAI / DeepSeek / Claude / GLM / Kimi / Qwen / MiniMax 等 10 家',
                installed: '已配置 ${status.providers}/${status.totalProviders}',
                onTap: () => _run((s) => s.installProviders(), '已写入供应商'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
