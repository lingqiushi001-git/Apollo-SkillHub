import AppKit
import SwiftUI

// MARK: - Add Watchlist Item Modal (Zero Local Clone + Read-Only GitHub API Fetch)

struct AddWatchlistModalView: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { ui.showAddWatchlistModal = false }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("收录研究 / 关注项目（不下载到本地）", systemImage: "star.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(palette.amberAccent)
                    Spacer()
                    Button(action: { ui.showAddWatchlistModal = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(palette.secondaryText)
                            .padding(5)
                            .background(palette.chipBg)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(palette.sidebarBg)

                Divider().background(palette.divider)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("项目地址（GitHub URL 或 owner/repo）")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(palette.secondaryText)
                        HStack(spacing: 8) {
                            TextField("如 nextlevelbuilder/ui-ux-pro-max-skill", text: $ui.wlUrlInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundColor(palette.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(palette.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                                .cornerRadius(8)

                            Button(action: {
                                ui.wlIsFetchingMeta = true
                                store.fetchGitHubMetadata(for: ui.wlUrlInput) { res in
                                    ui.wlIsFetchingMeta = false
                                    switch res {
                                    case .success(let meta):
                                        if ui.wlNameInput.trimmingCharacters(in: .whitespaces).isEmpty { ui.wlNameInput = meta.name }
                                        ui.wlUrlInput = meta.canonicalUrl
                                        if ui.wlSummaryInput.trimmingCharacters(in: .whitespaces).isEmpty { ui.wlSummaryInput = meta.desc }
                                        ui.wlStarsCache = meta.stars
                                        ui.wlLangCache = meta.language
                                        ui.wlPushedCache = meta.pushedAt
                                        store.showBanner("已抓取「\(meta.name)」元信息（Stars \(meta.stars) · 零本地下载）")
                                    case .failure(let err):
                                        store.showBanner(err.localizedDescription, isError: true)
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    if ui.wlIsFetchingMeta {
                                        ProgressView().scaleEffect(0.55).frame(width: 12, height: 12)
                                    } else {
                                        Image(systemName: "arrow.down.doc").font(.system(size: 11))
                                    }
                                    Text(ui.wlIsFetchingMeta ? "抓取中…" : "抓取元信息")
                                        .font(.system(size: 11.5, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(palette.accentBlue.opacity(0.16))
                                .foregroundColor(palette.accentBlue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(ui.wlIsFetchingMeta || ui.wlUrlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("名称").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.secondaryText)
                            TextField("自动从仓库名提取", text: $ui.wlNameInput)
                                .textFieldStyle(.plain).font(.system(size: 12)).foregroundColor(palette.primaryText)
                                .padding(.horizontal, 9).padding(.vertical, 6.5)
                                .background(palette.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                                .cornerRadius(7)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("资源类型").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.secondaryText)
                            Picker("", selection: $ui.wlKindInput) {
                                ForEach(WatchlistKind.allCases) { k in Text(k.label).tag(k) }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("研究状态").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.secondaryText)
                            Picker("", selection: $ui.wlStatusInput) {
                                ForEach(WatchlistStatus.allCases) { st in Text(st.label).tag(st) }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }
                    }

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("标签（逗号分隔）").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.secondaryText)
                            TextField("如 UI, 设计系统, 参考", text: $ui.wlTagsInput)
                                .textFieldStyle(.plain).font(.system(size: 12)).foregroundColor(palette.primaryText)
                                .padding(.horizontal, 9).padding(.vertical, 6.5)
                                .background(palette.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                                .cornerRadius(7)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("可选安装命令（CLI / MCP）").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.secondaryText)
                            TextField("如 npm i -g agent-browser", text: $ui.wlInstallCmdInput)
                                .textFieldStyle(.plain).font(.system(size: 12, design: .monospaced)).foregroundColor(palette.primaryText)
                                .padding(.horizontal, 9).padding(.vertical, 6.5)
                                .background(palette.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                                .cornerRadius(7)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("一句话定位 / 简介").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.secondaryText)
                        TextField("自动抓取或手动输入一句话摘要", text: $ui.wlSummaryInput)
                            .textFieldStyle(.plain).font(.system(size: 12)).foregroundColor(palette.primaryText)
                            .padding(.horizontal, 9).padding(.vertical, 6.5)
                            .background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                            .cornerRadius(7)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("研究笔记 / 关注原因").font(.system(size: 11.5, weight: .semibold)).foregroundColor(palette.secondaryText)
                        TextEditor(text: $ui.wlNotesInput)
                            .font(.system(size: 12))
                            .frame(height: 76)
                            .padding(5)
                            .background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                            .cornerRadius(7)
                    }

                    HStack {
                        Spacer()
                        Button("取消") { ui.showAddWatchlistModal = false }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 6.5)
                            .background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.primaryText).cornerRadius(8)

                        Button("保存到关注列表") {
                            let tags = ui.wlTagsInput
                                .replacingOccurrences(of: "，", with: ",")
                                .split(separator: ",")
                                .map { String($0).trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                            store.addWatchlistItem(
                                name: ui.wlNameInput,
                                kind: ui.wlKindInput,
                                status: ui.wlStatusInput,
                                repoUrl: ui.wlUrlInput,
                                summary: ui.wlSummaryInput,
                                notes: ui.wlNotesInput,
                                tags: tags,
                                installCmd: ui.wlInstallCmdInput,
                                starsText: ui.wlStarsCache,
                                language: ui.wlLangCache,
                                pushedAt: ui.wlPushedCache
                            )
                            ui.resetWatchlistDraft()
                            ui.showAddWatchlistModal = false
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14).padding(.vertical, 6.5)
                        .background(palette.amberAccent)
                        .foregroundColor(palette.amberFg)
                        .cornerRadius(8)
                        .disabled(ui.wlUrlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ui.wlNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .frame(width: 500)
            .background(palette.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 10)
        }
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
        return store.categories.first(where: { $0.id == "system-config" })?.id ?? store.categories.first?.id ?? "system-config"
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
                .onTapGesture { if !store.isImporting { ui.showImportModal = false } }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("导入新 Skill 到固定仓库", systemImage: "square.and.arrow.down.on.square")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(palette.primaryText)
                    Spacer()
                    Button(action: { ui.showImportModal = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(palette.secondaryText)
                            .padding(5).background(palette.chipBg).cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isImporting)
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(palette.sidebarBg)

                Divider().background(palette.divider)

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("方式一：从 GitHub 一键安装（支持 .claude/skills 等深层目录）")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(palette.primaryText)

                        HStack(spacing: 8) {
                            TextField("输入 owner/repo 或完整 GitHub 仓库地址", text: $ui.githubInput)
                                .textFieldStyle(.plain).font(.system(size: 12)).foregroundColor(palette.primaryText)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(palette.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                                .cornerRadius(8)

                            if store.isImporting {
                                Button("取消") { store.cancelActiveImport() }
                                    .buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 7.5)
                                    .background(palette.dangerColor).foregroundColor(.white).cornerRadius(8)
                            } else {
                                Button("安装") {
                                    store.installGitHubSkill(repoInput: ui.githubInput, categoryId: effectiveCategoryId, platforms: targetPlatforms) {
                                        ui.githubInput = ""
                                        ui.showImportModal = false
                                    }
                                }
                                .buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 14).padding(.vertical, 7.5)
                                .background(palette.accentBlue).foregroundColor(.white).cornerRadius(8)
                                .disabled(ui.githubInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }

                        if store.isImporting {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.55).frame(width: 12, height: 12)
                                Text("正在克隆仓库并校验 SKILL.md（35 秒超时保护）…")
                                    .font(.system(size: 11)).foregroundColor(palette.accentBlue)
                            }
                        } else {
                            Text("自动记录来源支持一键更新，落盘至 \(SkillStore.shortenHomePath(store.fixedVaultPath))")
                                .font(.system(size: 11)).foregroundColor(palette.mutedText)
                        }
                    }

                    HStack(spacing: 8) {
                        Rectangle().fill(palette.divider).frame(height: 1)
                        Text("或").font(.system(size: 11)).foregroundColor(palette.mutedText)
                        Rectangle().fill(palette.divider).frame(height: 1)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("方式二：导入本地 Skill 文件夹").font(.system(size: 12, weight: .bold)).foregroundColor(palette.primaryText)
                            Text("支持单 Skill 目录或包含多个 Skill 的父目录").font(.system(size: 11)).foregroundColor(palette.mutedText)
                        }
                        Spacer()
                        Button(action: {
                            let panel = NSOpenPanel()
                            panel.title = "选择包含 SKILL.md 的本地技能文件夹"
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            if panel.runModal() == .OK, let url = panel.url {
                                store.importLocalSkillFolder(from: url, categoryId: effectiveCategoryId, platforms: targetPlatforms)
                                ui.showImportModal = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus").font(.system(size: 11.5))
                                Text("选择目录").font(.system(size: 11.5, weight: .semibold))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6.5)
                            .background(palette.chipBg).foregroundColor(palette.primaryText).cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isImporting)
                    }
                    .padding(11).background(palette.inputBg)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    .cornerRadius(10)

                    Divider().background(palette.divider)

                    HStack {
                        Text("归属分类").font(.system(size: 12, weight: .medium)).foregroundColor(palette.secondaryText)
                        Spacer()
                        Menu {
                            ForEach(store.categories) { cat in Button(cat.name) { ui.importCategoryId = cat.id } }
                        } label: {
                            HStack(spacing: 5) {
                                Text(store.categories.first(where: { $0.id == effectiveCategoryId })?.name ?? "默认")
                                    .font(.system(size: 12, weight: .semibold)).foregroundColor(palette.primaryText)
                                Image(systemName: "chevron.down").font(.system(size: 9.5)).foregroundColor(palette.mutedText)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                            .cornerRadius(7)
                        }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    }

                    HStack {
                        Text("安装后默认启用端").font(.system(size: 12, weight: .medium)).foregroundColor(palette.secondaryText)
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
            .frame(width: 460)
            .background(palette.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 10)
        }
    }
}

// MARK: - Install Plugin Modal

struct InstallPluginModalView: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    private var sharePlatforms: Set<AgentPlatform> {
        var s = Set<AgentPlatform>()
        if ui.pluginShareCodex { s.insert(.codex) }
        if ui.pluginShareClaude { s.insert(.claude) }
        return s
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { if !store.isImporting { ui.showInstallPluginModal = false } }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("一键全局安装插件", systemImage: "puzzlepiece.extension.fill")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(palette.primaryText)
                    Spacer()
                    Button(action: { ui.showInstallPluginModal = false }) {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                            .foregroundColor(palette.secondaryText).padding(5).background(palette.chipBg).cornerRadius(6)
                    }
                    .buttonStyle(.plain).disabled(store.isImporting)
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(palette.sidebarBg)

                Divider().background(palette.divider)

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("方式一：从 GitHub 安装 Antigravity 插件").font(.system(size: 12, weight: .bold)).foregroundColor(palette.primaryText)
                        HStack(spacing: 8) {
                            TextField("输入 owner/repo 或插件 GitHub 地址", text: $ui.pluginGithubInput)
                                .textFieldStyle(.plain).font(.system(size: 12)).foregroundColor(palette.primaryText)
                                .padding(.horizontal, 10).padding(.vertical, 7).background(palette.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(8)

                            if store.isImporting {
                                Button("取消") { store.cancelActiveImport() }
                                    .buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 7.5)
                                    .background(palette.dangerColor).foregroundColor(.white).cornerRadius(8)
                            } else {
                                Button("安装") {
                                    store.installPluginFromGitHub(repoInput: ui.pluginGithubInput, shareSkillsTo: sharePlatforms) {
                                        ui.pluginGithubInput = ""; ui.showInstallPluginModal = false
                                    }
                                }
                                .buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 14).padding(.vertical, 7.5)
                                .background(palette.accentBlue).foregroundColor(.white).cornerRadius(8)
                                .disabled(ui.pluginGithubInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        HStack {
                            Text("同时共享插件内 Skill 到:").font(.system(size: 11)).foregroundColor(palette.mutedText)
                            ModalPlatformCheck(label: "Codex", isOn: $ui.pluginShareCodex, palette: palette)
                            ModalPlatformCheck(label: "Claude", isOn: $ui.pluginShareClaude, palette: palette)
                            Spacer()
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("方式二：导入本地插件文件夹").font(.system(size: 12, weight: .bold)).foregroundColor(palette.primaryText)
                            Text("包含 plugin.json 或 skills/ 目录，落盘至 ~/.gemini/config/plugins").font(.system(size: 11)).foregroundColor(palette.mutedText)
                        }
                        Spacer()
                        Button(action: {
                            let panel = NSOpenPanel()
                            panel.title = "选择本地插件目录"; panel.canChooseDirectories = true; panel.canChooseFiles = false
                            if panel.runModal() == .OK, let url = panel.url {
                                store.installPluginFromLocalFolder(sourceURL: url, shareSkillsTo: sharePlatforms)
                                ui.showInstallPluginModal = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus").font(.system(size: 11.5))
                                Text("选择目录").font(.system(size: 11.5, weight: .semibold))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6.5)
                            .background(palette.chipBg).foregroundColor(palette.primaryText).cornerRadius(8)
                        }
                        .buttonStyle(.plain).disabled(store.isImporting)
                    }
                    .padding(10).background(palette.inputBg)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    .cornerRadius(9)

                    Divider().background(palette.divider)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("方式三：通过 Codex CLI 安装 Codex 插件").font(.system(size: 12, weight: .bold)).foregroundColor(palette.primaryText)
                            Spacer()
                            let hasCli = store.locateCodexCLI() != nil
                            Text(hasCli ? "CLI 已就绪" : "未检测到 Codex CLI")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(hasCli ? palette.okColor : palette.mutedText)
                        }
                        HStack(spacing: 8) {
                            TextField("如 plugin-name@marketplace", text: $ui.codexPluginSpecInput)
                                .textFieldStyle(.plain).font(.system(size: 12)).foregroundColor(palette.primaryText)
                                .padding(.horizontal, 10).padding(.vertical, 7).background(palette.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(8)
                            Button("安装") {
                                store.installCodexPluginViaCLI(pluginSpec: ui.codexPluginSpecInput) {
                                    ui.codexPluginSpecInput = ""; ui.showInstallPluginModal = false
                                }
                            }
                            .buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 7.5)
                            .background(palette.purpleAccent).foregroundColor(.white).cornerRadius(8)
                            .disabled(store.isImporting || store.locateCodexCLI() == nil || ui.codexPluginSpecInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(16)
            }
            .frame(width: 470)
            .background(palette.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 10)
        }
    }
}

// MARK: - Health Check + CLI Readiness Modal

struct HealthCheckModalView: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    private var fixableCount: Int { store.healthIssues.filter { $0.canAutoFix }.count }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { ui.showHealthModal = false }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("环境健康体检 & CLI 依赖检测", systemImage: "stethoscope")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(palette.primaryText)
                    Spacer()
                    Button("重新扫描") { store.scanHealthIssues() }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 9).padding(.vertical, 4.5)
                        .background(palette.chipBg).foregroundColor(palette.primaryText).cornerRadius(6)
                    if fixableCount > 0 {
                        Button("一键修复 (\(fixableCount))") { store.fixAllHealthIssues() }
                            .buttonStyle(.plain).font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 10).padding(.vertical, 4.5)
                            .background(palette.okColor).foregroundColor(.white).cornerRadius(6)
                    }
                    Button(action: { ui.showHealthModal = false }) {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                            .foregroundColor(palette.secondaryText).padding(5).background(palette.chipBg).cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(palette.sidebarBg)

                Divider().background(palette.divider)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if store.healthIssues.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill").font(.system(size: 24)).foregroundColor(palette.okColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("软链接、仓库目录与 MCP 依赖均处于健康状态")
                                        .font(.system(size: 13, weight: .semibold)).foregroundColor(palette.primaryText)
                                    Text("未发现悬空软链接、旧目录残留、无效脏目录或缺失命令。")
                                        .font(.system(size: 11.5)).foregroundColor(palette.mutedText)
                                }
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(palette.okColor.opacity(0.10))
                            .cornerRadius(9)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("待处理项（\(store.healthIssues.count)）")
                                    .font(.system(size: 11.5, weight: .bold)).foregroundColor(palette.mutedText)
                                ForEach(store.healthIssues) { issue in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: issue.canAutoFix ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(issue.canAutoFix ? palette.warnColor : palette.accentBlue)
                                            .padding(.top, 2)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(issue.title).font(.system(size: 12.5, weight: .semibold)).foregroundColor(palette.primaryText)
                                            Text(issue.detail).font(.system(size: 11.5)).foregroundColor(palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                                            Text(SkillStore.shortenHomePath(issue.targetPath)).font(.system(size: 10.5, design: .monospaced)).foregroundColor(palette.mutedText)
                                        }
                                        Spacer()
                                        if issue.canAutoFix {
                                            Button("修复") { store.fixHealthIssue(issue) }
                                                .buttonStyle(.plain).font(.system(size: 11, weight: .bold))
                                                .padding(.horizontal, 10).padding(.vertical, 5)
                                                .background(palette.accentBlue.opacity(0.16)).foregroundColor(palette.accentBlue).cornerRadius(6)
                                        }
                                    }
                                    .padding(11).background(palette.inputBg)
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(9)
                                }
                            }
                        }

                        Divider().background(palette.divider)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI 生态 CLI 就绪状态（只读检测）")
                                .font(.system(size: 11.5, weight: .bold)).foregroundColor(palette.mutedText)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                                ForEach(store.cliChecks) { cli in
                                    HStack {
                                        Text(cli.name).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(palette.primaryText)
                                        Spacer()
                                        Text(cli.installed ? "已就绪" : "未检测到")
                                            .font(.system(size: 10.5, weight: .semibold))
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(cli.installed ? palette.okColor.opacity(0.15) : palette.chipBg)
                                            .foregroundColor(cli.installed ? palette.okColor : palette.mutedText)
                                            .cornerRadius(4)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(palette.inputBg)
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(palette.cardBorder, lineWidth: 1))
                                    .cornerRadius(7)
                                    .help(cli.path ?? "未在常见路径找到可执行文件")
                                }
                            }
                        }
                    }
                    .padding(14)
                }
                .frame(maxHeight: 420)
            }
            .frame(width: 540)
            .background(palette.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 10)
        }
    }
}

