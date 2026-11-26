import AppKit
import SwiftUI

// MARK: - Theme Palette (Apollo UI Contrast-Verified Dark & Light)

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
        isDark ? Color(red: 0.56, green: 0.63, blue: 0.74) : Color(red: 0.44, green: 0.50, blue: 0.59)
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
    var amberAccent: Color {
        isDark ? Color(red: 0.96, green: 0.72, blue: 0.23) : Color(red: 0.58, green: 0.32, blue: 0.00)
    }
    var amberFg: Color {
        isDark ? Color(red: 0.08, green: 0.10, blue: 0.16) : Color.white
    }
    var amberBg: Color {
        isDark ? Color(red: 0.96, green: 0.72, blue: 0.23).opacity(0.15) : Color(red: 0.58, green: 0.32, blue: 0.00).opacity(0.10)
    }
    var amberBorder: Color {
        isDark ? Color(red: 0.96, green: 0.72, blue: 0.23).opacity(0.45) : Color(red: 0.58, green: 0.32, blue: 0.00).opacity(0.36)
    }
    var okColor: Color {
        isDark ? Color(red: 0.20, green: 0.84, blue: 0.52) : Color(red: 0.07, green: 0.53, blue: 0.30)
    }
    var warnColor: Color {
        isDark ? Color(red: 0.99, green: 0.73, blue: 0.20) : Color(red: 0.72, green: 0.41, blue: 0.00)
    }
    var dangerColor: Color {
        isDark ? Color(red: 1.00, green: 0.38, blue: 0.40) : Color(red: 0.80, green: 0.15, blue: 0.19)
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

struct SkillSourceRecord: Codable, Equatable {
    var repoInput: String
    var cloneURL: String
    var branch: String?
    var subpath: String?
    var commitHash: String?
    var updatedAt: String
}

struct SkillProfile: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var skillPlatforms: [String: [String]]
}

struct SkillRegistryFile: Codable {
    var categories: [SkillCategory]
    var skillCategories: [String: String]
    var lastEnabledPlatforms: [String: [String]]
    var skillSources: [String: SkillSourceRecord]
    var profiles: [SkillProfile]
    var mcpCategories: [SkillCategory]
    var mcpCategoryMap: [String: String]
    var pluginCategories: [SkillCategory]
    var pluginCategoryMap: [String: String]

    init(
        categories: [SkillCategory],
        skillCategories: [String: String],
        lastEnabledPlatforms: [String: [String]],
        skillSources: [String: SkillSourceRecord] = [:],
        profiles: [SkillProfile] = [],
        mcpCategories: [SkillCategory] = [],
        mcpCategoryMap: [String: String] = [:],
        pluginCategories: [SkillCategory] = [],
        pluginCategoryMap: [String: String] = [:]
    ) {
        self.categories = categories
        self.skillCategories = skillCategories
        self.lastEnabledPlatforms = lastEnabledPlatforms
        self.skillSources = skillSources
        self.profiles = profiles
        self.mcpCategories = mcpCategories
        self.mcpCategoryMap = mcpCategoryMap
        self.pluginCategories = pluginCategories
        self.pluginCategoryMap = pluginCategoryMap
    }

    enum CodingKeys: String, CodingKey {
        case categories
        case skillCategories
        case lastEnabledPlatforms
        case skillSources
        case profiles
        case mcpCategories
        case mcpCategoryMap
        case pluginCategories
        case pluginCategoryMap
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.categories = try c.decodeIfPresent([SkillCategory].self, forKey: .categories) ?? []
        self.skillCategories = try c.decodeIfPresent([String: String].self, forKey: .skillCategories) ?? [:]
        self.lastEnabledPlatforms = try c.decodeIfPresent([String: [String]].self, forKey: .lastEnabledPlatforms) ?? [:]
        self.skillSources = try c.decodeIfPresent([String: SkillSourceRecord].self, forKey: .skillSources) ?? [:]
        self.profiles = try c.decodeIfPresent([SkillProfile].self, forKey: .profiles) ?? []
        self.mcpCategories = try c.decodeIfPresent([SkillCategory].self, forKey: .mcpCategories) ?? []
        self.mcpCategoryMap = try c.decodeIfPresent([String: String].self, forKey: .mcpCategoryMap) ?? [:]
        self.pluginCategories = try c.decodeIfPresent([SkillCategory].self, forKey: .pluginCategories) ?? []
        self.pluginCategoryMap = try c.decodeIfPresent([String: String].self, forKey: .pluginCategoryMap) ?? [:]
    }
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
    var charCount: Int
    var estimatedTokens: Int
    var sourceRecord: SkillSourceRecord?

