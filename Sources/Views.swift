import AppKit
import SwiftUI

// MARK: - Observable UI State

final class SkillHubUIState: ObservableObject {
    @Published var activeTab: HubTab = .skills
    @Published var selectedCategoryId: String = "ALL"
    @Published var filterPlatform: AgentPlatform? = nil
    @Published var searchText: String = ""
    @Published var expandedSkillIds: Set<String> = []
    @Published var previewSkillMdIds: Set<String> = []
    @Published var hoveredCategoryId: String? = nil

    // MCP (Left = Purpose Group, Top = Platform Filter)
    @Published var mcpCategoryFilter: String = "ALL"
    @Published var mcpPlatformFilter: String = "ALL" // ALL, MULTI, antigravity, codex, claude
    @Published var mcpSearchText: String = ""
    @Published var expandedMcpIds: Set<String> = []
    @Published var showAddMcpCatBox: Bool = false
    @Published var newMcpCatName: String = ""

    // Plugins (Left = Purpose Group, Top = Platform Filter)
    @Published var pluginCategoryFilter: String = "ALL"
    @Published var pluginPlatformFilter: AgentPlatform? = nil
    @Published var pluginSearchText: String = ""
    @Published var expandedPluginIds: Set<String> = []
    @Published var showAddPluginCatBox: Bool = false
    @Published var newPluginCatName: String = ""

    // Watchlist (Plan A Independent Research Radar Space)
    @Published var watchlistStatusFilter: WatchlistStatus? = nil
    @Published var watchlistKindFilter: WatchlistKind? = nil
    @Published var watchlistOnlyUninstalled: Bool = false
    @Published var watchlistSearchText: String = ""
    @Published var expandedWatchlistIds: Set<String> = []

    // Add Watchlist Draft
    @Published var showAddWatchlistModal: Bool = false
    @Published var wlIsFetchingMeta: Bool = false
    @Published var wlDraftNotes: [String: String] = [:]
    @Published var wlUrlInput: String = ""
    @Published var wlNameInput: String = ""
    @Published var wlKindInput: WatchlistKind = .skill
    @Published var wlStatusInput: WatchlistStatus = .todo
    @Published var wlTagsInput: String = ""
    @Published var wlInstallCmdInput: String = ""
    @Published var wlSummaryInput: String = ""
    @Published var wlNotesInput: String = ""
    @Published var wlStarsCache: String = ""
    @Published var wlLangCache: String = ""
    @Published var wlPushedCache: String = ""

    func resetWatchlistDraft() {
        wlUrlInput = ""; wlNameInput = ""; wlKindInput = .skill; wlStatusInput = .todo
        wlTagsInput = ""; wlInstallCmdInput = ""; wlSummaryInput = ""; wlNotesInput = ""
        wlStarsCache = ""; wlLangCache = ""; wlPushedCache = ""
    }

    // Left sidebar inline category create / rename (Skills)
    @Published var showAddCategoryBox: Bool = false
    @Published var newCategoryName: String = ""
    @Published var editingCategoryId: String? = nil
    @Published var editingCategoryName: String = ""

    // Modals
    @Published var pendingDeleteCategory: SkillCategory? = nil
    @Published var pendingTrashSkill: SkillItemModel? = nil
    @Published var pendingUninstallPlugin: PluginItemModel? = nil
    @Published var showHealthModal: Bool = false
    @Published var showProfileModal: Bool = false
    @Published var newProfileName: String = ""

    // Import Skill Modal
    @Published var showImportModal: Bool = false
    @Published var githubInput: String = ""
    @Published var importCategoryId: String = ""
    @Published var importEnableAgy: Bool = true
    @Published var importEnableCodex: Bool = true
    @Published var importEnableClaude: Bool = false

    // Install Plugin Modal
    @Published var showInstallPluginModal: Bool = false
    @Published var pluginGithubInput: String = ""
    @Published var codexPluginSpecInput: String = ""
    @Published var pluginShareCodex: Bool = true
    @Published var pluginShareClaude: Bool = false
}

func formatTokenBadge(_ tokens: Int) -> String {
    if tokens >= 1000 { return String(format: "~%.1fk tok", Double(tokens) / 1000.0) }
    return "~\(tokens) tok"
}

// MARK: - Reusable iOS Sliding Toggle Switch