// MARK: - Scenario Profile Manager Modal

struct ProfileModalView: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { ui.showProfileModal = false }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("场景预设管理（工作模式）", systemImage: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(palette.primaryText)
                    Spacer()
                    Button(action: { ui.showProfileModal = false }) {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                            .foregroundColor(palette.secondaryText).padding(5).background(palette.chipBg).cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(palette.sidebarBg)
                Divider().background(palette.divider)

                VStack(alignment: .leading, spacing: 12) {
                    Text("将当前三端 Skill 启停组合保存为预设，方便按任务场景一键切换、节省上下文 Token。")
                        .font(.system(size: 11.5)).foregroundColor(palette.mutedText)

                    HStack(spacing: 8) {
                        TextField("输入预设名（如：前端设计 / 逆向调试 / 日常轻量）", text: $ui.newProfileName)
                            .textFieldStyle(.plain).font(.system(size: 12)).foregroundColor(palette.primaryText)
                            .padding(.horizontal, 10).padding(.vertical, 7).background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(8)
                        Button("保存当前状态") {
                            store.saveCurrentAsProfile(name: ui.newProfileName); ui.newProfileName = ""
                        }
                        .buttonStyle(.plain).font(.system(size: 11.5, weight: .bold))
                        .padding(.horizontal, 12).padding(.vertical, 7.5)
                        .background(palette.accentBlue).foregroundColor(.white).cornerRadius(8)
                        .disabled(ui.newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Divider().background(palette.divider)

                    if store.profiles.isEmpty {
                        Text("暂无已保存的场景预设").font(.system(size: 12)).foregroundColor(palette.mutedText)
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                    } else {
                        ScrollView {
                            VStack(spacing: 7) {
                                ForEach(store.profiles) { prof in
                                    let activeCount = prof.skillPlatforms.values.filter { !$0.isEmpty }.count
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(prof.name).font(.system(size: 12.5, weight: .semibold)).foregroundColor(palette.primaryText)
                                            Text("包含 \(activeCount) 个启用中的用户 Skill").font(.system(size: 11)).foregroundColor(palette.mutedText)
                                        }
                                        Spacer()
                                        Button("应用") { store.applyProfile(prof); ui.showProfileModal = false }
                                            .buttonStyle(.plain).font(.system(size: 11.5, weight: .bold))
                                            .padding(.horizontal, 11).padding(.vertical, 5)
                                            .background(palette.okColor.opacity(0.18)).foregroundColor(palette.okColor).cornerRadius(6)
                                        Button(action: { store.deleteProfile(id: prof.id) }) {
                                            Image(systemName: "trash").font(.system(size: 11)).foregroundColor(palette.dangerColor)
                                                .padding(6).background(palette.dangerColor.opacity(0.12)).cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(10).background(palette.inputBg)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(8)
                                }
                            }
                        }
                        .frame(maxHeight: 220)
                    }
                }
                .padding(16)
            }
            .frame(width: 460).background(palette.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(14)
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 10)
        }
    }
}