    var isAnyActive: Bool {
        !activePlatforms.isEmpty || sourceKind == .builtin
    }

    var isManageable: Bool {
        sourceKind != .builtin
    }
}

enum HubTab: String, CaseIterable, Identifiable {
    case skills
    case mcp
    case plugins
    case watchlist

    var id: String { rawValue }

    static var localAssetTabs: [HubTab] {
        [.skills, .mcp, .plugins]
    }

    var title: String {
        switch self {
        case .skills: return "Skills 技能"
        case .mcp: return "MCP 服务"
        case .plugins: return "Plugins 插件"
        case .watchlist: return "关注收藏"
        }
    }
}

struct McpRawConfig: Equatable {
    var command: String?
    var args: [String]
    var url: String?
    var env: [String: String]
}

struct McpServerItemModel: Identifiable, Equatable {
    let id: String
    var commandSummary: String
    var envKeys: [String]
    var platforms: Set<AgentPlatform>
    var configPaths: [AgentPlatform: String]
    var rawConfigs: [AgentPlatform: McpRawConfig]
    var categoryId: String
}

struct PluginItemModel: Identifiable, Equatable {
    let id: String
    var rawId: String
    var platform: AgentPlatform
    var displayName: String
    var version: String
    var authorName: String
    var descriptionText: String
    var repositoryUrl: String
    var pluginPath: String
    var pluginJsonPath: String?
    var bundledSkills: [String]
    var isEnabled: Bool
    var canToggle: Bool
    var canUninstall: Bool
    var categoryId: String
}

// MARK: - Watchlist (Research Radar) Models

enum WatchlistKind: String, CaseIterable, Codable, Identifiable {
    case skill
    case plugin
    case mcp
    case cli
    case repo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .skill: return "Skill"
        case .plugin: return "Plugin"
        case .mcp: return "MCP"
        case .cli: return "CLI 工具"
        case .repo: return "其他仓库"
        }
    }
}

enum WatchlistStatus: String, CaseIterable, Codable, Identifiable {
    case todo
    case studying
    case recommended
    case watching
    case skip

    var id: String { rawValue }

    var label: String {
        switch self {
        case .todo: return "待研究"
        case .studying: return "研究中"
        case .recommended: return "已评估-推荐"
        case .watching: return "持续关注"
        case .skip: return "暂不安装"
        }
    }

    func tintColor(in palette: ThemePalette) -> Color {
        switch self {
        case .todo: return palette.accentBlue
        case .studying: return palette.purpleAccent
        case .recommended: return palette.okColor
        case .watching: return palette.amberAccent
        case .skip: return palette.mutedText
        }
    }
}

struct WatchlistItem: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var kind: WatchlistKind
    var status: WatchlistStatus
    var repoUrl: String
    var summary: String
    var notes: String
    var tags: [String]
    var installCmd: String
    var starsText: String
    var language: String
    var pushedAt: String
    var createdAt: String
    var updatedAt: String
}

struct WatchlistFile: Codable {
    var version: Int
    var items: [WatchlistItem]
}

// MARK: - Health & CLI Models

enum HealthIssueKind: String {
    case brokenSymlink
    case orphanVaultDir
    case unarchivedExternalSkill
    case shadowConflict
    case legacyCodexSymlink
    case missingMcpCommand
}

struct HealthIssue: Identifiable, Equatable {
    let id: String
    var kind: HealthIssueKind
    var title: String
    var detail: String
    var targetPath: String
    var canAutoFix: Bool
}

struct CliCheckItem: Identifiable, Equatable {
    let id: String
    var name: String
    var installed: Bool
    var path: String?
}

struct PendingOverwriteContext: Identifiable {
    let id = UUID().uuidString
    let existingSkillIds: [String]
    let discovered: [(id: String, url: URL)]
    let tempDirToCleanup: URL?
    let categoryId: String
    let platforms: Set<AgentPlatform>
    let sourceRecord: SkillSourceRecord?
    let onSuccess: (() -> Void)?
}

enum MountError: LocalizedError {
    case nonSymlinkConflict(path: String, platform: AgentPlatform)
    case ioFailed(String)

    var errorDescription: String? {
        switch self {
        case .nonSymlinkConflict(let path, let platform):
            return "\(platform.fullName) 目录存在非软链接实目录（\(SkillStore.shortenHomePath(path))），请先点击「刷新」归档后再切换"
        case .ioFailed(let msg):
            return msg
        }
    }
}