struct IOSToggleSwitch: View {
    let isOn: Bool
    let palette: ThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? palette.okColor : palette.switchOffTrack).frame(width: 38, height: 22)
                Circle().fill(Color.white).shadow(color: Color.black.opacity(0.24), radius: 2, x: 0, y: 1)
                    .frame(width: 18, height: 18).padding(2)
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

    private var isExpanded: Bool { ui.expandedSkillIds.contains(skill.id) }
    private var isPreviewingMd: Bool { ui.previewSkillMdIds.contains(skill.id) }
    private var isUpdating: Bool { store.updatingSkillIds.contains(skill.id) }
    private var isMasterOn: Bool {
        if skill.sourceKind == .plugin { return skill.activePlatforms.contains(.codex) || skill.activePlatforms.contains(.claude) }
        return !skill.activePlatforms.isEmpty
    }
    private var categoryName: String { store.categories.first(where: { $0.id == skill.categoryId })?.name ?? "未分类" }

    private func toggleExpand() {
        if ui.expandedSkillIds.contains(skill.id) { ui.expandedSkillIds.remove(skill.id) }
        else { ui.expandedSkillIds.insert(skill.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Circle().fill(skill.isAnyActive ? palette.okColor : palette.mutedText.opacity(0.5)).frame(width: 8.5, height: 8.5)
                    VStack(alignment: .leading, spacing: 2.5) {
                        HStack(spacing: 6) {
                            Text(skill.displayName)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(skill.isAnyActive ? palette.primaryText : palette.secondaryText)
                                .lineLimit(1).truncationMode(.tail)
                            if skill.sourceKind == .plugin {
                                Text(skill.pluginName.map { "插件: \($0)" } ?? "插件")
                                    .font(.system(size: 10, weight: .semibold)).padding(.horizontal, 6).padding(.vertical, 1.5)
                                    .background(palette.accentBlue.opacity(0.15)).foregroundColor(palette.accentBlue).cornerRadius(4)
                            } else if skill.sourceKind == .builtin {
                                Text("系统内置").font(.system(size: 10, weight: .semibold)).padding(.horizontal, 6).padding(.vertical, 1.5)
                                    .background(palette.chipBg).foregroundColor(palette.mutedText).cornerRadius(4)
                            }
                            if skill.estimatedTokens > 0 {
                                Text(formatTokenBadge(skill.estimatedTokens))
                                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                                    .background(palette.chipBg).foregroundColor(palette.mutedText).cornerRadius(4)
                                    .help("SKILL.md 约 \(skill.charCount) 字符，估算 \(skill.estimatedTokens) Tokens")
                            }
                        }
                        Text(skill.summaryLine).font(.system(size: 11.5)).foregroundColor(palette.mutedText).lineLimit(1).truncationMode(.tail)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle()).onTapGesture { toggleExpand() }

                HStack(spacing: 4) {
                    let activeList = AgentPlatform.allCases.filter { skill.activePlatforms.contains($0) }
                    if activeList.isEmpty {
                        Text("已停用").font(.system(size: 10.5, weight: .medium)).foregroundColor(palette.mutedText)
                    } else {
                        ForEach(activeList) { pf in
                            Text(pf.shortLabel).font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(palette.chipBg).foregroundColor(palette.secondaryText).cornerRadius(4)
                        }
                    }
                }

                if skill.isManageable {
                    IOSToggleSwitch(isOn: isMasterOn, palette: palette) { store.toggleMasterSwitch(for: skill) }
                } else {
                    Text("常驻").font(.system(size: 10.5, weight: .semibold)).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(palette.chipBg).foregroundColor(palette.mutedText).cornerRadius(10)
                }

                Button(action: toggleExpand) {
                    HStack(spacing: 3) {
                        Text(isExpanded ? "收起" : "详情").font(.system(size: 11, weight: .medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4.5).background(palette.inputBg)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                    .foregroundColor(palette.primaryText).cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 13).padding(.vertical, 10)

            if isExpanded {
                Divider().background(palette.divider)
                VStack(alignment: .leading, spacing: 11) {
                    Text(skill.descriptionText).font(.system(size: 12)).foregroundColor(palette.secondaryText)
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true)

                    if !skill.triggerHints.isEmpty {
                        HStack(spacing: 6) {
                            Text("触发词:").font(.system(size: 11, weight: .semibold)).foregroundColor(palette.mutedText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 5) {
                                    ForEach(skill.triggerHints, id: \.self) { hint in
                                        Text(hint).font(.system(size: 11, weight: .medium))
                                            .padding(.horizontal, 7).padding(.vertical, 2.5)
                                            .background(palette.accentBlue.opacity(0.14)).foregroundColor(palette.accentBlue).cornerRadius(5)
                                    }
                                }
                            }
                        }
                    }

                    if let src = skill.sourceRecord {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.branch").font(.system(size: 10.5)).foregroundColor(palette.mutedText)
                            Text("来源: \(src.repoInput)\(src.commitHash.map { " (\($0.prefix(7)))" } ?? "")")
                                .font(.system(size: 11, design: .monospaced)).foregroundColor(palette.mutedText)
                                .lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button(action: { store.updateSkillFromGitHub(skill) }) {
                                HStack(spacing: 4) {
                                    if isUpdating { ProgressView().scaleEffect(0.5).frame(width: 11, height: 11) }
                                    else { Image(systemName: "arrow.down.circle").font(.system(size: 11)) }
                                    Text(isUpdating ? "更新中…" : "拉取更新").font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(palette.accentBlue.opacity(0.15)).foregroundColor(palette.accentBlue).cornerRadius(6)
                            }
                            .buttonStyle(.plain).disabled(isUpdating)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("适用范围:").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.mutedText)
                        ForEach(AgentPlatform.allCases) { platform in
                            let isActive = skill.activePlatforms.contains(platform)
                            let isLocked = skill.sourceKind == .builtin || (skill.sourceKind == .plugin && platform == .antigravity)
                            if isLocked {
                                HStack(spacing: 4) {
                                    Image(systemName: isActive ? "checkmark" : "minus").font(.system(size: 9.5, weight: .bold))
                                    Text(platform.fullName).font(.system(size: 11.5, weight: .semibold))
                                }
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(isActive ? palette.accentBlue.opacity(0.18) : palette.chipBg)
                                .foregroundColor(isActive ? palette.accentBlue : palette.mutedText).cornerRadius(7)
                            } else {
                                Button(action: { store.togglePlatform(platform, for: skill) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isActive ? "checkmark.circle.fill" : "circle").font(.system(size: 10.5, weight: .semibold))
                                        Text(platform.fullName).font(.system(size: 11.5, weight: .semibold))
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(isActive ? palette.okColor.opacity(0.16) : palette.inputBg)
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(isActive ? palette.okColor.opacity(0.55) : palette.cardBorder, lineWidth: 1))
                                    .foregroundColor(isActive ? palette.okColor : palette.secondaryText).cornerRadius(7)
                                }
                                .buttonStyle(.plain).opacity(store.isPlatformInstalled(platform) || isActive ? 1.0 : 0.6)
                            }
                        }
                        Spacer()
                    }

                    if isPreviewingMd {
                        let mdText = (try? String(contentsOfFile: skill.skillMdPath, encoding: .utf8)) ?? "无法读取 SKILL.md"
                        ScrollView {
                            Text(mdText).font(.system(size: 11, design: .monospaced)).foregroundColor(palette.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).padding(10)
                        }
                        .frame(maxHeight: 200).background(palette.inputBg)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(7)
                    }

                    HStack(spacing: 7) {
                        Text("分类:").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.mutedText)
                        Menu {
                            ForEach(store.categories) { cat in
                                Button(action: { store.assignCategory(cat.id, to: skill.id) }) {
                                    Text(cat.id == skill.categoryId ? "✓ \(cat.name)" : cat.name)
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(categoryName).font(.system(size: 11.5, weight: .medium)).foregroundColor(palette.primaryText)
                                Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(palette.mutedText)
                            }
                            .padding(.horizontal, 9).padding(.vertical, 4.5).background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(6)
                        }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()

                        Spacer()

                        Button(action: {
                            if isPreviewingMd { ui.previewSkillMdIds.remove(skill.id) }
                            else { ui.previewSkillMdIds.insert(skill.id) }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isPreviewingMd ? "eye.slash" : "eye").font(.system(size: 11))
                                Text(isPreviewingMd ? "收起预览" : "预览").font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4.5).background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.primaryText).cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { NSWorkspace.shared.open(URL(fileURLWithPath: skill.skillMdPath)) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text").font(.system(size: 11))
                                Text("SKILL.md").font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4.5).background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.primaryText).cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: skill.canonicalPath)]) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder").font(.system(size: 11))
                                Text("访达").font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4.5).background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.primaryText).cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        if skill.sourceKind == .userVault {
                            Button(action: { ui.pendingTrashSkill = skill }) {
                                Image(systemName: "trash").font(.system(size: 11))
                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                    .background(palette.dangerColor.opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.dangerColor.opacity(0.35), lineWidth: 1))
                                    .foregroundColor(palette.dangerColor).cornerRadius(6)
                            }
                            .buttonStyle(.plain).help("卸载或转存到关注列表")
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(14).background(palette.windowBg.opacity(0.45))
            }
        }
        .background(palette.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(palette.cardBorder, lineWidth: 1))
        .cornerRadius(11)
        .opacity(skill.isAnyActive ? 1.0 : 0.78)
    }
}

// MARK: - Main Desktop Window Root View (Plan A Topbar)