// MARK: - Confirmation Modals

struct OverwriteConfirmModalView: View {
    let ctx: PendingOverwriteContext
    @ObservedObject var store: SkillStore
    let palette: ThemePalette

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(palette.warnColor)
                    Text("检测到同名 Skill，是否覆盖？").font(.system(size: 14, weight: .bold)).foregroundColor(palette.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(palette.sidebarBg)
                Divider().background(palette.divider)

                VStack(alignment: .leading, spacing: 10) {
                    Text("固定仓库中已存在以下 Skill：\(ctx.existingSkillIds.joined(separator: "、"))。继续安装将覆盖原有目录内容。")
                        .font(.system(size: 12.5)).foregroundColor(palette.primaryText).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Spacer()
                        Button("取消") { store.cancelPendingOverwrite() }
                            .buttonStyle(.plain).font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 6.5).background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.primaryText).cornerRadius(8)
                        Button("确认覆盖") { store.confirmPendingOverwrite() }
                            .buttonStyle(.plain).font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 14).padding(.vertical, 6.5)
                            .background(palette.warnColor).foregroundColor(.white).cornerRadius(8)
                    }
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .frame(width: 400).background(palette.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(14)
            .shadow(color: Color.black.opacity(0.35), radius: 22, x: 0, y: 10)
        }
    }
}

