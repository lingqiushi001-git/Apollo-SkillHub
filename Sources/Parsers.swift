import Foundation

// MARK: - Skill Metadata & Token Estimator

struct ParsedSkillMetadata {
    var name: String
    var summary: String
    var desc: String
    var triggers: [String]
    var skillMdPath: String
    var charCount: Int
    var estimatedTokens: Int
}

enum SkillParsers {
    static func estimateTokens(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        var cjkCount = 0
        var otherCount = 0
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) || (0x3000...0x303F).contains(v) || (0xFF00...0xFFEF).contains(v) {
                cjkCount += 1
            } else {
                otherCount += 1
            }
        }
        let est = Double(cjkCount) / 1.5 + Double(otherCount) / 4.0
        return max(1, Int(est.rounded()))
    }

    static func parseSkillMetadata(skillDir: String, fallbackId: String) -> ParsedSkillMetadata {
        let mdPath = "\(skillDir)/SKILL.md"
        guard let raw = try? String(contentsOfFile: mdPath, encoding: .utf8) else {
            return ParsedSkillMetadata(
                name: fallbackId,
                summary: "暂无 SKILL.md 描述",
                desc: "暂无 SKILL.md 描述",
                triggers: [],
                skillMdPath: mdPath,
                charCount: 0,
                estimatedTokens: 0
            )
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

        let summaryParts = parsedDesc.components(separatedBy: CharacterSet(charactersIn: "。；.\n"))
        let firstSentence = summaryParts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? parsedDesc
        let summary = firstSentence.count > 48 ? String(firstSentence.prefix(48)) + "…" : firstSentence

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

        return ParsedSkillMetadata(
            name: parsedName,
            summary: summary,
            desc: parsedDesc,
            triggers: hints,
            skillMdPath: mdPath,
            charCount: raw.count,
            estimatedTokens: estimateTokens(for: raw)
        )
    }

    static func parseGitHubInput(_ raw: String) -> (cloneURL: String, branch: String?, subpath: String?, fallbackName: String)? {
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

    /// Recursively discovers directories containing SKILL.md up to maxDepth.
    /// Traverses known dot-prefixed agent directories (.claude, .agents, .agent, .codex, .cursor, .gemini, etc.)
    /// while skipping .git, .github, node_modules, and build artifacts.
    static func discoverSkillDirectories(under root: URL, fallbackName: String, maxDepth: Int = 5) -> [(id: String, url: URL)] {
        let fm = FileManager.default
        if fm.fileExists(atPath: "\(root.path)/SKILL.md") {
            let meta = parseSkillMetadata(skillDir: root.path, fallbackId: fallbackName)
            let chosenId = !meta.name.isEmpty ? meta.name : fallbackName
            return [(chosenId, root)]
        }

        var results: [(id: String, url: URL)] = []
        var seenIds = Set<String>()
        let allowedDotDirs: Set<String> = [
            ".claude", ".agents", ".agent", ".codex", ".cursor", ".gemini", ".opencode", ".windsurf", ".shared"
        ]
        let skipNames: Set<String> = [
            ".git", ".github", ".vscode", ".idea", "node_modules", ".build", "dist", "target", ".DS_Store", "__pycache__", "tests", "__tests__"
        ]

        func walk(_ dir: URL, depth: Int) {
            guard depth <= maxDepth else { return }
            guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else { return }
            // Prioritize canonical skill roots (skills, .claude, .agents, .codex) before asset/template dirs
            let sortedItems = items.sorted { a, b in
                let prio: (String) -> Int = { name in
                    if name == "skills" { return 0 }
                    if allowedDotDirs.contains(name) { return 1 }
                    if name == "cli" || name == "assets" || name == "templates" { return 3 }
                    return 2
                }
                let pa = prio(a), pb = prio(b)
                if pa != pb { return pa < pb }
                return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
            }
            for item in sortedItems {
                if skipNames.contains(item) { continue }
                if item.hasPrefix(".") && !allowedDotDirs.contains(item) { continue }
                let child = dir.appendingPathComponent(item)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue else { continue }
                if fm.fileExists(atPath: "\(child.path)/SKILL.md") {
                    if !seenIds.contains(item) {
                        seenIds.insert(item)
                        results.append((item, child))
                    }
                } else {
                    walk(child, depth: depth + 1)
                }
            }
        }

        walk(root, depth: 1)
        return results
    }
}

// MARK: - Robust Codex TOML Parser & Writer

enum CodexTomlHelper {
    /// Splits a TOML table header like `mcp_servers."my-srv".env` into unquoted segments.
    static func parseTablePath(_ header: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inQuote: Character? = nil
        var escaped = false

        for ch in header {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if ch == "\\" && inQuote == "\"" {
                escaped = true
                continue
            }
            if let q = inQuote {
                if ch == q {
                    inQuote = nil
                } else {
                    current.append(ch)
                }
            } else {
                if ch == "\"" || ch == "'" {
                    inQuote = ch
                } else if ch == "." {
                    let trimmed = current.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { parts.append(trimmed) }
                    current = ""
                } else {
                    current.append(ch)
                }
            }
        }
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { parts.append(trimmed) }
        return parts
    }

    static func stripInlineComment(_ raw: String) -> String {
        var inQuote: Character? = nil
        var escaped = false
        var out = ""
        for ch in raw {
            if escaped {
                out.append(ch)
                escaped = false
                continue
            }
            if ch == "\\" && inQuote == "\"" {
                out.append(ch)
                escaped = true
                continue
            }
            if let q = inQuote {
                if ch == q { inQuote = nil }
                out.append(ch)
            } else {
                if ch == "\"" || ch == "'" {
                    inQuote = ch
                    out.append(ch)
                } else if ch == "#" {
                    break
                } else {
                    out.append(ch)
                }
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    static func parseTomlString(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 {
            let inner = String(s.dropFirst().dropLast())
            return inner
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }
        if s.hasPrefix("'") && s.hasSuffix("'") && s.count >= 2 {
            return String(s.dropFirst().dropLast())
        }
        return s
    }

    static func parseTomlStringArray(_ raw: String) -> [String] {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[") { trimmed.removeFirst() }
        if trimmed.hasSuffix("]") { trimmed.removeLast() }

        var results: [String] = []
        var current = ""
        var inQuote: Character? = nil
        var escaped = false

        for ch in trimmed {
            if escaped {
                current.append(ch)
                escaped = false
                continue
            }
            if ch == "\\" && inQuote == "\"" {
                escaped = true
                current.append(ch)
                continue
            }
            if let q = inQuote {
                if ch == q {
                    inQuote = nil
                }
                current.append(ch)
            } else {
                if ch == "\"" || ch == "'" {
                    inQuote = ch
                    current.append(ch)
                } else if ch == "," {
                    let val = parseTomlString(current)
                    if !val.isEmpty { results.append(val) }
                    current = ""
                } else {
                    current.append(ch)
                }
            }
        }
        let val = parseTomlString(current)
        if !val.isEmpty { results.append(val) }
        return results
    }

    static func parseInlineTable(_ raw: String) -> [String: String] {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") { trimmed.removeFirst() }
        if trimmed.hasSuffix("}") { trimmed.removeLast() }

        var dict: [String: String] = [:]
        var pairs: [String] = []
        var cur = ""
        var inQuote: Character? = nil
        var escaped = false

        for ch in trimmed {
            if escaped {
                cur.append(ch)
                escaped = false
                continue
            }
            if ch == "\\" && inQuote == "\"" {
                escaped = true
                cur.append(ch)
                continue
            }
            if let q = inQuote {
                if ch == q { inQuote = nil }
                cur.append(ch)
            } else {
                if ch == "\"" || ch == "'" {
                    inQuote = ch
                    cur.append(ch)
                } else if ch == "," {
                    pairs.append(cur)
                    cur = ""
                } else {
                    cur.append(ch)
                }
            }
        }
        if !cur.trimmingCharacters(in: .whitespaces).isEmpty {
            pairs.append(cur)
        }

        for p in pairs {
            guard let eq = p.firstIndex(of: "=") else { continue }
            let k = parseTomlString(String(p[..<eq]))
            let v = parseTomlString(String(p[p.index(after: eq)...]))
            if !k.isEmpty { dict[k] = v }
        }
        return dict
    }

    static func parseMcpServers(from content: String) -> [String: McpRawConfig] {
        var drafts: [String: McpRawConfig] = [:]
        let lines = content.components(separatedBy: .newlines)

        var currentServer: String? = nil
        var inEnvSection = false
        var idx = 0

        while idx < lines.count {
            let cleaned = stripInlineComment(lines[idx])
            if cleaned.isEmpty {
                idx += 1
                continue
            }

            if cleaned.hasPrefix("[") && cleaned.hasSuffix("]") && !cleaned.hasPrefix("[[") {
                let inner = String(cleaned.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                let path = parseTablePath(inner)
                if path.count >= 2 && path[0] == "mcp_servers" {
                    let srv = path[1]
                    if path.count == 2 {
                        currentServer = srv
                        inEnvSection = false
                    } else if path.count == 3 && path[2] == "env" {
                        currentServer = srv
                        inEnvSection = true
                    } else {
                        currentServer = nil
                        inEnvSection = false
                    }
                    if let s = currentServer, drafts[s] == nil {
                        drafts[s] = McpRawConfig(command: nil, args: [], url: nil, env: [:])
                    }
                } else {
                    currentServer = nil
                    inEnvSection = false
                }
                idx += 1
                continue
            }

            guard let srv = currentServer, let eqIdx = cleaned.firstIndex(of: "=") else {
                idx += 1
                continue
            }

            let rawKey = String(cleaned[..<eqIdx]).trimmingCharacters(in: .whitespaces)
            let key = parseTomlString(rawKey)
            var val = String(cleaned[cleaned.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)

            // Handle multiline arrays [...] or inline tables {...}
            if val.hasPrefix("[") && !val.hasSuffix("]") {
                var combined = val
                while idx + 1 < lines.count && !combined.hasSuffix("]") {
                    idx += 1
                    let nextPart = stripInlineComment(lines[idx])
                    if !nextPart.isEmpty { combined += " " + nextPart }
                }
                val = combined
            } else if val.hasPrefix("{") && !val.hasSuffix("}") {
                var combined = val
                while idx + 1 < lines.count && !combined.hasSuffix("}") {
                    idx += 1
                    let nextPart = stripInlineComment(lines[idx])
                    if !nextPart.isEmpty { combined += " " + nextPart }
                }
                val = combined
            }

            if inEnvSection {
                if !key.isEmpty {
                    drafts[srv]?.env[key] = parseTomlString(val)
                }
            } else {
                switch key {
                case "command":
                    drafts[srv]?.command = parseTomlString(val)
                case "url":
                    drafts[srv]?.url = parseTomlString(val)
                case "args":
                    drafts[srv]?.args = parseTomlStringArray(val)
                case "env":
                    if val.hasPrefix("{") {
                        for (ek, ev) in parseInlineTable(val) {
                            drafts[srv]?.env[ek] = ev
                        }
                    }
                default:
                    break
                }
            }
            idx += 1
        }

        return drafts
    }

    static func parsePlugins(from content: String) -> [(id: String, enabled: Bool)] {
        var result: [(id: String, enabled: Bool)] = []
        var order: [String] = []
        var map: [String: Bool] = [:]
        var currentPlugin: String? = nil

        for rawLine in content.components(separatedBy: .newlines) {
            let line = stripInlineComment(rawLine)
            if line.isEmpty { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") && !line.hasPrefix("[[") {
                let inner = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                let path = parseTablePath(inner)
                if path.count == 2 && path[0] == "plugins" {
                    currentPlugin = path[1]
                    if map[path[1]] == nil {
                        order.append(path[1])
                        map[path[1]] = true
                    }
                } else {
                    currentPlugin = nil
                }
                continue
            }
            if let pid = currentPlugin, let eq = line.firstIndex(of: "=") {
                let k = parseTomlString(String(line[..<eq]))
                let v = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces).lowercased()
                if k == "enabled" {
                    map[pid] = (v == "true")
                }
            }
        }

        for pid in order {
            result.append((pid, map[pid] ?? true))
        }
        return result
    }

    static func quoteKeyIfNeeded(_ key: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        if !key.isEmpty && key.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return key
        }
        return "\"\(escapeTomlString(key))\""
    }

    static func escapeTomlString(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// Updates `[plugins."<pluginId>"]` enabled flag in `~/.codex/config.toml`.
    static func setPluginEnabled(pluginId: String, enabled: Bool, configPath: String) throws {
        let fm = FileManager.default
        let existing = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""
        var lines = existing.components(separatedBy: .newlines)
        var inTarget = false
        var foundSection = false
        var updatedLine = false
        var sectionEndIdx = lines.count

        for i in 0..<lines.count {
            let cleaned = stripInlineComment(lines[i])
            if cleaned.hasPrefix("[") && cleaned.hasSuffix("]") && !cleaned.hasPrefix("[[") {
                if inTarget {
                    sectionEndIdx = i
                    inTarget = false
                }
                let inner = String(cleaned.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                let path = parseTablePath(inner)
                if path.count == 2 && path[0] == "plugins" && path[1] == pluginId {
                    inTarget = true
                    foundSection = true
                }
                continue
            }
            if inTarget, let eq = cleaned.firstIndex(of: "=") {
                let k = parseTomlString(String(cleaned[..<eq]))
                if k == "enabled" {
                    lines[i] = "enabled = \(enabled ? "true" : "false")"
                    updatedLine = true
                    break
                }
            }
        }

        if foundSection && !updatedLine {
            lines.insert("enabled = \(enabled ? "true" : "false")", at: sectionEndIdx)
        } else if !foundSection {
            if !lines.isEmpty && !lines.last!.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append("")
            }
            lines.append("[plugins.\"\(escapeTomlString(pluginId))\"]")
            lines.append("enabled = \(enabled ? "true" : "false")")
        }

        let parent = (configPath as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: parent, withIntermediateDirectories: true)
        try lines.joined(separator: "\n").write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    /// Removes `[mcp_servers.<name>]` and `[mcp_servers.<name>.env]` sections from TOML text.
    static func removeMcpSection(name: String, from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var out: [String] = []
        var skipping = false

        for line in lines {
            let cleaned = stripInlineComment(line)
            if cleaned.hasPrefix("[") && cleaned.hasSuffix("]") && !cleaned.hasPrefix("[[") {
                let inner = String(cleaned.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                let path = parseTablePath(inner)
                if path.count >= 2 && path[0] == "mcp_servers" && path[1] == name {
                    skipping = true
                    continue
                } else {
                    skipping = false
                }
            }
            if !skipping {
                out.append(line)
            }
        }
        return out.joined(separator: "\n")
    }

    /// Upserts an MCP server entry into `~/.codex/config.toml`.
    static func upsertMcpServer(name: String, config: McpRawConfig, configPath: String) throws {
        let fm = FileManager.default
        let existing = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""
        var cleaned = removeMcpSection(name: name, from: existing)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let keyPart = quoteKeyIfNeeded(name)
        var block: [String] = []
        block.append("[mcp_servers.\(keyPart)]")
        if let cmd = config.command, !cmd.isEmpty {
            block.append("command = \"\(escapeTomlString(cmd))\"")
            let argsList = config.args.map { "\"\(escapeTomlString($0))\"" }.joined(separator: ", ")
            block.append("args = [\(argsList)]")
        } else if let url = config.url, !url.isEmpty {
            block.append("url = \"\(escapeTomlString(url))\"")
        }

        if !config.env.isEmpty {
            block.append("")
            block.append("[mcp_servers.\(keyPart).env]")
            for k in config.env.keys.sorted() {
                let v = config.env[k] ?? ""
                block.append("\(quoteKeyIfNeeded(k)) = \"\(escapeTomlString(v))\"")
            }
        }

        if !cleaned.isEmpty {
            cleaned += "\n\n"
        }
        cleaned += block.joined(separator: "\n") + "\n"

        let parent = (configPath as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: parent, withIntermediateDirectories: true)
        try cleaned.write(toFile: configPath, atomically: true, encoding: .utf8)
    }
}
