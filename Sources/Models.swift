import AppKit
import SwiftUI

// MARK: - Theme Palette (Apollo UI Contrast-Verified Dark & Light)

struct ThemePalette {
    let isDark: Bool

    private func color(_ dark: Int, _ light: Int) -> Color {
        let rgb = isDark ? dark : light
        return Color(red: Double(rgb >> 16) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }

    var windowBg: Color { color(0x0C0E12, 0xF6F7F9) }
    var sidebarBg: Color { color(0x11141A, 0xEFF1F5) }
    var listBg: Color { color(0x151921, 0xFFFFFF) }
    var inspectorBg: Color { color(0x101319, 0xFAFBFD) }
    var surfaceBg: Color { color(0x1B202B, 0xEEF1F6) }
    var primaryText: Color { color(0xF3F5F8, 0x0F172A) }
    var secondaryText: Color { color(0x9AA4B2, 0x475569) }
    var mutedText: Color { color(0x636E7E, 0x64748B) }
    var okColor: Color { color(0x10B981, 0x059669) }
    var accentBlue: Color { color(0x3B82F6, 0x2563EB) }
    var amberAccent: Color { color(0xF59E0B, 0xB45309) }
    var dangerColor: Color { color(0xEF4444, 0xDC2626) }
    var cardBg: Color { surfaceBg }
    var inputBg: Color { windowBg }
    var chipBg: Color { surfaceBg }
    var divider: Color { cardBorder }
    var purpleAccent: Color { accentBlue }
    var amberFg: Color { isDark ? windowBg : .white }
    var amberBg: Color { amberAccent.opacity(isDark ? 0.13 : 0.10) }
    var amberBorder: Color { amberAccent.opacity(isDark ? 0.34 : 0.28) }
    var warnColor: Color { amberAccent }
    var switchOffTrack: Color { mutedText.opacity(0.55) }
    var cardBorder: Color { color(0xFFFFFF, 0x0F172A).opacity(0.08) }
    var strongBorder: Color { color(0xFFFFFF, 0x0F172A).opacity(isDark ? 0.14 : 0.15) }
    var greenBg: Color { okColor.opacity(isDark ? 0.14 : 0.11) }
    var greenBorder: Color { okColor.opacity(isDark ? 0.28 : 0.26) }
    var blueBg: Color { accentBlue.opacity(isDark ? 0.14 : 0.10) }
    var blueBorder: Color { accentBlue.opacity(isDark ? 0.30 : 0.26) }
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