struct TrashSkillConfirmModalView: View {
    let skill: SkillItemModel
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { ui.pendingTrashSkill = nil }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "trash.fill").foregroundColor(palette.dangerColor)
                    Text("确认卸载 Skill").font(.system(size: 14, weight: .bold)).foregroundColor(palette.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(palette.sidebarBg)
                Divider().background(palette.divider)

                VStack(alignment: .leading, spacing: 10) {
                    Text("确定要卸载「\(skill.displayName)」吗？将清理 Antigravity / Codex / Claude 的所有软链接，并将目录移入系统废纸篓。")
                        .font(.system(size: 12.5)).foregroundColor(palette.primaryText).fixedSize(horizontal: false, vertical: true)
                    Text(SkillStore.shortenHomePath(skill.canonicalPath))
                        .font(.system(size: 11, design: .monospaced)).foregroundColor(palette.mutedText)
                    HStack(spacing: 8) {
                        Spacer()
                        Button("取消") { ui.pendingTrashSkill = nil }
                            .buttonStyle(.plain).font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12).padding(.vertical, 6.5).background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.primaryText).cornerRadius(8)

                        Button(ui.archiveTrashedSkill ? "卸载并转存关注" : "移入废纸篓") {
                            store.trashSkill(skill, saveToWatchlist: ui.archiveTrashedSkill)
                            ui.pendingTrashSkill = nil
                        }
                        .buttonStyle(.plain).font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12).padding(.vertical, 6.5)
                        .background(palette.dangerColor).foregroundColor(.white).cornerRadius(8)
                    }
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .frame(width: 440).background(palette.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(14)
            .shadow(color: Color.black.opacity(0.35), radius: 22, x: 0, y: 10)
        }
    }
}

