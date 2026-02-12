//
//  FluxWorkspaceManager.swift
//  Flux
//
//  Created by opencode on 2/10/26.
//  Manages project paths, scoping, and report generation.
//

import Foundation

class FluxWorkspaceManager: ObservableObject {
    @Published var activeProject: String?
    @Published var projects = [String: String]()  // slug: path
    private let workspaceURL = URL(fileURLWithPath: "/Users/jcbbge/flux/workspace")
    private let homeURL = URL(fileURLWithPath: "/Users/jcbbge")
    private let userDefaultsKey = "fluxProjects"
    private let categorizer = FluxCategorizerService()
    private let provider = FileFluxProvider()
    private let dailyFormatter = DateFormatter()
    
    init() {
        dailyFormatter.dateFormat = "yyyy-MM-dd"
        loadProjects()
    }
    
    func loadProjects() {
        if let jsonData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] {
            projects = dict
        }
    }
    
    func saveProjects() {
        if let jsonData = try? JSONSerialization.data(withJSONObject: projects) {
            UserDefaults.standard.set(jsonData, forKey: userDefaultsKey)
        }
    }
    
    func addProject(from dir: URL) {
        let projectSlug = dir.lastPathComponent
        let workspacePath = dir.appendingPathComponent("workspace")
        guard FileManager.default.fileExists(atPath: workspacePath.path) else {
            // Alert: Scaffold first
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Scaffold Required"
                alert.informativeText = "Run /Users/jcbbge/spacely/scaffold-workspace.sh in \(dir.path)"
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }
        projects[projectSlug] = workspacePath.path
        saveProjects()
        activeProject = projectSlug
    }
    
    func generateReport(for project: String) async {
        guard let path = projects[project] else { return }
        let projectURL = URL(fileURLWithPath: path)
        let today = dailyFormatter.string(from: Date())
        let reportFilename = "fluxReport-\(today).md"
        let slugDir = workspaceURL.appendingPathComponent(project)
        try? FileManager.default.createDirectory(at: slugDir, withIntermediateDirectories: true)
        let reportURL = slugDir.appendingPathComponent(reportFilename)
        
        if FileManager.default.fileExists(atPath: reportURL.path) {
            // Load existing
            if let reportEntry = FluxEntry.parse(from: reportURL) {
                // Update if stale (e.g., >1 day)
                if Date() > Calendar.current.date(byAdding: .day, value: 1, to: extractDate(from: reportEntry.filename)!) {
                    await updateReport(&reportEntry, from: projectURL)
                }
                return
            }
        }
        
        // Generate new
        let mds = try? FileManager.default.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
            .prefix(20)  // Recent/limited
        let logs = try? FileManager.default.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "log" || $0.lastPathComponent.hasPrefix("session") }
            .prefix(5)  // High-level
        let commitOutput = bashGitLog(projectPath: dir.appendingPathComponent("\(project)"))
        
        let prompt = """
        Per /Users/jcbbge/spacely/workspace/WORKSPACE.md: Generate high-level fluxReport MD.
        MD files: \(mds?.map { $0.path } ?? [])
        Logs overview: \(logs?.map { $0.path } ?? [])
        Recent commits: \(commitOutput)
        Output: MD with YAML frontmatter (fluxType: report, fluxTitle: "\(project) Status - \(today)"). Sections: ## Recent Session (1-2 lines from MD/logs), ## Commits (\(commitOutput)), ## Next Steps (bullets), ## Issues/Intervene? (stagnation from mods), ## Overview. No deep analysis.
        """
        
        if let meta = await categorizer.enrichFlux(FluxEntry(id: UUID(), date: today, filename: reportFilename, content: "", fluxMeta: nil)) {
            let reportContent = await generateReportContent(prompt: prompt)
            let entry = FluxEntry(id: UUID(), date: today, filename: reportFilename, content: reportContent, fluxMeta: meta)
            let fullContent = entry.embedMeta(meta)
            try? fullContent.write(to: reportURL, atomically: true, encoding: .utf8)
            appendToNextSteps(project: project, summary: meta.summary ?? "Generated report")
        }
    }
    
    private func updateReport(_ entry: inout FluxEntry, from projectURL: URL) async {
        // Re-gen content
        let newContent = await generateReportContent(prompt: "Update high-level report from [projectURL] recent changes.")
        entry.content = newContent
        if let updatedMeta = await categorizer.suggestFluxInsights(entry) {
            entry.insights = updatedMeta.insights
        }
        try? entry.embedMeta(entry.fluxMeta ?? FluxMeta(fluxType: "report")).write(to: entry.filename, atomically: true, encoding: .utf8)
    }
    
    private func generateReportContent(prompt: String) async -> String {
        if let result = await categorizer.callCategorizer(with: prompt, type: .report) {
            return result["content"] as? String ?? ""
        }
        return "# No Report Generated\nRun scaffold and add path."
    }
    
    private func bashGitLog(projectPath: URL) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["log", "--oneline", "-5"]
        process.currentDirectoryURL = projectPath.deletingLastPathComponent()  // Root for git
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No commits"
    }
    
    func appendToNextSteps(project: String, summary: String) {
        let nextStepsURL = workspaceURL.appendingPathComponent(project).appendingPathComponent("NEXT_STEPS.md")
        let appendText = "\n\n[ \(Date().formatted(.dateTime)) ]: \(summary)"
        if let current = try? String(contentsOf: nextStepsURL, encoding: .utf8) {
            try? (current + appendText).write(to: nextStepsURL, atomically: true, encoding: .utf8)
        }
    }
    
    private func extractDate(from filename: String) -> Date? {
        let range = filename.range(of: "(\\d{4}-\\d{2}-\\d{2})", options: .regularExpression)
        if let match = range {
            let dateString = String(filename[match])
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateString)
        }
        return nil
    }
}