struct SkillHubRootView: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState

    private var palette: ThemePalette { ThemePalette(isDark: store.isDarkTheme) }
    private var visibleBaseSkills: [SkillItemModel] { store.skills.filter { store.showBuiltins || $0.sourceKind != .builtin } }
    private var categoryScopedSkills: [SkillItemModel] {
        ui.selectedCategoryId == "ALL" ? visibleBaseSkills : visibleBaseSkills.filter { $0.categoryId == ui.selectedCategoryId }
    }
    private var filteredSkills: [SkillItemModel] {
        let q = ui.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return categoryScopedSkills.filter { item in
            if let pf = ui.filterPlatform, !item.activePlatforms.contains(pf) { return false }
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
                // Top Bar (Plan A: Pure 3 Local Assets | Independent Watchlist Space Pill)
                HStack(spacing: 8) {
                    HStack(spacing: 7) {
                        Image(systemName: "square.grid.2x2.fill").font(.system(size: 14, weight: .semibold)).foregroundColor(palette.accentBlue)
                        Text("Apollo AgentHub").font(.system(size: 14.5, weight: .bold)).foregroundColor(palette.primaryText)
                    }

                    // Pure 3-Tab Local Runtime Assets Segmented Control
                    HStack(spacing: 2) {
                        ForEach(HubTab.localAssetTabs) { tab in
                            let isSelected = ui.activeTab == tab
                            let count: Int = {
                                switch tab {
                                case .skills: return visibleBaseSkills.count
                                case .mcp: return store.mcpServers.count
                                case .plugins: return store.plugins.count
                                case .watchlist: return store.watchlist.count
                                }
                            }()
                            Button(action: { ui.activeTab = tab }) {
                                HStack(spacing: 5) {
                                    Text(tab.title).font(.system(size: 11.5, weight: .semibold))
                                    Text("\(count)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(isSelected ? Color.white.opacity(0.22) : palette.chipBg)
                                        .cornerRadius(99)
                                }
                                .padding(.horizontal, 9).padding(.vertical, 5)
                                .background(isSelected ? palette.accentBlue : Color.clear)
                                .foregroundColor(isSelected ? .white : palette.secondaryText)
                                .cornerRadius(6.5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3).background(palette.inputBg)
                    .overlay(RoundedRectangle(cornerRadius: 8.5).stroke(palette.cardBorder, lineWidth: 1))
                    .cornerRadius(8.5)

                    // Clear 1px vertical separator between Local Runtime & External Watchlist
                    Rectangle().fill(palette.cardBorder).frame(width: 1, height: 18).padding(.horizontal, 2)

                    // Plan A Independent Watchlist Space Button
                    let isWatchlist = ui.activeTab == .watchlist
                    Button(action: { ui.activeTab = .watchlist }) {
                        HStack(spacing: 5) {
                            Image(systemName: "star.fill").font(.system(size: 10.5))
                            Text("关注收藏").font(.system(size: 11.5, weight: .semibold))
                            Text("\(store.watchlist.count)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(isWatchlist ? palette.amberAccent : palette.chipBg)
                                .foregroundColor(isWatchlist ? palette.amberFg : palette.secondaryText)
                                .cornerRadius(99)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(isWatchlist ? palette.amberBg : palette.inputBg)
                        .overlay(RoundedRectangle(cornerRadius: 8.5).stroke(isWatchlist ? palette.amberBorder : palette.cardBorder, lineWidth: 1))
                        .foregroundColor(isWatchlist ? palette.amberAccent : palette.secondaryText)
                        .cornerRadius(8.5)
                    }
                    .buttonStyle(.plain)
                    .help("外部研究与观察池（独立存储，不下载代码到本地）")

                    Spacer()

                    // Profile Preset Menu (visible in local modes)
                    if ui.activeTab != .watchlist {
                        Menu {
                            if store.profiles.isEmpty {
                                Text("暂无预设，点击下方新建")
                            } else {
                                ForEach(store.profiles) { prof in Button("切换：\(prof.name)") { store.applyProfile(prof) } }
                                Divider()
                            }
                            Button("管理 / 保存当前预设…") { ui.showProfileModal = true }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "slider.horizontal.3").font(.system(size: 11))
                                Text("场景").font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 9).padding(.vertical, 6).background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.primaryText).cornerRadius(8)
                        }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    }

                    // Health & CLI Check Button
                    Button(action: { store.scanHealthIssues(); ui.showHealthModal = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stethoscope").font(.system(size: 11, weight: .semibold))
                                .foregroundColor(store.healthIssues.isEmpty ? palette.okColor : palette.amberAccent)
                            Text("体检").font(.system(size: 11, weight: .semibold))
                            if !store.healthIssues.isEmpty {
                                Text("\(store.healthIssues.count)")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4.5).padding(.vertical, 1)
                                    .background(palette.amberAccent).foregroundColor(palette.amberFg).cornerRadius(99)
                            }
                        }
                        .padding(.horizontal, 9).padding(.vertical, 6).background(palette.cardBg)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.healthIssues.isEmpty ? palette.cardBorder : palette.amberBorder, lineWidth: 1))
                        .foregroundColor(palette.primaryText).cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        store.reloadSkills(autoIngest: true)
                        store.loadWatchlist()
                        store.showBanner("✅ 已刷新三端本地状态与关注收藏库")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
                            Text("刷新").font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 9).padding(.vertical, 6).background(palette.cardBg)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                        .foregroundColor(palette.primaryText).cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Contextual Primary Action Button
                    if ui.activeTab == .skills {
                        Button(action: {
                            ui.importEnableAgy = store.isPlatformInstalled(.antigravity)
                            ui.importEnableCodex = store.isPlatformInstalled(.codex)
                            ui.importEnableClaude = store.isPlatformInstalled(.claude)
                            ui.showImportModal = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                                Text("导入 Skill").font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(palette.accentBlue).foregroundColor(.white).cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else if ui.activeTab == .plugins {
                        Button(action: { ui.showInstallPluginModal = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                                Text("安装插件").font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(palette.purpleAccent).foregroundColor(.white).cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else if ui.activeTab == .watchlist {
                        Button(action: { ui.resetWatchlistDraft(); ui.showAddWatchlistModal = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                                Text("收录关注").font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(palette.amberAccent).foregroundColor(palette.amberFg).cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: { store.isDarkTheme.toggle() }) {
                        Image(systemName: store.isDarkTheme ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 12)).foregroundColor(palette.secondaryText)
                            .padding(6.5).background(palette.chipBg).cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 10).background(palette.sidebarBg)

                Divider().background(palette.divider)

                if let banner = store.statusBanner, !banner.isEmpty {
                    HStack(spacing: 8) {
                        Text(banner).font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(store.statusIsError ? palette.dangerColor : palette.okColor)
                        Spacer()
                        Button(action: { store.statusBanner = nil }) {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(palette.mutedText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .background((store.statusIsError ? palette.dangerColor : palette.okColor).opacity(0.12))
                    Divider().background(palette.divider)
                }

                // Workspace Body
                switch ui.activeTab {
                case .skills: skillsBodyView
                case .mcp: McpHubBodyView(store: store, ui: ui, palette: palette)
                case .plugins: PluginsHubBodyView(store: store, ui: ui, palette: palette)
                case .watchlist: WatchlistHubBodyView(store: store, ui: ui, palette: palette)
                }
            }

            // Modals
            if ui.showImportModal { ImportSkillModalView(store: store, ui: ui, palette: palette) }
            if ui.showInstallPluginModal { InstallPluginModalView(store: store, ui: ui, palette: palette) }
            if ui.showAddWatchlistModal { AddWatchlistModalView(store: store, ui: ui, palette: palette) }
            if ui.showHealthModal { HealthCheckModalView(store: store, ui: ui, palette: palette) }
            if ui.showProfileModal { ProfileModalView(store: store, ui: ui, palette: palette) }
            if let ctx = store.pendingOverwrite { OverwriteConfirmModalView(ctx: ctx, store: store, palette: palette) }
            if let pendingCat = ui.pendingDeleteCategory { DeleteCategoryModalView(category: pendingCat, store: store, ui: ui, palette: palette) }
            if let sk = ui.pendingTrashSkill { TrashSkillConfirmModalView(skill: sk, store: store, ui: ui, palette: palette) }
            if let pl = ui.pendingUninstallPlugin { UninstallPluginConfirmModalView(plugin: pl, store: store, ui: ui, palette: palette) }
        }
        .frame(minWidth: 920, minHeight: 600)
    }

    private var skillsBodyView: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("技能用途分类").font(.system(size: 11.5, weight: .bold)).foregroundColor(palette.mutedText)
                    Spacer()
                    Button("+ 新建") { ui.showAddCategoryBox.toggle() }
                        .buttonStyle(.plain).font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.accentBlue)
                }
                .padding(.horizontal, 6)

                if ui.showAddCategoryBox {
                    HStack(spacing: 5) {
                        TextField("如 🚀 自动化", text: $ui.newCategoryName)
                            .textFieldStyle(.plain).font(.system(size: 11.5)).foregroundColor(palette.primaryText)
                            .padding(.horizontal, 7).padding(.vertical, 5).background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(6)
                        Button("添加") {
                            if let newId = store.addCategory(name: ui.newCategoryName) {
                                ui.newCategoryName = ""; ui.showAddCategoryBox = false; ui.selectedCategoryId = newId
                            }
                        }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 5).background(palette.accentBlue).foregroundColor(.white).cornerRadius(6)
                        .disabled(ui.newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                ScrollView {
                    VStack(spacing: 3) {
                        let allActive = visibleBaseSkills.filter { $0.isAnyActive }.count
                        let allSelected = ui.selectedCategoryId == "ALL"
                        Button(action: { ui.selectedCategoryId = "ALL" }) {
                            HStack {
                                Text("📚 全部技能").font(.system(size: 12, weight: allSelected ? .bold : .medium)).lineLimit(1)
                                Spacer()
                                Text("\(allActive)/\(visibleBaseSkills.count)").font(.system(size: 10.5, weight: .semibold)).monospacedDigit().opacity(0.85)
                            }
                            .padding(.horizontal, 9).padding(.vertical, 7)
                            .background(allSelected ? palette.accentBlue : Color.clear)
                            .foregroundColor(allSelected ? .white : palette.primaryText).cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        ForEach(store.categories) { cat in
                            let inCat = visibleBaseSkills.filter { $0.categoryId == cat.id }
                            let actCount = inCat.filter { $0.isAnyActive }.count
                            let isSelected = ui.selectedCategoryId == cat.id
                            let showActions = isSelected || ui.hoveredCategoryId == cat.id

                            if ui.editingCategoryId == cat.id {
                                HStack(spacing: 4) {
                                    TextField("分类名称", text: $ui.editingCategoryName)
                                        .textFieldStyle(.plain).font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.primaryText)
                                        .padding(.horizontal, 6).padding(.vertical, 4).background(palette.inputBg)
                                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(palette.accentBlue, lineWidth: 1)).cornerRadius(5)
                                    Button("存") { store.renameCategory(id: cat.id, newName: ui.editingCategoryName); ui.editingCategoryId = nil }
                                        .buttonStyle(.plain).font(.system(size: 10.5, weight: .bold))
                                        .padding(.horizontal, 6).padding(.vertical, 4).background(palette.okColor).foregroundColor(.white).cornerRadius(5)
                                    Button(action: { ui.editingCategoryId = nil }) {
                                        Image(systemName: "xmark").font(.system(size: 9.5, weight: .bold)).foregroundColor(palette.mutedText)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(5).background(palette.cardBg).cornerRadius(7)
                            } else {
                                HStack(spacing: 4) {
                                    Text(cat.name).font(.system(size: 12, weight: isSelected ? .bold : .medium)).lineLimit(1).truncationMode(.tail)
                                    Spacer(minLength: 4)
                                    if showActions {
                                        Button(action: { ui.editingCategoryId = cat.id; ui.editingCategoryName = cat.name }) {
                                            Image(systemName: "pencil").font(.system(size: 10, weight: .semibold)).padding(3)
                                        }.buttonStyle(.plain)
                                        if store.categories.count > 1 {
                                            Button(action: { ui.pendingDeleteCategory = cat }) {
                                                Image(systemName: "trash").font(.system(size: 10, weight: .semibold)).padding(3)
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                    Text("\(actCount)/\(inCat.count)").font(.system(size: 10.5, weight: .semibold)).monospacedDigit().opacity(0.85)
                                }
                                .padding(.horizontal, 9).padding(.vertical, 7)
                                .background(isSelected ? palette.accentBlue : (ui.hoveredCategoryId == cat.id ? palette.chipBg : Color.clear))
                                .foregroundColor(isSelected ? .white : palette.primaryText).cornerRadius(8)
                                .contentShape(Rectangle())
                                .onTapGesture { ui.selectedCategoryId = cat.id }
                                .onHover { h in if h { ui.hoveredCategoryId = cat.id } else if ui.hoveredCategoryId == cat.id { ui.hoveredCategoryId = nil } }
                            }
                        }
                    }
                }

                Spacer(minLength: 4)
                Divider().background(palette.divider)

                HStack {
                    Text("显示系统内置 Skill").font(.system(size: 11.5)).foregroundColor(palette.secondaryText)
                    Spacer()
                    IOSToggleSwitch(isOn: store.showBuiltins, palette: palette) { store.showBuiltins.toggle() }
                }
                .padding(.horizontal, 4)

                HStack {
                    Button(action: { NSWorkspace.shared.open(URL(fileURLWithPath: store.fixedVaultPath)) }) {
                        Text(SkillStore.shortenHomePath(store.fixedVaultPath))
                            .font(.system(size: 10.5, design: .monospaced)).foregroundColor(palette.mutedText)
                            .lineLimit(1).truncationMode(.middle)
                    }.buttonStyle(.plain)
                    Spacer()
                    Button("更改") {
                        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
                        if panel.runModal() == .OK, let url = panel.url { store.changeFixedVaultDirectory(to: url.path) }
                    }.buttonStyle(.plain).font(.system(size: 10.5, weight: .semibold)).foregroundColor(palette.accentBlue)
                }
                .padding(.horizontal, 4)

                Text("已启用 ≈ \(formatTokenBadge(store.activeEstimatedTokens(for: ui.filterPlatform)))")
                    .font(.system(size: 10.5, design: .monospaced)).foregroundColor(palette.mutedText).padding(.horizontal, 4)
            }
            .padding(12).frame(width: 230).background(palette.sidebarBg)

            Divider().background(palette.divider)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    HorizontalPlatformTab(title: "全部平台 (\(categoryScopedSkills.count))", selected: ui.filterPlatform == nil, palette: palette) { ui.filterPlatform = nil }
                    ForEach(AgentPlatform.allCases) { pf in
                        let cnt = categoryScopedSkills.filter { $0.activePlatforms.contains(pf) }.count
                        HorizontalPlatformTab(title: "\(pf.fullName) (\(cnt))", selected: ui.filterPlatform == pf, palette: palette) {
                            ui.filterPlatform = (ui.filterPlatform == pf) ? nil : pf
                        }
                    }
                    Spacer()
                    if ui.selectedCategoryId != "ALL", let selCat = store.categories.first(where: { $0.id == ui.selectedCategoryId }) {
                        HStack(spacing: 5) {
                            Text("本分类:").font(.system(size: 11)).foregroundColor(palette.mutedText)
                            Button("全开") { store.setCategoryBatchEnabled(selCat.id, enabled: true) }
                                .buttonStyle(.plain).font(.system(size: 11, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 4)
                                .background(palette.okColor.opacity(0.16)).foregroundColor(palette.okColor).cornerRadius(6)
                            Button("全关") { store.setCategoryBatchEnabled(selCat.id, enabled: false) }
                                .buttonStyle(.plain).font(.system(size: 11, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 4)
                                .background(palette.warnColor.opacity(0.16)).foregroundColor(palette.warnColor).cornerRadius(6)
                        }
                    }
                }

                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundColor(palette.mutedText)
                        TextField("搜索当前列表中的 Skill 名称、用途或触发词…", text: $ui.searchText)
                            .textFieldStyle(.plain).font(.system(size: 12)).foregroundColor(palette.primaryText)
                        if !ui.searchText.isEmpty {
                            Button(action: { ui.searchText = "" }) {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundColor(palette.mutedText)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7).background(palette.cardBg)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(9)

                    Text("共 \(filteredSkills.count) 个").font(.system(size: 11.5, weight: .medium)).foregroundColor(palette.mutedText).monospacedDigit()
                    Button("全部展开") { filteredSkills.forEach { ui.expandedSkillIds.insert($0.id) } }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).padding(.horizontal, 8).padding(.vertical, 6)
                        .background(palette.cardBg).overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                        .foregroundColor(palette.secondaryText).cornerRadius(7)
                    Button("全部折叠") { ui.expandedSkillIds.removeAll() }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).padding(.horizontal, 8).padding(.vertical, 6)
                        .background(palette.cardBg).overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                        .foregroundColor(palette.secondaryText).cornerRadius(7)
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        if filteredSkills.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "tray").font(.system(size: 28)).foregroundColor(palette.mutedText)
                                Text("当前筛选条件下暂无匹配的 Skill").font(.system(size: 13)).foregroundColor(palette.secondaryText)
                            }.frame(maxWidth: .infinity).padding(.vertical, 70)
                        } else {
                            ForEach(filteredSkills) { skill in CollapsibleSkillCardView(skill: skill, store: store, ui: ui, palette: palette) }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity).background(palette.windowBg)
        }
    }
}

struct HorizontalPlatformTab: View {
    let title: String
    let selected: Bool
    var useAmber: Bool = false
    let palette: ThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: selected ? .bold : .medium))
                .padding(.horizontal, 11).padding(.vertical, 5.5)
                .background(selected ? (useAmber ? palette.amberAccent : palette.accentBlue) : palette.cardBg)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? (useAmber ? palette.amberAccent : palette.accentBlue) : palette.cardBorder, lineWidth: 1))
                .foregroundColor(selected ? (useAmber ? palette.amberFg : .white) : palette.secondaryText)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MCP Services View (Unified IA: Left = Purpose Group, Top = Platform Filter)

struct McpHubBodyView: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    private var categoryScoped: [McpServerItemModel] {
        ui.mcpCategoryFilter == "ALL" ? store.mcpServers : store.mcpServers.filter { $0.categoryId == ui.mcpCategoryFilter }
    }

    private var filteredServers: [McpServerItemModel] {
        let q = ui.mcpSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return categoryScoped.filter { srv in
            switch ui.mcpPlatformFilter {
            case "MULTI": if srv.platforms.count < 2 { return false }
            case "antigravity": if !srv.platforms.contains(.antigravity) { return false }
            case "codex": if !srv.platforms.contains(.codex) { return false }
            case "claude": if !srv.platforms.contains(.claude) { return false }
            default: break
            }
            if !q.isEmpty {
                let hay = "\(srv.id) \(srv.commandSummary) \(srv.envKeys.joined(separator: " "))".lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar: MCP Purpose Groups
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("MCP 用途分组").font(.system(size: 11.5, weight: .bold)).foregroundColor(palette.mutedText)
                    Spacer()
                    Button("+ 新建") { ui.showAddMcpCatBox.toggle() }
                        .buttonStyle(.plain).font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.accentBlue)
                }
                .padding(.horizontal, 6)

                if ui.showAddMcpCatBox {
                    HStack(spacing: 5) {
                        TextField("如 🔍 检索工具", text: $ui.newMcpCatName)
                            .textFieldStyle(.plain).font(.system(size: 11.5)).foregroundColor(palette.primaryText)
                            .padding(.horizontal, 7).padding(.vertical, 5).background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(6)
                        Button("添加") {
                            if let nid = store.addMcpCategory(name: ui.newMcpCatName) {
                                ui.newMcpCatName = ""; ui.showAddMcpCatBox = false; ui.mcpCategoryFilter = nid
                            }
                        }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 5).background(palette.accentBlue).foregroundColor(.white).cornerRadius(6)
                        .disabled(ui.newMcpCatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                ScrollView {
                    VStack(spacing: 3) {
                        catRow(id: "ALL", title: "🔌 全部 MCP 服务", count: store.mcpServers.count)
                        ForEach(store.mcpCategories) { cat in
                            catRow(id: cat.id, title: cat.name, count: store.mcpServers.filter { $0.categoryId == cat.id }.count)
                        }
                    }
                }

                Spacer()
                Divider().background(palette.divider)

                Text("配置文件快捷打开").font(.system(size: 10.5, weight: .bold)).foregroundColor(palette.mutedText).padding(.horizontal, 4)
                HStack(spacing: 5) {
                    ForEach(AgentPlatform.allCases) { pf in
                        let path = store.mcpConfigPath(for: pf)
                        let exists = FileManager.default.fileExists(atPath: path)
                        Button(action: {
                            if exists { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
                            else { store.showBanner("未检测到 \(pf.fullName) MCP 配置文件", isError: true) }
                        }) {
                            Text("\(pf.shortLabel) ↗")
                                .font(.system(size: 10.5, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5.5)
                                .background(palette.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                                .foregroundColor(exists ? palette.primaryText : palette.mutedText)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12).frame(width: 230).frame(maxHeight: .infinity).background(palette.sidebarBg)

            Divider().background(palette.divider)

            // Right Pane: Platform Filter Topbar + Cards
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    HorizontalPlatformTab(title: "全部平台 (\(categoryScoped.count))", selected: ui.mcpPlatformFilter == "ALL", palette: palette) { ui.mcpPlatformFilter = "ALL" }
                    HorizontalPlatformTab(title: "多端共用 (\(categoryScoped.filter { $0.platforms.count >= 2 }.count))", selected: ui.mcpPlatformFilter == "MULTI", palette: palette) {
                        ui.mcpPlatformFilter = ui.mcpPlatformFilter == "MULTI" ? "ALL" : "MULTI"
                    }
                    ForEach(AgentPlatform.allCases) { pf in
                        let cnt = categoryScoped.filter { $0.platforms.contains(pf) }.count
                        HorizontalPlatformTab(title: "\(pf.fullName) (\(cnt))", selected: ui.mcpPlatformFilter == pf.rawValue, palette: palette) {
                            ui.mcpPlatformFilter = (ui.mcpPlatformFilter == pf.rawValue) ? "ALL" : pf.rawValue
                        }
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundColor(palette.mutedText)
                        TextField("搜索 MCP 名称、命令或环境变量键…", text: $ui.mcpSearchText)
                            .textFieldStyle(.plain).font(.system(size: 12)).foregroundColor(palette.primaryText)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7).background(palette.cardBg)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(9)
                    Text("共 \(filteredServers.count) 个").font(.system(size: 11.5)).foregroundColor(palette.mutedText).monospacedDigit()
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        if filteredServers.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "server.rack").font(.system(size: 28)).foregroundColor(palette.mutedText)
                                Text("当前分组或平台下暂无 MCP 服务").font(.system(size: 13)).foregroundColor(palette.secondaryText)
                            }.frame(maxWidth: .infinity).padding(.vertical, 70)
                        } else {
                            ForEach(filteredServers) { srv in CollapsibleMcpCardView(server: srv, store: store, ui: ui, palette: palette) }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity).background(palette.windowBg)
        }
    }

    private func catRow(id: String, title: String, count: Int) -> some View {
        let selected = ui.mcpCategoryFilter == id
        return Button(action: { ui.mcpCategoryFilter = id }) {
            HStack {
                Text(title).font(.system(size: 12, weight: selected ? .bold : .medium)).lineLimit(1).truncationMode(.tail)
                Spacer()
                Text("\(count)").font(.system(size: 10.5, weight: .semibold, design: .monospaced)).opacity(0.85)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(selected ? palette.accentBlue : Color.clear)
            .foregroundColor(selected ? .white : palette.primaryText).cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct CollapsibleMcpCardView: View {
    let server: McpServerItemModel
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    private var isExpanded: Bool { ui.expandedMcpIds.contains(server.id) }
    private var catName: String { store.mcpCategories.first(where: { $0.id == server.categoryId })?.name ?? "其他服务" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(server.id).font(.system(size: 13.5, weight: .bold, design: .monospaced)).foregroundColor(palette.primaryText)
                        ForEach(AgentPlatform.allCases.filter { server.platforms.contains($0) }) { pf in
                            Text(pf.fullName).font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(palette.accentBlue.opacity(0.14)).foregroundColor(palette.accentBlue).cornerRadius(5)
                        }
                    }
                    Text(server.commandSummary).font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(palette.mutedText).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundColor(palette.mutedText)
            }
            .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
            .onTapGesture { if isExpanded { ui.expandedMcpIds.remove(server.id) } else { ui.expandedMcpIds.insert(server.id) } }

            if isExpanded {
                Divider().background(palette.divider)
                VStack(alignment: .leading, spacing: 10) {
                    Text(server.commandSummary)
                        .font(.system(size: 11.5, design: .monospaced)).foregroundColor(palette.primaryText)
                        .padding(9).frame(maxWidth: .infinity, alignment: .leading).background(palette.inputBg)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(7)

                    if !server.envKeys.isEmpty {
                        Text("环境变量键（值已隐藏）: \(server.envKeys.joined(separator: ", "))")
                            .font(.system(size: 11.5)).foregroundColor(palette.secondaryText)
                    }

                    HStack(spacing: 8) {
                        Text("跨端同步:").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.mutedText)
                        ForEach(AgentPlatform.allCases) { pf in
                            if server.platforms.contains(pf) {
                                Button(action: { store.removeMcpServer(server, from: pf) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill").font(.system(size: 10.5))
                                        Text("\(pf.fullName)（点击移除）").font(.system(size: 11, weight: .semibold))
                                    }
                                    .padding(.horizontal, 9).padding(.vertical, 4.5).background(palette.okColor.opacity(0.15))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.okColor.opacity(0.45), lineWidth: 1))
                                    .foregroundColor(palette.okColor).cornerRadius(6)
                                }.buttonStyle(.plain)
                            } else {
                                Button(action: { store.syncMcpServer(server, to: pf) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 10))
                                        Text("同步至 \(pf.fullName)").font(.system(size: 11, weight: .semibold))
                                    }
                                    .padding(.horizontal, 9).padding(.vertical, 4.5).background(palette.accentBlue.opacity(0.14))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.accentBlue.opacity(0.4), lineWidth: 1))
                                    .foregroundColor(palette.accentBlue).cornerRadius(6)
                                }.buttonStyle(.plain)
                            }
                        }
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        Text("用途分组:").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.mutedText)
                        Menu {
                            ForEach(store.mcpCategories) { c in
                                Button(c.id == server.categoryId ? "✓ \(c.name)" : c.name) { store.assignMcpCategory(c.id, to: server.id) }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(catName).font(.system(size: 11.5, weight: .medium)).foregroundColor(palette.primaryText)
                                Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(palette.mutedText)
                            }
                            .padding(.horizontal, 9).padding(.vertical, 4.5).background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(6)
                        }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                        Spacer()
                        ForEach(AgentPlatform.allCases.filter { server.configPaths[$0] != nil }) { pf in
                            if let path = server.configPaths[pf] {
                                Button(action: { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }) {
                                    Text("打开 \(pf.shortLabel) 配置 ↗").font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 8).padding(.vertical, 4.5).background(palette.cardBg)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                                        .foregroundColor(palette.primaryText).cornerRadius(6)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(14).background(palette.windowBg.opacity(0.45))
            }
        }
        .background(palette.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(11)
    }
}

// MARK: - Plugins View (Unified IA: Left = Purpose Group, Top = Platform Filter)

struct PluginsHubBodyView: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    private var categoryScoped: [PluginItemModel] {
        ui.pluginCategoryFilter == "ALL" ? store.plugins : store.plugins.filter { $0.categoryId == ui.pluginCategoryFilter }
    }

    private var filteredPlugins: [PluginItemModel] {
        let q = ui.pluginSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return categoryScoped.filter { p in
            if let pf = ui.pluginPlatformFilter, p.platform != pf { return false }
            if !q.isEmpty {
                let hay = "\(p.rawId) \(p.displayName) \(p.descriptionText) \(p.authorName) \(p.bundledSkills.joined(separator: " "))".lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("插件用途分组").font(.system(size: 11.5, weight: .bold)).foregroundColor(palette.mutedText)
                    Spacer()
                    Button("+ 新建") { ui.showAddPluginCatBox.toggle() }
                        .buttonStyle(.plain).font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.accentBlue)
                }
                .padding(.horizontal, 6)

                if ui.showAddPluginCatBox {
                    HStack(spacing: 5) {
                        TextField("如 🎬 多媒体", text: $ui.newPluginCatName)
                            .textFieldStyle(.plain).font(.system(size: 11.5)).foregroundColor(palette.primaryText)
                            .padding(.horizontal, 7).padding(.vertical, 5).background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(6)
                        Button("添加") {
                            if let nid = store.addPluginCategory(name: ui.newPluginCatName) {
                                ui.newPluginCatName = ""; ui.showAddPluginCatBox = false; ui.pluginCategoryFilter = nid
                            }
                        }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 5).background(palette.accentBlue).foregroundColor(.white).cornerRadius(6)
                        .disabled(ui.newPluginCatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                ScrollView {
                    VStack(spacing: 3) {
                        catRow(id: "ALL", title: "🧩 全部插件", count: store.plugins.count)
                        ForEach(store.pluginCategories) { cat in
                            catRow(id: cat.id, title: cat.name, count: store.plugins.filter { $0.categoryId == cat.id }.count)
                        }
                    }
                }

                Spacer()
                Divider().background(palette.divider)

                Button(action: { NSWorkspace.shared.open(URL(fileURLWithPath: store.agyPluginsDir())) }) {
                    HStack {
                        Text("~/.gemini/config/plugins").font(.system(size: 10.5, design: .monospaced)).foregroundColor(palette.primaryText).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text("↗").font(.system(size: 10.5)).foregroundColor(palette.accentBlue)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 6).background(palette.inputBg)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
            .padding(12).frame(width: 230).frame(maxHeight: .infinity).background(palette.sidebarBg)

            Divider().background(palette.divider)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    HorizontalPlatformTab(title: "全部平台 (\(categoryScoped.count))", selected: ui.pluginPlatformFilter == nil, palette: palette) { ui.pluginPlatformFilter = nil }
                    ForEach(AgentPlatform.allCases) { pf in
                        let cnt = categoryScoped.filter { $0.platform == pf }.count
                        HorizontalPlatformTab(title: "\(pf.fullName) (\(cnt))", selected: ui.pluginPlatformFilter == pf, palette: palette) {
                            ui.pluginPlatformFilter = (ui.pluginPlatformFilter == pf) ? nil : pf
                        }
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundColor(palette.mutedText)
                        TextField("搜索插件名称、描述或内置 Skill…", text: $ui.pluginSearchText)
                            .textFieldStyle(.plain).font(.system(size: 12)).foregroundColor(palette.primaryText)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7).background(palette.cardBg)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(9)
                    Text("共 \(filteredPlugins.count) 个").font(.system(size: 11.5)).foregroundColor(palette.mutedText).monospacedDigit()
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        if filteredPlugins.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "puzzlepiece.extension").font(.system(size: 28)).foregroundColor(palette.mutedText)
                                Text("当前分组或平台下暂无插件").font(.system(size: 13)).foregroundColor(palette.secondaryText)
                            }.frame(maxWidth: .infinity).padding(.vertical, 70)
                        } else {
                            ForEach(filteredPlugins) { plugin in CollapsiblePluginCardView(plugin: plugin, store: store, ui: ui, palette: palette) }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity).background(palette.windowBg)
        }
    }

    private func catRow(id: String, title: String, count: Int) -> some View {
        let selected = ui.pluginCategoryFilter == id
        return Button(action: { ui.pluginCategoryFilter = id }) {
            HStack {
                Text(title).font(.system(size: 12, weight: selected ? .bold : .medium)).lineLimit(1).truncationMode(.tail)
                Spacer()
                Text("\(count)").font(.system(size: 10.5, weight: .semibold, design: .monospaced)).opacity(0.85)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(selected ? palette.accentBlue : Color.clear)
            .foregroundColor(selected ? .white : palette.primaryText).cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct CollapsiblePluginCardView: View {
    let plugin: PluginItemModel
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    private var isExpanded: Bool { ui.expandedPluginIds.contains(plugin.id) }
    private var catName: String { store.pluginCategories.first(where: { $0.id == plugin.categoryId })?.name ?? "其他插件" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text("🧩 \(plugin.displayName)").font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(plugin.isEnabled ? palette.primaryText : palette.secondaryText)
                        Text(plugin.platform.shortLabel).font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(palette.accentBlue.opacity(0.14)).foregroundColor(palette.accentBlue).cornerRadius(5)
                        Text(plugin.version).font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(palette.purpleAccent.opacity(0.14)).foregroundColor(palette.purpleAccent).cornerRadius(5)
                        if !plugin.bundledSkills.isEmpty {
                            Text("\(plugin.bundledSkills.count) Skill").font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2).background(palette.chipBg).foregroundColor(palette.secondaryText).cornerRadius(5)
                        }
                    }
                    Text(plugin.descriptionText).font(.system(size: 11.5)).foregroundColor(palette.mutedText).lineLimit(1)
                }
                Spacer()
                if plugin.canToggle {
                    IOSToggleSwitch(isOn: plugin.isEnabled, palette: palette) { store.togglePlugin(plugin) }
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundColor(palette.mutedText)
            }
            .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
            .onTapGesture { if isExpanded { ui.expandedPluginIds.remove(plugin.id) } else { ui.expandedPluginIds.insert(plugin.id) } }

            if isExpanded {
                Divider().background(palette.divider)
                VStack(alignment: .leading, spacing: 10) {
                    Text("插件 ID: \(plugin.rawId)  ·  来源: \(plugin.authorName)").font(.system(size: 11.5)).foregroundColor(palette.secondaryText)

                    if !plugin.bundledSkills.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(plugin.bundledSkills, id: \.self) { sk in
                                    Button(action: {
                                        if plugin.platform == .antigravity {
                                            ui.selectedCategoryId = "ALL"; ui.filterPlatform = nil; ui.searchText = sk
                                            ui.expandedSkillIds.insert(sk); ui.activeTab = .skills
                                        }
                                    }) {
                                        Text(plugin.platform == .antigravity ? "\(sk) →" : sk)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .padding(.horizontal, 8).padding(.vertical, 4)
                                            .background(palette.accentBlue.opacity(0.14))
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.accentBlue.opacity(0.32), lineWidth: 1))
                                            .foregroundColor(palette.accentBlue).cornerRadius(6)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Text("用途分组:").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.mutedText)
                        Menu {
                            ForEach(store.pluginCategories) { c in
                                Button(c.id == plugin.categoryId ? "✓ \(c.name)" : c.name) { store.assignPluginCategory(c.id, to: plugin.id) }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(catName).font(.system(size: 11.5, weight: .medium)).foregroundColor(palette.primaryText)
                                Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(palette.mutedText)
                            }
                            .padding(.horizontal, 9).padding(.vertical, 4.5).background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(6)
                        }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()

                        Spacer()
                        Button("打开目录") { NSWorkspace.shared.open(URL(fileURLWithPath: plugin.pluginPath)) }
                            .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).padding(.horizontal, 9).padding(.vertical, 4.5)
                            .background(palette.cardBg).overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.primaryText).cornerRadius(6)

                        if plugin.canUninstall {
                            Button("卸载") { ui.pendingUninstallPlugin = plugin }
                                .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).padding(.horizontal, 9).padding(.vertical, 4.5)
                                .background(palette.dangerColor.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.dangerColor.opacity(0.35), lineWidth: 1))
                                .foregroundColor(palette.dangerColor).cornerRadius(6)
                        }
                    }
                }
                .padding(14).background(palette.windowBg.opacity(0.45))
            }
        }
        .background(palette.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(11)
        .opacity(plugin.isEnabled ? 1.0 : 0.72)
    }
}

