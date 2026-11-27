import UniformTypeIdentifiers
import AppKit
import SwiftUI

// MARK: - Observable UI State

final class SkillHubUIState: ObservableObject {
    @Published var lastMessage = "就绪"
    @Published var selections: [HubTab: String] = [:]
    @Published var editing: String? = nil
    @Published var draft = ""
    @Published var dropTarget: String? = nil
    @Published var dragged: String? = nil
    @Published var sourceMode = false
    @Published var toml = false
    @Published var destination = ""
    @Published var activeTab: HubTab = .skills {
        didSet {
            guard activeTab != oldValue else { return }
            editing = nil
            dragged = nil
            dropTarget = nil
        }
    }
    @Published var selectedCategoryId: String = "ALL"
    @Published var filterPlatform: AgentPlatform? = nil
    @Published var searchText: String = ""
    @Published var hoveredCategoryId: String? = nil

    // MCP (Left = Purpose Group, Top = Platform Filter)
    @Published var mcpCategoryFilter: String = "ALL"
    @Published var mcpPlatformFilter: String = "ALL" // ALL, MULTI, antigravity, codex, claude
    @Published var mcpSearchText: String = ""

    // Plugins (Left = Purpose Group, Top = Platform Filter)
    @Published var pluginCategoryFilter: String = "ALL"
    @Published var pluginPlatformFilter: AgentPlatform? = nil
    @Published var pluginSearchText: String = ""

    // Watchlist (Plan A Independent Research Radar Space)
    @Published var watchlistStatusFilter: WatchlistStatus? = nil
    @Published var watchlistKindFilter: WatchlistKind? = nil
    @Published var watchlistOnlyUninstalled: Bool = false
    @Published var watchlistSearchText: String = ""

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

    // Modals
    @Published var pendingDeleteCategory: SkillCategory? = nil
    @Published var archiveTrashedSkill = false
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

struct SkillHubRootView: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState

    private var palette: ThemePalette { ThemePalette(isDark: store.isDarkTheme) }
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Bar (Plan A: Pure 3 Local Assets | Independent Watchlist Space Pill)
                HStack(spacing: 8) {
                    HStack(spacing: 7) {
                        Image(systemName: "square.grid.2x2").font(.system(size: 14, weight: .semibold)).foregroundColor(palette.accentBlue)
                        Text("Apollo AgentHub").font(.system(size: 14.5, weight: .bold)).foregroundColor(palette.primaryText)
                    }

                    Text("v2.0").padding(.horizontal, 4).padding(.vertical, 2).background(palette.surfaceBg).cornerRadius(3).font(.system(size: 10, design: .monospaced)).foregroundColor(palette.secondaryText)
                    // Pure 3-Tab Local Runtime Assets Segmented Control
                    HStack(spacing: 2) {
                        ForEach(HubTab.localAssetTabs) { tab in
                            let isSelected = ui.activeTab == tab
                            Button(tab.rawValue == "mcp" ? "MCP" : tab == .skills ? "Skills" : "Plugins") { ui.activeTab = tab }
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .frame(width: 58, height: 24)
                                .background(isSelected ? palette.surfaceBg : Color.clear)
                                .cornerRadius(5)
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
                        .foregroundColor(palette.amberAccent)
                        .cornerRadius(8.5)
                    }
                    .buttonStyle(.plain)
                    .help("外部研究与观察池（独立存储，不下载代码到本地）")

                    Spacer()

                    // Profile Preset Menu (visible in local modes)
                    Group {
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
                                Text("场景预设").font(.system(size: 11, weight: .semibold))
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
                                Circle().fill(palette.amberAccent).frame(width: 6, height: 6)
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
                        store.showBanner("已刷新三端本地状态与关注收藏库")
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))

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
                .padding(.leading, 78).padding(.trailing, 12).frame(height: 50).background(palette.sidebarBg)

                Divider().background(palette.divider)

                if let banner = store.statusBanner, !banner.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: store.statusIsError ? "exclamationmark.circle" : "checkmark.circle")
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

                Workbench(store: store, ui: ui, palette: palette)
                Divider()
                HStack(spacing: 7) {
                    Circle().fill(palette.okColor).frame(width: 6, height: 6)
                    Text("本地工作区")
                    Spacer()
                    Text(ui.lastMessage).lineLimit(1)
                }.font(.system(size: 10, design: .monospaced)).foregroundColor(palette.secondaryText)
                    .padding(.horizontal, 12).frame(height: 24).background(palette.sidebarBg)
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
        .foregroundColor(palette.primaryText)
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(store.isDarkTheme ? .dark : .light)
        .onReceive(store.$statusBanner.compactMap { $0 }) { ui.lastMessage = $0 }
    }

}

