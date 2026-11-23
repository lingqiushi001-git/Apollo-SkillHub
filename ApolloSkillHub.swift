import AppKit
import SwiftUI

// MARK: - Theme Palette

struct ThemePalette {
    let isDark: Bool

    var windowBg: Color {
        isDark ? Color(red: 0.06, green: 0.08, blue: 0.12) : Color(red: 0.96, green: 0.97, blue: 0.99)
    }
    var sidebarBg: Color {
        isDark ? Color(red: 0.08, green: 0.10, blue: 0.16) : Color(red: 0.93, green: 0.95, blue: 0.98)
    }
    var cardBg: Color {
        isDark ? Color(red: 0.11, green: 0.14, blue: 0.20) : Color.white
    }
    var cardBorder: Color {
        isDark ? Color(red: 0.20, green: 0.25, blue: 0.35) : Color(red: 0.83, green: 0.87, blue: 0.92)
    }
    var primaryText: Color {
        isDark ? Color(red: 0.97, green: 0.98, blue: 1.00) : Color(red: 0.07, green: 0.10, blue: 0.18)
    }
    var secondaryText: Color {
        isDark ? Color(red: 0.76, green: 0.82, blue: 0.90) : Color(red: 0.30, green: 0.37, blue: 0.46)
    }
    var mutedText: Color {
        isDark ? Color(red: 0.56, green: 0.63, blue: 0.74) : Color(red: 0.47, green: 0.53, blue: 0.62)
    }
    var inputBg: Color {
        isDark ? Color(red: 0.08, green: 0.10, blue: 0.15) : Color(red: 0.95, green: 0.96, blue: 0.99)
    }
    var chipBg: Color {
        isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.06)
    }
    var divider: Color {
        isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }
    var accentBlue: Color {
        isDark ? Color(red: 0.36, green: 0.66, blue: 1.00) : Color(red: 0.14, green: 0.44, blue: 0.92)
    }
    var purpleAccent: Color {
        isDark ? Color(red: 0.66, green: 0.50, blue: 1.00) : Color(red: 0.46, green: 0.26, blue: 0.88)
    }
    var okColor: Color {
        isDark ? Color(red: 0.20, green: 0.84, blue: 0.52) : Color(red: 0.10, green: 0.66, blue: 0.38)
    }
    var warnColor: Color {
        isDark ? Color(red: 0.99, green: 0.73, blue: 0.20) : Color(red: 0.82, green: 0.48, blue: 0.02)
    }
    var dangerColor: Color {
        isDark ? Color(red: 1.00, green: 0.38, blue: 0.40) : Color(red: 0.84, green: 0.16, blue: 0.20)
    }
    var switchOffTrack: Color {
        isDark ? Color(red: 0.24, green: 0.29, blue: 0.39) : Color(red: 0.78, green: 0.82, blue: 0.88)
    }
}

// MARK: - Domain Models

enum AgentPlatform: String, CaseIterable, Codable, Identifiable {
    case antigravity
    case codex
    case claude

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .antigravity: return "AGY"
        case .codex: return "Codex"
        case .claude: return "Claude"
        }
    }

    var fullName: String {
        switch self {
        case .antigravity: return "Antigravity"
        case .codex: return "Codex"
        case .claude: return "Claude"
        }
    }
}

enum SkillSourceKind: String, Codable {
    case userVault
    case plugin
    case builtin

    var badgeTitle: String {
        switch self {
        case .userVault: return "用户全局"
        case .plugin: return "插件"
        case .builtin: return "内置"
        }
    }
}

struct SkillCategory: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var sortOrder: Int
}

struct SkillRegistryFile: Codable {
    var categories: [SkillCategory]
    var skillCategories: [String: String]
    var lastEnabledPlatforms: [String: [String]]
}

struct SkillItemModel: Identifiable, Equatable {
    let id: String
    var displayName: String
    var summaryLine: String
    var descriptionText: String
    var triggerHints: [String]
    var canonicalPath: String
    var skillMdPath: String
    var sourceKind: SkillSourceKind
    var pluginName: String?
    var categoryId: String
    var activePlatforms: Set<AgentPlatform>

    var isAnyActive: Bool {
        !activePlatforms.isEmpty || sourceKind == .builtin
    }

    var isManageable: Bool {
        sourceKind != .builtin
    }
}

// MARK: - SkillStore (Canonical Vault + 3-Platform Symlink Matrix)

final class SkillStore: ObservableObject {
    private static let vaultDirDefaultsKey = "apolloskillhub_vault_dir"
    private static let showBuiltinDefaultsKey = "apolloskillhub_show_builtins"
    private static let darkThemeDefaultsKey = "apolloskillhub_dark_theme"

    @Published var fixedVaultPath: String
    @Published var categories: [SkillCategory] = []
    @Published var skills: [SkillItemModel] = []
    @Published var showBuiltins: Bool {
        didSet { UserDefaults.standard.set(showBuiltins, forKey: Self.showBuiltinDefaultsKey) }
    }
    @Published var isDarkTheme: Bool {
        didSet { UserDefaults.standard.set(isDarkTheme, forKey: Self.darkThemeDefaultsKey) }
    }
    @Published var isImporting: Bool = false
    @Published var statusBanner: String? = nil
    @Published var statusIsError: Bool = false

