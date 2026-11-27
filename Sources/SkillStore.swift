import AppKit
import Foundation

// MARK: - Debounced Directory Watcher

final class DirectoryWatcher {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var fileDescriptors: [Int32] = []
    private var debounceWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "io.github.apollo.agenthub.watcher", qos: .utility)
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    deinit { stop() }

    func watch(paths: [String]) {
        stop()
        for path in Set(paths) {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let src = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .delete, .rename, .attrib],
                queue: queue
            )
            src.setEventHandler { [weak self] in self?.scheduleCallback() }
            src.setCancelHandler { close(fd) }
            src.resume()
            fileDescriptors.append(fd)
            sources.append(src)
        }
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        for src in sources { src.cancel() }
        sources.removeAll()
        fileDescriptors.removeAll()
    }

    private func scheduleCallback() {
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async { self?.onChange() }
        }
        debounceWorkItem = item
        queue.asyncAfter(deadline: .now() + 0.75, execute: item)
    }
}

// MARK: - SkillStore (Apollo AgentHub Unified Local Assets + Research Watchlist Store)

final class SkillStore: ObservableObject {
    private static let vaultDirDefaultsKey = "apolloagenthub_vault_dir"
    private static let legacyVaultDirKey = "apolloskillhub_vault_dir"
    private static let showBuiltinDefaultsKey = "apolloagenthub_show_builtins"
    private static let legacyShowBuiltinKey = "apolloskillhub_show_builtins"
    private static let darkThemeDefaultsKey = "apolloagenthub_dark_theme"
    private static let legacyDarkThemeKey = "apolloskillhub_dark_theme"

    @Published var fixedVaultPath: String
    @Published var categories: [SkillCategory] = []
    @Published var mcpCategories: [SkillCategory] = []
    @Published var pluginCategories: [SkillCategory] = []
    @Published var skills: [SkillItemModel] = []
    @Published var mcpServers: [McpServerItemModel] = []
    @Published var plugins: [PluginItemModel] = []
    @Published var watchlist: [WatchlistItem] = []
    @Published var profiles: [SkillProfile] = []
    @Published var healthIssues: [HealthIssue] = []
    @Published var cliChecks: [CliCheckItem] = []

    @Published var showBuiltins: Bool {
        didSet { UserDefaults.standard.set(showBuiltins, forKey: Self.showBuiltinDefaultsKey) }
    }
    @Published var isDarkTheme: Bool {
        didSet { UserDefaults.standard.set(isDarkTheme, forKey: Self.darkThemeDefaultsKey) }
    }
    @Published var isImporting: Bool = false
    @Published var fetchingWatchIds: Set<String> = []
    @Published var updatingSkillIds: Set<String> = []
    @Published var statusBanner: String? = nil
    @Published var statusIsError: Bool = false
    @Published var pendingOverwrite: PendingOverwriteContext? = nil

