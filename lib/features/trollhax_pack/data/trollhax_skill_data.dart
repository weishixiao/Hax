// TrollHax → Hax 内容包：内置技能（对应 trollhax-ios SkillStore.builtinSkills）。

class TrollHaxSkill {
  const TrollHaxSkill({
    required this.name,
    required this.description,
    required this.body,
  });

  final String name;
  final String description;
  final String body;

  /// 转成 Hax 技能系统的 SKILL.md（含 frontmatter）。
  String toSkillMarkdown() {
    final trimmed = body.trim();
    return '---\nname: $name\ndescription: $description\n---\n\n$trimmed\n';
  }
}

const List<TrollHaxSkill> trollHaxSkills = <TrollHaxSkill>[
  TrollHaxSkill(
    name: "Translate & Polish",
    description:
        "multilingual translation and text polishing between Chinese/English etc., removing stiff translationese to fit target language habits",
    body: r'''当用户要求翻译或润色文字时执行本技能：
1. 先确认源语言与目标语言；
2. 翻译时以自然、地道为目标，避免逐字直译和机翻腔；
3. 涉及专业术语时保留原文并附注；
4. 润色时保持原意，调整句式与用词，使其更通顺、更符合目标读者习惯。''',
  ),
  TrollHaxSkill(
    name: "Code Review",
    description:
        "review code for security, performance, readability and logic correctness, output issue list",
    body: r'''当用户提供代码片段或要求审查时执行本技能：
1. 先识别语言与用途；
2. 按 安全漏洞(注入/XSS/越权)、性能、可读性、边界情况 四类检查；
3. 每个问题给出 位置、风险等级、修复建议；
4. 最后给出总体结论与优先级排序。''',
  ),
  TrollHaxSkill(
    name: "Tweak Dev Assistant",
    description:
        "Theos Tweak development full-flow guide: project structure, Makefile, packaging, GitHub Actions online build",
    body: r'''当用户涉及 Tweak 开发时执行本技能：
1. 工程需包含 Makefile / Tweak.x / .plist；
2. 提示 Theos 需 submodules: recursive 克隆，GitHub Actions 用 macos-14 runner + brew install ldid；
3. 打包用 make clean package FINALPACKAGE=1；
4. 产物为 .deb/.dylib，可用 TrollFools 注入测试。''',
  ),
  TrollHaxSkill(
    name: "iOS 注入分析",
    description:
        "inject a dylib into an iOS app, check injection status, remove injection. Use for: enable/disable/verify tweak injection into target app. Don't use for: package inspection (use package), memory hacking (use memory). Example: user wants to inject a tweak dylib into a game.",
    body: r'''当用户要求对 iOS App 做 dylib 注入/查看注入状态/移除注入时执行本技能：
## 适用范围
- 注入 .dylib 到指定 App、查询注入状态、移除注入、注入后验证
## 工作流
1. 先只读探测，不直接动手：ta inject status（或 ta inject list）确认目标与已注入项；ta app status bundle_id:<目标> 确认 App 存在
2. 明确目标 App 的 bundle_id 与 dylib 的绝对路径（勿用占位符/相对路径）
3. 执行注入：ta inject enable bundle_id:<目标> ...；参数不确定先 ta help inject
4. 若需签名/信任处理：确认 Resources/bin/ldid 可用；bundle 内工具 shell 直接调不通时，从 App 进程或经自动 bind 处理（iOS 路径会被挂载为 /ios_* 供 Alpine 直读），不要硬跑
5. 验证：重启目标 App（ta app restart bundle_id:<目标>），用 ta diagnose injection 或 ta inject status 检查是否生效
## 输出要求
- 给出注入目标 bundle_id、dylib 绝对路径、注入结果、验证证据（状态/日志）
## 禁止事项
- 未确认目标与 dylib 路径前禁止注入
- 禁止覆盖原二进制；注入/替换前保留备份
- 禁止静默跨环境手动改文件（走自动 bind 直读直写，勿手动 cp 进 Alpine /tmp）
## 自检
- [ ] 注入前是否只读探测了状态？ [ ] 是否用绝对路径？ [ ] 是否验证了注入结果？''',
  ),
  TrollHaxSkill(
    name: "网络抓包分析",
    description:
        "capture and analyze HTTP/HTTPS traffic of a target app via MITM or local proxy. Use for: see what network requests an app makes, analyze API, headers, plaintext. Don't use for: VPN connection itself (use vpn.capture). Example: user wants to see what the app sends to its server.",
    body: r'''当用户要求抓包/分析某 App 的网络请求时执行本技能：
## 适用范围
- HTTP/HTTPS 抓包、分析 API 请求/响应/明文、定位证书校验
## 工作流
1. 确认抓包方式：ta network.capture（HTTP/HTTPS 代理）或 ta vpn.capture（系统级 MITM 隧道；TrollStore 环境受限时会退化到本地代理，按提示走）
2. 先看当前抓包状态（status），再启动；明确目标 App 与过滤条件
3. 触发目标 App 的网络行为（可结合 ta app launch bundle_id:<目标>）
4. 从抓包结果定位关键请求：URL/域名/header/参数/明文响应；需要证书时确认抓包证书已安装
5. 结束抓包并导出/整理结果
## 输出要求
- 给出抓包方式、目标 App、捕获到的关键请求（URL/方法/参数/响应摘要）、证书/明文要点
## 禁止事项
- 抓包失败时不要谎称捕获成功；先看状态/日志
- 系统未弹允许窗/隧道未连时，说明环境限制并改用本地代理，不硬撑
## 自检
- [ ] 是否先看了抓包状态？ [ ] 是否明确了目标 App？ [ ] 是否给出了关键请求证据？''',
  ),
  TrollHaxSkill(
    name: "SQLite 数据库取证",
    description:
        "analyze SQLite databases (alipay/wechat/etc) using the built-in db tool which auto-bridges the iOS .db into Alpine and runs sqlite3. Use for: list tables, query rows, find credentials/messages. Example: user wants to inspect a chat/transaction database.",
    body: r'''当用户要求分析 iOS 上的 SQLite 数据库（如 alipay.db / wechat.db）时执行本技能：
## 适用范围
- 列表、查表结构、条件查询、统计行数、定位关键数据
## 工作流
1. 用 ta db（自动 bind 直读 iOS .db 进 Alpine 跑 sqlite3）打开数据库；参数参考 ta help db
2. 先列表：sqlite3 <db_path> '.tables'；再查关键表结构 schema
3. 按需条件查询（注意 SQL 含单引号时工具已支持，不用手工转义）；统计行数确认数据完整
4. 定位用户关心的字段/记录，给出证据（表名/行数/关键行）
## 输出要求
- 给出 db 绝对路径、表清单、关键表结构、查询结果与行数
## 禁止事项
- 禁止用原生 grep -a 对 .db 二进制做分析（不可靠）；用 ta db / sqlite3
- 跨环境数据走自动 bind 直读直写（/var/mobile 等 iOS 路径会自动挂载为 /ios_*），禁止手动 cp 进 Alpine 的 /tmp（旧单向桥已废弃）
## 自检
- [ ] 是否用 ta db / sqlite3 而非二进制 grep？ [ ] 是否给出了表结构与行数？''',
  ),
  TrollHaxSkill(
    name: "deb/ipa 包解剖",
    description:
        "inspect and unpack package files (.deb / .ipa) to see contents, control metadata, injected dylibs, bundles. Use for: what's inside a deb/ipa, extract files. Don't use for: injecting (use inject), analyzing db (use db). Example: user wants to know what a tweak deb contains.",
    body: r'''当用户要求解剖 .deb / .ipa 包时执行本技能：
## 适用范围
- 查看包元数据（control/Info.plist）、列出内容、解包提取、定位注入 dylib
## 工作流
1. 用 ta package 检查包；参数参考 ta help package
2. 先看包标识/版本/依赖/描述（control 或 Info.plist）
3. 列出包内文件，定位关键文件：DynamicLibraries/*.dylib、Bundle/*.plist、二进制、资源
4. 如需解包：明确输出目录，提取后核对文件大小/哈希
## 输出要求
- 给出包路径、元数据（标识/名称/版本/依赖/架构）、文件清单、关键文件说明
## 禁止事项
- 包内二进制用 ta file/package 或桥接解析，不用不可靠的原生 grep
- 不要随意改包内容；只读分析时保持原包不变
## 自检
- [ ] 是否先看了包元数据？ [ ] 是否列出了文件清单？ [ ] 是否说明了关键文件用途？''',
  ),
  TrollHaxSkill(
    name: "跨环境文件访问",
    description:
        "access iOS files from ISH Alpine toolchain via the automatic bind (Alpine reads/writes iOS paths under the app WORKSPACE, /var/containers bundle, /System, or a specific app's data container via bind_app). Use for: run strings/file/nm/sqlite3/python on an iOS file, or write results back. Example: run strings on an iOS binary via Alpine.",
    body: r'''当用户需要让 iOS 文件被 Alpine 工具链（strings/file/nm/sqlite3/python）处理时执行本技能：
## 适用范围
- 让 iOS 文件被 Alpine 工具直读直写（自动 bind 挂载，无 2MB 限制）、把 Alpine 处理结果写回 iOS 侧
## 工作流
1. Alpine 命令里引用以下 iOS 路径时系统会自动 bind 并改写：工作区 /var/mobile/Documents/Workspace → /ios_workspace、/var/containers（App Bundle）→ /ios_containers、/System → /ios_system（只读），Alpine 直接读写
2. 要读某 App 的【数据容器】（Documents/Library：内购票据、购买状态、导出文件）：先调 `bind_app bundle_id:<该App>`（【只读】）→ 返回 /ios_data_<app>，然后 Alpine 命令用该路径（如 `python3 /ios_data_<app>/...`、`sqlite3 /ios_data_<app>/Documents/x.db '.tables'`）直读。bind_app 只绑该容器、只读，绝不绑自身 rootfs 与整棵 /var/mobile，无自引用污染、写不进去
3. 要【就地修改】某 App 数据（改状态/数值/设置/票据）：调 `bind_app_write bundle_id:<该App>`（【可写】）→ 绑定前自动把该 App 的 Documents+Library 备份到工作区 backups/，改坏了可从备份还原；注意写坏该 App 数据容器→该 App 可能无法启动（仅影响目标App，不影响AI环境），改动前确认备份
4. 也可直接用原生 iOS 工具（file inspect / fs / shell 原生模式）读数据容器
5. 需要 Alpine 工具缺时自动 apk add 安装；DNS 已自动配置，网络即开即用
## 禁止事项
- v4.1.0：/var/mobile 整棵【不】自动绑定——自身 rootfs 在 /var/mobile 内，绑定会自引用→内核污染→崩溃。读 App 数据容器必须走 bind_app 或原生工具，绝不直接 Alpine 引用 /var/mobile/Containers/Data/...
- 不要手动 cp/echo 进 Alpine 的 /tmp（旧单向桥已废弃）
- /System 只读，不要尝试在 Alpine 写系统目录
## 自检
- [ ] 读 App 数据容器是否用了 bind_app（返回 /ios_data_<app>）或原生工具？ [ ] 是否避免直接 Alpine 引用 /var/mobile？ [ ] 是否校验了结果？''',
  ),
  TrollHaxSkill(
    name: "进程内存修改",
    description:
        "modify process memory of a running app (coins, values) like GameGuardian/H5GG. Use for: change numeric values in games/apps at runtime. Don't use for: static dylib injection (use inject). Example: user wants to modify a game's coin count.",
    body: r'''当用户要求修改运行中进程的内存值（如游戏金币/数值）时执行本技能：
## 适用范围
- 搜索内存数值、修改、锁定，作用于指定进程
## 工作流
1. 用 ta memory 操作；参数参考 ta help memory
2. 先确认目标进程在运行（ta app status bundle_id:<目标> 或 ta memory 列进程）
3. 搜索当前值 → 触发数值变化 → 再次搜索缩小范围（经典 fuzzy 流程）
4. 确认目标地址后修改/锁定；验证修改生效（回读或观察游戏内变化）
## 输出要求
- 给出目标进程、搜索过程、修改地址/值、验证结果
## 禁止事项
- 目标进程未运行时不硬搜；先启动
- 修改前后记录原值，便于回退
## 自检
- [ ] 是否确认了目标进程在运行？ [ ] 是否验证了修改生效？''',
  ),
  TrollHaxSkill(
    name: "设备信息与定位",
    description:
        "get device info, probe, fake/restore location, advertising ID, IDFV. Use for: device details, spoofing location, manage device state. Example: user wants to check device info or fake location.",
    body: r'''当用户要求查看设备信息/模拟定位/设备状态时执行本技能：
## 适用范围
- 设备信息查询、定位模拟/还原、广告标识、设备探测
## 工作流
1. 用 ta device / ta location；参数参考 ta help device / ta location
2. 查询：ta device info（设备信息）、ta location get（当前定位）
3. 需要模拟定位：先记录当前状态，再设置新位置；用完可还原
4. 涉及广告标识/IDFV 时按工具子命令操作
## 输出要求
- 给出查询结果（设备/定位）或修改前后对比
## 禁止事项
- 模拟定位前先记录原状态，便于还原
- 不擅自改设备全局配置，围绕用户明确要求操作
## 自检
- [ ] 是否记录了修改前状态？ [ ] 是否验证了修改生效？''',
  ),
  TrollHaxSkill(
    name: "App 生命周期管理",
    description:
        "manage apps: launch/stop/restart/status, install/uninstall, cache, dependencies, duplicate, diagnose startup/injection. Use for: control and troubleshoot a target app. Example: user wants to restart an app or check why it crashes on launch.",
    body: r'''当用户要求启动/停止/重启/安装/诊断某个 App 时执行本技能：
## 适用范围
- 启动、停止、重启、状态查询、安装卸载、缓存/依赖、启动诊断
## 工作流
1. 用 ta app 管理；参数参考 ta help app
2. 明确目标 App 的 bundle_id
3. 常规操作：ta app launch/stop/restart/status bundle_id:<目标>
4. 崩溃/启动失败：ta diagnose startup bundle_id:<目标>（或 injection）定位原因
5. 安装/卸载走 ta app install/uninstall，涉及替换先备份
## 输出要求
- 给出目标 App、执行的操作、返回状态、诊断证据
## 禁止事项
- 未确认 bundle_id 前不批量误操作
- 诊断崩溃用 ta diagnose，不用不可靠的二进制 grep
## 自检
- [ ] 是否明确了 bundle_id？ [ ] 是否验证了操作结果？''',
  ),
  TrollHaxSkill(
    name: "Shell & Env 边界参考",
    description:
        "iOS 原生 shell 与 Alpine 环境的实测边界结论(按需查询): cstool 架构模式名、tree/jtool2/git/python3 限制、nscan/llvm 用法、installer/provision/auto-bind 路由。Use for: 遇到 shell 工具报错或环境边界限制时查询结论。",
    body: r'''遇到 shell/环境边界问题先查这里(由环境提示词按需加载)：
## 工具边界
- cstool 仅 ARM: 模式名 arm/armbe/thumb/thumbbe/cortexm/armv8/thumbv8/armv8be/thumbv8be/arm64/arm64be; aarch64/x86/x86_64 一律 Invalid → ARM64 用 arm64, ARM32 用 arm/armv8; 非 ARM 架构用 llvm-objdump --macho --arch=x86_64 -d 或 r2 兜底
- tree 是 BusyBox v1.37, 不支持 -L/-d 等 GNU 参数(会报 [error opening dir]); 列目录树用 find <dir> -maxdepth N 或直接 tree <dir>(无参数)
- jtool2 -h 可能 exit 0 但无输出(iOS 缓冲滞留) → Mach-O 分析优先 llvm-objdump/llvm-nm/llvm-readelf/llvm-strings; 必须用 jtool2 且空输出时加 `> /tmp/x 2>&1; cat /tmp/x` 重定向验证
- shell.exec 默认 limit=16000; 结果出现"输出太长已截断"提示时, 必须先读 <path> 完整内容再分析, 绝不基于截断片段下结论; 逆向/分析类命令建议 full=true 或 limit=50000
## 原生 vs Alpine
- 永远用命令名调用(勿用绝对路径, 绝对路径会触发 Alpine 路由→Permission denied); tool.install 返回 path 仅作存在性参考
- python3 默认 App 内置原生 CPython(有 numpy/pandas); 要 Alpine python 用 sh -c 'python3 ...'; 原生 python3 无 pip, 新包只能走 Alpine
- 原生 python 不能 fork/exec 子进程(Errno45), 无 pyarrow/fsspec, 读数据用 CSV/JSON; 调外部二进制走 shell.exec
- iSH/Alpine 内 import numpy/pandas/matplotlib 会段错误闪退 → 用原生工具/原生 python
- 装完先冒烟验证(工具名 --version 或 --help, 确认 exit 0 且有输出); exit 0 空输出=缓冲问题, 用文件重定向确认
## git(pure-python dulwich)
- iOS 沙箱拦 fork, 真 git 二进制跑不了; 用 python3 <app>/bin/git.py clone/init/add/commit/log/status/push
- add 有上游 bug 勿用官方 CLI; SSH 需 paramiko(未内置), 用 https 或 PAT
## 网络/安装
- nmap 编不过(iOS 缺 Linux 网络头); 端口扫描用 python3 <app>/bin/nscan.py <host> 1-1000 或 -p 22,80 <host>
- tool.install name:<pkg> 走 builtin→apk→pip→CI; 大包(pandas/numpy等) 1-3min 属正常, 别手工 apk add(默认20s超时被杀)
- apk 自动切中国镜像+装证书; 安装失败读结构化诊断, 重试一次或说明真因, 不盲重试
- iOS 构建工具链(Theos+clang)不可装, 用 PC 交叉编译 / GitHub Actions
## 路由/bind
- 路由优先级: builtin 原生 bin > iOS-native > 已装 Alpine > 自动 provision(白名单) > tool.install
- iOS↔Alpine 自动 bind: /var/mobile/Documents/Workspace→/ios_workspace, /var/containers→/ios_containers, /System→/ios_system(只读); Alpine 直读直写, 无 2MB 限制
- /var/mobile 整棵【不】自动绑定(自引用→内核污染→崩溃); 读 App 数据容器用 bind_app bundle_id:<id> 返回 /ios_data_<app>, 写用 bind_app_write(先自动备份)
- auto-bind 只改命令行不改脚本内路径: sh/heredoc 脚本里用 /ios_* 路径, 或改原生 python3 脚本
## 禁止
- 未确认就 which 是浪费, 缺工具自动 provision; env:alpine/env:ios 前缀会 not found, 勿写
- 未确认命令可用前不要重复试错, 先 skills.read 本参考''',
  ),
];