    private var registry = SkillRegistryFile(categories: [], skillCategories: [:], lastEnabledPlatforms: [:])
    private var bannerToken = 0

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let savedVault = UserDefaults.standard.string(forKey: Self.vaultDirDefaultsKey)
            ?? UserDefaults.standard.string(forKey: "agentmeter_skills_vault_dir")
        if let saved = savedVault, !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.fixedVaultPath = (saved as NSString).expandingTildeInPath
        } else {
            self.fixedVaultPath = "\(home)/.agents/skills-vault"
        }
        self.showBuiltins = UserDefaults.standard.bool(forKey: Self.showBuiltinDefaultsKey)
        if UserDefaults.standard.object(forKey: Self.darkThemeDefaultsKey) == nil {
            self.isDarkTheme = true
        } else {
            self.isDarkTheme = UserDefaults.standard.bool(forKey: Self.darkThemeDefaultsKey)
        }
        reloadSkills()
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

    private var registryPath: String {
        "\(fixedVaultPath)/.skill_registry.json"
    }

    private static var defaultCategories: [SkillCategory] {
        [
            SkillCategory(id: "ui-frontend", name: "🎨 UI 与前端设计", sortOrder: 0),
            SkillCategory(id: "video-media", name: "🎬 视频与多媒体", sortOrder: 1),
            SkillCategory(id: "finance-thinking", name: "📈 投研与思维框架", sortOrder: 2),
            SkillCategory(id: "re-debug", name: "🔍 逆向与调试工程", sortOrder: 3),
            SkillCategory(id: "info-productivity", name: "📰 资讯与效率办公", sortOrder: 4),
            SkillCategory(id: "system-config", name: "⚙️ 系统与配置管理", sortOrder: 5)
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
        "migrate-agent-settings": "system-config",
        "migrate-workflows": "system-config",
        "plugin": "system-config",
        "swarm_monitor": "system-config",
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
        return categories.first?.id ?? "system-config"
    }

    func showBanner(_ message: String, isError: Bool = false) {
        DispatchQueue.main.async {
            self.bannerToken += 1
            let token = self.bannerToken
            self.statusBanner = message
            self.statusIsError = isError
            DispatchQueue.main.asyncAfter(deadline: .now() + (isError ? 7.0 : 3.8)) {
                if self.bannerToken == token {
                    self.statusBanner = nil
                }
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
        if let data = try? Data(contentsOf: URL(fileURLWithPath: registryPath)),
           let decoded = try? JSONDecoder().decode(SkillRegistryFile.self, from: data),
           !decoded.categories.isEmpty {
            registry = decoded
            categories = registry.categories.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            var previousPlatforms: [String: [String]] = [:]
            if let data = try? Data(contentsOf: URL(fileURLWithPath: registryPath)),
               let broken = try? JSONDecoder().decode(SkillRegistryFile.self, from: data) {
                previousPlatforms = broken.lastEnabledPlatforms
            }
            registry = SkillRegistryFile(
                categories: Self.defaultCategories,
                skillCategories: Self.defaultSkillMappings,
                lastEnabledPlatforms: previousPlatforms
            )
            categories = registry.categories
            saveRegistry()
        }
    }

    private func saveRegistry() {
        let sorted = categories.enumerated().map { idx, cat in
            SkillCategory(id: cat.id, name: cat.name, sortOrder: idx)
        }
        categories = sorted
        registry.categories = sorted
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(registry) {
            try? FileManager.default.createDirectory(atPath: fixedVaultPath, withIntermediateDirectories: true)
            try? data.write(to: URL(fileURLWithPath: registryPath), options: .atomic)
        }
    }

    private func isSymlink(_ path: String) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil
    }

    /// Scans external agent skill folders and ingests any newly installed real directories into `fixedVaultPath`.
    private func ingestExternalSkillsIntoVault() {
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
            for name in items {
                if name.hasPrefix(".") { continue }
                let itemPath = "\(entry.path)/\(name)"
                let vaultSkillPath = "\(fixedVaultPath)/\(name)"

                if isSymlink(itemPath) {
                    if fm.fileExists(atPath: "\(vaultSkillPath)/SKILL.md") {
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
                        do {
                            try fm.moveItem(atPath: itemPath, toPath: vaultSkillPath)
                        } catch {
                            continue
                        }
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
        let fm = FileManager.default
        let linkPath = "\(platformDir(for: platform))/\(skillId)"
        return fm.fileExists(atPath: "\(linkPath)/SKILL.md")
    }

    func reloadSkills() {
        ensureDirectoriesExist()
        ingestExternalSkillsIntoVault()
        loadRegistry()

        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        var loaded: [SkillItemModel] = []
        var seenIds = Set<String>()
        var registryDirty = false

        // 1. User skills in fixedVaultPath
        if let vaultEntries = try? fm.contentsOfDirectory(atPath: fixedVaultPath) {
            for name in vaultEntries.sorted() {
                if name.hasPrefix(".") { continue }
                let dir = "\(fixedVaultPath)/\(name)"
                guard fm.fileExists(atPath: "\(dir)/SKILL.md") else { continue }

                let meta = parseSkillMetadata(skillDir: dir, fallbackId: name)
                let catId: String
                if let assigned = registry.skillCategories[name], categories.contains(where: { $0.id == assigned }) {
                    catId = assigned
                } else {
                    catId = inferCategoryId(for: name, desc: meta.desc)
                    registry.skillCategories[name] = catId
                    registryDirty = true
                }

                var active = Set<AgentPlatform>()
                for p in AgentPlatform.allCases {
                    if hasActiveMount(skillId: name, platform: p) {
                        active.insert(p)
                    }
                }
                if !active.isEmpty && registry.lastEnabledPlatforms[name] == nil {
                    registry.lastEnabledPlatforms[name] = active.map { $0.rawValue }.sorted()
                    registryDirty = true
                }

                seenIds.insert(name)
                loaded.append(SkillItemModel(
                    id: name,
                    displayName: meta.name,
                    summaryLine: meta.summary,
                    descriptionText: meta.desc,
                    triggerHints: meta.triggers,
                    canonicalPath: dir,
                    skillMdPath: meta.skillMdPath,
                    sourceKind: .userVault,
                    pluginName: nil,
                    categoryId: catId,
                    activePlatforms: active
                ))
            }
        }

        // 2. Plugin skills (~/.gemini/config/plugins/*/skills/*)
        let pluginsRoot = "\(home)/.gemini/config/plugins"
        if let pluginDirs = try? fm.contentsOfDirectory(atPath: pluginsRoot) {
            for pluginDirName in pluginDirs.sorted() {
                let skillsSub = "\(pluginsRoot)/\(pluginDirName)/skills"
                guard let pSkills = try? fm.contentsOfDirectory(atPath: skillsSub) else { continue }
                for name in pSkills.sorted() {
                    if name.hasPrefix(".") || seenIds.contains(name) { continue }
                    let dir = "\(skillsSub)/\(name)"
                    guard fm.fileExists(atPath: "\(dir)/SKILL.md") else { continue }

                    let meta = parseSkillMetadata(skillDir: dir, fallbackId: name)
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
                        id: name,
                        displayName: meta.name,
                        summaryLine: meta.summary,
                        descriptionText: meta.desc,
                        triggerHints: meta.triggers,
                        canonicalPath: dir,
                        skillMdPath: meta.skillMdPath,
                        sourceKind: .plugin,
                        pluginName: pluginDirName,
                        categoryId: catId,
                        activePlatforms: active
                    ))
                }
            }
        }

        // 3. Built-in Antigravity skills (~/.gemini/antigravity/builtin/skills/*)
        let builtinRoot = "\(home)/.gemini/antigravity/builtin/skills"
        if let bSkills = try? fm.contentsOfDirectory(atPath: builtinRoot) {
            for name in bSkills.sorted() {
                if name.hasPrefix(".") || seenIds.contains(name) { continue }
                let dir = "\(builtinRoot)/\(name)"
                guard fm.fileExists(atPath: "\(dir)/SKILL.md") else { continue }

                let meta = parseSkillMetadata(skillDir: dir, fallbackId: name)
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
                    id: name,
                    displayName: meta.name,
                    summaryLine: meta.summary,
                    descriptionText: meta.desc,
                    triggerHints: meta.triggers,
                    canonicalPath: dir,
                    skillMdPath: meta.skillMdPath,
                    sourceKind: .builtin,
                    pluginName: nil,
                    categoryId: catId,
                    activePlatforms: [.antigravity]
                ))
            }
        }

        if registryDirty {
            saveRegistry()
        }

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
    }

    private func setMount(skill: SkillItemModel, platform: AgentPlatform, enabled: Bool) {
        guard skill.sourceKind != .builtin else { return }
        if skill.sourceKind == .plugin && platform == .antigravity { return }

        let fm = FileManager.default
        let targetDir = platformDir(for: platform)
        try? fm.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
        let linkPath = "\(targetDir)/\(skill.id)"

        if enabled {
            if isSymlink(linkPath) {
                let currentDest = (try? fm.destinationOfSymbolicLink(atPath: linkPath)) ?? ""
                if currentDest == skill.canonicalPath { return }
                try? fm.removeItem(atPath: linkPath)
            } else if fm.fileExists(atPath: linkPath) {
                return
            }
            try? fm.createSymbolicLink(atPath: linkPath, withDestinationPath: skill.canonicalPath)
        } else {
            if isSymlink(linkPath) {
                try? fm.removeItem(atPath: linkPath)
            }
        }
    }

    func togglePlatform(_ platform: AgentPlatform, for skill: SkillItemModel) {
        let nextEnabled = !skill.activePlatforms.contains(platform)
        setMount(skill: skill, platform: platform, enabled: nextEnabled)

        var current = Set(skill.activePlatforms)
        if nextEnabled {
            current.insert(platform)
        } else {
            current.remove(platform)
        }
        let mutable = skill.sourceKind == .plugin ? current.filter { $0 != .antigravity } : current
        if !mutable.isEmpty {
            registry.lastEnabledPlatforms[skill.id] = mutable.map { $0.rawValue }.sorted()
            saveRegistry()
        }
        reloadSkills()
        showBanner(nextEnabled ? "✅ 已在 \(platform.fullName) 启用「\(skill.displayName)」" : "⏸ 已从 \(platform.fullName) 停用「\(skill.displayName)」")
    }

    func toggleMasterSwitch(for skill: SkillItemModel) {
        guard skill.isManageable else { return }
        let mutablePlatforms: [AgentPlatform] = skill.sourceKind == .plugin
            ? [.codex, .claude]
            : AgentPlatform.allCases
        let activeMutable = mutablePlatforms.filter { skill.activePlatforms.contains($0) }

        if !activeMutable.isEmpty {
            registry.lastEnabledPlatforms[skill.id] = activeMutable.map { $0.rawValue }.sorted()
            saveRegistry()
            for p in mutablePlatforms {
                setMount(skill: skill, platform: p, enabled: false)
            }
            reloadSkills()
            showBanner("⏸ 已停用「\(skill.displayName)」")
        } else {
            let saved = (registry.lastEnabledPlatforms[skill.id] ?? [])
                .compactMap { AgentPlatform(rawValue: $0) }
                .filter { mutablePlatforms.contains($0) }
            let defaultInstalled = mutablePlatforms.filter { isPlatformInstalled($0) }
            let targets = !saved.isEmpty ? saved : (!defaultInstalled.isEmpty ? defaultInstalled : mutablePlatforms)
            for p in targets {
                setMount(skill: skill, platform: p, enabled: true)
            }
            reloadSkills()
            showBanner("✅ 已启用「\(skill.displayName)」")
        }
    }

    func setCategoryBatchEnabled(_ categoryId: String, enabled: Bool) {
        let targets = skills.filter { $0.categoryId == categoryId && $0.sourceKind == .userVault }
        let installedDefaults = AgentPlatform.allCases.filter { isPlatformInstalled($0) }
        for skill in targets {
            if enabled {
                let saved = (registry.lastEnabledPlatforms[skill.id] ?? []).compactMap { AgentPlatform(rawValue: $0) }
                let platforms = !saved.isEmpty ? saved : (!installedDefaults.isEmpty ? installedDefaults : AgentPlatform.allCases)
                for p in platforms {
                    setMount(skill: skill, platform: p, enabled: true)
                }
            } else {
                if !skill.activePlatforms.isEmpty {
                    registry.lastEnabledPlatforms[skill.id] = skill.activePlatforms.map { $0.rawValue }.sorted()
                }
                for p in AgentPlatform.allCases {
                    setMount(skill: skill, platform: p, enabled: false)
                }
            }
        }
        saveRegistry()
        reloadSkills()
        showBanner(enabled ? "✅ 已一键启用当前分类下的所有用户技能" : "⏸ 已一键停用当前分类下的所有用户技能")
    }

    func assignCategory(_ categoryId: String, to skillId: String) {
        registry.skillCategories[skillId] = categoryId
        saveRegistry()
        reloadSkills()
        if let cat = categories.first(where: { $0.id == categoryId }) {
            showBanner("🏷️ 已归入「\(cat.name)」")
        }
    }

    func addCategory(name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let id = "cat-" + String(UUID().uuidString.prefix(8)).lowercased()
        let cat = SkillCategory(id: id, name: trimmed, sortOrder: categories.count)
        categories.append(cat)
        saveRegistry()
        reloadSkills()
        showBanner("✅ 已新增分类「\(trimmed)」")
        return id
    }

    func renameCategory(id: String, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = categories.firstIndex(where: { $0.id == id }) {
            categories[idx].name = trimmed
            saveRegistry()
            reloadSkills()
            showBanner("✅ 分类已重命名为「\(trimmed)」")
        }
    }

    func deleteCategory(id: String) -> Bool {
        guard categories.count > 1 else {
            showBanner("至少需要保留 1 个分类", isError: true)
            return false
        }
        guard let target = categories.first(where: { $0.id == id }),
              let fallback = categories.first(where: { $0.id != id }) else { return false }
        categories.removeAll { $0.id == id }
        for (k, v) in registry.skillCategories where v == id {
            registry.skillCategories[k] = fallback.id
        }
        saveRegistry()
        reloadSkills()
        showBanner("🗑 已删除「\(target.name)」，原技能已归入「\(fallback.name)」")
        return true
    }

    func changeFixedVaultDirectory(to newPath: String) {
        let normalized = (newPath as NSString).expandingTildeInPath
        guard !normalized.isEmpty, normalized != fixedVaultPath else { return }
        let fm = FileManager.default
        let oldVault = fixedVaultPath

        do {
            try fm.createDirectory(atPath: normalized, withIntermediateDirectories: true)
            if let items = try? fm.contentsOfDirectory(atPath: oldVault) {
                for item in items {
                    let src = "\(oldVault)/\(item)"
                    let dst = "\(normalized)/\(item)"
                    if fm.fileExists(atPath: dst) {
                        if item == ".skill_registry.json" {
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
            showBanner("✅ 固定仓库已切换至 \(Self.shortenHomePath(normalized))")
        } catch {
            showBanner("切换目录失败: \(error.localizedDescription)", isError: true)
        }
    }

    private func installDiscoveredSkillDirs(
        _ dirs: [(id: String, url: URL)],
        categoryId: String,
        platforms: Set<AgentPlatform>
    ) throws -> [String] {
        let fm = FileManager.default
        try fm.createDirectory(atPath: fixedVaultPath, withIntermediateDirectories: true)
        var installed: [String] = []

        for item in dirs {
            let safeId = item.id
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "/", with: "-")
            guard !safeId.isEmpty, !safeId.hasPrefix(".") else { continue }

            let destPath = "\(fixedVaultPath)/\(safeId)"
            let destURL = URL(fileURLWithPath: destPath)
            if fm.fileExists(atPath: destPath) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: item.url, to: destURL)

            let nestedGit = "\(destPath)/.git"
            if fm.fileExists(atPath: nestedGit) {
                try? fm.removeItem(atPath: nestedGit)
            }

            registry.skillCategories[safeId] = categoryId
            if !platforms.isEmpty {
                registry.lastEnabledPlatforms[safeId] = platforms.map { $0.rawValue }.sorted()
            }

            for p in platforms {
                let targetDir = platformDir(for: p)
                try? fm.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
                let linkPath = "\(targetDir)/\(safeId)"
                if isSymlink(linkPath) {
                    try? fm.removeItem(atPath: linkPath)
                }
                if !fm.fileExists(atPath: linkPath) {
                    try? fm.createSymbolicLink(atPath: linkPath, withDestinationPath: destPath)
                }
            }
            installed.append(safeId)
        }

        saveRegistry()
        return installed
    }

    func importLocalSkillFolder(from sourceURL: URL, categoryId: String, platforms: Set<AgentPlatform>) {
        let fm = FileManager.default
        let path = sourceURL.path
        var targets: [(id: String, url: URL)] = []

        if fm.fileExists(atPath: "\(path)/SKILL.md") {
            targets.append((sourceURL.lastPathComponent, sourceURL))
        } else if let subs = try? fm.contentsOfDirectory(atPath: path) {
            for sub in subs where !sub.hasPrefix(".") {
                let subPath = "\(path)/\(sub)"
                if fm.fileExists(atPath: "\(subPath)/SKILL.md") {
                    targets.append((sub, URL(fileURLWithPath: subPath)))
                }
            }
        }

        guard !targets.isEmpty else {
            showBanner("所选目录中未找到 SKILL.md 文件", isError: true)
            return
        }

        do {
            let names = try installDiscoveredSkillDirs(targets, categoryId: categoryId, platforms: platforms)
            reloadSkills()
            showBanner("✅ 已导入 \(names.joined(separator: ", ")) 到固定仓库")
        } catch {
            showBanner("导入失败: \(error.localizedDescription)", isError: true)
        }
    }

    private func parseGitHubInput(_ raw: String) -> (cloneURL: String, branch: String?, subpath: String?, fallbackName: String)? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.hasSuffix("/") { s.removeLast() }

        if !s.contains("://") && !s.hasPrefix("git@") {
            let parts = s.split(separator: "/").map(String.init)
            guard parts.count >= 2 else { return nil }
            let clone = "https://github.com/\(parts[0])/\(parts[1]).git"
            let sub = parts.count > 2 ? parts.dropFirst(2).joined(separator: "/") : nil
            return (clone, nil, sub, parts.last ?? parts[1])
        }

        if let url = URL(string: s), let host = url.host?.lowercased(), host.contains("github.com") {
            let comps = url.pathComponents.filter { $0 != "/" }
            guard comps.count >= 2 else { return nil }
            let owner = comps[0]
            var repo = comps[1]
            if repo.hasSuffix(".git") { repo = String(repo.dropLast(4)) }
            let clone = "https://github.com/\(owner)/\(repo).git"

            if comps.count >= 4 && comps[2] == "tree" {
                let branch = comps[3]
                let sub = comps.count > 4 ? comps.dropFirst(4).joined(separator: "/") : nil
                return (clone, branch, sub, comps.last ?? repo)
            }
            return (clone, nil, nil, repo)
        }

        return (s, nil, nil, URL(string: s)?.deletingPathExtension().lastPathComponent ?? "custom-skill")
    }

    func installGitHubSkill(repoInput: String, categoryId: String, platforms: Set<AgentPlatform>, onSuccess: (() -> Void)? = nil) {
        guard let parsed = parseGitHubInput(repoInput) else {
            showBanner("请输入有效的 GitHub 地址或 owner/repo", isError: true)
            return
        }

        DispatchQueue.main.async {
            self.isImporting = true
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let fm = FileManager.default
            let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("apolloskillhub-gh-\(UUID().uuidString)")
            defer {
                try? fm.removeItem(at: tmpDir)
                DispatchQueue.main.async { self.isImporting = false }
            }

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            var args = ["clone", "--depth", "1"]
            if let b = parsed.branch, !b.isEmpty {
                args.append(contentsOf: ["-b", b])
            }
            args.append(contentsOf: [parsed.cloneURL, tmpDir.path])
            task.arguments = args
            let errPipe = Pipe()
            task.standardOutput = Pipe()
            task.standardError = errPipe

            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                self.showBanner("无法启动 git: \(error.localizedDescription)", isError: true)
                return
            }

            guard task.terminationStatus == 0 else {
                let errMsg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "git clone 失败"
                self.showBanner("GitHub 克隆失败: \(errMsg.prefix(120))", isError: true)
                return
            }

            let searchRoot = parsed.subpath.map { tmpDir.appendingPathComponent($0) } ?? tmpDir
            var discovered: [(id: String, url: URL)] = []

            if fm.fileExists(atPath: "\(searchRoot.path)/SKILL.md") {
                let meta = self.parseSkillMetadata(skillDir: searchRoot.path, fallbackId: parsed.fallbackName)
                let chosenId = (parsed.subpath == nil && !meta.name.isEmpty) ? meta.name : parsed.fallbackName
                discovered.append((chosenId, searchRoot))
            } else {
                let candidateRoots = [
                    searchRoot.appendingPathComponent("skills"),
                    searchRoot
                ]
                var seenPaths = Set<String>()
                for root in candidateRoots {
                    guard let subs = try? fm.contentsOfDirectory(atPath: root.path) else { continue }
                    for sub in subs.sorted() where !sub.hasPrefix(".") {
                        let subURL = root.appendingPathComponent(sub)
                        guard !seenPaths.contains(subURL.path) else { continue }
                        if fm.fileExists(atPath: "\(subURL.path)/SKILL.md") {
                            seenPaths.insert(subURL.path)
                            discovered.append((sub, subURL))
                        }
                    }
                }
            }

            guard !discovered.isEmpty else {
                self.showBanner("仓库中未找到包含 SKILL.md 的技能目录", isError: true)
                return
            }

            do {
                let installed = try self.installDiscoveredSkillDirs(discovered, categoryId: categoryId, platforms: platforms)
                DispatchQueue.main.async {
                    self.reloadSkills()
                    self.showBanner("✅ 已从 GitHub 安装 \(installed.count) 个 Skill: \(installed.joined(separator: ", "))")
                    onSuccess?()
                }
            } catch {
                self.showBanner("安装到固定仓库失败: \(error.localizedDescription)", isError: true)
            }
        }
    }

    private func parseSkillMetadata(skillDir: String, fallbackId: String) -> (name: String, summary: String, desc: String, triggers: [String], skillMdPath: String) {
        let mdPath = "\(skillDir)/SKILL.md"
        guard let raw = try? String(contentsOfFile: mdPath, encoding: .utf8) else {
            return (fallbackId, "暂无 SKILL.md 描述", "暂无 SKILL.md 描述", [], mdPath)
        }

        let lines = raw.components(separatedBy: .newlines)
        var parsedName = ""
        var parsedDesc = ""

        if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
            var i = 1
            while i < lines.count {
                let line = lines[i]
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == "---" { break }

                if line.hasPrefix("name:") {
                    var val = String(line.dropFirst("name:".count)).trimmingCharacters(in: .whitespaces)
                    val = val.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    if !val.isEmpty { parsedName = val }
                } else if line.hasPrefix("description:") {
                    let rest = String(line.dropFirst("description:".count)).trimmingCharacters(in: .whitespaces)
                    if rest == "|" || rest == "|-" || rest == ">" || rest == ">-" {
                        var block: [String] = []
                        var j = i + 1
                        while j < lines.count {
                            let nextLine = lines[j]
                            let nextTrim = nextLine.trimmingCharacters(in: .whitespaces)
                            if nextTrim == "---" { break }
                            if !nextLine.isEmpty && !nextLine.hasPrefix(" ") && !nextLine.hasPrefix("\t") && nextLine.contains(":") {
                                break
                            }
                            if !nextTrim.isEmpty { block.append(nextTrim) }
                            j += 1
                        }
                        parsedDesc = block.joined(separator: " ")
                        i = j - 1
                    } else {
                        parsedDesc = rest.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    }
                }
                i += 1
            }
        }

        if parsedName.isEmpty { parsedName = fallbackId }
        if parsedDesc.isEmpty {
            let bodyLines = lines.filter { l in
                let t = l.trimmingCharacters(in: .whitespaces)
                return !t.isEmpty && t != "---" && !t.hasPrefix("#") && !t.hasPrefix(">")
            }
            parsedDesc = bodyLines.first ?? "暂无描述"
        }

        // Concise 1-line summary for collapsed card row
        let summaryParts = parsedDesc.components(separatedBy: CharacterSet(charactersIn: "。；.\n"))
        let firstSentence = summaryParts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? parsedDesc
        let summary = firstSentence.count > 48 ? String(firstSentence.prefix(48)) + "…" : firstSentence

        // Extract concise trigger phrases such as 「...」 or “...”
        var hints: [String] = []
        let patterns = ["「([^」]{2,18})」", "“([^”]{2,18})”"]
        for pat in patterns {
            if let regex = try? NSRegularExpression(pattern: pat) {
                let ns = parsedDesc as NSString
                let matches = regex.matches(in: parsedDesc, range: NSRange(location: 0, length: ns.length))
                for m in matches where m.numberOfRanges > 1 {
                    let s = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !s.isEmpty && !hints.contains(s) {
                        hints.append(s)
                        if hints.count >= 5 { break }
                    }
                }
            }
            if hints.count >= 5 { break }
        }

        return (parsedName, summary, parsedDesc, hints, mdPath)
    }
}