struct UninstallPluginConfirmModalView: View {
    let plugin: PluginItemModel
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { ui.pendingUninstallPlugin = nil }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "trash.fill").foregroundColor(palette.dangerColor)
                    Text("确认卸载插件").font(.system(size: 14, weight: .bold)).foregroundColor(palette.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(palette.sidebarBg)
                Divider().background(palette.divider)

                VStack(alignment: .leading, spacing: 10) {
                    Text("确定将插件「\(plugin.displayName)」移入废纸篓吗？可在废纸篓中手动恢复。")
                        .font(.system(size: 12.5)).foregroundColor(palette.primaryText).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Spacer()
                        Button("取消") { ui.pendingUninstallPlugin = nil }
                            .buttonStyle(.plain).font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 6.5).background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.primaryText).cornerRadius(8)
                        Button("确认卸载") { store.uninstallPlugin(plugin); ui.pendingUninstallPlugin = nil }
                            .buttonStyle(.plain).font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 14).padding(.vertical, 6.5)
                            .background(palette.dangerColor).foregroundColor(.white).cornerRadius(8)
                    }
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .frame(width: 380).background(palette.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(14)
            .shadow(color: Color.black.opacity(0.35), radius: 22, x: 0, y: 10)
        }
    }
}

struct DeleteCategoryModalView: View {
    let category: SkillCategory
    @ObservedObject var store: SkillStore
    @ObservedObject var ui: SkillHubUIState
    let palette: ThemePalette

