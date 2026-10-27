import Darwin
import Flutter
import Foundation
import UIKit

/// 设备级能力桥接（越狱探测 / 应用进程 / 内存 / 注入）。
///
/// 设计原则：所有能力先探测再执行，缺权限时返回结构化错误而不是崩溃。
/// 通道：app.device_ops
final class DeviceOpsPlugin {
  static let channelName = "app.device_ops"

  static func register(messenger: FlutterBinaryMessenger) -> DeviceOpsPlugin {
    let plugin = DeviceOpsPlugin()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      plugin.handle(call, result: result)
    }
    return plugin
  }

  private let queue = DispatchQueue(label: "app.device_ops", qos: .userInitiated)

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = (call.arguments as? [String: Any]) ?? [:]
    switch call.method {
    case "probe":
      result(probe())
    case "listApps":
      queue.async { Self.finish(self.listApps(), result: result) }
    case "listProcesses":
      queue.async { Self.finish(Self.listProcesses(), result: result) }
    case "kill":
      queue.async { Self.finish(Self.killApp(args: args), result: result) }
    case "memSearch":
      queue.async { Self.finish(Self.memSearch(args: args), result: result) }
    case "memWrite":
      queue.async { Self.finish(Self.memWrite(args: args), result: result) }
    case "inject":
      queue.async { Self.finish(Self.inject(args: args), result: result) }
    case "bundleInfo":
      queue.async { Self.finish(Self.bundleInfo(args: args), result: result) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func finish(_ payload: Any, result: @escaping FlutterResult) {
    DispatchQueue.main.async { result(payload) }
  }

  // MARK: - 环境探测

  private func probe() -> [String: Any] {
    let fm = FileManager.default
    let roots = ["/var/jb", "/usr/bin/sbreload", "/Applications/Sileo.app", "/usr/libexec/sileo"]
    let jailbroken = roots.contains { fm.fileExists(atPath: $0) }
    let trollstore = fm.fileExists(
      atPath: "/var/mobile/Library/Application Support/com.opa334.TrollStore"
    ) || fm.fileExists(atPath: "/Applications/TrollStore.app")
    return [
      "jailbroken": jailbroken,
      "rootless": fm.fileExists(atPath: "/var/jb"),
      "trollstore": trollstore,
      "platformApplication": Self.hasPlatformEntitlement(),
      "canTaskForPid": Self.canTaskForPid(),
      "uid": getuid(),
      "sandbox": NSHomeDirectory(),
      "device": UIDevice.current.model,
      "systemVersion": UIDevice.current.systemVersion,
      "ldid": Self.ldidPath() ?? "",
    ]
  }

  /// 二进制里是否带 platform-application（越狱 / TrollStore 签名后可见）。
  private static func hasPlatformEntitlement() -> Bool {
    guard let path = Bundle.main.executablePath,
      let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
    else {
      return false
    }
    return data.range(of: Data("platform-application".utf8)) != nil
  }

  /// 能否拿到别的进程（launchd）的 task port —— 这是越狱权限的实际判据。
  private static func canTaskForPid() -> Bool {
    var task: mach_port_t = 0
    let kr = task_for_pid(mach_task_self_, 1, &task)
    if task != 0 { mach_port_deallocate(mach_task_self_, task) }
    return kr == KERN_SUCCESS
  }

  private static func ldidPath() -> String? {
    let candidates = ["/var/jb/usr/bin/ldid", "/usr/bin/ldid", "/var/jb/usr/local/bin/ldid"]
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
  }

  // MARK: - 应用 / 进程

  private func listApps() -> [[String: Any]] {
    var apps: [[String: Any]] = []
    if let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type {
      let workspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?
        .takeUnretainedValue()
      if let ws = workspace as? NSObject,
        let list = ws.perform(NSSelectorFromString("allInstalledApplications"))?
          .takeUnretainedValue() as? [NSObject]
      {
        for proxy in list {
          var item: [String: Any] = [:]
          if let bundleId = proxy.perform(NSSelectorFromString("applicationIdentifier"))?
            .takeUnretainedValue() as? String
          {
            item["bundleId"] = bundleId
          }
          if let name = proxy.perform(NSSelectorFromString("localizedName"))?
            .takeUnretainedValue() as? String
          {
            item["name"] = name
          }
          if let url = proxy.perform(NSSelectorFromString("bundleURL"))?
            .takeUnretainedValue() as? URL
          {
            item["path"] = url.path
          }
          if !item.isEmpty { apps.append(item) }
        }
      }
    }
    if apps.isEmpty {
      let searchRoots = ["/Applications", "/var/jb/Applications", "/var/containers/Bundle/Application"]
      for root in searchRoots {
        guard let children = try? FileManager.default.contentsOfDirectory(atPath: root) else {
          continue
        }
        for child in children {
          let path = (root as NSString).appendingPathComponent(child)
          if !path.hasSuffix(".app") { continue }
          let infoPath = (path as NSString).appendingPathComponent("Info.plist")
          guard let info = NSDictionary(contentsOfFile: infoPath) else { continue }
          apps.append([
            "bundleId": (info["CFBundleIdentifier"] as? String) ?? child,
            "name": (info["CFBundleDisplayName"] as? String)
              ?? (info["CFBundleName"] as? String)
              ?? child,
            "path": path,
          ])
        }
      }
    }
    return apps.sorted {
      let a = ($0["name"] as? String) ?? ""
      let b = ($1["name"] as? String) ?? ""
      return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
    }
  }

  // iOS SDK 不带 libproc.h，运行时用 dlsym 取符号。
  private typealias ProcListAllPidsFn = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Int32
  private typealias ProcPidPathFn = @convention(c) (Int32, UnsafeMutableRawPointer?, UInt32) -> Int32

  private static let libprocHandle: UnsafeMutableRawPointer? =
    dlopen("/usr/lib/libproc.dylib", RTLD_LAZY) ?? dlopen(nil, RTLD_LAZY)

  private static func listProcesses() -> [[String: Any]] {
    guard let handle = libprocHandle,
      let listSym = dlsym(handle, "proc_listallpids"),
      let pathSym = dlsym(handle, "proc_pidpath")
    else { return [] }
    let listFn = unsafeBitCast(listSym, to: ProcListAllPidsFn.self)
    let pathFn = unsafeBitCast(pathSym, to: ProcPidPathFn.self)

    let maxCount = 4096
    var pids = [pid_t](repeating: 0, count: maxCount)
    let bytes = pids.withUnsafeMutableBytes { raw -> Int32 in
      listFn(raw.baseAddress, Int32(maxCount * MemoryLayout<pid_t>.size))
    }
    guard bytes > 0 else { return [] }
    let count = Int(bytes) / MemoryLayout<pid_t>.size

    var out: [[String: Any]] = []
    var buffer = [CChar](repeating: 0, count: 4096)
    for index in 0..<count {
      let pid = pids[index]
      if pid <= 0 { continue }
      let len = buffer.withUnsafeMutableBytes { raw -> Int32 in
        pathFn(pid, raw.baseAddress, UInt32(raw.count))
      }
      let path = len > 0 ? String(cString: buffer) : ""
      let name = path.isEmpty ? "" : (path as NSString).lastPathComponent
      out.append(["pid": Int(pid), "name": name, "path": path])
    }
    return out.sorted { (($0["name"] as? String) ?? "") < (($1["name"] as? String) ?? "") }
  }

  private static func killApp(args: [String: Any]) -> [String: Any] {
    guard let pid = (args["pid"] as? NSNumber)?.int32Value, pid > 0 else {
      return ["error": "missing pid"]
    }
    let r = kill(pid, SIGKILL)
    if r == 0 { return ["ok": true, "pid": Int(pid)] }
    return ["error": String(cString: strerror(errno)), "errno": Int(errno)]
  }

  private static func bundleInfo(args: [String: Any]) -> [String: Any] {
    guard let path = args["path"] as? String else { return ["error": "missing path"] }
    let infoPath = (path as NSString).appendingPathComponent("Info.plist")
    guard let info = NSDictionary(contentsOfFile: infoPath) else {
      return ["error": "Info.plist 不可读（沙盒限制或无权限）"]
    }
    var result: [String: Any] = [
      "path": path,
      "bundleId": (info["CFBundleIdentifier"] as? String) ?? "",
      "name": (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? "",
      "version": (info["CFBundleShortVersionString"] as? String) ?? "",
      "executable": (info["CFBundleExecutable"] as? String) ?? "",
    ]
    let frameworks = (path as NSString).appendingPathComponent("Frameworks")
    if let files = try? FileManager.default.contentsOfDirectory(atPath: frameworks) {
      result["frameworks"] = files
    }
    return result
  }

  // MARK: - 内存（mach_vm_* 用 dlsym 取，避免依赖 SDK 头文件）

  private typealias MachVmRegionFn = @convention(c) (
    UInt32, UnsafeMutablePointer<UInt64>, UnsafeMutablePointer<UInt64>, Int32,
    UnsafeMutablePointer<Int32>?, UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<UInt32>?
  ) -> Int32
  private typealias MachVmReadOverwriteFn = @convention(c) (
    UInt32, UInt64, UInt64, UInt64, UnsafeMutablePointer<UInt64>
  ) -> Int32
  private typealias MachVmWriteFn = @convention(c) (
    UInt32, UInt64, UInt, UInt32
  ) -> Int32

  private static let kernelHandle: UnsafeMutableRawPointer? =
    dlopen("/usr/lib/system/libsystem_kernel.dylib", RTLD_LAZY) ?? dlopen(nil, RTLD_LAZY)

  private static func machVmRegion() -> MachVmRegionFn? {
    guard let h = kernelHandle, let sym = dlsym(h, "mach_vm_region") else { return nil }
    return unsafeBitCast(sym, to: MachVmRegionFn.self)
  }

  private static func machVmReadOverwrite() -> MachVmReadOverwriteFn? {
    guard let h = kernelHandle, let sym = dlsym(h, "mach_vm_read_overwrite") else { return nil }
    return unsafeBitCast(sym, to: MachVmReadOverwriteFn.self)
  }

  private static func machVmWrite() -> MachVmWriteFn? {
    guard let h = kernelHandle, let sym = dlsym(h, "mach_vm_write") else { return nil }
    return unsafeBitCast(sym, to: MachVmWriteFn.self)
  }

  private static func memSearch(args: [String: Any]) -> [String: Any] {
    guard let pid = (args["pid"] as? NSNumber)?.int32Value, pid > 0 else {
      return ["error": "missing pid"]
    }
    guard let value = (args["value"] as? NSNumber)?.int64Value else {
      return ["error": "missing value"]
    }
    let width = (args["width"] as? NSNumber)?.intValue ?? 8
    let limit = (args["limit"] as? NSNumber)?.intValue ?? 64
    guard let regionFn = machVmRegion(), let readFn = machVmReadOverwrite() else {
      return ["error": "mach_vm 符号不可用"]
    }

    var task: mach_port_t = 0
    let kr = task_for_pid(mach_task_self_, pid, &task)
    guard kr == KERN_SUCCESS, task != 0 else {
      return ["error": "task_for_pid 失败：需要越狱 + task_for_pid-allow 权限", "code": Int(kr)]
    }
    defer { mach_port_deallocate(mach_task_self_, task) }

    var hits: [[String: Any]] = []
    var address: UInt64 = 0
    var guardCounter = 0
    while hits.count < limit && guardCounter < 20000 {
      guardCounter += 1
      var size: UInt64 = 0
      var info = [Int32](repeating: 0, count: 64)
      var infoCount: UInt32 = 64
      var objectName: UInt32 = 0
      let query = regionFn(task, &address, &size, 9, &info, &infoCount, &objectName)
      if query != 0 || size == 0 { break }
      let writable = (info[0] & 0x2) != 0  // VM_PROT_WRITE
      if writable && size <= 16 * 1024 * 1024 {
        hits.append(
          contentsOf: scanRegion(
            readFn: readFn,
            task: task,
            start: address,
            size: size,
            value: value,
            width: width,
            limit: limit - hits.count
          )
        )
      }
      address += size
    }
    return ["hits": hits, "count": hits.count]
  }

  private static func scanRegion(
    readFn: MachVmReadOverwriteFn,
    task: mach_port_t,
    start: UInt64,
    size: UInt64,
    value: Int64,
    width: Int,
    limit: Int
  ) -> [[String: Any]] {
    guard size > 0, limit > 0 else { return [] }
    var buffer = [UInt8](repeating: 0, count: Int(size))
    var outSize: UInt64 = 0
    let kr = buffer.withUnsafeMutableBytes { raw -> Int32 in
      guard let base = raw.baseAddress else { return -1 }
      return readFn(task, start, size, UInt64(UInt(bitPattern: base)), &outSize)
    }
    guard kr == 0, outSize >= UInt64(width) else { return [] }

    var hits: [[String: Any]] = []
    let step = max(width, 1)
    var offset = 0
    let total = Int(outSize)
    while offset + width <= total && hits.count < limit {
      var candidate: Int64 = 0
      if width == 4 {
        let raw = UInt32(buffer[offset])
          | (UInt32(buffer[offset + 1]) << 8)
          | (UInt32(buffer[offset + 2]) << 16)
          | (UInt32(buffer[offset + 3]) << 24)
        candidate = Int64(Int32(bitPattern: raw))
      } else if width == 2 {
        let raw = UInt16(buffer[offset]) | (UInt16(buffer[offset + 1]) << 8)
        candidate = Int64(Int16(bitPattern: raw))
      } else {
        var raw: UInt64 = 0
        for i in 0..<8 { raw |= UInt64(buffer[offset + i]) << (8 * UInt64(i)) }
        candidate = Int64(bitPattern: raw)
      }
      if candidate == value {
        hits.append(["address": start + UInt64(offset), "value": candidate])
      }
      offset += step
    }
    return hits
  }

  private static func memWrite(args: [String: Any]) -> [String: Any] {
    guard let pid = (args["pid"] as? NSNumber)?.int32Value, pid > 0,
      let address = (args["address"] as? NSNumber)?.uint64Value,
      let value = (args["value"] as? NSNumber)?.int64Value
    else {
      return ["error": "missing pid/address/value"]
    }
    let width = (args["width"] as? NSNumber)?.intValue ?? 8
    guard let writeFn = machVmWrite() else { return ["error": "mach_vm_write 符号不可用"] }
    var task: mach_port_t = 0
    let kr = task_for_pid(mach_task_self_, pid, &task)
    guard kr == KERN_SUCCESS, task != 0 else {
      return ["error": "task_for_pid 失败：需要越狱权限", "code": Int(kr)]
    }
    defer { mach_port_deallocate(mach_task_self_, task) }

    var data = [UInt8](repeating: 0, count: width)
    let bits = UInt64(bitPattern: value)
    for i in 0..<width { data[i] = UInt8((bits >> (8 * UInt64(i))) & 0xFF) }
    let result = data.withUnsafeMutableBytes { raw -> Int32 in
      guard let base = raw.baseAddress else { return -1 }
      return writeFn(task, address, UInt(UInt(bitPattern: base)), UInt32(width))
    }
    if result == 0 { return ["ok": true] }
    return ["error": "写入失败", "code": Int(result)]
  }

  // MARK: - 注入

  private static func inject(args: [String: Any]) -> [String: Any] {
    guard let bundlePath = args["bundlePath"] as? String,
      let dylibPath = args["dylibPath"] as? String
    else {
      return ["error": "missing bundlePath/dylibPath"]
    }
    let fm = FileManager.default
    guard fm.fileExists(atPath: bundlePath), fm.fileExists(atPath: dylibPath) else {
      return ["error": "bundle 或 dylib 不存在"]
    }
    let infoPath = (bundlePath as NSString).appendingPathComponent("Info.plist")
    guard let info = NSDictionary(contentsOfFile: infoPath),
      let executable = info["CFBundleExecutable"] as? String
    else {
      return ["error": "Info.plist 不可读"]
    }
    let frameworksDir = (bundlePath as NSString).appendingPathComponent("Frameworks")
    try? fm.createDirectory(atPath: frameworksDir, withIntermediateDirectories: true)
    let dylibName = (dylibPath as NSString).lastPathComponent
    let targetDylib = (frameworksDir as NSString).appendingPathComponent(dylibName)
    do {
      if fm.fileExists(atPath: targetDylib) { try fm.removeItem(atPath: targetDylib) }
      try fm.copyItem(atPath: dylibPath, toPath: targetDylib)
    } catch {
      return ["error": "拷贝 dylib 失败：\(error.localizedDescription)"]
    }

    let binaryPath = (bundlePath as NSString).appendingPathComponent(executable)
    let loadPath = "@executable_path/Frameworks/\(dylibName)"
    var steps: [String] = ["已拷贝 \(dylibName) → Frameworks"]

    switch MachOPatcher.addLoadDylib(at: binaryPath, dylibPath: loadPath) {
    case .success:
      steps.append("已写入 LC_LOAD_DYLIB：\(loadPath)")
    case .alreadyPresent:
      steps.append("LC_LOAD_DYLIB 已存在，跳过")
    case .failure(let message):
      return ["error": "Mach-O 写入失败：\(message)", "steps": steps]
    }

    if let ldid = ldidPath() {
      let code = runTask(ldid, args: ["-S", binaryPath])
      steps.append(code == 0 ? "ldid 重签成功" : "ldid 重签失败（exit \(code)）")
    } else {
      steps.append("未找到 ldid，需要自行重签后才能启动")
    }
    return ["ok": true, "steps": steps, "binary": binaryPath, "dylib": targetDylib]
  }

  private static func runTask(_ executable: String, args: [String]) -> Int32 {
    var pid: pid_t = 0
    var argv: [UnsafeMutablePointer<CChar>?] = ([executable] + args).map { strdup($0) }
    argv.append(nil)
    defer {
      for pointer in argv where pointer != nil { free(pointer) }
    }
    let spawned = posix_spawn(&pid, executable, nil, nil, &argv, environ)
    guard spawned == 0 else { return -1 }
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    return (status & 0x7F) == 0 ? (status >> 8) & 0xFF : -1
  }
}

/// 最小 Mach-O 载入命令编辑器：向 __TEXT 头部空余空间追加 LC_LOAD_DYLIB。
enum MachOPatcher {
  enum Result {
    case success
    case alreadyPresent
    case failure(String)
  }

  static func addLoadDylib(at binaryPath: String, dylibPath: String) -> Result {
    guard let handle = FileHandle(forUpdatingAtPath: binaryPath) else {
      return .failure("无法打开二进制（需要写权限）")
    }
    defer { try? handle.close() }
    guard let header = try? handle.read(upToCount: 32), header.count == 32 else {
      return .failure("读取头部失败")
    }
    let head = [UInt8](header)
    guard u32(head, 0) == 0xFEEDFACF else {
      return .failure("不是 64 位 thin Mach-O（fat / 加密二进制需先处理）")
    }
    let ncmds = u32(head, 16)
    let sizeofcmds = u32(head, 20)
    guard ncmds > 0, sizeofcmds > 0, sizeofcmds < 4 * 1024 * 1024 else {
      return .failure("Load commands 尺寸异常")
    }
    try? handle.seek(toOffset: 32)
    guard let cmdData = try? handle.read(upToCount: Int(sizeofcmds)),
      cmdData.count == Int(sizeofcmds)
    else {
      return .failure("读取 load commands 失败")
    }
    let cmds = [UInt8](cmdData)

    var offset = 0
    var firstSectionOffset: UInt32 = 0
    for _ in 0..<ncmds {
      guard offset + 8 <= cmds.count else { break }
      let cmd = u32(cmds, offset)
      let size = u32(cmds, offset + 4)
      if size == 0 { break }
      if cmd == 0x19 && offset + 72 <= cmds.count {
        let fileoff = u64(cmds, offset + 40)
        if fileoff == 0 && u32(cmds, offset + 64) > 0 && offset + 72 + 52 <= cmds.count {
          firstSectionOffset = u32(cmds, offset + 72 + 48)
        }
      } else if cmd == 0xC {
        let nameOffset = u32(cmds, offset + 8)
        let start = offset + Int(nameOffset)
        let end = offset + Int(size)
        if start < end, end <= cmds.count,
          let name = String(bytes: cmds[start..<end], encoding: .utf8)
        {
          if name.hasPrefix(dylibPath) { return .alreadyPresent }
        }
      }
      offset += Int(size)
    }

    let pathBytes = Array(dylibPath.utf8) + [0]
    let rawSize = 24 + pathBytes.count
    let aligned = (rawSize + 7) & ~7
    let headerEnd = 32 + Int(sizeofcmds)
    let limit = firstSectionOffset > 0 ? Int(firstSectionOffset) : headerEnd
    guard limit - headerEnd >= aligned else {
      return .failure("头部空余不足（需要 \(aligned) 字节，只剩 \(limit - headerEnd)）")
    }

    var command = [UInt8]()
    command.append(contentsOf: bytes32(0xC))
    command.append(contentsOf: bytes32(UInt32(aligned)))
    command.append(contentsOf: bytes32(24))
    command.append(contentsOf: bytes32(2))
    command.append(contentsOf: bytes32(0x10000))
    command.append(contentsOf: bytes32(0x10000))
    command.append(contentsOf: pathBytes)
    while command.count < aligned { command.append(0) }

    do {
      try handle.seek(toOffset: UInt64(headerEnd))
      try handle.write(contentsOf: Data(command))
      try handle.seek(toOffset: 16)
      try handle.write(contentsOf: Data(bytes32(ncmds + 1)))
      try handle.seek(toOffset: 20)
      try handle.write(contentsOf: Data(bytes32(sizeofcmds + UInt32(aligned))))
      return .success
    } catch {
      return .failure(error.localizedDescription)
    }
  }

  private static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
    guard offset + 4 <= bytes.count else { return 0 }
    return UInt32(bytes[offset])
      | (UInt32(bytes[offset + 1]) << 8)
      | (UInt32(bytes[offset + 2]) << 16)
      | (UInt32(bytes[offset + 3]) << 24)
  }

  private static func u64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
    guard offset + 8 <= bytes.count else { return 0 }
    var value: UInt64 = 0
    for i in 0..<8 { value |= UInt64(bytes[offset + i]) << (8 * UInt64(i)) }
    return value
  }

  private static func bytes32(_ value: UInt32) -> [UInt8] {
    return [
      UInt8(value & 0xFF),
      UInt8((value >> 8) & 0xFF),
      UInt8((value >> 16) & 0xFF),
      UInt8((value >> 24) & 0xFF),
    ]
  }
}