// MARK: - Observable UI State (Zero @State Macro Dependency)

final class SkillHubUIState: ObservableObject {
    @Published var selectedCategoryId: String = "ALL"
    @Published var filterPlatform: AgentPlatform? = nil
    @Published var searchText: String = ""
    @Published var expandedSkillIds: Set<String> = []
    @Published var hoveredCategoryId: String? = nil

    // Left sidebar inline category create / rename
    @Published var showAddCategoryBox: Bool = false
    @Published var newCategoryName: String = ""
    @Published var editingCategoryId: String? = nil
    @Published var editingCategoryName: String = ""

    // Delete category confirmation modal
    @Published var pendingDeleteCategory: SkillCategory? = nil

    // Centered Import Skill Modal
    @Published var showImportModal: Bool = false
    @Published var githubInput: String = ""
    @Published var importCategoryId: String = ""
    @Published var importEnableAgy: Bool = true
    @Published var importEnableCodex: Bool = true
    @Published var importEnableClaude: Bool = false
}

// MARK: - Reusable iOS Sliding Toggle Switch

struct IOSToggleSwitch: View {
    let isOn: Bool
    let palette: ThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? palette.okColor : palette.switchOffTrack)
                    .frame(width: 38, height: 22)
                Circle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.24), radius: 2, x: 0, y: 1)
                    .frame(width: 18, height: 18)
                    .padding(2)
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isOn)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collapsible Skill Card View