private struct Workbench: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette
    @FocusState private var editingFocused: Bool
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

    private var categoryScopedMcp: [McpServerItemModel] {
        ui.mcpCategoryFilter == "ALL" ? store.mcpServers : store.mcpServers.filter { $0.categoryId == ui.mcpCategoryFilter }
    }

    private var filteredServers: [McpServerItemModel] {
        let q = ui.mcpSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return categoryScopedMcp.filter { srv in
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

    private var categoryScopedPlugin: [PluginItemModel] {
        ui.pluginCategoryFilter == "ALL" ? store.plugins : store.plugins.filter { $0.categoryId == ui.pluginCategoryFilter }
    }

    private var filteredPlugins: [PluginItemModel] {
        let q = ui.pluginSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return categoryScopedPlugin.filter { p in
            if let pf = ui.pluginPlatformFilter, p.platform != pf { return false }
            if !q.isEmpty {
                let hay = "\(p.rawId) \(p.displayName) \(p.descriptionText) \(p.authorName) \(p.bundledSkills.joined(separator: " "))".lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

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

    var tab: HubTab { ui.activeTab }
    var research: Bool { tab == .watchlist }
    var tint: Color { research ? palette.amberAccent : palette.accentBlue }
    var groups: [SkillCategory] {
        switch tab {
        case .skills: return store.categories
        case .mcp: return store.mcpCategories
        case .plugins: return store.pluginCategories
        case .watchlist: return []
        }
    }
    var group: Binding<String> {
        switch tab {
        case .skills: return $ui.selectedCategoryId
        case .mcp: return $ui.mcpCategoryFilter
        case .plugins: return $ui.pluginCategoryFilter
        case .watchlist: return .constant("ALL")
        }
    }
    var query: Binding<String> {
        switch tab {
        case .skills: return $ui.searchText
        case .mcp: return $ui.mcpSearchText
        case .plugins: return $ui.pluginSearchText
        case .watchlist: return $ui.watchlistSearchText
        }
    }
    var ids: [String] {
        switch tab {
        case .skills: return filteredSkills.map(\.id)
        case .mcp: return filteredServers.map(\.id)
        case .plugins: return filteredPlugins.map(\.id)
        case .watchlist: return filteredItems.map(\.id)
        }
    }
    func count(_ id: String) -> Int {
        switch tab {
        case .skills: return visibleBaseSkills.filter { id == "ALL" || $0.categoryId == id }.count
        case .mcp: return store.mcpServers.filter { id == "ALL" || $0.categoryId == id }.count
        case .plugins: return store.plugins.filter { id == "ALL" || $0.categoryId == id }.count
        case .watchlist: return store.watchlist.count
        }
    }
    var body: some View {
        let visible = ids
        let current = ui.selections[tab].flatMap { visible.contains($0) ? $0 : nil } ?? visible.first
        HStack(spacing: 0) {
            sidebar.frame(width: 224)
            Divider()
            VStack(spacing: 0) {
                summary
                Divider()
                filters(total: visible.count)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        rows(current)
                        if visible.isEmpty { Text("暂无匹配的资产").foregroundColor(palette.mutedText).padding(28) }
                    }
                }
            }.frame(maxWidth: .infinity).background(palette.listBg)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("INSPECTOR").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(palette.mutedText)
                    details(current)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }.frame(width: 332).background(palette.inspectorBg)
        }.font(.system(size: 12))
    }
    var sidebar: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(research ? "研究状态" : "用途分组").fontWeight(.semibold)
                Spacer()
                if !research { icon("plus", "新建分组") { startEdit("NEW", "") } }
            }
            ScrollView {
                VStack(spacing: 3) {
                    if research {
                        status(nil)
                        ForEach(WatchlistStatus.allCases) { status($0) }
                    } else {
                        if ui.editing == "NEW" { editor }
                        groupRow(nil)
                        ForEach(groups) { cat in
                            if ui.editing == cat.id { editor }
                            else { groupRow(cat)
                                .onDrag { ui.dragged = cat.id; return NSItemProvider(object: ("agenthub/" + tab.rawValue + "/" + cat.id) as NSString) }
                                .onDrop(of: [UTType.plainText], isTargeted: Binding(get: { ui.dropTarget == cat.id }, set: { over in
                                    if over && ui.dragged != nil { ui.dropTarget = cat.id } else if ui.dropTarget == cat.id { ui.dropTarget = nil }
                                })) { providers in
                                    defer { ui.dragged = nil; ui.dropTarget = nil }
                                    guard let from = ui.dragged, let provider = providers.first else { return false }
                                    let space = tab
                                    _ = provider.loadObject(ofClass: NSString.self) { value, _ in
                                        guard value as? String == "agenthub/" + space.rawValue + "/" + from else { return }
                                        DispatchQueue.main.async {
                                            switch space {
                                            case .skills: store.reorderCategories(fromId: from, toId: cat.id)
                                            case .mcp: store.reorderMcpCategories(fromId: from, toId: cat.id)
                                            case .plugins: store.reorderPluginCategories(fromId: from, toId: cat.id)
                                            case .watchlist: break
                                            }
                                        }
                                    }
                                    return true
                                }
                            }
                        }
                    }
                }
            }
            if tab == .skills {
                Divider()
                Text("已启用估算  " + formatTokenBadge(store.activeEstimatedTokens())).font(.system(size: 11, design: .monospaced))
                HStack { Text("显示内置技能"); Spacer(); Toggle("显示内置技能", isOn: $store.showBuiltins).labelsHidden().toggleStyle(.switch).controlSize(.mini) }
                HStack {
                    Button(SkillStore.shortenHomePath(store.fixedVaultPath)) { NSWorkspace.shared.open(URL(fileURLWithPath: store.fixedVaultPath)) }.lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("更改") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.canCreateDirectories = true
                        if panel.runModal() == .OK, let url = panel.url { store.changeFixedVaultDirectory(to: url.path) }
                    }
                }.buttonStyle(.plain).font(.system(size: 10, design: .monospaced))
            } else if research {
                Divider()
                Label(".watchlist.json", systemImage: "doc.text").font(.caption.monospaced())
                HStack { Button("导出 JSON", action: store.exportWatchlistAsJSON); Button("导出 MD", action: store.exportWatchlistAsMarkdown) }.controlSize(.small)
            }
        }.padding(12).background(palette.sidebarBg)
    }
    func startEdit(_ id: String, _ name: String) { ui.draft = name; ui.editing = id }
    var editor: some View {
        HStack {
            TextField("分组名称", text: $ui.draft).focused($editingFocused).onSubmit { saveName() }.onAppear { editingFocused = true }
            icon("xmark", "取消") { ui.editing = nil }
        }.onExitCommand { ui.editing = nil }
    }
    func saveName() {
        guard let id = ui.editing else { return }
        let name = ui.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !groups.contains(where: { $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            store.showBanner("分组名称为空或已存在", isError: true); return
        }
        switch tab {
        case .skills: if id == "NEW" { _ = store.addCategory(name: name) } else { store.renameCategory(id: id, newName: name) }
        case .mcp: if id == "NEW" { _ = store.addMcpCategory(name: name) } else { store.renameMcpCategory(id: id, newName: name) }
        case .plugins: if id == "NEW" { _ = store.addPluginCategory(name: name) } else { store.renamePluginCategory(id: id, newName: name) }
        case .watchlist: break
        }
        ui.editing = nil
    }
    func icon(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 18, height: 18) }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
    func groupRow(_ cat: SkillCategory?) -> some View {
        let id = cat?.id ?? "ALL"
        let selected = group.wrappedValue == id
        let draggedIndex = groups.firstIndex { $0.id == ui.dragged } ?? Int.max
        let targetIndex = groups.firstIndex { $0.id == id } ?? 0
        return HStack(spacing: 5) {
            if cat == nil { Image(systemName: "square.grid.2x2").foregroundColor(palette.mutedText) }
            else {
                VStack(spacing: 1.5) {
                    ForEach(0..<3) { _ in
                        HStack(spacing: 1.5) {
                            Circle().frame(width: 2, height: 2)
                            Circle().frame(width: 2, height: 2)
                        }
                    }
                }.frame(width: 12).foregroundColor(palette.mutedText)
            }
            Text(cat?.name ?? "全部资产").lineLimit(1)
            Spacer()
            if let cat, selected || ui.hoveredCategoryId == id {
                icon("pencil", "重命名") { startEdit(id, cat.name) }
                if groups.count > 1 { icon("trash", "删除用途分组") { ui.pendingDeleteCategory = cat } }
            } else { Text(String(count(id))).font(.caption.monospacedDigit()) }
        }.padding(.horizontal, 7).frame(height: 31).background(selected ? palette.blueBg : Color.clear).cornerRadius(5)
            .contentShape(Rectangle()).onTapGesture { group.wrappedValue = id }
            .onHover { if $0 { ui.hoveredCategoryId = id } else if ui.hoveredCategoryId == id { ui.hoveredCategoryId = nil } }
            .overlay(alignment: draggedIndex < targetIndex ? .bottom : .top) { if ui.dropTarget == id { Rectangle().fill(tint).frame(height: 2) } }
    }
    func status(_ st: WatchlistStatus?) -> some View {
        HStack {
            Image(systemName: st == nil ? "star" : "circle")
            Text(st?.label ?? "全部关注"); Spacer()
            Text(String(store.watchlist.filter { st == nil || $0.status == st }.count)).monospacedDigit()
        }.padding(7).background(ui.watchlistStatusFilter == st ? palette.amberBg : Color.clear).cornerRadius(5)
            .contentShape(Rectangle()).onTapGesture { ui.watchlistStatusFilter = st }
    }
    var summaryData: (String, String, Int, Int) {
        switch tab {
        case .skills: return ("SKILL ROUTING", "技能路由矩阵", visibleBaseSkills.filter(\.isAnyActive).count, visibleBaseSkills.reduce(0) { $0 + $1.activePlatforms.count })
        case .mcp: return ("MCP SERVICES", "MCP 同步矩阵", store.mcpServers.filter { !$0.platforms.isEmpty }.count, store.mcpServers.reduce(0) { $0 + $1.platforms.count })
        case .plugins: return ("PLUGIN REGISTRY", "插件管理", store.plugins.filter(\.isEnabled).count, store.plugins.reduce(0) { $0 + $1.bundledSkills.count })
        case .watchlist: return ("RESEARCH RADAR", "研究雷达", store.watchlist.filter { $0.status == .studying }.count, store.watchlist.filter(store.isWatchlistItemInstalledLocally).count)
        }
    }
    var summary: some View {
        let data = summaryData
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(data.0).tracking(1).font(.system(size: 9, design: .monospaced)).foregroundColor(palette.mutedText)
                Text(data.1).font(.system(size: 17, weight: .semibold))
            }
            Spacer()
            HStack(spacing: 0) {
                metric(research ? "关注" : "总数", count("ALL"))
                Divider()
                metric(research ? "研究中" : "启用", data.2).foregroundColor(research ? tint : palette.okColor)
                Divider()
                metric(research ? "本地已装" : tab == .plugins ? "内含" : "路由", data.3)
            }.frame(height: 34).background(palette.surfaceBg).cornerRadius(6)
        }.padding(.horizontal, 14).frame(height: 58)
    }
    func metric(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 0) { Text(label).font(.system(size: 9)).foregroundColor(palette.mutedText); Text(String(value)).font(.system(size: 13, weight: .semibold, design: .monospaced)) }.frame(minWidth: 44)
    }
    func pill(_ text: String, _ selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(text, action: action).buttonStyle(.plain).font(.system(size: 10, weight: .medium)).padding(.horizontal, 6).padding(.vertical, 4)
            .foregroundColor(selected ? tint : palette.secondaryText).background(selected ? tint.opacity(0.12) : Color.clear).cornerRadius(4)
    }
    func filters(total: Int) -> some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    if research {
                        pill("全部", ui.watchlistKindFilter == nil) { ui.watchlistKindFilter = nil }
                        ForEach(WatchlistKind.allCases) { k in pill(k.label, ui.watchlistKindFilter == k) { ui.watchlistKindFilter = k } }
                        pill("仅看未装", ui.watchlistOnlyUninstalled) { ui.watchlistOnlyUninstalled.toggle() }
                    } else {
                        let platform = tab == .skills ? $ui.filterPlatform : $ui.pluginPlatformFilter
                        pill("全部", tab == .mcp ? ui.mcpPlatformFilter == "ALL" : platform.wrappedValue == nil) {
                            if tab == .mcp { ui.mcpPlatformFilter = "ALL" } else { platform.wrappedValue = nil }
                        }
                        ForEach(AgentPlatform.allCases) { pf in
                            pill(pf.shortLabel, tab == .mcp ? ui.mcpPlatformFilter == pf.rawValue : platform.wrappedValue == pf) {
                                if tab == .mcp { ui.mcpPlatformFilter = pf.rawValue } else { platform.wrappedValue = pf }
                            }
                        }
                        if tab == .mcp { pill("多端", ui.mcpPlatformFilter == "MULTI") { ui.mcpPlatformFilter = "MULTI" } }
                        if tab == .skills && group.wrappedValue != "ALL" {
                            Button("全开") { store.setCategoryBatchEnabled(group.wrappedValue, enabled: true) }
                            Button("全关") { store.setCategoryBatchEnabled(group.wrappedValue, enabled: false) }
                        }
                    }
                }.controlSize(.mini)
            }
            HStack(spacing: 3) {
                Image(systemName: "magnifyingglass")
                TextField("搜索", text: query).textFieldStyle(.plain)
                if !query.wrappedValue.isEmpty { icon("xmark", "清空搜索") { query.wrappedValue = "" } }
            }.padding(5).frame(width: 112).background(palette.windowBg).cornerRadius(5)
            Text("\(total) 项").fixedSize().font(.caption.monospacedDigit())
        }.padding(.horizontal, 9).frame(height: 39)
    }
    func badge(_ title: String) -> some View {
        Text(title).font(.system(size: 9, design: .monospaced)).lineLimit(1).padding(.horizontal, 4).padding(.vertical, 2)
            .foregroundColor(palette.secondaryText).background(palette.surfaceBg).cornerRadius(3)
    }
    func row<Badges: View, Controls: View>(_ id: String, current: String?, active: Bool, name: String, subtitle: String,
        @ViewBuilder badges: () -> Badges, @ViewBuilder controls: () -> Controls) -> some View {
        HStack(spacing: 7) {
            Circle().fill(active ? (research ? tint : palette.okColor) : palette.mutedText).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(name).font(.system(size: 12, weight: .semibold, design: .monospaced)).lineLimit(1).layoutPriority(1)
                    badges()
                }
                Text(subtitle).font(.system(size: 10.5, design: tab == .mcp ? .monospaced : .default)).foregroundColor(palette.secondaryText).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
            controls()
        }.padding(.horizontal, 10).frame(height: 53).contentShape(Rectangle())
            .background(current == id ? tint.opacity(0.075) : Color.clear)
            .overlay(alignment: .leading) { if current == id { Rectangle().fill(tint).frame(width: 2) } }
            .overlay(alignment: .bottom) { Rectangle().fill(palette.cardBorder).frame(height: 1) }
            .onTapGesture { ui.selections[tab] = id }
    }
    func routes(_ active: Set<AgentPlatform>, highlightLocked: Bool = false, locked: @escaping (AgentPlatform) -> Bool, action: @escaping (AgentPlatform) -> Void) -> some View {
        HStack(spacing: 3) {
            ForEach(AgentPlatform.allCases) { pf in
                let on = active.contains(pf)
                Button { action(pf) } label: {
                    HStack(spacing: 3) {
                        Circle().frame(width: 4, height: 4)
                        Text(pf.shortLabel).font(.system(size: 9, weight: .medium, design: .monospaced))
                    }.padding(.horizontal, 4).frame(height: 20)
                        .foregroundColor(locked(pf) && !highlightLocked ? palette.mutedText : on ? palette.okColor : palette.secondaryText)
                        .background(on && (!locked(pf) || highlightLocked) ? palette.greenBg : palette.surfaceBg).cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(on ? palette.greenBorder : palette.cardBorder))
                }.buttonStyle(.plain).disabled(locked(pf)).help(pf.fullName + (locked(pf) ? (on ? " · 已连通" : " · 已锁定") : on ? " · 点击断开" : " · 点击连通"))
            }
        }
    }
    func skillRoutes(_ sk: SkillItemModel) -> some View {
        routes(sk.activePlatforms, locked: { !sk.isManageable || (sk.sourceKind == .plugin && $0 == .antigravity) }) { store.togglePlatform($0, for: sk) }
    }
    @ViewBuilder func rows(_ current: String?) -> some View {
        switch tab {
        case .skills:
            ForEach(filteredSkills) { sk in
                row(sk.id, current: current, active: sk.isAnyActive, name: sk.displayName, subtitle: sk.summaryLine) {
                    if sk.sourceKind != .userVault { badge(sk.sourceKind.badgeTitle) }
                    badge(formatTokenBadge(sk.estimatedTokens))
                } controls: {
                    skillRoutes(sk)
                    let mutable = sk.sourceKind == .plugin ? sk.activePlatforms.subtracting([.antigravity]).count : sk.activePlatforms.count
                    let all = mutable == (sk.sourceKind == .plugin ? 2 : 3)
                    Button { store.toggleMasterSwitch(for: sk) } label: {
                        ZStack(alignment: all ? .trailing : mutable > 0 ? .center : .leading) {
                            Capsule().fill(mutable > 0 ? palette.okColor : palette.switchOffTrack).frame(width: 27, height: 15)
                            Circle().fill(.white).frame(width: 11, height: 11).padding(2)
                        }
                    }.buttonStyle(.plain).disabled(!sk.isManageable).accessibilityLabel("技能总开关")
                }
            }
        case .mcp:
            ForEach(filteredServers) { srv in
                row(srv.id, current: current, active: true, name: srv.id, subtitle: srv.commandSummary) {
                    badge("\(srv.envKeys.count) ENV")
                } controls: { routes(srv.platforms, highlightLocked: true, locked: { srv.platforms.contains($0) }) { store.syncMcpServer(srv, to: $0) } }
            }
        case .plugins:
            ForEach(filteredPlugins) { pl in
                row(pl.id, current: current, active: pl.isEnabled, name: pl.displayName, subtitle: pl.bundledSkills.isEmpty ? pl.descriptionText : pl.bundledSkills.joined(separator: " · ")) {
                    badge(pl.platform.shortLabel); badge(pl.version)
                } controls: { IOSToggleSwitch(isOn: pl.isEnabled, palette: palette) { store.togglePlugin(pl) }.disabled(!pl.canToggle) }
            }
        case .watchlist:
            ForEach(filteredItems) { item in
                row(item.id, current: current, active: true, name: item.name, subtitle: item.summary) {
                    badge(item.kind.label)
                    if !item.starsText.isEmpty { Label(item.starsText, systemImage: "star").font(.caption2) }
                    if store.isWatchlistItemInstalledLocally(item) { badge("本地已装") }
                } controls: {
                    if let url = URL(string: item.repoUrl), !item.repoUrl.isEmpty { Link("GitHub ↗", destination: url).font(.caption) }
                }
            }
        }
    }
    func sectionTitle(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(palette.cardBorder).frame(height: 1)
            Text(text).font(.system(size: 11, weight: .semibold)).foregroundColor(palette.secondaryText)
        }
    }
    func title(_ name: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).font(.system(size: 18)).foregroundColor(tint).frame(width: 36, height: 36).background(tint.opacity(0.12)).cornerRadius(8)
            Text(tab == .skills ? "LOCAL SKILL" : tab == .mcp ? "MCP SERVER" : research ? "WATCHLIST" : "LOCAL PLUGIN").font(.system(size: 9, design: .monospaced)).foregroundColor(palette.mutedText)
            Text(name).font(.system(size: 18, weight: .semibold, design: .monospaced)).textSelection(.enabled)
        }
    }
    func categoryPicker(_ id: String, assign: @escaping (String) -> Void) -> some View {
        Picker("所属用途分组", selection: Binding(get: { id }, set: assign)) { ForEach(groups) { Text($0.name).tag($0.id) } }
    }
    func topology(_ active: Set<AgentPlatform>) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for (i, pf) in AgentPlatform.allCases.enumerated() {
                        let end = CGPoint(x: width - 58, y: CGFloat(18 + i * 27))
                        var path = Path()
                        path.move(to: CGPoint(x: 70, y: 45))
                        path.addCurve(to: end, control1: CGPoint(x: width * 0.54, y: 45), control2: CGPoint(x: width * 0.54, y: end.y))
                        context.stroke(path, with: .color(active.contains(pf) ? palette.okColor : palette.mutedText), style: StrokeStyle(lineWidth: 1.5, dash: active.contains(pf) ? [] : [4, 4]))
                    }
                }
                badge("LOCAL HUB").position(x: 45, y: 45)
                ForEach(Array(AgentPlatform.allCases.enumerated()), id: \.offset) { i, pf in
                    badge(pf.shortLabel).position(x: width - 38, y: CGFloat(18 + i * 27))
                }
            }
        }.frame(height: 90).background(palette.windowBg).cornerRadius(7)
    }
    @ViewBuilder func details(_ id: String?) -> some View {
        if let id {
            switch tab {
            case .skills: if let sk = store.skills.first(where: { $0.id == id }) { skillDetail(sk) }
            case .mcp: if let srv = store.mcpServers.first(where: { $0.id == id }) { mcpDetail(srv) }
            case .plugins: if let pl = store.plugins.first(where: { $0.id == id }) { pluginDetail(pl) }
            case .watchlist: if let item = store.watchlist.first(where: { $0.id == id }) { watchDetail(item) }
            }
        } else { Text("选择资产以查看详情").foregroundColor(palette.mutedText) }
    }
    @ViewBuilder func skillDetail(_ sk: SkillItemModel) -> some View {
        title(sk.displayName, "square.3.layers.3d")
        sectionTitle("挂载矩阵")
        topology(sk.activePlatforms)
        skillRoutes(sk)
        Picker("详情", selection: $ui.sourceMode) { Text("概览").tag(false); Text("SKILL.md 源码").tag(true) }.labelsHidden().pickerStyle(.segmented)
        if ui.sourceMode {
            code((try? String(contentsOfFile: sk.skillMdPath, encoding: .utf8)) ?? "无法读取 SKILL.md")
            Button("打开 SKILL.md") { openPath(sk.skillMdPath) }
        } else {
            sectionTitle("描述")
            Text(sk.descriptionText).textSelection(.enabled)
            if !sk.triggerHints.isEmpty { Text("触发词 · " + sk.triggerHints.joined(separator: "、")).foregroundColor(palette.secondaryText) }
            if let src = sk.sourceRecord {
                sectionTitle("来源仓库"); code(src.repoInput + "\n" + (src.commitHash ?? ""))
                Button("拉取更新") { store.updateSkillFromGitHub(sk) }.disabled(store.updatingSkillIds.contains(sk.id))
            }
            categoryPicker(sk.categoryId) { store.assignCategory($0, to: sk.id) }
            Button("打开目录") { openPath(sk.canonicalPath) }
            if sk.sourceKind == .userVault {
                HStack {
                    Button("卸载并转存关注") { ui.archiveTrashedSkill = true; ui.pendingTrashSkill = sk }
                    Button("移入废纸篓") { ui.archiveTrashedSkill = false; ui.pendingTrashSkill = sk }
                        .foregroundColor(palette.dangerColor)
                }
            }
        }
    }
    func openPath(_ path: String) { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
    func code(_ text: String) -> some View {
        Text(verbatim: text).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading).padding(9).background(palette.windowBg).cornerRadius(5)
    }
    @ViewBuilder func mcpDetail(_ srv: McpServerItemModel) -> some View {
        title(srv.id, "point.3.connected.trianglepath.dotted")
        sectionTitle("跨端同步")
        topology(srv.platforms)
        routes(srv.platforms, locked: { _ in false }) { pf in
            if srv.platforms.contains(pf) { store.removeMcpServer(srv, from: pf) } else { store.syncMcpServer(srv, to: pf) }
        }
        Text("启动命令"); code(srv.commandSummary)
        if !srv.envKeys.isEmpty { Text("环境变量 · " + srv.envKeys.joined(separator: ", ")) }
        Picker("配置预览", selection: $ui.toml) { Text("JSON").tag(false); Text("TOML").tag(true) }.labelsHidden().pickerStyle(.segmented)
        code(configPreview(srv))
        Button("同步至全部平台") { for pf in AgentPlatform.allCases where !srv.platforms.contains(pf) { store.syncMcpServer(srv, to: pf) } }.disabled(srv.platforms.count == 3)
        categoryPicker(srv.categoryId) { store.assignMcpCategory($0, to: srv.id) }
        ForEach(AgentPlatform.allCases) { pf in
            if let path = srv.configPaths[pf] { Button("打开 " + pf.shortLabel + " 配置") { openPath(path) } }
        }
    }
    func configPreview(_ srv: McpServerItemModel) -> String {
        let order: [AgentPlatform] = ui.toml ? [.codex, .antigravity, .claude] : [.antigravity, .claude, .codex]
        guard let cfg = order.compactMap({ srv.rawConfigs[$0] }).first else { return "无法读取配置" }
        if ui.toml {
            let table = "mcp_servers." + CodexTomlHelper.quoteKeyIfNeeded(srv.id)
            func quote(_ value: String) -> String { "\"" + CodexTomlHelper.escapeTomlString(value) + "\"" }
            var lines = ["[" + table + "]"]
            if let cmd = cfg.command { lines.append("command = " + quote(cmd)); lines.append("args = [" + cfg.args.map(quote).joined(separator: ", ") + "]") }
            if let url = cfg.url { lines.append("url = " + quote(url)) }
            if !cfg.env.isEmpty { lines.append("[" + table + ".env]"); lines += cfg.env.keys.sorted().map { CodexTomlHelper.quoteKeyIfNeeded($0) + " = \"••••\"" } }
            return lines.joined(separator: "\n")
        }
        var object: [String: Any] = [:]
        if let cmd = cfg.command { object["command"] = cmd; object["args"] = cfg.args }
        if let url = cfg.url { object["url"] = url }
        if !cfg.env.isEmpty { object["env"] = cfg.env.mapValues { _ in "••••" } }
        guard let data = try? JSONSerialization.data(withJSONObject: ["mcpServers": [srv.id: object]], options: [.prettyPrinted, .sortedKeys]) else { return "无法生成配置预览" }
        return String(decoding: data, as: UTF8.self)
    }
    @ViewBuilder func pluginDetail(_ pl: PluginItemModel) -> some View {
        title(pl.displayName, "puzzlepiece.extension")
        Text([pl.platform.fullName, pl.version, pl.authorName].filter { !$0.isEmpty }.joined(separator: " · "))
        Text(pl.descriptionText)
        sectionTitle("安装路径")
        code(SkillStore.shortenHomePath(pl.pluginPath))
        Button("打开目录") { openPath(pl.pluginPath) }
        if !pl.bundledSkills.isEmpty { sectionTitle("内含 Skills") }
        ForEach(pl.bundledSkills, id: \.self) { name in
            Button {
                if let sk = store.skills.first(where: { $0.id == name && $0.canonicalPath == (pl.pluginPath as NSString).appendingPathComponent("skills/" + name) }) {
                    ui.selectedCategoryId = "ALL"; ui.filterPlatform = nil; ui.searchText = ""; ui.selections[.skills] = sk.id; ui.activeTab = .skills
                } else { openPath((pl.pluginPath as NSString).appendingPathComponent("skills/" + name)) }
            } label: { Label(name, systemImage: "arrow.up.right") }
        }
        categoryPicker(pl.categoryId) { store.assignPluginCategory($0, to: pl.id) }
        HStack {
            Button(pl.isEnabled ? "停用插件" : "启用插件") { store.togglePlugin(pl) }.disabled(!pl.canToggle)
            if pl.canUninstall { Button("卸载…") { ui.pendingUninstallPlugin = pl } }
        }
    }
    @ViewBuilder func watchDetail(_ item: WatchlistItem) -> some View {
        title(item.name, "star")
        sectionTitle("GitHub 元信息")
        Text(item.summary)
        Text([item.starsText.isEmpty ? "" : "Stars " + item.starsText, item.language, item.pushedAt].filter { !$0.isEmpty }.joined(separator: " · ")).foregroundColor(palette.secondaryText)
        if !item.tags.isEmpty { Text(item.tags.map { "#" + $0 }.joined(separator: "  ")) }
        if let url = URL(string: item.repoUrl), !item.repoUrl.isEmpty { Link(item.repoUrl, destination: url) }
        if !item.installCmd.isEmpty {
            sectionTitle("CLI 安装命令")
            code(item.installCmd)
            Button("复制安装命令") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(item.installCmd, forType: .string); store.showBanner("已复制安装命令") }
        }
        Picker("研究状态", selection: Binding(get: { item.status }, set: { var updated = item; updated.status = $0; store.updateWatchlistItem(updated) })) {
            ForEach(WatchlistStatus.allCases) { Text($0.label).tag($0) }
        }
        HStack {
            Text("研究笔记"); Spacer()
            Button("保存笔记") {
                guard let note = ui.wlDraftNotes.removeValue(forKey: item.id) else { return }
                var updated = item; updated.notes = note; store.updateWatchlistItem(updated); store.showBanner("已保存研究笔记")
            }.disabled((ui.wlDraftNotes[item.id] ?? item.notes) == item.notes)
        }
        TextEditor(text: Binding(get: { ui.wlDraftNotes[item.id] ?? item.notes }, set: { ui.wlDraftNotes[item.id] = $0 }))
            .frame(minHeight: 90).overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.strongBorder))
        Button("刷新元信息") { store.refreshWatchlistItemMetadata(item) }.disabled(store.fetchingWatchIds.contains(item.id) || item.repoUrl.isEmpty)
        if item.kind == .skill || item.kind == .plugin {
            Button(store.isWatchlistItemInstalledLocally(item) ? "在本地查看" : "转入本地安装") { installOrSelect(item) }
        }
        Button("移除关注") { store.deleteWatchlistItem(id: item.id) }
    }
    func installOrSelect(_ item: WatchlistItem) {
        if store.isWatchlistItemInstalledLocally(item) {
            if let pl = store.plugins.first(where: { $0.rawId.caseInsensitiveCompare(item.name) == .orderedSame || $0.displayName.caseInsensitiveCompare(item.name) == .orderedSame }) {
                ui.pluginSearchText = ""; ui.pluginPlatformFilter = nil; ui.pluginCategoryFilter = "ALL"; ui.selections[.plugins] = pl.id; ui.activeTab = .plugins
            } else {
                let sk = store.skills.first { $0.id.caseInsensitiveCompare(item.name) == .orderedSame || $0.displayName.caseInsensitiveCompare(item.name) == .orderedSame || $0.sourceRecord?.cloneURL.localizedCaseInsensitiveContains(item.name) == true || $0.sourceRecord?.repoInput.caseInsensitiveCompare(item.repoUrl) == .orderedSame }
                ui.searchText = ""; ui.selectedCategoryId = "ALL"; ui.filterPlatform = nil
                if sk?.sourceKind == .builtin { store.showBuiltins = true }
                ui.selections[.skills] = sk?.id; ui.activeTab = .skills
            }
        } else if item.kind == .plugin { ui.pluginGithubInput = item.repoUrl; ui.showInstallPluginModal = true }
        else {
            ui.githubInput = item.repoUrl
            ui.importEnableAgy = store.isPlatformInstalled(.antigravity)
            ui.importEnableCodex = store.isPlatformInstalled(.codex)
            ui.importEnableClaude = store.isPlatformInstalled(.claude)
            ui.showImportModal = true
        }
    }
}