// MARK: - Independent Research Watchlist Space (Plan A)

struct WatchlistHubBodyView: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    private var statusScoped: [WatchlistItem] {
        guard let st = ui.watchlistStatusFilter else { return store.watchlist }
        return store.watchlist.filter { $0.status == st }
    }

    private var filteredItems: [WatchlistItem] {
        let q = ui.watchlistSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return statusScoped.filter { w in
            if let k = ui.watchlistKindFilter, w.kind != k { return false }
            if ui.watchlistOnlyUninstalled && store.isWatchlistItemInstalledLocally(w) { return false }
            if !q.isEmpty {
                let hay = "\(w.name) \(w.repoUrl) \(w.summary) \(w.notes) \(w.tags.joined(separator: " ")) \(w.installCmd)".lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar: Research Status Grouping
            VStack(alignment: .leading, spacing: 8) {
                Text("研究状态分组").font(.system(size: 11.5, weight: .bold)).foregroundColor(palette.mutedText).padding(.horizontal, 6)

                statusRow(nil, title: "全部关注", dotColor: palette.amberAccent, count: store.watchlist.count)
                ForEach(WatchlistStatus.allCases) { st in
                    statusRow(st, title: st.label, dotColor: st.tintColor(in: palette), count: store.watchlist.filter { $0.status == st }.count)
                }

                Spacer()
                Divider().background(palette.divider)

                Text("独立存储: .watchlist.json").font(.system(size: 10.5, design: .monospaced)).foregroundColor(palette.mutedText).padding(.horizontal, 4)
                HStack(spacing: 6) {
                    Button("导出 JSON") { store.exportWatchlistAsJSON() }
                        .buttonStyle(.plain).font(.system(size: 10.5, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 5.5)
                        .background(palette.inputBg).overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                        .foregroundColor(palette.primaryText).cornerRadius(6)
                    Button("导出 MD") { store.exportWatchlistAsMarkdown() }
                        .buttonStyle(.plain).font(.system(size: 10.5, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 5.5)
                        .background(palette.inputBg).overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                        .foregroundColor(palette.primaryText).cornerRadius(6)
                }
            }
            .padding(12).frame(width: 230).frame(maxHeight: .infinity).background(palette.sidebarBg)

            Divider().background(palette.divider)

            // Right Main Radar Workspace
            VStack(alignment: .leading, spacing: 12) {
                // Context Space Banner
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("研究雷达 · 关注收藏空间").font(.system(size: 12.5, weight: .bold)).foregroundColor(palette.amberAccent)
                            Text("（与本地已装运行态隔离）").font(.system(size: 11.5)).foregroundColor(palette.secondaryText)
                        }
                        Text("仅保存结构化元信息、GitHub 地址与研究笔记，不克隆代码到本地、不消耗 Agent 上下文；随时可一键转入本地安装。")
                            .font(.system(size: 11)).foregroundColor(palette.mutedText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 13).padding(.vertical, 10)
                .background(palette.amberBg)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.amberBorder, lineWidth: 1))
                .cornerRadius(9)

                // Kind Filter Pills + Only Uninstalled Toggle
                HStack(spacing: 6) {
                    HorizontalPlatformTab(title: "全部类型 (\(statusScoped.count))", selected: ui.watchlistKindFilter == nil, useAmber: true, palette: palette) {
                        ui.watchlistKindFilter = nil
                    }
                    ForEach(WatchlistKind.allCases) { k in
                        let cnt = statusScoped.filter { $0.kind == k }.count
                        HorizontalPlatformTab(title: "\(k.label) (\(cnt))", selected: ui.watchlistKindFilter == k, useAmber: true, palette: palette) {
                            ui.watchlistKindFilter = (ui.watchlistKindFilter == k) ? nil : k
                        }
                    }
                    Spacer()
                    Button(action: { ui.watchlistOnlyUninstalled.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: ui.watchlistOnlyUninstalled ? "checkmark.circle.fill" : "circle").font(.system(size: 10.5))
                            Text("仅看本地未装").font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(ui.watchlistOnlyUninstalled ? palette.okColor.opacity(0.16) : palette.cardBg)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(ui.watchlistOnlyUninstalled ? palette.okColor : palette.cardBorder, lineWidth: 1))
                        .foregroundColor(ui.watchlistOnlyUninstalled ? palette.okColor : palette.secondaryText).cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                }

                // Search Row
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundColor(palette.mutedText)
                        TextField("搜索关注项目名、GitHub 地址、标签或研究笔记…", text: $ui.watchlistSearchText)
                            .textFieldStyle(.plain).font(.system(size: 12)).foregroundColor(palette.primaryText)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7).background(palette.cardBg)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(9)
                    Text("共 \(filteredItems.count) 项").font(.system(size: 11.5)).foregroundColor(palette.mutedText).monospacedDigit()
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        if filteredItems.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "star.circle").font(.system(size: 32)).foregroundColor(palette.amberAccent.opacity(0.8))
                                Text(store.watchlist.isEmpty ? "还没有收录关注项目，点击右上角「+ 收录关注」开始建立你的研究雷达" : "当前筛选条件下暂无匹配条目")
                                    .font(.system(size: 12.5)).foregroundColor(palette.secondaryText)
                            }.frame(maxWidth: .infinity).padding(.vertical, 64)
                        } else {
                            ForEach(filteredItems) { item in
                                CollapsibleWatchlistCardView(item: item, store: store, ui: ui, palette: palette)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity).background(palette.windowBg)
        }
    }

    private func statusRow(_ st: WatchlistStatus?, title: String, dotColor: Color, count: Int) -> some View {
        let selected = ui.watchlistStatusFilter == st
        return Button(action: { ui.watchlistStatusFilter = st }) {
            HStack(spacing: 7) {
                Circle().fill(dotColor).frame(width: 7, height: 7)
                Text(title).font(.system(size: 12, weight: selected ? .bold : .medium)).lineLimit(1)
                Spacer()
                Text("\(count)").font(.system(size: 10.5, weight: .semibold, design: .monospaced)).opacity(0.85)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(selected ? palette.amberBg : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? palette.amberBorder : Color.clear, lineWidth: 1))
            .foregroundColor(selected ? palette.amberAccent : palette.primaryText).cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct CollapsibleWatchlistCardView: View {
    let item: WatchlistItem
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    private var isExpanded: Bool { ui.expandedWatchlistIds.contains(item.id) }
    private var isFetching: Bool { store.fetchingWatchIds.contains(item.id) }
    private var isInstalledLocally: Bool { store.isWatchlistItemInstalledLocally(item) }
    private var currentDraftNote: String { ui.wlDraftNotes[item.id] ?? item.notes }
    private var noteBinding: Binding<String> {
        Binding(
            get: { ui.wlDraftNotes[item.id] ?? item.notes },
            set: { ui.wlDraftNotes[item.id] = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Circle().fill(item.status.tintColor(in: palette)).frame(width: 8.5, height: 8.5)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.name).font(.system(size: 13.5, weight: .semibold)).foregroundColor(palette.primaryText).lineLimit(1)
                        Text(item.kind.label).font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(palette.accentBlue.opacity(0.14)).foregroundColor(palette.accentBlue).cornerRadius(4)
                        Text(item.status.label).font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(palette.chipBg).foregroundColor(item.status.tintColor(in: palette)).cornerRadius(4)
                        if !item.starsText.isEmpty {
                            Text("★ \(item.starsText)").font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(palette.chipBg).foregroundColor(palette.secondaryText).cornerRadius(4)
                        }
                        if isInstalledLocally {
                            Text("本地已装").font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(palette.okColor.opacity(0.16)).foregroundColor(palette.okColor).cornerRadius(4)
                        }
                    }
                    Text(item.summary).font(.system(size: 11.5)).foregroundColor(palette.mutedText).lineLimit(1)
                }
                Spacer()

                if !item.repoUrl.isEmpty, let url = URL(string: item.repoUrl) {
                    Button("GitHub ↗") { NSWorkspace.shared.open(url) }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8).padding(.vertical, 4.5).background(palette.inputBg)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                        .foregroundColor(palette.primaryText).cornerRadius(6)
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundColor(palette.mutedText)
            }
            .padding(.horizontal, 14).padding(.vertical, 11).contentShape(Rectangle())
            .onTapGesture {
                if isExpanded { ui.expandedWatchlistIds.remove(item.id) }
                else { ui.wlDraftNotes[item.id] = item.notes; ui.expandedWatchlistIds.insert(item.id) }
            }

            if isExpanded {
                Divider().background(palette.divider)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        if !item.repoUrl.isEmpty {
                            Text(item.repoUrl).font(.system(size: 11, design: .monospaced)).foregroundColor(palette.accentBlue).lineLimit(1).truncationMode(.middle)
                        }
                        if !item.language.isEmpty { Text("· \(item.language)").font(.system(size: 11)).foregroundColor(palette.mutedText) }
                        if !item.pushedAt.isEmpty { Text("· 更新于 \(item.pushedAt)").font(.system(size: 11)).foregroundColor(palette.mutedText) }
                        Spacer()
                        ForEach(item.tags.prefix(4), id: \.self) { t in
                            Text("#\(t)").font(.system(size: 10.5)).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(palette.chipBg).foregroundColor(palette.secondaryText).cornerRadius(4)
                        }
                    }

                    if !item.installCmd.isEmpty {
                        HStack {
                            Text("$ \(item.installCmd)").font(.system(size: 11.5, design: .monospaced)).foregroundColor(palette.primaryText)
                            Spacer()
                            Button("复制命令") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.installCmd, forType: .string)
                                store.showBanner("✅ 已复制命令到剪贴板")
                            }
                            .buttonStyle(.plain).font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3.5).background(palette.chipBg).foregroundColor(palette.primaryText).cornerRadius(5)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6).background(palette.inputBg)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(7)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("研究笔记").font(.system(size: 11, weight: .semibold)).foregroundColor(palette.mutedText)
                            Spacer()
                            if currentDraftNote != item.notes {
                                Button("保存笔记") {
                                    var updated = item; updated.notes = currentDraftNote
                                    store.updateWatchlistItem(updated)
                                    store.showBanner("✅ 已保存「\(item.name)」的研究笔记")
                                }
                                .buttonStyle(.plain).font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(palette.amberAccent).foregroundColor(palette.amberFg).cornerRadius(5)
                            }
                        }
                        TextEditor(text: noteBinding)
                            .font(.system(size: 12))
                            .frame(minHeight: 62, maxHeight: 110)
                            .padding(5).background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(7)
                    }

                    HStack(spacing: 8) {
                        Text("研究状态:").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.mutedText)
                        Menu {
                            ForEach(WatchlistStatus.allCases) { st in
                                Button(st == item.status ? "✓ \(st.label)" : st.label) {
                                    var updated = item; updated.status = st
                                    store.updateWatchlistItem(updated)
                                    store.showBanner("✅ 状态已切换为「\(st.label)」")
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(item.status.label).font(.system(size: 11.5, weight: .medium)).foregroundColor(palette.primaryText)
                                Image(systemName: "chevron.down").font(.system(size: 9)).foregroundColor(palette.mutedText)
                            }
                            .padding(.horizontal, 9).padding(.vertical, 4.5).background(palette.cardBg)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(6)
                        }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()

                        Spacer()

                        if !item.repoUrl.isEmpty {
                            Button(action: { store.refreshWatchlistItemMetadata(item) }) {
                                HStack(spacing: 4) {
                                    if isFetching { ProgressView().scaleEffect(0.5).frame(width: 11, height: 11) }
                                    Text(isFetching ? "抓取中…" : "刷新元信息").font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 9).padding(.vertical, 4.5).background(palette.cardBg)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.cardBorder, lineWidth: 1))
                                .foregroundColor(palette.primaryText).cornerRadius(6)
                            }
                            .buttonStyle(.plain).disabled(isFetching)
                        }

                        if item.kind == .skill || item.kind == .plugin {
                            Button(isInstalledLocally ? "在本地查看 →" : "转入本地安装 →") {
                                if isInstalledLocally {
                                    ui.searchText = item.name
                                    ui.activeTab = item.kind == .plugin ? .plugins : .skills
                                } else if item.kind == .skill {
                                    ui.githubInput = item.repoUrl
                                    ui.importEnableAgy = store.isPlatformInstalled(.antigravity)
                                    ui.importEnableCodex = store.isPlatformInstalled(.codex)
                                    ui.importEnableClaude = store.isPlatformInstalled(.claude)
                                    ui.showImportModal = true
                                } else {
                                    ui.pluginGithubInput = item.repoUrl
                                    ui.showInstallPluginModal = true
                                }
                            }
                            .buttonStyle(.plain).font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 9).padding(.vertical, 4.5)
                            .background(palette.okColor.opacity(0.16)).foregroundColor(palette.okColor).cornerRadius(6)
                        }

                        Button("移除") { store.deleteWatchlistItem(id: item.id) }
                            .buttonStyle(.plain).font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 9).padding(.vertical, 4.5)
                            .background(palette.dangerColor.opacity(0.12)).foregroundColor(palette.dangerColor).cornerRadius(6)
                    }
                }
                .padding(14).background(palette.windowBg.opacity(0.45))
            }
        }
        .background(palette.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(11)
    }
}