    private var groups: [SkillCategory] {
        switch ui.activeTab {
        case .mcp: return store.mcpCategories
        case .plugins: return store.pluginCategories
        default: return store.categories
        }
    }
    private var targets: [SkillCategory] { groups.filter { $0.id != category.id } }
    private var count: Int {
        switch ui.activeTab {
        case .mcp: return store.mcpServers.filter { $0.categoryId == category.id }.count
        case .plugins: return store.plugins.filter { $0.categoryId == category.id }.count
        default: return store.skills.filter { $0.categoryId == category.id }.count
        }
    }
    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { ui.pendingDeleteCategory = nil }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(palette.dangerColor)
                    Text("删除用途分组").font(.system(size: 14, weight: .bold)).foregroundColor(palette.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(palette.sidebarBg)
                Divider().background(palette.divider)

                VStack(alignment: .leading, spacing: 10) {
                    Text("「\(category.name)」包含 \(count) 项资产。")
                    Picker("将组内资产迁移至", selection: $ui.destination) {
                        ForEach(targets) { Text($0.name).tag($0.id) }
                    }.onAppear { ui.destination = targets.first?.id ?? "" }
                    HStack(spacing: 8) {
                        Spacer()
                        Button("取消") { ui.pendingDeleteCategory = nil }
                            .buttonStyle(.plain).font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 6.5).background(palette.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.cardBorder, lineWidth: 1))
                            .foregroundColor(palette.primaryText).cornerRadius(8)
                        Button("确认删除") {
                            switch ui.activeTab {
                            case .skills:
                                if store.deleteCategory(id: category.id, migrateTo: ui.destination), ui.selectedCategoryId == category.id { ui.selectedCategoryId = ui.destination }
                            case .mcp:
                                if store.deleteMcpCategory(id: category.id, migrateTo: ui.destination), ui.mcpCategoryFilter == category.id { ui.mcpCategoryFilter = ui.destination }
                            case .plugins:
                                if store.deletePluginCategory(id: category.id, migrateTo: ui.destination), ui.pluginCategoryFilter == category.id { ui.pluginCategoryFilter = ui.destination }
                            case .watchlist: break
                            }
                            ui.pendingDeleteCategory = nil
                        }
                        .buttonStyle(.plain).font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14).padding(.vertical, 6.5)
                        .background(palette.dangerColor).foregroundColor(.white).cornerRadius(8)
                    }
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .frame(width: 380).background(palette.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.cardBorder, lineWidth: 1)).cornerRadius(14)
            .shadow(color: Color.black.opacity(0.35), radius: 22, x: 0, y: 10)
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
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle").font(.system(size: 11))
                Text(label).font(.system(size: 11.5, weight: .semibold))
            }
            .padding(.horizontal, 8).padding(.vertical, 4.5)
            .background(isOn ? palette.okColor.opacity(0.18) : palette.chipBg)
            .foregroundColor(isOn ? palette.okColor : palette.secondaryText)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