    private var registry = SkillRegistryFile(categories: [], skillCategories: [:], lastEnabledPlatforms: [:])
    private var bannerToken = 0
    private var activeImportProcess: Process? = nil
    private var importCancelled = false
    private var suppressWatcherUntil: Date = .distantPast
    private var watcher: DirectoryWatcher?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let ud = UserDefaults.standard
        let savedVault = ud.string(forKey: Self.vaultDirDefaultsKey)
            ?? ud.string(forKey: Self.legacyVaultDirKey)
            ?? ud.string(forKey: "agentmeter_skills_vault_dir")
        if let saved = savedVault, !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.fixedVaultPath = (saved as NSString).expandingTildeInPath
        } else {
            self.fixedVaultPath = "\(home)/.agents/skills-vault"
        }

        if ud.object(forKey: Self.showBuiltinDefaultsKey) != nil {
            self.showBuiltins = ud.bool(forKey: Self.showBuiltinDefaultsKey)
        } else {
            self.showBuiltins = ud.bool(forKey: Self.legacyShowBuiltinKey)
        }

        if ud.object(forKey: Self.darkThemeDefaultsKey) != nil {
            self.isDarkTheme = ud.bool(forKey: Self.darkThemeDefaultsKey)
        } else if ud.object(forKey: Self.legacyDarkThemeKey) != nil {
            self.isDarkTheme = ud.bool(forKey: Self.legacyDarkThemeKey)
        } else {
            self.isDarkTheme = true
        }

        self.watcher = DirectoryWatcher { [weak self] in
            guard let self = self else { return }
            if Date() < self.suppressWatcherUntil { return }
            self.reloadSkills(autoIngest: false)
        }

        reloadSkills()
        loadWatchlist()
        refreshWatchers()
    }

    private func markInternalWrite() {
        suppressWatcherUntil = Date().addingTimeInterval(1.5)
    }

    func refreshWatchers() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = [
            fixedVaultPath,
            platformDir(for: .antigravity),
            platformDir(for: .codex),
            platformDir(for: .claude),
            "\(home)/.codex/skills",
            "\(home)/.gemini/config/plugins",
            "\(home)/.codex/config.toml",
            "\(home)/.gemini/config/mcp_config.json",
            "\(home)/.claude.json"
        ]
        watcher?.watch(paths: paths)
    }

    static func shortenHomePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }

    func platformDir(for platform: AgentPlatform) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch platform {
        case .antigravity: return "\(home)/.gemini/config/skills"
        case .codex: return "\(home)/.agents/skills"
        case .claude: return "\(home)/.claude/skills"
        }
    }

    func isPlatformInstalled(_ platform: AgentPlatform) -> Bool {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        switch platform {
        case .antigravity: return fm.fileExists(atPath: "\(home)/.gemini")
        case .codex: return fm.fileExists(atPath: "\(home)/.codex") || fm.fileExists(atPath: "\(home)/.agents")
        case .claude:
            if let items = try? fm.contentsOfDirectory(atPath: "\(home)/.claude") {
                return items.contains { $0 != "skills" && $0 != ".DS_Store" } ||
                    !((try? fm.contentsOfDirectory(atPath: "\(home)/.claude/skills")) ?? []).isEmpty
            }
            return false
        }
    }

    func locateBinary(_ name: String) -> String? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        if name == "codex" {
            let appCli = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
            if fm.isExecutableFile(atPath: appCli) { return appCli }
        }
        if name == "node" {
            let cuaNode = "/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node"
            if fm.isExecutableFile(atPath: cuaNode) { return cuaNode }
        }
        if name.hasPrefix("/") {
            return fm.isExecutableFile(atPath: name) ? name : nil
        }
        let searchDirs = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.local/bin",
            "\(home)/.gemini/antigravity/bin",
            "\(home)/.cargo/bin",
            "/usr/bin",
            "/bin"
        ]
        for dir in searchDirs {
            let p = "\(dir)/\(name)"
            if fm.isExecutableFile(atPath: p) { return p }
        }
        return nil
    }

    func locateCodexCLI() -> String? { locateBinary("codex") }

    private var registryPath: String { "\(fixedVaultPath)/.skill_registry.json" }
    var watchlistPath: String { "\(fixedVaultPath)/.watchlist.json" }

    // MARK: - Default Purpose Categories (Unified across Skills / MCP / Plugins)

    private static var defaultCategories: [SkillCategory] {
        [
            SkillCategory(id: "ui-frontend", name: "UI 与前端设计", sortOrder: 0),
            SkillCategory(id: "video-media", name: "视频与多媒体", sortOrder: 1),
            SkillCategory(id: "finance-thinking", name: "投研与思维框架", sortOrder: 2),
            SkillCategory(id: "re-debug", name: "逆向与调试工程", sortOrder: 3),
            SkillCategory(id: "info-productivity", name: "资讯与效率办公", sortOrder: 4),
            SkillCategory(id: "system-config", name: "系统与配置管理", sortOrder: 5)
        ]
    }

    private static var defaultMcpCategories: [SkillCategory] {
        [
            SkillCategory(id: "mcp-browser", name: "浏览器与网页", sortOrder: 0),
            SkillCategory(id: "mcp-dev", name: "开发与代码工具", sortOrder: 1),
            SkillCategory(id: "mcp-data", name: "文件与数据存储", sortOrder: 2),
            SkillCategory(id: "mcp-auto", name: "自动化与系统控制", sortOrder: 3),
            SkillCategory(id: "mcp-other", name: "其他服务", sortOrder: 4)
        ]
    }

    private static var defaultPluginCategories: [SkillCategory] {
        [
            SkillCategory(id: "pl-docs", name: "文档与办公套件", sortOrder: 0),
            SkillCategory(id: "pl-browser", name: "浏览器与桌面控制", sortOrder: 1),
            SkillCategory(id: "pl-visual", name: "可视化与设计", sortOrder: 2),
            SkillCategory(id: "pl-dev", name: "开发与工具扩展", sortOrder: 3),
            SkillCategory(id: "pl-other", name: "其他插件", sortOrder: 4)
        ]
    }

    private static let defaultSkillMappings: [String: String] = [
        "a11y-debugging": "ui-frontend",
        "generative_ui": "ui-frontend",
        "ui-plugin-navigation": "ui-frontend",
        "mcp-app-development": "ui-frontend",
        "chrome-devtools": "re-debug",
        "cookie-debugging": "re-debug",
        "debug-optimize-lcp": "re-debug",
        "memory-leak-debugging": "re-debug",
        "troubleshooting": "re-debug",
        "gmail": "info-productivity",
        "gdrive": "info-productivity",
        "automation": "info-productivity",
        "run-workflow": "info-productivity",
        "agy-customizations": "system-config",
        "antigravity-guide": "system-config",
        "antigravity_guide": "system-config",
        "conversations": "system-config",
        "migrate-agent-settings": "system-config",
        "migrate-workflows": "system-config",
        "native_swarm": "system-config",
        "permissioned-github": "system-config",
        "plugin": "system-config",
        "swarm_monitor": "system-config",
        "swarm_narrator": "system-config",
        "swarm_pane": "system-config"
    ]

    private func inferCategoryId(for id: String, desc: String) -> String {
        if let preset = Self.defaultSkillMappings[id], categories.contains(where: { $0.id == preset }) {
            return preset
        }
        let haystack = "\(id) \(desc)".lowercased()
        let rules: [(String, [String])] = [
            ("ui-frontend", ["ui", "design", "css", "a11y", "figma", "frontend", "界面", "视觉", "设计"]),
            ("video-media", ["video", "remotion", "audio", "render", "视频", "剪辑", "动画"]),
            ("finance-thinking", ["finance", "invest", "stock", "research", "think", "decision", "投研", "思维", "分析"]),
            ("re-debug", ["reverse", "debug", "memory", "devtools", "cookie", "lcp", "trace", "逆向", "调试"]),
            ("info-productivity", ["mail", "drive", "calendar", "news", "workflow", "资讯", "邮件", "效率"])
        ]
        for (catId, keywords) in rules {
            if categories.contains(where: { $0.id == catId }), keywords.contains(where: { haystack.contains($0) }) {
                return catId
            }
        }
        if categories.contains(where: { $0.id == "system-config" }) { return "system-config" }
        return categories.last?.id ?? "system-config"
    }

    private func inferMcpCategoryId(for name: String, cmd: String) -> String {
        let h = "\(name) \(cmd)".lowercased()
        let rules: [(String, [String])] = [
            ("mcp-browser", ["chrome", "browser", "playwright", "puppeteer", "fetch", "web", "crawl", "firecrawl"]),
            ("mcp-dev", ["github", "git", "code", "xcode", "linear", "jira", "sentry", "context7", "devtools"]),
            ("mcp-data", ["file", "sqlite", "postgres", "mysql", "mongo", "redis", "drive", "notion", "obsidian", "memory"]),
            ("mcp-auto", ["node_repl", "repl", "shell", "computer", "sky", "apple", "macos", "exec"])
        ]
        for (cid, kws) in rules {
            if mcpCategories.contains(where: { $0.id == cid }), kws.contains(where: { h.contains($0) }) {
                return cid
            }
        }
        return mcpCategories.last?.id ?? "mcp-other"
    }

    private func inferPluginCategoryId(for id: String, desc: String) -> String {
        let h = "\(id) \(desc)".lowercased()
        let rules: [(String, [String])] = [
            ("pl-docs", ["doc", "pdf", "sheet", "excel", "slide", "presentation", "template", "word", "office"]),
            ("pl-browser", ["browser", "computer-use", "cua", "chrome", "desktop", "sky"]),
            ("pl-visual", ["visual", "design", "figma", "canva", "chart", "ui", "image"]),
            ("pl-dev", ["tool", "app-tools", "dev", "git", "code", "debug", "cli", "cloud", "auth"])
        ]
        for (cid, kws) in rules {
            if pluginCategories.contains(where: { $0.id == cid }), kws.contains(where: { h.contains($0) }) {
                return cid
            }
        }
        return pluginCategories.last?.id ?? "pl-other"
    }

    func showBanner(_ message: String, isError: Bool = false) {
        DispatchQueue.main.async {
            self.bannerToken += 1
            let token = self.bannerToken
            self.statusBanner = message
            self.statusIsError = isError
            DispatchQueue.main.asyncAfter(deadline: .now() + (isError ? 7.0 : 3.8)) {
                if self.bannerToken == token { self.statusBanner = nil }
            }
        }
    }

    private func ensureDirectoriesExist() {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: fixedVaultPath, withIntermediateDirectories: true)
        for p in AgentPlatform.allCases where isPlatformInstalled(p) {
            try? fm.createDirectory(atPath: platformDir(for: p), withIntermediateDirectories: true)
        }
    }

    private func loadRegistry() {
        var dirty = false
        if let data = try? Data(contentsOf: URL(fileURLWithPath: registryPath)),
           let decoded = try? JSONDecoder().decode(SkillRegistryFile.self, from: data),
           !decoded.categories.isEmpty {
            registry = decoded
            categories = registry.categories.sorted { $0.sortOrder < $1.sortOrder }
            profiles = registry.profiles
        } else {
            var previousPlatforms: [String: [String]] = [:]
            if let data = try? Data(contentsOf: URL(fileURLWithPath: registryPath)),
               let broken = try? JSONDecoder().decode(SkillRegistryFile.self, from: data) {
                previousPlatforms = broken.lastEnabledPlatforms
            }
            registry = SkillRegistryFile(
                categories: Self.defaultCategories,
                skillCategories: Self.defaultSkillMappings,
                lastEnabledPlatforms: previousPlatforms,
                skillSources: [:],
                profiles: [],
                mcpCategories: Self.defaultMcpCategories,
                mcpCategoryMap: [:],
                pluginCategories: Self.defaultPluginCategories,
                pluginCategoryMap: [:]
            )
            categories = registry.categories
            profiles = []
            dirty = true
        }

        if registry.mcpCategories.isEmpty {
            registry.mcpCategories = Self.defaultMcpCategories
            dirty = true
        }
        mcpCategories = registry.mcpCategories.sorted { $0.sortOrder < $1.sortOrder }

        if registry.pluginCategories.isEmpty {
            registry.pluginCategories = Self.defaultPluginCategories
            dirty = true
        }
        pluginCategories = registry.pluginCategories.sorted { $0.sortOrder < $1.sortOrder }

        if dirty { saveRegistry() }
    }

    private func saveRegistry() {
        markInternalWrite()
        categories = categories.enumerated().map { SkillCategory(id: $1.id, name: $1.name, sortOrder: $0) }
        mcpCategories = mcpCategories.enumerated().map { SkillCategory(id: $1.id, name: $1.name, sortOrder: $0) }
        pluginCategories = pluginCategories.enumerated().map { SkillCategory(id: $1.id, name: $1.name, sortOrder: $0) }
        registry.categories = categories
        registry.mcpCategories = mcpCategories
        registry.pluginCategories = pluginCategories
        registry.profiles = profiles
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(registry) {
            try? FileManager.default.createDirectory(atPath: fixedVaultPath, withIntermediateDirectories: true)
            try? data.write(to: URL(fileURLWithPath: registryPath), options: .atomic)
        }
    }

    // MARK: - Watchlist Persistence, GitHub Read-Only Metadata Fetch & Export

    func loadWatchlist() {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: watchlistPath)),
           let decoded = try? JSONDecoder().decode(WatchlistFile.self, from: data) {
            watchlist = decoded.items
        } else {
            watchlist = []
        }
    }

    func saveWatchlist() {
        markInternalWrite()
        let file = WatchlistFile(version: 1, items: watchlist)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(file) {
            try? FileManager.default.createDirectory(atPath: fixedVaultPath, withIntermediateDirectories: true)
            try? data.write(to: URL(fileURLWithPath: watchlistPath), options: .atomic)
        }
    }

    func isWatchlistItemInstalledLocally(_ item: WatchlistItem) -> Bool {
        let normName = item.name.lowercased()
        let normUrl = item.repoUrl.lowercased()
        if skills.contains(where: {
            $0.id.lowercased() == normName ||
            $0.displayName.lowercased() == normName ||
            ($0.sourceRecord?.cloneURL.lowercased().contains(normName) ?? false) ||
            ($0.sourceRecord?.repoInput.lowercased() == normUrl)
        }) {
            return true
        }
        if plugins.contains(where: { $0.rawId.lowercased() == normName || $0.displayName.lowercased() == normName }) {
            return true
        }
        return false
    }

    func addWatchlistItem(
        name: String,
        kind: WatchlistKind,
        status: WatchlistStatus,
        repoUrl: String,
        summary: String,
        notes: String,
        tags: [String],
        installCmd: String,
        starsText: String = "",
        language: String = "",
        pushedAt: String = ""
    ) {
        let now = Self.isoNow()
        let cleanUrl = Self.normalizeRepoUrl(repoUrl)
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (URL(string: cleanUrl)?.deletingPathExtension().lastPathComponent ?? "未命名项目")
            : name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? String(notes.trimmingCharacters(in: .whitespacesAndNewlines).prefix(56))
            : summary.trimmingCharacters(in: .whitespacesAndNewlines)

        let item = WatchlistItem(
            id: "wl-" + String(UUID().uuidString.prefix(8)).lowercased(),
            name: finalName,
            kind: kind,
            status: status,
            repoUrl: cleanUrl,
            summary: finalSummary.isEmpty ? "已收录待研究" : finalSummary,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            installCmd: installCmd.trimmingCharacters(in: .whitespacesAndNewlines),
            starsText: starsText,
            language: language,
            pushedAt: pushedAt,
            createdAt: now,
            updatedAt: now
        )
        watchlist.insert(item, at: 0)
        saveWatchlist()
        showBanner("已收录「\(finalName)」到关注收藏（未下载到本地）")
    }

    func updateWatchlistItem(_ item: WatchlistItem) {
        guard let idx = watchlist.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.updatedAt = Self.isoNow()
        watchlist[idx] = updated
        saveWatchlist()
    }

    func deleteWatchlistItem(id: String) {
        guard let idx = watchlist.firstIndex(where: { $0.id == id }) else { return }
        let name = watchlist[idx].name
        watchlist.remove(at: idx)
        saveWatchlist()
        showBanner("已从关注收藏移除「\(name)」")
    }

    static func normalizeRepoUrl(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "" }
        if s.contains("://") { return s }
        let parts = s.split(separator: "/")
        if parts.count >= 2 { return "https://github.com/\(s)" }
        return s
    }

    static func extractGitHubOwnerRepo(from raw: String) -> (owner: String, repo: String)? {
        let norm = normalizeRepoUrl(raw)
        guard let url = URL(string: norm), let host = url.host?.lowercased(), host.contains("github.com") else { return nil }
        let comps = url.pathComponents.filter { $0 != "/" }
        guard comps.count >= 2 else { return nil }
        var repo = comps[1]
        if repo.hasSuffix(".git") { repo = String(repo.dropLast(4)) }
        return (comps[0], repo)
    }

    /// Pure read-only GitHub REST API metadata fetch (zero git clone / zero local download).
    func fetchGitHubMetadata(
        for repoInput: String,
        completion: @escaping (Result<(name: String, desc: String, stars: String, language: String, pushedAt: String, canonicalUrl: String), Error>) -> Void
    ) {
        guard let pair = Self.extractGitHubOwnerRepo(from: repoInput) else {
            completion(.failure(NSError(domain: "AgentHub", code: -1, userInfo: [NSLocalizedDescriptionKey: "请输入有效的 GitHub 仓库地址或 owner/repo"])))
            return
        }
        guard let apiUrl = URL(string: "https://api.github.com/repos/\(pair.owner)/\(pair.repo)") else { return }
        var req = URLRequest(url: apiUrl, timeoutInterval: 12)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Apollo-AgentHub/1.3.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let msg = http.statusCode == 403 ? "GitHub API 频率受限，请稍后再试" : "GitHub API 返回状态码 \(http.statusCode)"
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "AgentHub", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])))
                }
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "AgentHub", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法解析 GitHub 返回数据"])))
                }
                return
            }
            let name = (json["name"] as? String) ?? pair.repo
            let desc = (json["description"] as? String) ?? ""
            let starCount = (json["stargazers_count"] as? Int) ?? 0
            let stars = starCount >= 1000 ? String(format: "%.1fk", Double(starCount) / 1000.0) : "\(starCount)"
            let lang = (json["language"] as? String) ?? "Markdown"
            let pushedRaw = (json["pushed_at"] as? String) ?? ""
            let pushedShort = pushedRaw.count >= 10 ? String(pushedRaw.prefix(10)) : pushedRaw
            let htmlUrl = (json["html_url"] as? String) ?? "https://github.com/\(pair.owner)/\(pair.repo)"

            DispatchQueue.main.async {
                completion(.success((name, desc, stars, lang, pushedShort, htmlUrl)))
            }
        }.resume()
    }

    func refreshWatchlistItemMetadata(_ item: WatchlistItem) {
        DispatchQueue.main.async { self.fetchingWatchIds.insert(item.id) }
        fetchGitHubMetadata(for: item.repoUrl) { [weak self] result in
            guard let self = self else { return }
            self.fetchingWatchIds.remove(item.id)
            switch result {
            case .success(let meta):
                guard var updated = self.watchlist.first(where: { $0.id == item.id }) else { return }
                updated.starsText = meta.stars
                updated.language = meta.language
                updated.pushedAt = meta.pushedAt
                if updated.summary.isEmpty || updated.summary == "已收录待研究" {
                    updated.summary = meta.desc
                }
                self.updateWatchlistItem(updated)
                self.showBanner("已刷新「\(item.name)」元信息（Stars \(meta.stars) · \(meta.pushedAt)）")
            case .failure(let err):
                self.showBanner("抓取失败: \(err.localizedDescription)", isError: true)
            }
        }
    }

    func exportWatchlistAsJSON() {
        let panel = NSSavePanel()
        panel.title = "导出关注收藏库 (JSON)"
        panel.nameFieldStringValue = "apollo-agenthub-watchlist.json"
        if panel.runModal() == .OK, let url = panel.url {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(WatchlistFile(version: 1, items: watchlist)) {
                do {
                    try data.write(to: url, options: .atomic)
                    showBanner("已导出 JSON 至 \(Self.shortenHomePath(url.path))")
                } catch {
                    showBanner("导出失败: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    func exportWatchlistAsMarkdown() {
        let panel = NSSavePanel()
        panel.title = "导出研究清单 (Markdown)"
        panel.nameFieldStringValue = "apollo-agenthub-watchlist.md"
        if panel.runModal() == .OK, let url = panel.url {
            var lines: [String] = [
                "# Apollo AgentHub — 关注收藏研究清单",
                "",
                "> 导出时间：\(Self.isoNow()) · 共 \(watchlist.count) 项",
                "",
                "| 名称 | 类型 | 状态 | Star | 简介 / 笔记 | 仓库地址 |",
                "| :--- | :--- | :--- | :--- | :--- | :--- |"
            ]
            for w in watchlist {
                let note = (w.notes.isEmpty ? w.summary : w.notes)
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "|", with: "\\|")
                let star = w.starsText.isEmpty ? "-" : "★ \(w.starsText)"
                lines.append("| **\(w.name)** | \(w.kind.label) | \(w.status.label) | \(star) | \(note) | \(w.repoUrl) |")
            }
            do {
                try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
                showBanner("已导出 Markdown 清单至 \(Self.shortenHomePath(url.path))")
            } catch {
                showBanner("导出失败: \(error.localizedDescription)", isError: true)
            }
        }
    }

    // MARK: - Symlink & Skill Reload

    private func isSymlink(_ path: String) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil
    }

    private func ingestExternalSkillsIntoVault() {
        markInternalWrite()
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let scanDirs: [(path: String, replaceWithSymlink: Bool)] = [
            (platformDir(for: .codex), true),
            (platformDir(for: .antigravity), true),
            (platformDir(for: .claude), true),
            ("\(home)/.codex/skills", false)
        ]

        for entry in scanDirs {
            guard let items = try? fm.contentsOfDirectory(atPath: entry.path) else { continue }
            for name in items where !name.hasPrefix(".") {
                let itemPath = "\(entry.path)/\(name)"
                let vaultSkillPath = "\(fixedVaultPath)/\(name)"
                if isSymlink(itemPath) {
                    if entry.replaceWithSymlink && fm.fileExists(atPath: "\(vaultSkillPath)/SKILL.md") {
                        let currentDest = (try? fm.destinationOfSymbolicLink(atPath: itemPath)) ?? ""
                        if currentDest != vaultSkillPath {
                            try? fm.removeItem(atPath: itemPath)
                            try? fm.createSymbolicLink(atPath: itemPath, withDestinationPath: vaultSkillPath)
                        }
                    }
                    continue
                }
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue,
                   fm.fileExists(atPath: "\(itemPath)/SKILL.md") {
                    if !fm.fileExists(atPath: vaultSkillPath) {
                        do { try fm.moveItem(atPath: itemPath, toPath: vaultSkillPath) } catch { continue }
                    } else {
                        try? fm.removeItem(atPath: itemPath)
                    }
                    if entry.replaceWithSymlink {
                        try? fm.createSymbolicLink(atPath: itemPath, withDestinationPath: vaultSkillPath)
                    } else {
                        let codexLink = "\(platformDir(for: .codex))/\(name)"
                        try? fm.createDirectory(atPath: platformDir(for: .codex), withIntermediateDirectories: true)
                        if !fm.fileExists(atPath: codexLink) && !isSymlink(codexLink) {
                            try? fm.createSymbolicLink(atPath: codexLink, withDestinationPath: vaultSkillPath)
                        }
                    }
                }
            }
        }
    }

    private func hasActiveMount(skillId: String, platform: AgentPlatform) -> Bool {
        FileManager.default.fileExists(atPath: "\(platformDir(for: platform))/\(skillId)/SKILL.md")
    }

    func activeEstimatedTokens(for platform: AgentPlatform? = nil) -> Int {
        skills.reduce(0) { acc, sk in
            if sk.sourceKind == .builtin { return acc }
            if let pf = platform { return acc + (sk.activePlatforms.contains(pf) ? sk.estimatedTokens : 0) }
            return acc + (sk.isAnyActive ? sk.estimatedTokens : 0)
        }
    }

    func reloadSkills(autoIngest: Bool = true) {
        ensureDirectoriesExist()
        if autoIngest { ingestExternalSkillsIntoVault() }
        loadRegistry()

        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        var loaded: [SkillItemModel] = []
        var seenIds = Set<String>()
        var registryDirty = false

        if let vaultEntries = try? fm.contentsOfDirectory(atPath: fixedVaultPath) {
            for name in vaultEntries.sorted() where !name.hasPrefix(".") {
                let dir = "\(fixedVaultPath)/\(name)"
                guard fm.fileExists(atPath: "\(dir)/SKILL.md") else { continue }

                let meta = SkillParsers.parseSkillMetadata(skillDir: dir, fallbackId: name)
                let catId: String
                if let assigned = registry.skillCategories[name], categories.contains(where: { $0.id == assigned }) {
                    catId = assigned
                } else {
                    catId = inferCategoryId(for: name, desc: meta.desc)
                    registry.skillCategories[name] = catId
                    registryDirty = true
                }

                var active = Set<AgentPlatform>()
                for p in AgentPlatform.allCases where hasActiveMount(skillId: name, platform: p) {
                    active.insert(p)
                }
                if !active.isEmpty && registry.lastEnabledPlatforms[name] == nil {
                    registry.lastEnabledPlatforms[name] = active.map { $0.rawValue }.sorted()
                    registryDirty = true
                }

                seenIds.insert(name)
                loaded.append(SkillItemModel(
                    id: name, displayName: meta.name, summaryLine: meta.summary, descriptionText: meta.desc,
                    triggerHints: meta.triggers, canonicalPath: dir, skillMdPath: meta.skillMdPath,
                    sourceKind: .userVault, pluginName: nil, categoryId: catId, activePlatforms: active,
                    charCount: meta.charCount, estimatedTokens: meta.estimatedTokens, sourceRecord: registry.skillSources[name]
                ))
            }
        }

        let pluginsRoot = "\(home)/.gemini/config/plugins"
        if let pluginDirs = try? fm.contentsOfDirectory(atPath: pluginsRoot) {
            for pluginDirName in pluginDirs.sorted() {
                let skillsSub = "\(pluginsRoot)/\(pluginDirName)/skills"
                guard let pSkills = try? fm.contentsOfDirectory(atPath: skillsSub) else { continue }
                for name in pSkills.sorted() where !name.hasPrefix(".") && !seenIds.contains(name) {
                    let dir = "\(skillsSub)/\(name)"
                    guard fm.fileExists(atPath: "\(dir)/SKILL.md") else { continue }
                    let meta = SkillParsers.parseSkillMetadata(skillDir: dir, fallbackId: name)
                    let catId: String
                    if let assigned = registry.skillCategories[name], categories.contains(where: { $0.id == assigned }) {
                        catId = assigned
                    } else {
                        catId = inferCategoryId(for: name, desc: meta.desc)
                        registry.skillCategories[name] = catId
                        registryDirty = true
                    }
                    var active: Set<AgentPlatform> = [.antigravity]
                    if hasActiveMount(skillId: name, platform: .codex) { active.insert(.codex) }
                    if hasActiveMount(skillId: name, platform: .claude) { active.insert(.claude) }

                    seenIds.insert(name)
                    loaded.append(SkillItemModel(
                        id: name, displayName: meta.name, summaryLine: meta.summary, descriptionText: meta.desc,
                        triggerHints: meta.triggers, canonicalPath: dir, skillMdPath: meta.skillMdPath,
                        sourceKind: .plugin, pluginName: pluginDirName, categoryId: catId, activePlatforms: active,
                        charCount: meta.charCount, estimatedTokens: meta.estimatedTokens, sourceRecord: nil
                    ))
                }
            }
        }

        let builtinRoot = "\(home)/.gemini/antigravity/builtin/skills"
        if let bSkills = try? fm.contentsOfDirectory(atPath: builtinRoot) {
            for name in bSkills.sorted() where !name.hasPrefix(".") && !seenIds.contains(name) {
                let dir = "\(builtinRoot)/\(name)"
                guard fm.fileExists(atPath: "\(dir)/SKILL.md") else { continue }
                let meta = SkillParsers.parseSkillMetadata(skillDir: dir, fallbackId: name)
                let catId: String
                if let assigned = registry.skillCategories[name], categories.contains(where: { $0.id == assigned }) {
                    catId = assigned
                } else {
                    catId = inferCategoryId(for: name, desc: meta.desc)
                    registry.skillCategories[name] = catId
                    registryDirty = true
                }
                seenIds.insert(name)
                loaded.append(SkillItemModel(
                    id: name, displayName: meta.name, summaryLine: meta.summary, descriptionText: meta.desc,
                    triggerHints: meta.triggers, canonicalPath: dir, skillMdPath: meta.skillMdPath,
                    sourceKind: .builtin, pluginName: nil, categoryId: catId, activePlatforms: [.antigravity],
                    charCount: meta.charCount, estimatedTokens: meta.estimatedTokens, sourceRecord: nil
                ))
            }
        }

        if registryDirty { saveRegistry() }

        let rank: (SkillItemModel) -> Int = { item in
            switch item.sourceKind {
            case .userVault: return item.activePlatforms.isEmpty ? 1 : 0
            case .plugin: return 2
            case .builtin: return 3
            }
        }
        skills = loaded.sorted {
            let r1 = rank($0), r2 = rank($1)
            if r1 != r2 { return r1 < r2 }
            return $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
        }
        reloadMcpServers()
        reloadPlugins()
        scanHealthIssues()
    }

    // MARK: - MCP Scanner, Purpose Grouping & Cross-Platform Sync

    func mcpConfigPath(for platform: AgentPlatform) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch platform {
        case .antigravity: return "\(home)/.gemini/config/mcp_config.json"
        case .codex: return "\(home)/.codex/config.toml"
        case .claude: return "\(home)/.claude.json"
        }
    }

    func reloadMcpServers() {
        let fm = FileManager.default
        struct Draft {
            var commands: [String] = []
            var envKeys: Set<String> = []
            var platforms: Set<AgentPlatform> = []
            var configPaths: [AgentPlatform: String] = [:]
            var rawConfigs: [AgentPlatform: McpRawConfig] = [:]
        }
        var merged: [String: Draft] = [:]

        func parseJsonMcpFile(path: String, platform: AgentPlatform) {
            guard fm.fileExists(atPath: path),
                  let data = fm.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let servers = json["mcpServers"] as? [String: Any] else { return }
            for (name, rawVal) in servers {
                guard let dict = rawVal as? [String: Any] else { continue }
                var draft = merged[name] ?? Draft()
                draft.platforms.insert(platform)
                draft.configPaths[platform] = path
                let cmd = dict["command"] as? String
                let args = (dict["args"] as? [String]) ?? []
                let url = dict["url"] as? String
                var envMap: [String: String] = [:]
                if let env = dict["env"] as? [String: Any] {
                    for (k, v) in env {
                        draft.envKeys.insert(k)
                        envMap[k] = "\(v)"
                    }
                }
                draft.rawConfigs[platform] = McpRawConfig(command: cmd, args: args, url: url, env: envMap)
                if let c = cmd {
                    let line = ([c] + args).joined(separator: " ")
                    if !draft.commands.contains(line) { draft.commands.append(line) }
                } else if let u = url, !draft.commands.contains(u) {
                    draft.commands.append(u)
                }
                merged[name] = draft
            }
        }

        parseJsonMcpFile(path: mcpConfigPath(for: .antigravity), platform: .antigravity)
        parseJsonMcpFile(path: mcpConfigPath(for: .claude), platform: .claude)

        let codexPath = mcpConfigPath(for: .codex)
        if fm.fileExists(atPath: codexPath),
           let content = try? String(contentsOfFile: codexPath, encoding: .utf8) {
            for (name, info) in CodexTomlHelper.parseMcpServers(from: content) {
                var draft = merged[name] ?? Draft()
                draft.platforms.insert(.codex)
                draft.configPaths[.codex] = codexPath
                draft.rawConfigs[.codex] = info
                if let cmd = info.command {
                    let line = ([cmd] + info.args).joined(separator: " ")
                    if !draft.commands.contains(line) { draft.commands.append(line) }
                } else if let url = info.url, !draft.commands.contains(url) {
                    draft.commands.append(url)
                }
                for k in info.env.keys { draft.envKeys.insert(k) }
                merged[name] = draft
            }
        }

        var dirty = false
        mcpServers = merged.map { (name, d) in
            let cmdSum = d.commands.first ?? "configured in local config"
            let catId: String
            if let assigned = registry.mcpCategoryMap[name], mcpCategories.contains(where: { $0.id == assigned }) {
                catId = assigned
            } else {
                catId = inferMcpCategoryId(for: name, cmd: cmdSum)
                registry.mcpCategoryMap[name] = catId
                dirty = true
            }
            return McpServerItemModel(
                id: name, commandSummary: cmdSum, envKeys: d.envKeys.sorted(),
                platforms: d.platforms, configPaths: d.configPaths, rawConfigs: d.rawConfigs, categoryId: catId
            )
        }.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
        if dirty { saveRegistry() }
    }

    func assignMcpCategory(_ categoryId: String, to serverId: String) {
        registry.mcpCategoryMap[serverId] = categoryId
        saveRegistry()
        reloadMcpServers()
        if let cat = mcpCategories.first(where: { $0.id == categoryId }) {
            showBanner("已将 MCP「\(serverId)」归入「\(cat.name)」")
        }
    }

    func addMcpCategory(name: String) -> String? {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !mcpCategories.contains(where: { $0.name.caseInsensitiveCompare(t) == .orderedSame }) else { return nil }
        let id = "mcp-cat-" + String(UUID().uuidString.prefix(6)).lowercased()
        mcpCategories.append(SkillCategory(id: id, name: t, sortOrder: mcpCategories.count))
        saveRegistry()
        showBanner("已新增 MCP 分组「\(t)」")
        return id
    }

    func syncMcpServer(_ server: McpServerItemModel, to target: AgentPlatform) {
        let preferredOrder: [AgentPlatform] = [.antigravity, .codex, .claude]
        guard let sourceConfig = preferredOrder.compactMap({ server.rawConfigs[$0] }).first else {
            showBanner("未找到「\(server.id)」的可同步配置", isError: true)
            return
        }
        markInternalWrite()
        let targetPath = mcpConfigPath(for: target)
        do {
            if target == .codex {
                try CodexTomlHelper.upsertMcpServer(name: server.id, config: sourceConfig, configPath: targetPath)
            } else {
                try upsertJsonMcpServer(name: server.id, config: sourceConfig, configPath: targetPath)
            }
            reloadMcpServers()
            showBanner("已将 MCP「\(server.id)」同步至 \(target.fullName)")
        } catch {
            showBanner("同步 MCP 失败: \(error.localizedDescription)", isError: true)
        }
    }

    func removeMcpServer(_ server: McpServerItemModel, from target: AgentPlatform) {
        markInternalWrite()
        let targetPath = mcpConfigPath(for: target)
        do {
            if target == .codex {
                if let content = try? String(contentsOfFile: targetPath, encoding: .utf8) {
                    let updated = CodexTomlHelper.removeMcpSection(name: server.id, from: content)
                    try updated.write(toFile: targetPath, atomically: true, encoding: .utf8)
                }
            } else {
                try removeJsonMcpServer(name: server.id, configPath: targetPath)
            }
            reloadMcpServers()
            showBanner("已从 \(target.fullName) 移除 MCP「\(server.id)」")
        } catch {
            showBanner("移除 MCP 失败: \(error.localizedDescription)", isError: true)
        }
    }

    private func upsertJsonMcpServer(name: String, config: McpRawConfig, configPath: String) throws {
        let fm = FileManager.default
        var root: [String: Any] = [:]
        if fm.fileExists(atPath: configPath),
           let data = fm.contents(atPath: configPath),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = obj
        }
        var servers = (root["mcpServers"] as? [String: Any]) ?? [:]
        var entry: [String: Any] = [:]
        if let cmd = config.command, !cmd.isEmpty {
            entry["command"] = cmd
            entry["args"] = config.args
        } else if let url = config.url, !url.isEmpty {
            entry["url"] = url
        }
        if !config.env.isEmpty { entry["env"] = config.env }
        servers[name] = entry
        root["mcpServers"] = servers
        try fm.createDirectory(atPath: (configPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        let outData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try outData.write(to: URL(fileURLWithPath: configPath), options: .atomic)
    }

    private func removeJsonMcpServer(name: String, configPath: String) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: configPath),
              let data = fm.contents(atPath: configPath),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var servers = root["mcpServers"] as? [String: Any] else { return }
        servers.removeValue(forKey: name)
        root["mcpServers"] = servers
        let outData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try outData.write(to: URL(fileURLWithPath: configPath), options: .atomic)
    }

    // MARK: - Multi-Platform Plugins & Purpose Grouping

    func agyPluginsDir() -> String { "\(FileManager.default.homeDirectoryForCurrentUser.path)/.gemini/config/plugins" }
    func agyDisabledPluginsDir() -> String { "\(FileManager.default.homeDirectoryForCurrentUser.path)/.gemini/config/plugins-disabled" }

    func reloadPlugins() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        var loaded: [PluginItemModel] = []
        var dirty = false

        func resolveCat(_ fullId: String, name: String, desc: String) -> String {
            if let assigned = registry.pluginCategoryMap[fullId], pluginCategories.contains(where: { $0.id == assigned }) {
                return assigned
            }
            let inferred = inferPluginCategoryId(for: name, desc: desc)
            registry.pluginCategoryMap[fullId] = inferred
            dirty = true
            return inferred
        }

        func scanAgyPlugins(in root: String, enabled: Bool) {
            guard let dirs = try? fm.contentsOfDirectory(atPath: root) else { return }
            for dirName in dirs.sorted() where !dirName.hasPrefix(".") {
                let pluginPath = "\(root)/\(dirName)"
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: pluginPath, isDirectory: &isDir), isDir.boolValue else { continue }
                let jsonPath = "\(pluginPath)/plugin.json"
                var displayName = dirName, version = enabled ? "已安装" : "已停用", authorName = "Antigravity Plugin", desc = "Antigravity 插件", repoUrl = ""
                let hasJson = fm.fileExists(atPath: jsonPath)
                if hasJson, let data = fm.contents(atPath: jsonPath), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let dn = json["displayName"] as? String, !dn.isEmpty { displayName = dn }
                    else if let nm = json["name"] as? String, !nm.isEmpty { displayName = nm }
                    if let v = json["version"] as? String, !v.isEmpty { version = "v\(v)" }
                    if let d = json["description"] as? String, !d.isEmpty { desc = d }
                    if let r = json["repository"] as? String { repoUrl = r }
                    if let author = json["author"] as? [String: Any], let an = author["name"] as? String, !an.isEmpty { authorName = an }
                }
                let skillsSub = "\(pluginPath)/skills"
                var bundled: [String] = []
                if let skillDirs = try? fm.contentsOfDirectory(atPath: skillsSub) {
                    for sName in skillDirs.sorted() where !sName.hasPrefix(".") {
                        var sIsDir: ObjCBool = false
                        if fm.fileExists(atPath: "\(skillsSub)/\(sName)", isDirectory: &sIsDir), sIsDir.boolValue { bundled.append(sName) }
                    }
                }
                let fid = "agy:\(dirName)"
                loaded.append(PluginItemModel(
                    id: fid, rawId: dirName, platform: .antigravity, displayName: displayName, version: version,
                    authorName: authorName, descriptionText: desc, repositoryUrl: repoUrl, pluginPath: pluginPath,
                    pluginJsonPath: hasJson ? jsonPath : nil, bundledSkills: bundled, isEnabled: enabled,
                    canToggle: true, canUninstall: true, categoryId: resolveCat(fid, name: displayName, desc: desc)
                ))
            }
        }

        scanAgyPlugins(in: agyPluginsDir(), enabled: true)
        scanAgyPlugins(in: agyDisabledPluginsDir(), enabled: false)

        let codexConfig = mcpConfigPath(for: .codex)
        if fm.fileExists(atPath: codexConfig), let content = try? String(contentsOfFile: codexConfig, encoding: .utf8) {
            for item in CodexTomlHelper.parsePlugins(from: content) {
                let parts = item.id.split(separator: "@", maxSplits: 1).map(String.init)
                let shortName = parts.first ?? item.id
                let marketplace = parts.count > 1 ? parts[1] : "codex"
                let cacheDir = "\(home)/.codex/plugins/cache/\(marketplace)/\(shortName)"
                var resolvedPath = cacheDir, version = marketplace, bundled: [String] = []
                if let versions = try? fm.contentsOfDirectory(atPath: cacheDir) {
                    if let latest = versions.filter({ !$0.hasPrefix(".") }).sorted().last {
                        version = "v\(latest)"
                        resolvedPath = "\(cacheDir)/\(latest)"
                        if let sDirs = try? fm.contentsOfDirectory(atPath: "\(resolvedPath)/skills") {
                            bundled = sDirs.filter { !$0.hasPrefix(".") }.sorted()
                        }
                    }
                }
                let fid = "codex:\(item.id)"
                let desc = "Codex 插件 (\(item.id))"
                loaded.append(PluginItemModel(
                    id: fid, rawId: item.id, platform: .codex, displayName: shortName, version: version,
                    authorName: marketplace, descriptionText: desc, repositoryUrl: "",
                    pluginPath: fm.fileExists(atPath: resolvedPath) ? resolvedPath : "\(home)/.codex/plugins",
                    pluginJsonPath: nil, bundledSkills: bundled, isEnabled: item.enabled,
                    canToggle: true, canUninstall: false, categoryId: resolveCat(fid, name: shortName, desc: desc)
                ))
            }
        }

        let claudePluginsRoot = "\(home)/.claude/plugins"
        if let cDirs = try? fm.contentsOfDirectory(atPath: claudePluginsRoot) {
            for dirName in cDirs.sorted() where !dirName.hasPrefix(".") {
                let pPath = "\(claudePluginsRoot)/\(dirName)"
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: pPath, isDirectory: &isDir), isDir.boolValue else { continue }
                let fid = "claude:\(dirName)"
                loaded.append(PluginItemModel(
                    id: fid, rawId: dirName, platform: .claude, displayName: dirName, version: "已安装",
                    authorName: "Claude Plugin", descriptionText: "Claude Code 插件", repositoryUrl: "",
                    pluginPath: pPath, pluginJsonPath: fm.fileExists(atPath: "\(pPath)/plugin.json") ? "\(pPath)/plugin.json" : nil,
                    bundledSkills: [], isEnabled: true, canToggle: false, canUninstall: true,
                    categoryId: resolveCat(fid, name: dirName, desc: "Claude Code 插件")
                ))
            }
        }

        plugins = loaded
        if dirty { saveRegistry() }
    }

    func assignPluginCategory(_ categoryId: String, to pluginId: String) {
        registry.pluginCategoryMap[pluginId] = categoryId
        saveRegistry()
        reloadPlugins()
        if let cat = pluginCategories.first(where: { $0.id == categoryId }) {
            showBanner("已将插件归入「\(cat.name)」")
        }
    }

    func addPluginCategory(name: String) -> String? {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !pluginCategories.contains(where: { $0.name.caseInsensitiveCompare(t) == .orderedSame }) else { return nil }
        let id = "pl-cat-" + String(UUID().uuidString.prefix(6)).lowercased()
        pluginCategories.append(SkillCategory(id: id, name: t, sortOrder: pluginCategories.count))
        saveRegistry()
        showBanner("已新增插件分组「\(t)」")
        return id
    }

    func togglePlugin(_ plugin: PluginItemModel) {
        guard plugin.canToggle else { return }
        markInternalWrite()
        let fm = FileManager.default
        let nextEnabled = !plugin.isEnabled
        do {
            switch plugin.platform {
            case .antigravity:
                let dstRoot = nextEnabled ? agyPluginsDir() : agyDisabledPluginsDir()
                try fm.createDirectory(atPath: dstRoot, withIntermediateDirectories: true)
                let dst = "\(dstRoot)/\(plugin.rawId)"
                if fm.fileExists(atPath: dst) { try fm.removeItem(atPath: dst) }
                try fm.moveItem(atPath: plugin.pluginPath, toPath: dst)
                reloadSkills(autoIngest: false)
                showBanner(nextEnabled ? "已启用 Antigravity 插件「\(plugin.displayName)」" : "已停用 Antigravity 插件「\(plugin.displayName)」")
            case .codex:
                try CodexTomlHelper.setPluginEnabled(pluginId: plugin.rawId, enabled: nextEnabled, configPath: mcpConfigPath(for: .codex))
                reloadPlugins()
                showBanner(nextEnabled ? "已在 Codex config.toml 启用插件「\(plugin.displayName)」" : "已在 Codex config.toml 停用插件「\(plugin.displayName)」")
            case .claude: break
            }
        } catch {
            showBanner("切换插件状态失败: \(error.localizedDescription)", isError: true)
        }
    }

    func uninstallPlugin(_ plugin: PluginItemModel) {
        guard plugin.canUninstall else { return }
        markInternalWrite()
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: plugin.pluginPath), resultingItemURL: nil)
            reloadSkills(autoIngest: false)
            showBanner("已将插件「\(plugin.displayName)」移入废纸篓")
        } catch {
            showBanner("卸载插件失败: \(error.localizedDescription)", isError: true)
        }
    }

    func installPluginFromLocalFolder(sourceURL: URL, shareSkillsTo: Set<AgentPlatform>) {
        let fm = FileManager.default
        let path = sourceURL.path
        let hasPluginJson = fm.fileExists(atPath: "\(path)/plugin.json")
        let hasSkillsDir = fm.fileExists(atPath: "\(path)/skills")
        guard hasPluginJson || hasSkillsDir else {
            showBanner("所选目录不是有效的插件目录（需包含 plugin.json 或 skills/ 目录）", isError: true)
            return
        }
        var pluginId = sourceURL.lastPathComponent
        if hasPluginJson, let data = fm.contents(atPath: "\(path)/plugin.json"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let nm = json["name"] as? String, !nm.isEmpty {
            pluginId = nm.replacingOccurrences(of: "/", with: "-")
        }
        markInternalWrite()
        do {
            try fm.createDirectory(atPath: agyPluginsDir(), withIntermediateDirectories: true)
            let dest = "\(agyPluginsDir())/\(pluginId)"
            if fm.fileExists(atPath: dest) { try fm.removeItem(atPath: dest) }
            try fm.copyItem(at: sourceURL, to: URL(fileURLWithPath: dest))
            if fm.fileExists(atPath: "\(dest)/.git") { try? fm.removeItem(atPath: "\(dest)/.git") }
            sharePluginSkills(pluginDir: dest, platforms: shareSkillsTo)
            reloadSkills(autoIngest: false)
            showBanner("已全局安装插件「\(pluginId)」")
        } catch {
            showBanner("安装插件失败: \(error.localizedDescription)", isError: true)
        }
    }

    func installPluginFromGitHub(repoInput: String, shareSkillsTo: Set<AgentPlatform>, onSuccess: (() -> Void)? = nil) {
        guard let parsed = SkillParsers.parseGitHubInput(repoInput) else {
            showBanner("请输入有效的 GitHub 地址或 owner/repo", isError: true)
            return
        }
        DispatchQueue.main.async { self.isImporting = true }
        importCancelled = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("apolloagenthub-plugin-\(UUID().uuidString)")
            defer {
                try? fm.removeItem(at: tmpDir)
                DispatchQueue.main.async { self.activeImportProcess = nil; self.isImporting = false }
            }
            if case .failure(let err) = self.runGitClone(cloneURL: parsed.cloneURL, branch: parsed.branch, destDir: tmpDir) {
                if !self.importCancelled { self.showBanner(err.localizedDescription, isError: true) }
                return
            }
            let targetRoot = parsed.subpath.map { tmpDir.appendingPathComponent($0) } ?? tmpDir
            guard fm.fileExists(atPath: "\(targetRoot.path)/plugin.json") || fm.fileExists(atPath: "\(targetRoot.path)/skills") else {
                self.showBanner("仓库中未找到 plugin.json 或 skills/ 目录", isError: true)
                return
            }
            DispatchQueue.main.async {
                self.installPluginFromLocalFolder(sourceURL: targetRoot, shareSkillsTo: shareSkillsTo)
                onSuccess?()
            }
        }
    }

    func installCodexPluginViaCLI(pluginSpec: String, onSuccess: (() -> Void)? = nil) {
        let trimmed = pluginSpec.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let codexBin = locateCodexCLI() else {
            showBanner("未检测到 Codex CLI 或插件名为空", isError: true)
            return
        }
        DispatchQueue.main.async { self.isImporting = true }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: codexBin)
            task.arguments = ["plugin", "add", trimmed]
            let errPipe = Pipe()
            task.standardOutput = Pipe()
            task.standardError = errPipe
            defer { DispatchQueue.main.async { self.isImporting = false } }
            do {
                try task.run(); task.waitUntilExit()
                if task.terminationStatus == 0 {
                    DispatchQueue.main.async { self.reloadPlugins(); self.showBanner("已通过 Codex CLI 安装插件「\(trimmed)」"); onSuccess?() }
                } else {
                    let errMsg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "codex plugin add 失败"
                    self.showBanner("Codex 插件安装失败: \(errMsg.prefix(140))", isError: true)
                }
            } catch {
                self.showBanner("无法调用 Codex CLI: \(error.localizedDescription)", isError: true)
            }
        }
    }

    private func sharePluginSkills(pluginDir: String, platforms: Set<AgentPlatform>) {
        let fm = FileManager.default
        let skillsSub = "\(pluginDir)/skills"
        guard let skillDirs = try? fm.contentsOfDirectory(atPath: skillsSub) else { return }
        for sName in skillDirs where !sName.hasPrefix(".") {
            let sPath = "\(skillsSub)/\(sName)"
            guard fm.fileExists(atPath: "\(sPath)/SKILL.md") else { continue }
            for pf in platforms where pf != .antigravity {
                let targetDir = platformDir(for: pf)
                try? fm.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
                let linkPath = "\(targetDir)/\(sName)"
                if isSymlink(linkPath) { try? fm.removeItem(atPath: linkPath) }
                if !fm.fileExists(atPath: linkPath) { try? fm.createSymbolicLink(atPath: linkPath, withDestinationPath: sPath) }
            }
        }
    }

    // MARK: - Symlink Mount Matrix

    private func setMount(skill: SkillItemModel, platform: AgentPlatform, enabled: Bool) -> Result<Void, MountError> {
        guard skill.sourceKind != .builtin else { return .success(()) }
        if skill.sourceKind == .plugin && platform == .antigravity { return .success(()) }
        markInternalWrite()
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let targetDir = platformDir(for: platform)
        try? fm.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
        let linkPath = "\(targetDir)/\(skill.id)"

        if enabled {
            if isSymlink(linkPath) {
                if ((try? fm.destinationOfSymbolicLink(atPath: linkPath)) ?? "") == skill.canonicalPath { return .success(()) }
                try? fm.removeItem(atPath: linkPath)
            } else if fm.fileExists(atPath: linkPath) {
                return .failure(.nonSymlinkConflict(path: linkPath, platform: platform))
            }
            do {
                try fm.createSymbolicLink(atPath: linkPath, withDestinationPath: skill.canonicalPath)
                return .success(())
            } catch {
                return .failure(.ioFailed(error.localizedDescription))
            }
        } else {
            if isSymlink(linkPath) {
                do { try fm.removeItem(atPath: linkPath) } catch { return .failure(.ioFailed(error.localizedDescription)) }
            } else if fm.fileExists(atPath: linkPath) {
                return .failure(.nonSymlinkConflict(path: linkPath, platform: platform))
            }
            if platform == .codex {
                let legacyLink = "\(home)/.codex/skills/\(skill.id)"
                if isSymlink(legacyLink) { try? fm.removeItem(atPath: legacyLink) }
            }
            return .success(())
        }
    }

    func togglePlatform(_ platform: AgentPlatform, for skill: SkillItemModel) {
        let nextEnabled = !skill.activePlatforms.contains(platform)
        if case .failure(let err) = setMount(skill: skill, platform: platform, enabled: nextEnabled) {
            showBanner(err.localizedDescription, isError: true)
            return
        }
        var current = Set(skill.activePlatforms)
        if nextEnabled { current.insert(platform) } else { current.remove(platform) }
        let mutable = skill.sourceKind == .plugin ? current.filter { $0 != .antigravity } : current
        if !mutable.isEmpty {
            registry.lastEnabledPlatforms[skill.id] = mutable.map { $0.rawValue }.sorted()
            saveRegistry()
        }
        reloadSkills(autoIngest: false)
        showBanner(nextEnabled ? "已在 \(platform.fullName) 启用「\(skill.displayName)」" : "已从 \(platform.fullName) 停用「\(skill.displayName)」")
    }

    func toggleMasterSwitch(for skill: SkillItemModel) {
        guard skill.isManageable else { return }
        let mutablePlatforms: [AgentPlatform] = skill.sourceKind == .plugin ? [.codex, .claude] : AgentPlatform.allCases
        let activeMutable = mutablePlatforms.filter { skill.activePlatforms.contains($0) }
        var firstError: MountError? = nil

        if !activeMutable.isEmpty {
            registry.lastEnabledPlatforms[skill.id] = activeMutable.map { $0.rawValue }.sorted()
            saveRegistry()
            for p in mutablePlatforms {
                if case .failure(let err) = setMount(skill: skill, platform: p, enabled: false) { firstError = firstError ?? err }
            }
            reloadSkills(autoIngest: false)
            if let err = firstError { showBanner(err.localizedDescription, isError: true) }
            else { showBanner("已停用「\(skill.displayName)」") }
        } else {
            let saved = (registry.lastEnabledPlatforms[skill.id] ?? []).compactMap { AgentPlatform(rawValue: $0) }.filter { mutablePlatforms.contains($0) }
            let defaultInstalled = mutablePlatforms.filter { isPlatformInstalled($0) }
            let targets = !saved.isEmpty ? saved : (!defaultInstalled.isEmpty ? defaultInstalled : mutablePlatforms)
            for p in targets {
                if case .failure(let err) = setMount(skill: skill, platform: p, enabled: true) { firstError = firstError ?? err }
            }
            reloadSkills(autoIngest: false)
            if let err = firstError { showBanner(err.localizedDescription, isError: true) }
            else { showBanner("已启用「\(skill.displayName)」") }
        }
    }

    func setCategoryBatchEnabled(_ categoryId: String, enabled: Bool) {
        let targets = skills.filter { $0.categoryId == categoryId && $0.sourceKind == .userVault }
        let installedDefaults = AgentPlatform.allCases.filter { isPlatformInstalled($0) }
        var conflictCount = 0
        for skill in targets {
            if enabled {
                let saved = (registry.lastEnabledPlatforms[skill.id] ?? []).compactMap { AgentPlatform(rawValue: $0) }
                let platforms = !saved.isEmpty ? saved : (!installedDefaults.isEmpty ? installedDefaults : AgentPlatform.allCases)
                for p in platforms { if case .failure = setMount(skill: skill, platform: p, enabled: true) { conflictCount += 1 } }
            } else {
                if !skill.activePlatforms.isEmpty { registry.lastEnabledPlatforms[skill.id] = skill.activePlatforms.map { $0.rawValue }.sorted() }
                for p in AgentPlatform.allCases { if case .failure = setMount(skill: skill, platform: p, enabled: false) { conflictCount += 1 } }
            }
        }
        saveRegistry()
        reloadSkills(autoIngest: false)
        if conflictCount > 0 { showBanner("批量操作完成，但有 \(conflictCount) 处非软链接冲突，请点击「刷新」归档", isError: true) }
        else { showBanner(enabled ? "已一键启用当前分类下的所有用户技能" : "已一键停用当前分类下的所有用户技能") }
    }

    // MARK: - Skill Lifecycle (Trash / Demote to Watchlist / Update)

    func trashSkill(_ skill: SkillItemModel, saveToWatchlist: Bool = false) {
        guard skill.sourceKind == .userVault else {
            showBanner("仅支持卸载用户仓库中的 Skill", isError: true)
            return
        }
        if saveToWatchlist {
            let repoUrl = skill.sourceRecord?.repoInput ?? ""
            addWatchlistItem(
                name: skill.displayName,
                kind: .skill,
                status: .skip,
                repoUrl: repoUrl,
                summary: skill.summaryLine,
                notes: "从本地仓库卸载并转存至关注收藏，保留以便后续按需重新安装。",
                tags: ["本地卸载留存"],
                installCmd: ""
            )
        }
        markInternalWrite()
        for p in AgentPlatform.allCases { _ = setMount(skill: skill, platform: p, enabled: false) }
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: skill.canonicalPath), resultingItemURL: nil)
            registry.skillCategories.removeValue(forKey: skill.id)
            registry.lastEnabledPlatforms.removeValue(forKey: skill.id)
            registry.skillSources.removeValue(forKey: skill.id)
            saveRegistry()
            reloadSkills(autoIngest: false)
            showBanner(saveToWatchlist ? "已卸载「\(skill.displayName)」并转存至关注收藏" : "已将「\(skill.displayName)」移入废纸篓")
        } catch {
            showBanner("删除失败: \(error.localizedDescription)", isError: true)
        }
    }

    func updateSkillFromGitHub(_ skill: SkillItemModel) {
        guard let src = skill.sourceRecord else {
            showBanner("「\(skill.displayName)」无 GitHub 来源记录，无法自动更新", isError: true)
            return
        }
        DispatchQueue.main.async { self.updatingSkillIds.insert(skill.id) }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("apolloagenthub-upd-\(UUID().uuidString)")
            defer {
                try? fm.removeItem(at: tmpDir)
                DispatchQueue.main.async { self.updatingSkillIds.remove(skill.id) }
            }
            if case .failure(let err) = self.runGitClone(cloneURL: src.cloneURL, branch: src.branch, destDir: tmpDir) {
                self.showBanner("更新「\(skill.displayName)」失败: \(err.localizedDescription)", isError: true)
                return
            }
            let commitHash = self.readGitHeadCommit(in: tmpDir)
            let searchRoot = src.subpath.map { tmpDir.appendingPathComponent($0) } ?? tmpDir
            let discovered = SkillParsers.discoverSkillDirectories(under: searchRoot, fallbackName: skill.id)
            guard let match = discovered.first(where: { $0.id == skill.id }) ?? (discovered.count == 1 ? discovered.first : nil) else {
                self.showBanner("未在远端仓库中定位到「\(skill.id)」", isError: true)
                return
            }
            let updatedRecord = SkillSourceRecord(repoInput: src.repoInput, cloneURL: src.cloneURL, branch: src.branch, subpath: src.subpath, commitHash: commitHash, updatedAt: Self.isoNow())
            do {
                _ = try self.installDiscoveredSkillDirs([(skill.id, match.url)], categoryId: skill.categoryId, platforms: skill.activePlatforms, sourceRecord: updatedRecord)
                DispatchQueue.main.async {
                    self.reloadSkills(autoIngest: false)
                    self.showBanner("已更新「\(skill.displayName)」至 \(commitHash.map { String($0.prefix(7)) } ?? "latest")")
                }
            } catch {
                self.showBanner("写入更新失败: \(error.localizedDescription)", isError: true)
            }
        }
    }

    // MARK: - Scenario Profiles

    func saveCurrentAsProfile(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var snapshot: [String: [String]] = [:]
        for sk in skills where sk.sourceKind == .userVault {
            snapshot[sk.id] = sk.activePlatforms.map { $0.rawValue }.sorted()
        }
        profiles.append(SkillProfile(id: "prof-" + String(UUID().uuidString.prefix(8)).lowercased(), name: trimmed, skillPlatforms: snapshot))
        saveRegistry()
        showBanner("已保存场景预设「\(trimmed)」")
    }

    func applyProfile(_ profile: SkillProfile) {
        var applied = 0
        for sk in skills where sk.sourceKind == .userVault {
            let targetSet = Set((profile.skillPlatforms[sk.id] ?? []).compactMap { AgentPlatform(rawValue: $0) })
            for p in AgentPlatform.allCases {
                let shouldEnable = targetSet.contains(p)
                if sk.activePlatforms.contains(p) != shouldEnable {
                    _ = setMount(skill: sk, platform: p, enabled: shouldEnable)
                    applied += 1
                }
            }
            if !targetSet.isEmpty { registry.lastEnabledPlatforms[sk.id] = targetSet.map { $0.rawValue }.sorted() }
        }
        saveRegistry()
        reloadSkills(autoIngest: false)
        showBanner("已切换至场景预设「\(profile.name)」（调整 \(applied) 项挂载）")
    }

    func deleteProfile(id: String) {
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        let name = profiles[idx].name
        profiles.remove(at: idx)
        saveRegistry()
        showBanner("已删除场景预设「\(name)」")
    }

    // MARK: - Health Check + CLI Dependency Scanner

    func scanHealthIssues() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        var issues: [HealthIssue] = []

        let linkDirs: [(String, String)] = [
            (platformDir(for: .antigravity), "Antigravity"),
            (platformDir(for: .codex), "Codex (~/.agents/skills)"),
            (platformDir(for: .claude), "Claude"),
            ("\(home)/.codex/skills", "Codex 旧目录 (~/.codex/skills)")
        ]
        for (dir, label) in linkDirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for name in items where !name.hasPrefix(".") {
                let full = "\(dir)/\(name)"
                if isSymlink(full) {
                    if !fm.fileExists(atPath: "\(full)/SKILL.md") {
                        issues.append(HealthIssue(id: "broken:\(full)", kind: .brokenSymlink, title: "悬空软链接：\(name)", detail: "\(label) 中的软链接指向目标已不存在或缺少 SKILL.md", targetPath: full, canAutoFix: true))
                    } else if dir == "\(home)/.codex/skills" {
                        issues.append(HealthIssue(id: "legacy-codex:\(full)", kind: .legacyCodexSymlink, title: "Codex 旧目录残留软链：\(name)", detail: "~/.codex/skills 存在软链接，可能导致停用 ~/.agents/skills 后仍被 Codex 加载", targetPath: full, canAutoFix: true))
                    }
                } else {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue, fm.fileExists(atPath: "\(full)/SKILL.md") {
                        issues.append(HealthIssue(id: "unarchived:\(full)", kind: .unarchivedExternalSkill, title: "未归档的外部 Skill：\(name)", detail: "\(label) 中存在实目录，归档入固定仓库后才可三端统一热开关", targetPath: full, canAutoFix: true))
                    }
                }
            }
        }

        if let vItems = try? fm.contentsOfDirectory(atPath: fixedVaultPath) {
            for name in vItems where !name.hasPrefix(".") {
                let full = "\(fixedVaultPath)/\(name)"
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue, !fm.fileExists(atPath: "\(full)/SKILL.md") {
                    issues.append(HealthIssue(id: "orphan:\(full)", kind: .orphanVaultDir, title: "无效仓库目录：\(name)", detail: "固定仓库中的此目录不含 SKILL.md，可能是历史遗留目录", targetPath: full, canAutoFix: true))
                }
            }
        }

        let vaultIds = Set(skills.filter { $0.sourceKind == .userVault }.map { $0.id })
        if let pDirs = try? fm.contentsOfDirectory(atPath: agyPluginsDir()) {
            for pDir in pDirs where !pDir.hasPrefix(".") {
                let sSub = "\(agyPluginsDir())/\(pDir)/skills"
                if let pSkills = try? fm.contentsOfDirectory(atPath: sSub) {
                    for sName in pSkills where vaultIds.contains(sName) {
                        issues.append(HealthIssue(id: "shadow:\(pDir):\(sName)", kind: .shadowConflict, title: "同名遮蔽冲突：\(sName)", detail: "用户固定仓库与插件「\(pDir)」均包含同名 Skill，界面优先展示用户仓库版本", targetPath: "\(sSub)/\(sName)", canAutoFix: false))
                    }
                }
            }
        }

        // Check MCP configured command executables
        for srv in mcpServers {
            for (pf, raw) in srv.rawConfigs {
                if let cmd = raw.command, !cmd.isEmpty, locateBinary(cmd) == nil {
                    issues.append(HealthIssue(
                        id: "mcp-cmd:\(srv.id):\(pf.rawValue)",
                        kind: .missingMcpCommand,
                        title: "MCP 依赖命令缺失：\(cmd)",
                        detail: "\(pf.fullName) 中的 MCP 服务「\(srv.id)」引用了命令 \(cmd)，但在常见路径中未检测到可执行文件",
                        targetPath: srv.configPaths[pf] ?? cmd,
                        canAutoFix: false
                    ))
                }
            }
        }

        // Read-only AI ecosystem CLI readiness check
        let coreClis = ["codex", "claude", "agy", "git", "node", "npx", "uvx", "python3"]
        cliChecks = coreClis.map { bin in
            let found = locateBinary(bin)
            return CliCheckItem(id: bin, name: bin, installed: found != nil, path: found)
        }

        healthIssues = issues
    }

    func fixHealthIssue(_ issue: HealthIssue) {
        guard issue.canAutoFix else { return }
        markInternalWrite()
        let fm = FileManager.default
        do {
            switch issue.kind {
            case .brokenSymlink, .legacyCodexSymlink: try fm.removeItem(atPath: issue.targetPath)
            case .orphanVaultDir: try fm.trashItem(at: URL(fileURLWithPath: issue.targetPath), resultingItemURL: nil)
            case .unarchivedExternalSkill: ingestExternalSkillsIntoVault()
            case .shadowConflict, .missingMcpCommand: break
            }
            reloadSkills(autoIngest: false)
            showBanner("已修复：\(issue.title)")
        } catch {
            showBanner("修复失败: \(error.localizedDescription)", isError: true)
        }
    }

    func fixAllHealthIssues() {
        let fixables = healthIssues.filter { $0.canAutoFix }
        guard !fixables.isEmpty else { return }
        markInternalWrite()
        let fm = FileManager.default
        var fixedCount = 0, needIngest = false
        for issue in fixables {
            switch issue.kind {
            case .brokenSymlink, .legacyCodexSymlink: if (try? fm.removeItem(atPath: issue.targetPath)) != nil { fixedCount += 1 }
            case .orphanVaultDir: if (try? fm.trashItem(at: URL(fileURLWithPath: issue.targetPath), resultingItemURL: nil)) != nil { fixedCount += 1 }
            case .unarchivedExternalSkill: needIngest = true; fixedCount += 1
            case .shadowConflict, .missingMcpCommand: break
            }
        }
        if needIngest { ingestExternalSkillsIntoVault() }
        reloadSkills(autoIngest: false)
        showBanner("已自动修复 \(fixedCount) 项环境问题")
    }

    // MARK: - Skill Categories & Vault Path

    func assignCategory(_ categoryId: String, to skillId: String) {
        registry.skillCategories[skillId] = categoryId
        saveRegistry()
        reloadSkills(autoIngest: false)
        if let cat = categories.first(where: { $0.id == categoryId }) { showBanner("已归入「\(cat.name)」") }
    }

    func addCategory(name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !categories.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return nil }
        let id = "cat-" + String(UUID().uuidString.prefix(8)).lowercased()
        categories.append(SkillCategory(id: id, name: trimmed, sortOrder: categories.count))
        saveRegistry()
        reloadSkills(autoIngest: false)
        showBanner("已新增分类「\(trimmed)」")
        return id
    }


    func renameCategory(id: String, newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !categories.contains(where: { $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            showBanner("分组名称为空或已存在", isError: true)
            return
        }
        guard let index = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[index].name = name
        saveRegistry()
    }

    @discardableResult
    func deleteCategory(id: String, migrateTo targetCategoryId: String) -> Bool {
        guard id != targetCategoryId, categories.contains(where: { $0.id == id }),
              categories.contains(where: { $0.id == targetCategoryId }) else { return false }
        registry.skillCategories = registry.skillCategories.mapValues { $0 == id ? targetCategoryId : $0 }
        categories.removeAll { $0.id == id }
        saveRegistry()
        reloadSkills(autoIngest: false)
        showBanner("已迁移资产并删除分组")
        return true
    }

    func reorderCategories(fromId: String, toId: String) {
        guard fromId != toId, let from = categories.firstIndex(where: { $0.id == fromId }),
              let to = categories.firstIndex(where: { $0.id == toId }) else { return }
        let moved = categories.remove(at: from)
        categories.insert(moved, at: to)
        saveRegistry()
    }

    func renameMcpCategory(id: String, newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !mcpCategories.contains(where: { $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            showBanner("分组名称为空或已存在", isError: true)
            return
        }
        guard let index = mcpCategories.firstIndex(where: { $0.id == id }) else { return }
        mcpCategories[index].name = name
        saveRegistry()
    }

    @discardableResult
    func deleteMcpCategory(id: String, migrateTo targetCategoryId: String) -> Bool {
        guard id != targetCategoryId, mcpCategories.contains(where: { $0.id == id }),
              mcpCategories.contains(where: { $0.id == targetCategoryId }) else { return false }
        registry.mcpCategoryMap = registry.mcpCategoryMap.mapValues { $0 == id ? targetCategoryId : $0 }
        mcpCategories.removeAll { $0.id == id }
        saveRegistry()
        reloadMcpServers()
        showBanner("已迁移资产并删除分组")
        return true
    }

    func reorderMcpCategories(fromId: String, toId: String) {
        guard fromId != toId, let from = mcpCategories.firstIndex(where: { $0.id == fromId }),
              let to = mcpCategories.firstIndex(where: { $0.id == toId }) else { return }
        let moved = mcpCategories.remove(at: from)
        mcpCategories.insert(moved, at: to)
        saveRegistry()
    }

    func renamePluginCategory(id: String, newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !pluginCategories.contains(where: { $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            showBanner("分组名称为空或已存在", isError: true)
            return
        }
        guard let index = pluginCategories.firstIndex(where: { $0.id == id }) else { return }
        pluginCategories[index].name = name
        saveRegistry()
    }

    @discardableResult
    func deletePluginCategory(id: String, migrateTo targetCategoryId: String) -> Bool {
        guard id != targetCategoryId, pluginCategories.contains(where: { $0.id == id }),
              pluginCategories.contains(where: { $0.id == targetCategoryId }) else { return false }
        registry.pluginCategoryMap = registry.pluginCategoryMap.mapValues { $0 == id ? targetCategoryId : $0 }
        pluginCategories.removeAll { $0.id == id }
        saveRegistry()
        reloadPlugins()
        showBanner("已迁移资产并删除分组")
        return true
    }

    func reorderPluginCategories(fromId: String, toId: String) {
        guard fromId != toId, let from = pluginCategories.firstIndex(where: { $0.id == fromId }),
              let to = pluginCategories.firstIndex(where: { $0.id == toId }) else { return }
        let moved = pluginCategories.remove(at: from)
        pluginCategories.insert(moved, at: to)
        saveRegistry()
    }

    func changeFixedVaultDirectory(to newPath: String) {
        let normalized = (newPath as NSString).expandingTildeInPath
        guard !normalized.isEmpty, normalized != fixedVaultPath else { return }
        markInternalWrite()
        let fm = FileManager.default
        let oldVault = fixedVaultPath
        do {
            try fm.createDirectory(atPath: normalized, withIntermediateDirectories: true)
            if let items = try? fm.contentsOfDirectory(atPath: oldVault) {
                for item in items {
                    let src = "\(oldVault)/\(item)", dst = "\(normalized)/\(item)"
                    if fm.fileExists(atPath: dst) {
                        if item == ".skill_registry.json" || item == ".watchlist.json" {
                            try? fm.removeItem(atPath: dst)
                            try fm.moveItem(atPath: src, toPath: dst)
                        }
                        continue
                    }
                    try fm.moveItem(atPath: src, toPath: dst)
                }
            }
            fixedVaultPath = normalized
            UserDefaults.standard.set(normalized, forKey: Self.vaultDirDefaultsKey)
            for p in AgentPlatform.allCases {
                let pDir = platformDir(for: p)
                guard let entries = try? fm.contentsOfDirectory(atPath: pDir) else { continue }
                for name in entries {
                    let linkPath = "\(pDir)/\(name)"
                    if isSymlink(linkPath), fm.fileExists(atPath: "\(normalized)/\(name)/SKILL.md") {
                        try? fm.removeItem(atPath: linkPath)
                        try? fm.createSymbolicLink(atPath: linkPath, withDestinationPath: "\(normalized)/\(name)")
                    }
                }
            }
            reloadSkills()
            loadWatchlist()
            refreshWatchers()
            showBanner("固定仓库已切换至 \(Self.shortenHomePath(normalized))")
        } catch {
            showBanner("切换目录失败: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Skill Import

    func cancelActiveImport() {
        importCancelled = true
        activeImportProcess?.terminate()
        activeImportProcess = nil
        DispatchQueue.main.async { self.isImporting = false; self.showBanner("已取消当前导入操作") }
    }

    private func runGitClone(cloneURL: String, branch: String?, destDir: URL, timeoutSeconds: Double = 35) -> Result<Void, NSError> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        var args = ["clone", "--depth", "1"]
        if let b = branch, !b.isEmpty { args.append(contentsOf: ["-b", b]) }
        args.append(contentsOf: [cloneURL, destDir.path])
        task.arguments = args
        let errPipe = Pipe()
        task.standardOutput = Pipe()
        task.standardError = errPipe
        DispatchQueue.main.async { self.activeImportProcess = task }
        var timedOut = false
        let timer = DispatchWorkItem { if task.isRunning { timedOut = true; task.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: timer)
        do { try task.run(); task.waitUntilExit(); timer.cancel() } catch {
            timer.cancel()
            return .failure(NSError(domain: "AgentHub", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法启动 git: \(error.localizedDescription)"]))
        }
        if importCancelled { return .failure(NSError(domain: "AgentHub", code: -2, userInfo: [NSLocalizedDescriptionKey: "已取消克隆"])) }
        if timedOut { return .failure(NSError(domain: "AgentHub", code: -3, userInfo: [NSLocalizedDescriptionKey: "GitHub 克隆超时（超过 \(Int(timeoutSeconds)) 秒）"])) }
        guard task.terminationStatus == 0 else {
            let errMsg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "git clone 失败"
            return .failure(NSError(domain: "AgentHub", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "GitHub 克隆失败: \(errMsg.prefix(120))"]))
        }
        return .success(())
    }

    private func readGitHeadCommit(in repoDir: URL) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["-C", repoDir.path, "rev-parse", "HEAD"]
        let pipe = Pipe()
        task.standardOutput = pipe; task.standardError = Pipe()
        do {
            try task.run(); task.waitUntilExit()
            if task.terminationStatus == 0 {
                return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}
        return nil
    }

    private static func isoNow() -> String { ISO8601DateFormatter().string(from: Date()) }

    private func installDiscoveredSkillDirs(
        _ dirs: [(id: String, url: URL)],
        categoryId: String,
        platforms: Set<AgentPlatform>,
        sourceRecord: SkillSourceRecord?
    ) throws -> [String] {
        markInternalWrite()
        let fm = FileManager.default
        try fm.createDirectory(atPath: fixedVaultPath, withIntermediateDirectories: true)
        var installed: [String] = []
        for item in dirs {
            let safeId = item.id.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
            guard !safeId.isEmpty, !safeId.hasPrefix(".") else { continue }
            let destPath = "\(fixedVaultPath)/\(safeId)"
            let destURL = URL(fileURLWithPath: destPath)
            if fm.fileExists(atPath: destPath) { try fm.removeItem(at: destURL) }
            try fm.copyItem(at: item.url, to: destURL)
            if fm.fileExists(atPath: "\(destPath)/.git") { try? fm.removeItem(atPath: "\(destPath)/.git") }
            registry.skillCategories[safeId] = categoryId
            if !platforms.isEmpty { registry.lastEnabledPlatforms[safeId] = platforms.map { $0.rawValue }.sorted() }
            if let rec = sourceRecord { registry.skillSources[safeId] = rec }
            for p in platforms {
                let targetDir = platformDir(for: p)
                try? fm.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
                let linkPath = "\(targetDir)/\(safeId)"
                if isSymlink(linkPath) { try? fm.removeItem(atPath: linkPath) }
                if !fm.fileExists(atPath: linkPath) { try? fm.createSymbolicLink(atPath: linkPath, withDestinationPath: destPath) }
            }
            installed.append(safeId)
        }
        saveRegistry()
        return installed
    }

    func confirmPendingOverwrite() {
        guard let ctx = pendingOverwrite else { return }
        pendingOverwrite = nil
        defer { if let tmp = ctx.tempDirToCleanup { try? FileManager.default.removeItem(at: tmp) } }
        do {
            let names = try installDiscoveredSkillDirs(ctx.discovered, categoryId: ctx.categoryId, platforms: ctx.platforms, sourceRecord: ctx.sourceRecord)
            reloadSkills(autoIngest: false)
            showBanner("已覆盖安装 \(names.count) 个 Skill: \(names.joined(separator: ", "))")
            ctx.onSuccess?()
        } catch {
            showBanner("覆盖安装失败: \(error.localizedDescription)", isError: true)
        }
    }

    func cancelPendingOverwrite() {
        if let tmp = pendingOverwrite?.tempDirToCleanup { try? FileManager.default.removeItem(at: tmp) }
        pendingOverwrite = nil
        showBanner("已取消覆盖安装")
    }

    func importLocalSkillFolder(from sourceURL: URL, categoryId: String, platforms: Set<AgentPlatform>) {
        let fm = FileManager.default
        let targets = SkillParsers.discoverSkillDirectories(under: sourceURL, fallbackName: sourceURL.lastPathComponent)
        guard !targets.isEmpty else { showBanner("所选目录中未找到 SKILL.md 文件", isError: true); return }
        let conflicts = targets.map { $0.id }.filter { fm.fileExists(atPath: "\(fixedVaultPath)/\($0)") }
        if !conflicts.isEmpty {
            pendingOverwrite = PendingOverwriteContext(existingSkillIds: conflicts, discovered: targets, tempDirToCleanup: nil, categoryId: categoryId, platforms: platforms, sourceRecord: nil, onSuccess: nil)
            return
        }
        do {
            let names = try installDiscoveredSkillDirs(targets, categoryId: categoryId, platforms: platforms, sourceRecord: nil)
            reloadSkills(autoIngest: false)
            showBanner("已导入 \(names.joined(separator: ", ")) 到固定仓库")
        } catch {
            showBanner("导入失败: \(error.localizedDescription)", isError: true)
        }
    }

    func installGitHubSkill(repoInput: String, categoryId: String, platforms: Set<AgentPlatform>, onSuccess: (() -> Void)? = nil) {
        guard let parsed = SkillParsers.parseGitHubInput(repoInput) else {
            showBanner("请输入有效的 GitHub 地址或 owner/repo", isError: true)
            return
        }
        DispatchQueue.main.async { self.isImporting = true }
        importCancelled = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("apolloagenthub-gh-\(UUID().uuidString)")
            var keepTempForConfirm = false
            defer {
                if !keepTempForConfirm { try? fm.removeItem(at: tmpDir) }
                DispatchQueue.main.async { self.activeImportProcess = nil; self.isImporting = false }
            }
            if case .failure(let err) = self.runGitClone(cloneURL: parsed.cloneURL, branch: parsed.branch, destDir: tmpDir) {
                if !self.importCancelled { self.showBanner(err.localizedDescription, isError: true) }
                return
            }
            let commitHash = self.readGitHeadCommit(in: tmpDir)
            let searchRoot = parsed.subpath.map { tmpDir.appendingPathComponent($0) } ?? tmpDir
            let discovered = SkillParsers.discoverSkillDirectories(under: searchRoot, fallbackName: parsed.fallbackName)
            guard !discovered.isEmpty else {
                self.showBanner("仓库中未找到包含 SKILL.md 的技能目录", isError: true)
                return
            }
            let sourceRec = SkillSourceRecord(repoInput: repoInput.trimmingCharacters(in: .whitespacesAndNewlines), cloneURL: parsed.cloneURL, branch: parsed.branch, subpath: parsed.subpath, commitHash: commitHash, updatedAt: Self.isoNow())
            let conflicts = discovered.map { $0.id }.filter { fm.fileExists(atPath: "\(self.fixedVaultPath)/\($0)") }
            if !conflicts.isEmpty {
                keepTempForConfirm = true
                DispatchQueue.main.async {
                    self.pendingOverwrite = PendingOverwriteContext(existingSkillIds: conflicts, discovered: discovered, tempDirToCleanup: tmpDir, categoryId: categoryId, platforms: platforms, sourceRecord: sourceRec, onSuccess: onSuccess)
                }
                return
            }
            do {
                let installed = try self.installDiscoveredSkillDirs(discovered, categoryId: categoryId, platforms: platforms, sourceRecord: sourceRec)
                DispatchQueue.main.async {
                    self.reloadSkills(autoIngest: false)
                    self.showBanner("已从 GitHub 安装 \(installed.count) 个 Skill: \(installed.joined(separator: ", "))")
                    onSuccess?()
                }
            } catch {
                self.showBanner("安装到固定仓库失败: \(error.localizedDescription)", isError: true)
            }
        }
    }
}