struct CollapsibleSkillCardView: View {
    let skill: SkillItemModel
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    private var isExpanded: Bool {
        ui.expandedSkillIds.contains(skill.id)
    }

    private var isMasterOn: Bool {
        if skill.sourceKind == .plugin {
            return skill.activePlatforms.contains(.codex) || skill.activePlatforms.contains(.claude)
        }
        return !skill.activePlatforms.isEmpty
    }

    private var categoryName: String {
        store.categories.first(where: { $0.id == skill.categoryId })?.name ?? "未分类"
    }

    private func toggleExpand() {
        if ui.expandedSkillIds.contains(skill.id) {
            ui.expandedSkillIds.remove(skill.id)
        } else {
            ui.expandedSkillIds.insert(skill.id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed Header Row (Clean, Airy, Single-Row with iOS Toggle + Expand Button)
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(skill.isAnyActive ? palette.okColor : palette.mutedText.opacity(0.5))
                        .frame(width: 8.5, height: 8.5)

                    VStack(alignment: .leading, spacing: 2.5) {
                        HStack(spacing: 6) {
                            Text(skill.displayName)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(skill.isAnyActive ? palette.primaryText : palette.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            if skill.sourceKind == .plugin {
                                Text(skill.pluginName.map { "插件: \($0)" } ?? "插件")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1.5)
                                    .background(palette.accentBlue.opacity(0.15))
                                    .foregroundColor(palette.accentBlue)
                                    .cornerRadius(4)
                            } else if skill.sourceKind == .builtin {
                                Text("系统内置")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1.5)
                                    .background(palette.chipBg)
                                    .foregroundColor(palette.mutedText)
                                    .cornerRadius(4)
                            }
                        }

                        Text(skill.summaryLine)
                            .font(.system(size: 11.5))
                            .foregroundColor(palette.mutedText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleExpand()
                }

                // Active platform micro-badges
                HStack(spacing: 4) {
                    let activeList = AgentPlatform.allCases.filter { skill.activePlatforms.contains($0) }
                    if activeList.isEmpty {
                        Text("已停用")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(palette.mutedText)
                    } else {
                        ForEach(activeList) { pf in
                            Text(pf.shortLabel)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(palette.chipBg)
                                .foregroundColor(palette.secondaryText)
                                .cornerRadius(4)
                        }
                    }
                }

                // iOS Sliding Toggle Switch directly on the main card row
                if skill.isManageable {
                    IOSToggleSwitch(isOn: isMasterOn, palette: palette) {
                        store.toggleMasterSwitch(for: skill)
                    }
                    .help(skill.sourceKind == .plugin ? "一键切换是否共享至 Codex / Claude" : (isMasterOn ? "点击停用此 Skill" : "点击启用此 Skill"))
                } else {
                    Text("常驻")
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(palette.chipBg)
                        .foregroundColor(palette.mutedText)
                        .cornerRadius(10)
                }

                // Expand / Collapse Detail Button
                Button(action: toggleExpand) {
                    HStack(spacing: 3) {
                        Text(isExpanded ? "收起" : "详情")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(palette.inputBg)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                    .foregroundColor(palette.primaryText)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)

            // Expanded Detail Area
            if isExpanded {
                Divider().background(palette.divider)

                VStack(alignment: .leading, spacing: 11) {
                    // Full description
                    Text(skill.descriptionText)
                        .font(.system(size: 12))
                        .foregroundColor(palette.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Trigger hints
                    if !skill.triggerHints.isEmpty {
                        HStack(spacing: 6) {
                            Text("触发词:")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(palette.mutedText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 5) {
                                    ForEach(skill.triggerHints, id: \.self) { hint in
                                        Text(hint)
                                            .font(.system(size: 11, weight: .medium))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2.5)
                                            .background(palette.accentBlue.opacity(0.14))
                                            .foregroundColor(palette.accentBlue)
                                            .cornerRadius(5)
                                    }
                                }
                            }
                        }
                    }

                    // 3-Platform Granular Scope Toggles
                    HStack(spacing: 8) {
                        Text("适用范围:")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(palette.mutedText)

                        ForEach(AgentPlatform.allCases) { platform in
                            let isActive = skill.activePlatforms.contains(platform)
                            let isLocked = skill.sourceKind == .builtin || (skill.sourceKind == .plugin && platform == .antigravity)

                            if isLocked {
                                HStack(spacing: 4) {
                                    Image(systemName: isActive ? "checkmark" : "minus")
                                        .font(.system(size: 9.5, weight: .bold))
                                    Text(platform.fullName)
                                        .font(.system(size: 11.5, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isActive ? palette.accentBlue.opacity(0.18) : palette.chipBg)
                                .foregroundColor(isActive ? palette.accentBlue : palette.mutedText)
                                .cornerRadius(7)
                                .help("\(platform.fullName) 由插件或系统自动加载")
                            } else {
                                Button(action: {
                                    store.togglePlatform(platform, for: skill)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 10.5, weight: .semibold))
                                        Text(platform.fullName)
                                            .font(.system(size: 11.5, weight: .semibold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(isActive ? palette.okColor.opacity(0.16) : palette.inputBg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .stroke(isActive ? palette.okColor.opacity(0.55) : palette.cardBorder, lineWidth: 1)
                                    )
                                    .foregroundColor(isActive ? palette.okColor : palette.secondaryText)
                                    .cornerRadius(7)
                                }
                                .buttonStyle(.plain)
                                .opacity(store.isPlatformInstalled(platform) || isActive ? 1.0 : 0.6)
                                .help(
                                    store.isPlatformInstalled(platform)
                                        ? "点击切换是否在 \(platform.fullName) 中启用此 Skill"
                                        : "本机尚未安装 \(platform.fullName)，开启后将预先建立技能链接"
                                )
                            }
                        }
                        Spacer()
                    }

                    // Footer: Category Reassignment + File Actions
                    HStack(spacing: 8) {
                        Text("所属分类:")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(palette.mutedText)

                        Menu {
                            ForEach(store.categories) { cat in
                                Button(action: { store.assignCategory(cat.id, to: skill.id) }) {
                                    Text(cat.id == skill.categoryId ? "✓ \(cat.name)" : cat.name)
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(categoryName)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(palette.primaryText)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9))
                                    .foregroundColor(palette.mutedText)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                            .cornerRadius(6)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()

                        Spacer()

                        Button(action: {
                            NSWorkspace.shared.open(URL(fileURLWithPath: skill.skillMdPath))
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11))
                                Text("查看 SKILL.md")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.primaryText)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: skill.canonicalPath)])
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                    .font(.system(size: 11))
                                Text("访达定位")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.primaryText)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
                .padding(14)
                .background(palette.windowBg.opacity(0.45))
            }
        }
        .background(palette.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(palette.cardBorder, lineWidth: 1)
        )
        .cornerRadius(11)
        .opacity(skill.isAnyActive ? 1.0 : 0.78)
    }
}

// MARK: - Centered Import Skill Modal

struct ImportSkillModalView: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    private var effectiveCategoryId: String {
        if !ui.importCategoryId.isEmpty && store.categories.contains(where: { $0.id == ui.importCategoryId }) {
            return ui.importCategoryId
        }
        if ui.selectedCategoryId != "ALL" && store.categories.contains(where: { $0.id == ui.selectedCategoryId }) {
            return ui.selectedCategoryId
        }
        return store.categories.first?.id ?? "system-config"
    }

    private var targetPlatforms: Set<AgentPlatform> {
        var s = Set<AgentPlatform>()
        if ui.importEnableAgy { s.insert(.antigravity) }
        if ui.importEnableCodex { s.insert(.codex) }
        if ui.importEnableClaude { s.insert(.claude) }
        return s
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    if !store.isImporting {
                        ui.showImportModal = false
                    }
                }

            VStack(alignment: .leading, spacing: 0) {
                // Modal Header
                HStack {
                    Label("导入新 Skill 到固定仓库", systemImage: "square.and.arrow.down.on.square")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(palette.primaryText)
                    Spacer()
                    Button(action: { ui.showImportModal = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(palette.secondaryText)
                            .padding(5)
                            .background(palette.chipBg)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isImporting)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(palette.sidebarBg)

                Divider().background(palette.divider)

                VStack(alignment: .leading, spacing: 14) {
                    // Mode 1: GitHub
                    VStack(alignment: .leading, spacing: 6) {
                        Text("方式一：从 GitHub 一键安装")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(palette.primaryText)

                        HStack(spacing: 8) {
                            TextField("输入 owner/repo 或完整 GitHub 仓库地址", text: $ui.githubInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundColor(palette.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(palette.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                                .cornerRadius(8)

                            Button(action: {
                                store.installGitHubSkill(
                                    repoInput: ui.githubInput,
                                    categoryId: effectiveCategoryId,
                                    platforms: targetPlatforms
                                ) {
                                    ui.githubInput = ""
                                    ui.showImportModal = false
                                }
                            }) {
                                HStack(spacing: 5) {
                                    if store.isImporting {
                                        ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                                    }
                                    Text(store.isImporting ? "安装中…" : "安装")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7.5)
                                .background(palette.accentBlue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(store.isImporting || ui.githubInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        Text("自动校验 SKILL.md 并落盘至 \(SkillStore.shortenHomePath(store.fixedVaultPath))")
                            .font(.system(size: 11))
                            .foregroundColor(palette.mutedText)
                    }

                    HStack(spacing: 8) {
                        Rectangle().fill(palette.divider).frame(height: 1)
                        Text("或").font(.system(size: 11)).foregroundColor(palette.mutedText)
                        Rectangle().fill(palette.divider).frame(height: 1)
                    }

                    // Mode 2: Local Folder
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("方式二：导入本地 Skill 文件夹")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(palette.primaryText)
                            Text("选择包含 SKILL.md 的目录，自动复制到固定仓库")
                                .font(.system(size: 11))
                                .foregroundColor(palette.mutedText)
                        }
                        Spacer()
                        Button(action: {
                            let panel = NSOpenPanel()
                            panel.title = "选择包含 SKILL.md 的本地技能文件夹"
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                store.importLocalSkillFolder(
                                    from: url,
                                    categoryId: effectiveCategoryId,
                                    platforms: targetPlatforms
                                )
                                ui.showImportModal = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 11.5))
                                Text("选择目录")
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6.5)
                            .background(palette.chipBg)
                            .foregroundColor(palette.primaryText)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(11)
                    .background(palette.inputBg)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    .cornerRadius(10)

                    Divider().background(palette.divider)

                    // Category & Default Enabled Platforms
                    HStack {
                        Text("归属分类")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(palette.secondaryText)
                        Spacer()
                        Menu {
                            ForEach(store.categories) { cat in
                                Button(cat.name) { ui.importCategoryId = cat.id }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(store.categories.first(where: { $0.id == effectiveCategoryId })?.name ?? "默认")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(palette.primaryText)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(palette.mutedText)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                            .cornerRadius(7)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                    }

                    HStack {
                        Text("安装后默认启用端")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(palette.secondaryText)
                        Spacer()
                        HStack(spacing: 8) {
                            ModalPlatformCheck(label: "AGY", isOn: $ui.importEnableAgy, palette: palette)
                            ModalPlatformCheck(label: "Codex", isOn: $ui.importEnableCodex, palette: palette)
                            ModalPlatformCheck(label: "Claude", isOn: $ui.importEnableClaude, palette: palette)
                        }
                    }
                }
                .padding(16)
            }
            .frame(width: 440)
            .background(palette.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 10)
        }
    }
}

struct ModalPlatformCheck: View {
    let label: String
    @Binding var isOn: Bool
    let palette: ThemePalette

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(isOn ? palette.okColor.opacity(0.18) : palette.chipBg)
            .foregroundColor(isOn ? palette.okColor : palette.secondaryText)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Delete Category Confirmation Modal

struct DeleteCategoryModalView: View {
    let category: SkillCategory
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    private var skillCount: Int {
        store.skills.filter { $0.categoryId == category.id }.count
    }

    private var fallbackName: String {
        store.categories.first(where: { $0.id != category.id })?.name ?? "默认分类"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    ui.pendingDeleteCategory = nil
                }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(palette.dangerColor)
                    Text("确认删除分类")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(palette.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(palette.sidebarBg)

                Divider().background(palette.divider)

                VStack(alignment: .leading, spacing: 10) {
                    Text("确定要删除分类「\(category.name)」吗？该分类下的 \(skillCount) 个技能将自动归入「\(fallbackName)」。")
                        .font(.system(size: 12.5))
                        .foregroundColor(palette.primaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("此操作仅移除分类标签，不会删除任何本地 Skill 文件。")
                        .font(.system(size: 11.5))
                        .foregroundColor(palette.mutedText)

                    HStack(spacing: 8) {
                        Spacer()
                        Button("取消") {
                            ui.pendingDeleteCategory = nil
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6.5)
                        .background(palette.inputBg)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                        .foregroundColor(palette.primaryText)
                        .cornerRadius(8)

                        Button("确认删除") {
                            let targetId = category.id
                            if store.deleteCategory(id: targetId) {
                                if ui.selectedCategoryId == targetId {
                                    ui.selectedCategoryId = "ALL"
                                }
                            }
                            ui.pendingDeleteCategory = nil
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6.5)
                        .background(palette.dangerColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .frame(width: 380)
            .background(palette.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.35), radius: 22, x: 0, y: 10)
        }
    }
}

// MARK: - Main Desktop Window Root View

struct SkillHubRootView: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState

    private var palette: ThemePalette {
        ThemePalette(isDark: store.isDarkTheme)
    }

    private var visibleBaseSkills: [SkillItemModel] {
        store.skills.filter { store.showBuiltins || $0.sourceKind != .builtin }
    }

    private var categoryScopedSkills: [SkillItemModel] {
        if ui.selectedCategoryId == "ALL" { return visibleBaseSkills }
        return visibleBaseSkills.filter { $0.categoryId == ui.selectedCategoryId }
    }

    private var filteredSkills: [SkillItemModel] {
        let q = ui.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return categoryScopedSkills.filter { item in
            if let pf = ui.filterPlatform, !item.activePlatforms.contains(pf) {
                return false
            }
            if !q.isEmpty {
                let hay = "\(item.id) \(item.displayName) \(item.summaryLine) \(item.descriptionText) \(item.triggerHints.joined(separator: " ")) \(item.pluginName ?? "")".lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Bar
                HStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(palette.accentBlue)
                        Text("Apollo SkillHub")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(palette.primaryText)
                    }

                    // Clickable Fixed Vault Quick-Access Pill
                    HStack(spacing: 0) {
                        Button(action: {
                            NSWorkspace.shared.open(URL(fileURLWithPath: store.fixedVaultPath))
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(palette.accentBlue)
                                Text(SkillStore.shortenHomePath(store.fixedVaultPath))
                                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                    .foregroundColor(palette.primaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundColor(palette.mutedText)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                        .help("点击直接在访达中打开固定 Skill 仓库目录")

                        Rectangle().fill(palette.cardBorder).frame(width: 1, height: 16)

                        Button("更改") {
                            let panel = NSOpenPanel()
                            panel.title = "选择新的固定 Skill 仓库根目录（自动迁移已有技能并重连）"
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.canCreateDirectories = true
                            if panel.runModal() == .OK, let url = panel.url {
                                store.changeFixedVaultDirectory(to: url.path)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(palette.accentBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .help("更改固定 Skill 仓库路径")
                    }
                    .background(palette.inputBg)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                    .cornerRadius(8)

                    Spacer()

                    Button(action: {
                        store.reloadSkills()
                        store.showBanner("✅ 已刷新三端状态，并自动归档外部新安装的 Skill 至固定仓库")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                            Text("扫描刷新")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(palette.cardBg)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                        .foregroundColor(palette.primaryText)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("重新扫描本地状态，并将命令行/GitHub 新装到外部目录的 Skill 自动归入固定仓库")

                    Button(action: {
                        ui.showImportModal = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("导入 Skill")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(palette.accentBlue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: { store.isDarkTheme.toggle() }) {
                        Image(systemName: store.isDarkTheme ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 12))
                            .foregroundColor(palette.secondaryText)
                            .padding(6.5)
                            .background(palette.chipBg)
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .help("切换深浅色主题")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(palette.sidebarBg)

                Divider().background(palette.divider)

                // Toast Feedback Banner
                if let banner = store.statusBanner, !banner.isEmpty {
                    HStack(spacing: 8) {
                        Text(banner)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(store.statusIsError ? palette.dangerColor : palette.okColor)
                        Spacer()
                        Button(action: { store.statusBanner = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(palette.mutedText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background((store.statusIsError ? palette.dangerColor : palette.okColor).opacity(0.12))
                    Divider().background(palette.divider)
                }

                // Two-Column Body: Left Category Sidebar + Right Main Content
                HStack(spacing: 0) {
                    // LEFT SIDEBAR: Categories (Add / Inline Rename / Delete with Confirmation)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("技能分类")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(palette.mutedText)
                            Spacer()
                            Button("+ 新建") {
                                ui.showAddCategoryBox.toggle()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(palette.accentBlue)
                        }
                        .padding(.horizontal, 6)

                        if ui.showAddCategoryBox {
                            HStack(spacing: 5) {
                                TextField("如 🚀 自动化", text: $ui.newCategoryName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(palette.primaryText)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 5)
                                    .background(palette.inputBg)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                                    .cornerRadius(6)

                                Button("添加") {
                                    if let newId = store.addCategory(name: ui.newCategoryName) {
                                        ui.newCategoryName = ""
                                        ui.showAddCategoryBox = false
                                        ui.selectedCategoryId = newId
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(palette.accentBlue)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                                .disabled(ui.newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }

                        ScrollView {
                            VStack(spacing: 3) {
                                // All Skills Row
                                let allActive = visibleBaseSkills.filter { $0.isAnyActive }.count
                                let allSelected = ui.selectedCategoryId == "ALL"
                                Button(action: { ui.selectedCategoryId = "ALL" }) {
                                    HStack {
                                        Text("📚 全部技能")
                                            .font(.system(size: 12, weight: allSelected ? .bold : .medium))
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(allActive)/\(visibleBaseSkills.count)")
                                            .font(.system(size: 10.5, weight: .semibold))
                                            .monospacedDigit()
                                            .opacity(0.85)
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 7)
                                    .background(allSelected ? palette.accentBlue : Color.clear)
                                    .foregroundColor(allSelected ? .white : palette.primaryText)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)

                                // Each Category Row
                                ForEach(store.categories) { cat in
                                    let inCat = visibleBaseSkills.filter { $0.categoryId == cat.id }
                                    let actCount = inCat.filter { $0.isAnyActive }.count
                                    let isSelected = ui.selectedCategoryId == cat.id
                                    let showActions = isSelected || ui.hoveredCategoryId == cat.id

                                    if ui.editingCategoryId == cat.id {
                                        HStack(spacing: 4) {
                                            TextField("分类名称", text: $ui.editingCategoryName)
                                                .textFieldStyle(.plain)
                                                .font(.system(size: 11.5, weight: .semibold))
                                                .foregroundColor(palette.primaryText)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 4)
                                                .background(palette.inputBg)
                                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(palette.accentBlue, lineWidth: 1))
                                                .cornerRadius(5)

                                            Button("存") {
                                                store.renameCategory(id: cat.id, newName: ui.editingCategoryName)
                                                ui.editingCategoryId = nil
                                            }
                                            .buttonStyle(.plain)
                                            .font(.system(size: 10.5, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 4)
                                            .background(palette.okColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(5)

                                            Button(action: { ui.editingCategoryId = nil }) {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 9.5, weight: .bold))
                                                    .foregroundColor(palette.mutedText)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(5)
                                        .background(palette.cardBg)
                                        .cornerRadius(7)
                                    } else {
                                        HStack(spacing: 4) {
                                            Text(cat.name)
                                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                            Spacer(minLength: 4)

                                            if showActions {
                                                Button(action: {
                                                    ui.editingCategoryId = cat.id
                                                    ui.editingCategoryName = cat.name
                                                }) {
                                                    Image(systemName: "pencil")
                                                        .font(.system(size: 10, weight: .semibold))
                                                        .padding(3)
                                                }
                                                .buttonStyle(.plain)
                                                .help("重命名分类")

                                                if store.categories.count > 1 {
                                                    Button(action: {
                                                        ui.pendingDeleteCategory = cat
                                                    }) {
                                                        Image(systemName: "trash")
                                                            .font(.system(size: 10, weight: .semibold))
                                                            .padding(3)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help("删除分类")
                                                }
                                            }

                                            Text("\(actCount)/\(inCat.count)")
                                                .font(.system(size: 10.5, weight: .semibold))
                                                .monospacedDigit()
                                                .opacity(0.85)
                                        }
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 7)
                                        .background(isSelected ? palette.accentBlue : (ui.hoveredCategoryId == cat.id ? palette.chipBg : Color.clear))
                                        .foregroundColor(isSelected ? .white : palette.primaryText)
                                        .cornerRadius(8)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            ui.selectedCategoryId = cat.id
                                        }
                                        .onHover { hovering in
                                            if hovering {
                                                ui.hoveredCategoryId = cat.id
                                            } else if ui.hoveredCategoryId == cat.id {
                                                ui.hoveredCategoryId = nil
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 4)

                        Divider().background(palette.divider)

                        // Built-in Toggle at Sidebar Footer
                        HStack {
                            Text("显示系统内置 Skill")
                                .font(.system(size: 11.5))
                                .foregroundColor(palette.secondaryText)
                            Spacer()
                            IOSToggleSwitch(isOn: store.showBuiltins, palette: palette) {
                                store.showBuiltins.toggle()
                            }
                        }
                        .padding(.horizontal, 4)

                        Text("悬停左侧分类可改名或删除")
                            .font(.system(size: 10.5))
                            .foregroundColor(palette.mutedText)
                            .padding(.horizontal, 4)
                    }
                    .padding(12)
                    .frame(width: 224)
                    .background(palette.sidebarBg)

                    Divider().background(palette.divider)

                    // RIGHT MAIN AREA: Horizontal Platform Bar + Search + Collapsible Cards
                    VStack(alignment: .leading, spacing: 12) {
                        // Horizontal Platform Scope Filter Bar
                        HStack(spacing: 6) {
                            HorizontalPlatformTab(
                                title: "全部平台 (\(categoryScopedSkills.count))",
                                selected: ui.filterPlatform == nil,
                                palette: palette
                            ) {
                                ui.filterPlatform = nil
                            }

                            ForEach(AgentPlatform.allCases) { pf in
                                let cnt = categoryScopedSkills.filter { $0.activePlatforms.contains(pf) }.count
                                HorizontalPlatformTab(
                                    title: "\(pf.fullName) (\(cnt))",
                                    selected: ui.filterPlatform == pf,
                                    palette: palette
                                ) {
                                    ui.filterPlatform = (ui.filterPlatform == pf) ? nil : pf
                                }
                            }

                            Spacer()

                            if ui.selectedCategoryId != "ALL",
                               let selCat = store.categories.first(where: { $0.id == ui.selectedCategoryId }) {
                                HStack(spacing: 5) {
                                    Text("本分类:")
                                        .font(.system(size: 11))
                                        .foregroundColor(palette.mutedText)
                                    Button("全开") {
                                        store.setCategoryBatchEnabled(selCat.id, enabled: true)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(palette.okColor.opacity(0.16))
                                    .foregroundColor(palette.okColor)
                                    .cornerRadius(6)

                                    Button("全关") {
                                        store.setCategoryBatchEnabled(selCat.id, enabled: false)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(palette.warnColor.opacity(0.16))
                                    .foregroundColor(palette.warnColor)
                                    .cornerRadius(6)
                                }
                            }
                        }

                        // Search Bar + Expand/Collapse All
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12))
                                    .foregroundColor(palette.mutedText)
                                TextField("搜索当前列表中的 Skill 名称、用途或触发词…", text: $ui.searchText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                    .foregroundColor(palette.primaryText)
                                if !ui.searchText.isEmpty {
                                    Button(action: { ui.searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(palette.mutedText)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.cardBorder, lineWidth: 1))
                            .cornerRadius(9)

                            Text("共 \(filteredSkills.count) 个")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(palette.mutedText)
                                .monospacedDigit()

                            Button("全部展开") {
                                filteredSkills.forEach { ui.expandedSkillIds.insert($0.id) }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.secondaryText)
                            .cornerRadius(7)

                            Button("全部折叠") {
                                ui.expandedSkillIds.removeAll()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.secondaryText)
                            .cornerRadius(7)
                        }

                        // Scrollable Collapsible Skill Cards
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                if filteredSkills.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "tray")
                                            .font(.system(size: 28))
                                            .foregroundColor(palette.mutedText)
                                        Text("当前筛选条件下暂无匹配的 Skill")
                                            .font(.system(size: 13))
                                            .foregroundColor(palette.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 70)
                                } else {
                                    ForEach(filteredSkills) { skill in
                                        CollapsibleSkillCardView(
                                            skill: skill,
                                            store: store,
                                            ui: ui,
                                            palette: palette
                                        )
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.windowBg)
                }
            }

            // Centered Modals
            if ui.showImportModal {
                ImportSkillModalView(store: store, ui: ui, palette: palette)
            }

            if let pendingCat = ui.pendingDeleteCategory {
                DeleteCategoryModalView(category: pendingCat, store: store, ui: ui, palette: palette)
            }
        }
        .frame(minWidth: 780, minHeight: 560)
    }
}

struct HorizontalPlatformTab: View {
    let title: String
    let selected: Bool
    let palette: ThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: selected ? .bold : .medium))
                .padding(.horizontal, 11)
                .padding(.vertical, 5.5)
                .background(selected ? palette.accentBlue : palette.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? palette.accentBlue : palette.cardBorder, lineWidth: 1)
                )
                .foregroundColor(selected ? .white : palette.secondaryText)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AppDelegate (Standard macOS Desktop Application)

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?
    private let store = SkillStore()
    private let ui = SkillHubUIState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMainMenu()
        showMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        } else {
            mainWindow?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    private func showMainWindow() {
        if mainWindow == nil {
            let hosting = NSHostingController(
                rootView: SkillHubRootView(store: store, ui: ui)
            )
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 880, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Apollo SkillHub"
            win.minSize = NSSize(width: 780, height: 560)
            win.contentViewController = hosting
            win.isReleasedWhenClosed = false
            win.center()
            win.setFrameAutosaveName("ApolloSkillHubMainWindow")
            mainWindow = win
        }
        store.reloadSkills()
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "退出 Apollo SkillHub", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu

        let editItem = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let windowItem = NSMenuItem(title: "窗口", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenu.addItem(NSMenuItem(title: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        NSApp.mainMenu = mainMenu
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
