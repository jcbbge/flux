// Swift 5.0
//
//  ContentView.swift
//  Flux
//
//  Created by thorfinn on 2/14/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit

// MARK: - DateFormatter Cache (Performance Fix)
struct DateFormatterCache {
    static let shared = DateFormatterCache()
    private let formatter = DateFormatter()
    private let queue = DispatchQueue(label: "flux.dateformatter")
    
    func string(from date: Date, format: String) -> String {
        queue.sync {
            formatter.dateFormat = format
            return formatter.string(from: date)
        }
    }
    
    func date(from string: String, format: String) -> Date? {
        queue.sync {
            formatter.dateFormat = format
            return formatter.date(from: string)
        }
    }
}

struct HumanEntry: Identifiable {
    let id: UUID
    let date: String
    let filename: String
    var previewText: String
    
    static func createNew() -> HumanEntry {
        let id = UUID()
        let now = Date()
        let dateString = DateFormatterCache.shared.string(from: now, format: "yyyy-MM-dd")
        let displayDate = DateFormatterCache.shared.string(from: now, format: "MMM d")
        
        // Short UUID prefix (first 8 chars) for filename readability
        let idPrefix = String(id.uuidString.prefix(8))
        
        return HumanEntry(
            id: id,
            date: displayDate,
            filename: "\(dateString)-\(idPrefix).md",
            previewText: ""
        )
    }
}

// MARK: - Project Model
struct Project: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let lastModified: Date
    var hasWorkspace: Bool
    
    var displayName: String {
        return name
    }
}

// MARK: - Search Result Model
struct SearchResult: Identifiable {
    let id = UUID()
    let entry: HumanEntry
    let filename: String
    let preview: String
    let matchRange: Range<String.Index>?
}

// MARK: - Todo Item Model
struct TodoItem: Identifiable {
    let id = UUID()
    let entryId: UUID
    let entryFilename: String
    let text: String
    let isDone: Bool
}

struct HeartEmoji: Identifiable {
    let id = UUID()
    var position: CGPoint
    var offset: CGFloat = 0
}

struct ContentView: View {
    private let headerString = "\n\n"
    @State private var entries: [HumanEntry] = []
    @State private var entryDictionary: [UUID: HumanEntry] = [:]
    @State private var projects: [Project] = []
    @State private var selectedProjectPath: String? = nil
    @State private var text: String = ""  // Remove initial welcome text since we'll handle it in createNewEntry
    @State private var isSearchMode: Bool = false
    @State private var searchQuery: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var selectedSearchIndex: Int = 0
    @State private var todos: [TodoItem] = []

    @State private var isFullscreen = false
    @State private var selectedFont: String = "Lato-Regular"
    @State private var currentRandomFont: String = ""
    @State private var timeRemaining: Int = 900  // Changed to 900 seconds (15 minutes)
    @State private var timerIsRunning = false
    @State private var isHoveringTimer = false
    @State private var isHoveringFullscreen = false
    @State private var hoveredFont: String? = nil
    @State private var isHoveringSize = false
    @State private var fontSize: CGFloat = 18
    @State private var blinkCount = 0
    @State private var isBlinking = false
    @State private var opacity: Double = 1.0
    @State private var shouldShowGray = true // New state to control color
    @State private var lastClickTime: Date? = nil
    @State private var bottomNavOpacity: Double = 1.0
    @State private var isHoveringBottomNav = false
    @State private var selectedEntryIndex: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedEntryId: UUID? = nil
    @State private var hoveredEntryId: UUID? = nil
    @State private var isHoveringChat = false  // Add this state variable
    @State private var showingChatMenu = false
    @State private var chatMenuAnchor: CGPoint = .zero
    @State private var showingSidebar = false  // Add this state variable
    @State private var hoveredTrashId: UUID? = nil
    @State private var hoveredExportId: UUID? = nil
    @State private var isHoveringNewEntry = false
    @State private var isHoveringClock = false
    @State private var isHoveringHistory = false
    @State private var isHoveringHistoryText = false
    @State private var isHoveringHistoryPath = false
    @State private var isHoveringHistoryArrow = false
    @State private var colorScheme: ColorScheme = .light // Add state for color scheme
    @State private var isHoveringThemeToggle = false // Add state for theme toggle hover
    @State private var didCopyPrompt: Bool = false // Add state for copy prompt feedback
    @State private var backspaceDisabled = false // Add state for backspace toggle
    @State private var isHoveringBackspaceToggle = false // Add state for backspace toggle hover
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let entryHeight: CGFloat = 40
    
    // Debounced save timer
    @State private var pendingSaveTimer: Timer? = nil
    private let saveDebounceInterval: TimeInterval = 2.0
    
let availableFonts = NSFontManager.shared.availableFontFamilies

// Add state for manager
@StateObject private var workspaceManager = FluxWorkspaceManager()
    let standardFonts = ["Lato-Regular", "Arial", ".AppleSystemUIFont", "Times New Roman"]
    let fontSizes: [CGFloat] = [16, 18, 20, 22, 24, 26]
    
    // Add file manager and save timer
    private let fileManager = FileManager.default
    private let saveTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    private static func ensureDirectoryExists(at url: URL, label: String) -> URL {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                print("Warning: expected directory for \(label) at \(url.path) but found a file")
            }
        } else {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                print("Created \(label) at: \(url.path)")
            } catch {
                print("Error creating \(label): \(error)")
            }
        }
        return url
    }
    
    // Add cached directories inside /Users/<user>/flux
    private let documentsDirectory: URL = {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let targetDirectory = homeDirectory
            .appendingPathComponent("flux", isDirectory: true)
            .appendingPathComponent("Entries", isDirectory: true)
        let entriesDirectory = ContentView.ensureDirectoryExists(at: targetDirectory, label: "Flux entries directory")
        
        // Migrate existing entries from the legacy Documents/Flux directory if it exists
        let legacyDirectory = fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flux", isDirectory: true)
        if fileManager.fileExists(atPath: legacyDirectory.path) {
            do {
                let legacyFiles = try fileManager.contentsOfDirectory(at: legacyDirectory, includingPropertiesForKeys: nil)
                for file in legacyFiles where file.pathExtension == "md" {
                    let destination = entriesDirectory.appendingPathComponent(file.lastPathComponent)
                    if !fileManager.fileExists(atPath: destination.path) {
                        try fileManager.copyItem(at: file, to: destination)
                        print("Migrated legacy entry: \(file.lastPathComponent)")
                    }
                }
            } catch {
                print("Error migrating legacy entries: \(error)")
            }
        }
        
        return entriesDirectory
    }()
    
    private let backupDirectory: URL = {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let targetDirectory = homeDirectory
            .appendingPathComponent("flux", isDirectory: true)
            .appendingPathComponent("EntriesBackup", isDirectory: true)
        return ContentView.ensureDirectoryExists(at: targetDirectory, label: "Flux backups directory")
    }()
    
    // Add shared prompt constant
    private let aiChatPrompt = """
    below is my journal entry. wyt? talk through it with me like a friend. don't therpaize me and give me a whole breakdown, don't repeat my thoughts with headings. really take all of this, and tell me back stuff truly as if you're an old homie.
    
    Keep it casual, dont say yo, help me make new connections i don't see, comfort, validate, challenge, all of it. dont be afraid to say a lot. format with markdown headings if needed.

    do not just go through every single thing i say, and say it back to me. you need to proccess everythikng is say, make connections i don't see it, and deliver it all back to me as a story that makes me feel what you think i wanna feel. thats what the best therapists do.

    ideally, you're style/tone should sound like the user themselves. it's as if the user is hearing their own tone but it should still feel different, because you have different things to say and don't just repeat back they say.

    else, start by saying, "hey, thanks for showing me this. my thoughts:"
        
    my entry:
    """
    
    private let claudePrompt = """
    Take a look at my journal entry below. I'd like you to analyze it and respond with deep insight that feels personal, not clinical.
    Imagine you're not just a friend, but a mentor who truly gets both my tech background and my psychological patterns. I want you to uncover the deeper meaning and emotional undercurrents behind my scattered thoughts.
    Keep it casual, dont say yo, help me make new connections i don't see, comfort, validate, challenge, all of it. dont be afraid to say a lot. format with markdown headings if needed.
    Use vivid metaphors and powerful imagery to help me see what I'm really building. Organize your thoughts with meaningful headings that create a narrative journey through my ideas.
    Don't just validate my thoughts - reframe them in a way that shows me what I'm really seeking beneath the surface. Go beyond the product concepts to the emotional core of what I'm trying to solve.
    Be willing to be profound and philosophical without sounding like you're giving therapy. I want someone who can see the patterns I can't see myself and articulate them in a way that feels like an epiphany.
    Start with 'hey, thanks for showing me this. my thoughts:' and then use markdown headings to structure your response.

    Here's my journal entry:
    """
    
    // Initialize with saved theme preference if available
    init() {
        // Load saved color scheme preference
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "light"
        _colorScheme = State(initialValue: savedScheme == "dark" ? .dark : .light)
    }
    
    // Modify getDocumentsDirectory to use cached value
    private func getDocumentsDirectory() -> URL {
        return documentsDirectory
    }
    
    // Add function to save text
    private func saveText() {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent("entry.md")
        
        print("Attempting to save file to: \(fileURL.path)")
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved file")
            backupEntryFile(from: fileURL)
        } catch {
            print("Error saving file: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    // Add function to load text
    private func loadText() {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent("entry.md")
        
        print("Attempting to load file from: \(fileURL.path)")
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                text = try String(contentsOf: fileURL, encoding: .utf8)
                print("Successfully loaded file")
            } else {
                print("File does not exist yet")
            }
        } catch {
            print("Error loading file: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    // Add function to load existing entries
    private func loadExistingEntries() {
        let documentsDirectory = getDocumentsDirectory()
        print("Looking for entries in: \(documentsDirectory.path)")

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

            print("Found \(mdFiles.count) .md files")

            let entriesWithDates = mdFiles.compactMap { fileURL -> (entry: HumanEntry, date: Date, content: String)? in
                let filename = fileURL.lastPathComponent
                print("Processing: \(filename)")

                if let result = parseNewFormat(filename: filename, fileURL: fileURL) {
                    return result
                }

                if let result = parseOldFormat(filename: filename, fileURL: fileURL) {
                    return result
                }

                print("Failed to parse filename: \(filename)")
                return nil
            }

            entries = entriesWithDates
                .sorted { $0.date > $1.date }
                .map { $0.entry }

            entryDictionary = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })

            print("Successfully loaded and sorted \(entries.count) entries")

            let calendar = Calendar.current
            let today = Date()
            let todayStart = calendar.startOfDay(for: today)

            let hasEmptyEntryToday = entries.contains { entry in
                if let entryDate = DateFormatterCache.shared.date(from: entry.date, format: "MMM d") {
                    var components = calendar.dateComponents([.year, .month, .day], from: entryDate)
                    components.year = calendar.component(.year, from: today)

                    if let entryDateWithYear = calendar.date(from: components) {
                        let entryDayStart = calendar.startOfDay(for: entryDateWithYear)
                        return calendar.isDate(entryDayStart, inSameDayAs: todayStart) && entry.previewText.isEmpty
                    }
                }
                return false
            }

            let hasOnlyWelcomeEntry = entries.count == 1 && entriesWithDates.first?.content.contains("Welcome to Flux.") == true

            if entries.isEmpty {
                print("First time user, creating welcome entry")
                createNewEntry()
            } else if !hasEmptyEntryToday && !hasOnlyWelcomeEntry {
                print("No empty entry for today, creating new entry")
                createNewEntry()
            } else {
                if let todayEntry = entries.first(where: { entry in
                    if let entryDate = DateFormatterCache.shared.date(from: entry.date, format: "MMM d") {
                        var components = calendar.dateComponents([.year, .month, .day], from: entryDate)
                        components.year = calendar.component(.year, from: today)

                        if let entryDateWithYear = calendar.date(from: components) {
                            let entryDayStart = calendar.startOfDay(for: entryDateWithYear)
                            return calendar.isDate(entryDayStart, inSameDayAs: todayStart) && entry.previewText.isEmpty
                        }
                    }
                    return false
                }) {
                    selectedEntryId = todayEntry.id
                    loadEntry(entry: todayEntry)
                } else if hasOnlyWelcomeEntry {
                    selectedEntryId = entries[0].id
                    loadEntry(entry: entries[0])
                } else {
                    selectedEntryId = entries[0].id
                    loadEntry(entry: entries[0])
                }
            }

        } catch {
            print("Error loading directory contents: \(error)")
            print("Creating default entry after error")
            createNewEntry()
        }
    }

    private func parseNewFormat(filename: String, fileURL: URL) -> (entry: HumanEntry, date: Date, content: String)? {
        let name = filename.replacingOccurrences(of: ".md", with: "")
        let parts = name.components(separatedBy: "-")

        guard parts.count >= 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              (1...31).contains(day) else {
            return nil
        }

        guard let idPart = parts.last,
              idPart.count == 8,
              idPart.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }

        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day

        guard let fileDate = Calendar.current.date(from: dateComponents) else {
            return nil
        }

        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let padded = "\(idPart)-0000-0000-0000-000000000000"
            let uuid = UUID(uuidString: padded) ?? UUID()

            let preview = generatePreview(from: content)
            let displayDate = DateFormatterCache.shared.string(from: fileDate, format: "MMM d")

            return (
                entry: HumanEntry(
                    id: uuid,
                    date: displayDate,
                    filename: filename,
                    previewText: preview
                ),
                date: fileDate,
                content: content
            )
        } catch {
            print("Error reading file: \(error)")
            return nil
        }
    }

    private func parseOldFormat(filename: String, fileURL: URL) -> (entry: HumanEntry, date: Date, content: String)? {
        guard let uuidStart = filename.firstIndex(of: "["),
              let uuidEnd = filename[uuidStart...].dropFirst().firstIndex(of: "]"),
              let dateStart = filename[uuidEnd...].dropFirst().firstIndex(of: "["),
              let dateEnd = filename[dateStart...].dropFirst().firstIndex(of: "]") else {
            return nil
        }

        let uuidString = String(filename[filename.index(after: uuidStart)..<uuidEnd])
        let dateString = String(filename[filename.index(after: dateStart)..<dateEnd])

        guard let uuid = UUID(uuidString: uuidString),
              let fileDate = DateFormatterCache.shared.date(from: dateString, format: "yyyy-MM-dd-HH-mm-ss") else {
            return nil
        }

        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let preview = generatePreview(from: content)
            let displayDate = DateFormatterCache.shared.string(from: fileDate, format: "MMM d")

            return (
                entry: HumanEntry(
                    id: uuid,
                    date: displayDate,
                    filename: filename,
                    previewText: preview
                ),
                date: fileDate,
                content: content
            )
        } catch {
            print("Error reading file: \(error)")
            return nil
        }
    }

    private func generatePreview(from content: String) -> String {
        let maxPreviewChars = 200
        let maxDisplayChars = 30
        let previewEnd = min(content.count, maxPreviewChars)
        let partialContent = previewEnd < content.count
            ? String(content.prefix(previewEnd))
            : content

        var result = ""
        result.reserveCapacity(min(partialContent.count, maxDisplayChars + 3))

        for char in partialContent {
            if result.count >= maxDisplayChars {
                result.append("...")
                break
            }
            result.append(char == "\n" ? " " : char)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Project Discovery
    private func discoverProjects() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        print("Scanning for projects in: \(homeDirectory.path)")
        
        var discoveredProjects: [Project] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: homeDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            
            for url in contents {
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else { continue }
                
                let path = url.path
                let name = url.lastPathComponent
                
                // Skip system directories and common non-project folders
                let skipList = [
                    "Applications", "Desktop", "Documents", "Downloads", "Library",
                    "Movies", "Music", "Pictures", "Public", "flux", ".Trash",
                    "node_modules", ".git", ".swiftpm", "build-output"
                ]
                guard !skipList.contains(name), !name.hasPrefix(".") else { continue }
                
                // Check for project indicators
                let hasGit = fileManager.fileExists(atPath: "\(path)/.git")
                let hasWorkspace = fileManager.fileExists(atPath: "\(path)/workspace")
                let hasNextSteps = fileManager.fileExists(atPath: "\(path)/workspace/NEXT_STEPS.md")
                
                // Only include if it has git or workspace
                guard hasGit || hasWorkspace else { continue }
                
                // Get modification date
                var lastModified = Date()
                if let attrs = try? fileManager.attributesOfItem(atPath: path) {
                    lastModified = attrs[.modificationDate] as? Date ?? Date()
                }
                
                let project = Project(
                    name: name,
                    path: path,
                    lastModified: lastModified,
                    hasWorkspace: hasWorkspace || hasNextSteps
                )
                discoveredProjects.append(project)
                print("Found project: \(name) (git: \(hasGit), workspace: \(hasWorkspace))")
            }
            
            // Sort by last modified, newest first
            projects = discoveredProjects.sorted { $0.lastModified > $1.lastModified }
            print("Discovered \(projects.count) projects")
            
        } catch {
            print("Error scanning for projects: \(error)")
        }
    }
    
    // MARK: - Project NEXT_STEPS.md Integration
    private func loadProjectNextSteps(project: Project) {
        let nextStepsPath = "\(project.path)/workspace/NEXT_STEPS.md"
        let fileURL = URL(fileURLWithPath: nextStepsPath)
        
        // Save current entry before switching
        if let currentId = selectedEntryId,
           let currentEntry = entryDictionary[currentId] {
            pendingSaveTimer?.invalidate()
            saveEntry(entry: currentEntry)
        }
        
        // Clear entry selection to indicate we're viewing a project file
        selectedEntryId = nil
        
        do {
            if fileManager.fileExists(atPath: nextStepsPath) {
                text = try String(contentsOf: fileURL, encoding: .utf8)
                print("Loaded NEXT_STEPS.md for project: \(project.name)")
            } else {
                // Create default NEXT_STEPS.md content if it doesn't exist
                let defaultContent = """
# Next Steps: \(project.name)

## Current State


## Next Actions
- [ ] 

## Blockers


## Decisions Needed


"""
                text = defaultContent
                // Save the default content
                try defaultContent.write(to: fileURL, atomically: true, encoding: .utf8)
                print("Created default NEXT_STEPS.md for project: \(project.name)")
            }
        } catch {
            print("Error loading/creating NEXT_STEPS.md: \(error)")
            text = "\n\nError loading project file."
        }
    }
    
    var randomButtonTitle: String {
        return currentRandomFont.isEmpty ? "Random" : "Random [\(currentRandomFont)]"
    }
    
    var timerButtonTitle: String {
        if !timerIsRunning && timeRemaining == 900 {
            return "15:00"
        }
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var timerColor: Color {
        if timerIsRunning {
            return isHoveringTimer ? (colorScheme == .light ? .black : .white) : .gray.opacity(0.8)
        } else {
            return isHoveringTimer ? (colorScheme == .light ? .black : .white) : (colorScheme == .light ? .gray : .gray.opacity(0.8))
        }
    }
    
    var lineHeight: CGFloat {
        let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let defaultLineHeight = getLineHeight(font: font)
        return (fontSize * 1.5) - defaultLineHeight
    }
    
    var fontSizeButtonTitle: String {
        return "\(Int(fontSize))px"
    }
    
    // Add a color utility computed property
    var popoverBackgroundColor: Color {
        return colorScheme == .light ? Color(NSColor.controlBackgroundColor) : Color(NSColor.darkGray)
    }
    
    var popoverTextColor: Color {
        return colorScheme == .light ? Color.primary : Color.white
    }

    var todayHeaderText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        
        // Show project name if a project is selected
        if let projectPath = selectedProjectPath,
           let project = projects.first(where: { $0.path == projectPath }) {
            return "📁 \(project.name)"
        }
        
        return formatter.string(from: Date())
    }
    
    var searchView: some View {
        VStack(spacing: 0) {
            // Search input
            HStack {
                TextField("Search...", text: $searchQuery)
                    .font(.system(size: 16))
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .onChange(of: searchQuery) {
                        performSearch()
                    }
                
                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        performSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 16)
                }
            }
            .background(Color(colorScheme == .light ? .white : Color.black))
            
            Divider()
            
            // Results count
            HStack {
                Text("\(searchResults.count) results")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Search results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, result in
                        Button(action: {
                            selectSearchResult(result)
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    // Filename
                                    Text(result.filename)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    
                                    // Preview with match
                                    if !result.preview.isEmpty {
                                        Text(result.preview)
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                selectedSearchIndex == index
                                    ? (colorScheme == .light ? Color.black : Color.white)
                                    : Color.clear
                            )
                            .foregroundColor(
                                selectedSearchIndex == index
                                    ? (colorScheme == .light ? Color.white : Color.black)
                                    : (colorScheme == .light ? Color.black : Color.white)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .scrollIndicators(.never)
            
            Spacer()
            
            // Footer hint
            HStack {
                Text("↑↓ navigate • ↵ select • esc close")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: 650)
        .background(Color(colorScheme == .light ? .white : Color.black))
    }
    
    var body: some View {
        let navHeight: CGFloat = 68
        let textColor = colorScheme == .light ? Color.gray : Color.gray.opacity(0.8)
        let textHoverColor = colorScheme == .light ? Color.black : Color.white
        
        HStack(spacing: 0) {
            // Main content
            ZStack {
                Color(colorScheme == .light ? .white : .black)
                    .ignoresSafeArea()
                
              
                if isSearchMode {
                    // Search UI
                    searchView
                } else {
                    // Content with date header
                    VStack(spacing: 0) {
                    // Date header
                    Text(todayHeaderText)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(colorScheme == .light ? .gray : .gray.opacity(0.8))
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    // Text editor
                    TextEditor(text: Binding(
                        get: { text },
                        set: { newValue in
                            // Ensure the text always starts with two newlines
                            if !newValue.hasPrefix("\n\n") {
                                text = "\n\n" + newValue.trimmingCharacters(in: .newlines)
                            } else {
                                text = newValue
                            }
                        }
                    ))
                    .background(Color(colorScheme == .light ? .white : .black))
                    .font(.custom(selectedFont, size: fontSize))
                    .foregroundColor(colorScheme == .light ? Color(red: 0.20, green: 0.20, blue: 0.20) : Color(red: 0.9, green: 0.9, blue: 0.9))
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .lineSpacing(lineHeight)
                    .frame(maxWidth: 650)
                    
          
                    .id("\(selectedFont)-\(fontSize)-\(colorScheme)")
                    .padding(.bottom, bottomNavOpacity > 0 ? navHeight : 0)
                    .ignoresSafeArea()
                    .colorScheme(colorScheme)
                    .onAppear {
                        // Removed findSubview code which was causing errors

                        // Add keyboard monitor for backspace/delete keys
                        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                            // Check for Cmd+K (keycode 40)
                            let hasCommand = event.modifierFlags.contains(.command)
                            let isKKey = event.keyCode == 40
                            
                            // Search mode keyboard navigation
                            if isSearchMode {
                                // Escape to close
                                if event.keyCode == 53 {
                                    DispatchQueue.main.async {
                                        exitSearchMode()
                                    }
                                    return nil
                                }
                                
                                // Down arrow (keycode 125)
                                if event.keyCode == 125 {
                                    DispatchQueue.main.async {
                                        if selectedSearchIndex < searchResults.count - 1 {
                                            selectedSearchIndex += 1
                                        }
                                    }
                                    return nil
                                }
                                
                                // Up arrow (keycode 126)
                                if event.keyCode == 126 {
                                    DispatchQueue.main.async {
                                        if selectedSearchIndex > 0 {
                                            selectedSearchIndex -= 1
                                        }
                                    }
                                    return nil
                                }
                                
                                // Enter/Return (keycode 36)
                                if event.keyCode == 36 && !searchResults.isEmpty {
                                    DispatchQueue.main.async {
                                        selectSearchResult(searchResults[selectedSearchIndex])
                                    }
                                    return nil
                                }
                            }
                            
                            if hasCommand && isKKey {
                                DispatchQueue.main.async {
                                    if !isSearchMode {
                                        isSearchMode = true
                                        searchQuery = ""
                                        searchResults = entries.map { SearchResult(entry: $0, filename: $0.filename, preview: $0.previewText, matchRange: nil) }
                                        selectedSearchIndex = 0
                                    }
                                }
                                return nil // Consume the event
                            }
                            
                            // Check for Cmd+Delete (keycode 51 with Command)
                            if hasCommand && event.keyCode == 51 {
                                DispatchQueue.main.async {
                                    if let currentId = selectedEntryId,
                                       let currentEntry = entryDictionary[currentId] {
                                        deleteEntry(entry: currentEntry)
                                    }
                                }
                                return nil // Consume the event
                            }
                            
                            // Check if backspace is disabled and the key is delete/backspace
                            if backspaceDisabled && (event.keyCode == 51 || event.keyCode == 117) {
                                // Block the backspace/delete key
                                return nil
                            }
                            return event
                        }
                    }
                }
                }
                VStack {
                    Spacer()
                    HStack {
                        // Font buttons (moved to left)
                        HStack(spacing: 8) {
                            Button(fontSizeButtonTitle) {
                                if let currentIndex = fontSizes.firstIndex(of: fontSize) {
                                    let nextIndex = (currentIndex + 1) % fontSizes.count
                                    fontSize = fontSizes[nextIndex]
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringSize ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringSize = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Button("Lato") {
                                selectedFont = "Lato-Regular"
                                currentRandomFont = ""
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(hoveredFont == "Lato" ? textHoverColor : textColor)
                            .onHover { hovering in
                                hoveredFont = hovering ? "Lato" : nil
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Button("Arial") {
                                selectedFont = "Arial"
                                currentRandomFont = ""
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(hoveredFont == "Arial" ? textHoverColor : textColor)
                            .onHover { hovering in
                                hoveredFont = hovering ? "Arial" : nil
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Button("System") {
                                selectedFont = ".AppleSystemUIFont"
                                currentRandomFont = ""
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(hoveredFont == "System" ? textHoverColor : textColor)
                            .onHover { hovering in
                                hoveredFont = hovering ? "System" : nil
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Button("Serif") {
                                selectedFont = "Times New Roman"
                                currentRandomFont = ""
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(hoveredFont == "Serif" ? textHoverColor : textColor)
                            .onHover { hovering in
                                hoveredFont = hovering ? "Serif" : nil
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Button(randomButtonTitle) {
                                if let randomFont = availableFonts.randomElement() {
                                    selectedFont = randomFont
                                    currentRandomFont = randomFont
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(hoveredFont == "Random" ? textHoverColor : textColor)
                            .onHover { hovering in
                                hoveredFont = hovering ? "Random" : nil
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                        .padding(8)
                        .cornerRadius(6)
                        .onHover { hovering in
                            isHoveringBottomNav = hovering
                        }
                        
                        Spacer()
                        
                        // Utility buttons (moved to right)
                        HStack(spacing: 8) {
                            Button(timerButtonTitle) {
                                let now = Date()
                                if let lastClick = lastClickTime,
                                   now.timeIntervalSince(lastClick) < 0.3 {
                                    timeRemaining = 900
                                    timerIsRunning = false
                                    lastClickTime = nil
                                } else {
                                    timerIsRunning.toggle()
                                    lastClickTime = now
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(timerColor)
                            .onHover { hovering in
                                isHoveringTimer = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .onAppear {
                                NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                                    if isHoveringTimer {
                                        let scrollBuffer = event.deltaY * 0.25
                                        
                                        if abs(scrollBuffer) >= 0.1 {
                                            let currentMinutes = timeRemaining / 60
                                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                                            let direction = -scrollBuffer > 0 ? 5 : -5
                                            let newMinutes = currentMinutes + direction
                                            let roundedMinutes = (newMinutes / 5) * 5
                                            let newTime = roundedMinutes * 60
                                            timeRemaining = min(max(newTime, 0), 2700)
                                        }
                                    }
                                    return event
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Button("Chat") {
                                showingChatMenu = true
                                // Ensure didCopyPrompt is reset when opening the menu
                                didCopyPrompt = false
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringChat ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringChat = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .popover(isPresented: $showingChatMenu, attachmentAnchor: .point(UnitPoint(x: 0.5, y: 0)), arrowEdge: .top) {
                                VStack(spacing: 0) { // Wrap everything in a VStack for consistent styling and onChange
                                    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                                    
                                    // Calculate potential URL lengths
                                    let gptFullText = aiChatPrompt + "\n\n" + trimmedText
                                    let claudeFullText = claudePrompt + "\n\n" + trimmedText
                                    let encodedGptText = gptFullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                    let encodedClaudeText = claudeFullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                                    
                                    let gptUrlLength = "https://chat.openai.com/?m=".count + encodedGptText.count
                                    let claudeUrlLength = "https://claude.ai/new?q=".count + encodedClaudeText.count
                                    let isUrlTooLong = gptUrlLength > 6000 || claudeUrlLength > 6000
                                    
                                    if isUrlTooLong {
                                        // View for long text (URL too long)
                                        Text("Hey, your entry is quite long. You'll need to manually copy the prompt by clicking 'Copy Prompt' below and then paste it into AI of your choice (ex. ChatGPT). The prompt includes your entry as well. So just copy paste and go! See what the AI says.")
                                            .font(.system(size: 14))
                                            .foregroundColor(popoverTextColor)
                                            .lineLimit(nil)
                                            .multilineTextAlignment(.leading)
                                            .frame(width: 200, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                        
                                        Divider()

                                        Button(action: {
                                            copyPromptToClipboard()
                                            didCopyPrompt = true
                                        }) {
                                            Text(didCopyPrompt ? "Copied!" : "Copy Prompt")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                        
                                    } else if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("hi. my name is farza.") {
                                        Text("Yo. Sorry, you can't chat with the guide lol. Please write your own entry.")
                                            .font(.system(size: 14))
                                            .foregroundColor(popoverTextColor)
                                            .frame(width: 250)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                    } else if text.count < 350 {
                                        Text("Please free write for at minimum 5 minutes first. Then click this. Trust.")
                                            .font(.system(size: 14))
                                            .foregroundColor(popoverTextColor)
                                            .frame(width: 250)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                    } else {
                                        // View for normal text length
                                        Button(action: {
                                            showingChatMenu = false
                                            openChatGPT()
                                        }) {
                                            Text("ChatGPT")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        Button(action: {
                                            showingChatMenu = false
                                            openClaude()
                                        }) {
                                            Text("Claude")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        Button(action: {
                                            // Don't dismiss menu, just copy and update state
                                            copyPromptToClipboard()
                                            didCopyPrompt = true
                                        }) {
                                            Text(didCopyPrompt ? "Copied!" : "Copy Prompt")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                    }
                                }
                                .frame(minWidth: 120, maxWidth: 250) // Allow width to adjust
                                .background(popoverBackgroundColor)
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                                // Reset copied state when popover dismisses
                                .onChange(of: showingChatMenu) {
                                    if !showingChatMenu {
                                        didCopyPrompt = false
                                    }
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)

                            // Backspace toggle button
                            Button(action: {
                                backspaceDisabled.toggle()
                            }) {
                                Text(backspaceDisabled ? "Backspace is Off" : "Backspace is On")
                                    .foregroundColor(isHoveringBackspaceToggle ? textHoverColor : textColor)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isHoveringBackspaceToggle = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }

                            Text("•")
                                .foregroundColor(.gray)

                            Button(isFullscreen ? "Minimize" : "Fullscreen") {
                                if let window = NSApplication.shared.windows.first {
                                    window.toggleFullScreen(nil)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringFullscreen ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringFullscreen = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                createNewEntry()
                            }) {
                                Text("New Entry")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringNewEntry ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringNewEntry = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            // Theme toggle button
                            Button(action: {
                                colorScheme = colorScheme == .light ? .dark : .light
                                // Save preference
                                UserDefaults.standard.set(colorScheme == .light ? "light" : "dark", forKey: "colorScheme")
                            }) {
                                Image(systemName: colorScheme == .light ? "moon.fill" : "sun.max.fill")
                                    .foregroundColor(isHoveringThemeToggle ? textHoverColor : textColor)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isHoveringThemeToggle = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }

                            Text("•")
                                .foregroundColor(.gray)

                            // Version history button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingSidebar.toggle()
                                }
                            }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(isHoveringClock ? textHoverColor : textColor)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isHoveringClock = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                        .padding(8)
                        .cornerRadius(6)
                        .onHover { hovering in
                            isHoveringBottomNav = hovering
                        }
                    }
                    .padding()
                    .background(Color(colorScheme == .light ? .white : .black))
                    .opacity(bottomNavOpacity)
                    .onHover { hovering in
                        isHoveringBottomNav = hovering
                        if hovering {
                            withAnimation(.easeOut(duration: 0.2)) {
                                bottomNavOpacity = 1.0
                            }
                        } else if timerIsRunning {
                            withAnimation(.easeIn(duration: 1.0)) {
                                bottomNavOpacity = 0.0
                            }
                        }
                    }
                }
            }
            
            // Right sidebar
            if showingSidebar {
                Divider()
                
                VStack(spacing: 0) {
                    // Projects Section
                    if !projects.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Projects")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(colorScheme == .light ? .gray : .gray.opacity(0.8))
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 8)
                            
                            ForEach(projects.prefix(5)) { project in
                                Button(action: {
                                    selectedProjectPath = project.path
                                    print("Selected project: \(project.name)")
                                    loadProjectNextSteps(project: project)
                                }) {
                                    HStack {
                                        HStack(spacing: 4) {
                                            // Project indicator
                                            Circle()
                                                .fill(project.hasWorkspace ? Color.green.opacity(0.6) : Color.gray.opacity(0.4))
                                                .frame(width: 6, height: 6)
                                            
                                            Text(project.displayName)
                                                .font(.system(size: 12))
                                                .lineLimit(1)
                                                .foregroundColor(selectedProjectPath == project.path ? 
                                                    (colorScheme == .light ? .black : .white) :
                                                    (colorScheme == .light ? .gray : .gray.opacity(0.8)))
                                        }
                                        
                                        Spacer()
                                        
                                        if project.hasWorkspace {
                                            Image(systemName: "doc.text")
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray.opacity(0.5))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    selectedProjectPath == project.path ?
                                        Color.gray.opacity(0.1) :
                                        Color.clear
                                )
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                    
                    // Todos Section
                    if !todos.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Todos")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(colorScheme == .light ? .gray : .gray.opacity(0.8))
                                
                                // Count badge
                                let openCount = todos.filter { !$0.isDone }.count
                                if openCount > 0 {
                                    Text("\(openCount)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.black)
                                        .cornerRadius(10)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            
                            // Show open todos first, then done (limited to 10)
                            let displayTodos = todos
                                .sorted { (!$0.isDone && $1.isDone) || ($0.isDone == $1.isDone) }
                                .prefix(10)
                            
                            ForEach(Array(displayTodos.enumerated()), id: \.element.id) { index, todo in
                                Button(action: {
                                    // Jump to entry containing this todo
                                    if let entry = entryDictionary[todo.entryId] {
                                        selectedProjectPath = nil
                                        selectedEntryId = entry.id
                                        loadEntry(entry: entry)
                                    }
                                }) {
                                    HStack(alignment: .top, spacing: 8) {
                                        // Checkbox indicator
                                        Image(systemName: todo.isDone ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 11))
                                            .foregroundColor(todo.isDone ? .gray : (colorScheme == .light ? .black : .white))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            // Todo text
                                            Text(todo.text)
                                                .font(.system(size: 11))
                                                .strikethrough(todo.isDone)
                                                .foregroundColor(todo.isDone ? .gray : (colorScheme == .light ? .black : .white))
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            
                                            // Entry filename
                                            Text(todo.entryFilename)
                                                .font(.system(size: 9))
                                                .foregroundColor(.gray.opacity(0.7))
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                                .opacity(todo.isDone ? 0.6 : 1.0)
                                
                                if index < displayTodos.count - 1 && index < 9 {
                                    Divider()
                                        .padding(.leading, 38)
                                }
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                    
                    // Header
                    Button(action: {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: getDocumentsDirectory().path)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("Show in Finder")
                                        .font(.system(size: 13))
                                        .foregroundColor(isHoveringHistory ? textHoverColor : textColor)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(isHoveringHistory ? textHoverColor : textColor)
                                }
                                
                                // Build hash where path was
                                VersionInfoInline()
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .onHover { hovering in
                        isHoveringHistory = hovering
                    }
                    
                    Divider()
                    // Entries List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(entries) { entry in
                                Button(action: {
                                    if selectedEntryId != entry.id {
                                        // Save current entry before switching
                                        if let currentId = selectedEntryId,
                                           let currentEntry = entryDictionary[currentId] {
                                            // Immediate save on context switch
                                            pendingSaveTimer?.invalidate()
                                            saveEntry(entry: currentEntry)
                                        }
                                        
                                        selectedEntryId = entry.id
                                        loadEntry(entry: entry)
                                    }
                                }) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(entry.previewText)
                                                    .font(.system(size: 13))
                                                    .lineLimit(1)
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                // Export/Trash icons that appear on hover
                                                if hoveredEntryId == entry.id {
                                                    HStack(spacing: 8) {
                                                        // Export PDF button
                                                        Button(action: {
                                                            exportEntryAsPDF(entry: entry)
                                                        }) {
                                                            Image(systemName: "arrow.down.circle")
                                                                .font(.system(size: 11))
                                                                .foregroundColor(hoveredExportId == entry.id ? 
                                                                    (colorScheme == .light ? .black : .white) : 
                                                                    (colorScheme == .light ? .gray : .gray.opacity(0.8)))
                                                        }
                                                        .buttonStyle(.plain)
                                                        .help("Export entry as PDF")
                                                        .onHover { hovering in
                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                hoveredExportId = hovering ? entry.id : nil
                                                            }
                                                            if hovering {
                                                                NSCursor.pointingHand.push()
                                                            } else {
                                                                NSCursor.pop()
                                                            }
                                                        }
                                                        
                                                        // Trash icon
                                                        Button(action: {
                                                            deleteEntry(entry: entry)
                                                        }) {
                                                            Image(systemName: "trash")
                                                                .font(.system(size: 11))
                                                                .foregroundColor(hoveredTrashId == entry.id ? .red : .gray)
                                                        }
                                                        .buttonStyle(.plain)
                                                        .onHover { hovering in
                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                hoveredTrashId = hovering ? entry.id : nil
                                                            }
                                                            if hovering {
                                                                NSCursor.pointingHand.push()
                                                            } else {
                                                                NSCursor.pop()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            Text(entry.date)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(backgroundColor(for: entry))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        hoveredEntryId = hovering ? entry.id : nil
                                    }
                                }
                                .onAppear {
                                    NSCursor.pop()  // Reset cursor when button appears
                                }
                                .help("Click to select this entry")  // Add tooltip
                                
                                if entry.id != entries.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
                .frame(width: 200)
                .background(Color(colorScheme == .light ? .white : NSColor.black))
            }
        }
        .frame(minWidth: 1100, minHeight: 600)
        .animation(.easeInOut(duration: 0.2), value: showingSidebar)
        .preferredColorScheme(colorScheme)
        .onAppear {
            showingSidebar = false  // Hide sidebar by default
            loadExistingEntries()
            discoverProjects()
            extractTodos()
        }
        .onChange(of: text) {
            if let currentId = selectedEntryId,
               let currentEntry = entryDictionary[currentId] {
                // Debounced save: cancel pending, schedule new
                pendingSaveTimer?.invalidate()
                pendingSaveTimer = Timer.scheduledTimer(withTimeInterval: saveDebounceInterval, repeats: false) { _ in
                    saveEntry(entry: currentEntry)
                }
            } else if let projectPath = selectedProjectPath {
                // Save project NEXT_STEPS.md
                pendingSaveTimer?.invalidate()
                pendingSaveTimer = Timer.scheduledTimer(withTimeInterval: saveDebounceInterval, repeats: false) { _ in
                    let nextStepsPath = "\(projectPath)/workspace/NEXT_STEPS.md"
                    let fileURL = URL(fileURLWithPath: nextStepsPath)
                    do {
                        try text.write(to: fileURL, atomically: true, encoding: .utf8)
                        print("Saved NEXT_STEPS.md for project")
                    } catch {
                        print("Error saving NEXT_STEPS.md: \(error)")
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            if timerIsRunning && timeRemaining > 0 {
                timeRemaining -= 1
            } else if timeRemaining == 0 {
                timerIsRunning = false
                if !isHoveringBottomNav {
                    withAnimation(.easeOut(duration: 1.0)) {
                        bottomNavOpacity = 1.0
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullscreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullscreen = false
        }
    }
    
    private func backgroundColor(for entry: HumanEntry) -> Color {
        if entry.id == selectedEntryId {
            return Color.gray.opacity(0.1)  // More subtle selection highlight
        } else if entry.id == hoveredEntryId {
            return Color.gray.opacity(0.05)  // Even more subtle hover state
        } else {
            return Color.clear
        }
    }
    
    private func updatePreviewText(for entry: HumanEntry) {
        // Deprecated: use updatePreviewFromMemory instead
    }
    
    private func updatePreviewFromMemory(for entry: HumanEntry, content: String) {
        // Single-pass preview generation
        let maxDisplayChars = 30
        var result = ""
        result.reserveCapacity(maxDisplayChars + 3)
        
        for char in content {
            if result.count >= maxDisplayChars {
                result.append("...")
                break
            }
            result.append(char == "\n" ? " " : char)
        }
        
        let truncated = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update both array and dictionary
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].previewText = truncated.isEmpty ? "" : truncated
            entryDictionary[entry.id] = entries[index]
        }
    }
    
    // MARK: - Search Functionality
    private func performSearch() {
        if searchQuery.isEmpty {
            // Show all entries when no query
            searchResults = entries.map { entry in
                SearchResult(
                    entry: entry,
                    filename: entry.filename,
                    preview: entry.previewText,
                    matchRange: nil
                )
            }
            return
        }
        
        let query = searchQuery.lowercased()
        var results: [SearchResult] = []
        
        for entry in entries {
            let documentsDirectory = getDocumentsDirectory()
            let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
            
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            
            let (_, bodyContent) = parseFrontmatter(from: content)
            let lowerContent = bodyContent.lowercased()
            
            if let range = lowerContent.range(of: query) {
                // Find context around match
                let startIndex = bodyContent.index(range.lowerBound, offsetBy: -30, limitedBy: bodyContent.startIndex) ?? bodyContent.startIndex
                let endIndex = bodyContent.index(range.upperBound, offsetBy: 30, limitedBy: bodyContent.endIndex) ?? bodyContent.endIndex
                let context = String(bodyContent[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                results.append(SearchResult(
                    entry: entry,
                    filename: entry.filename,
                    preview: context,
                    matchRange: range
                ))
            } else if entry.filename.lowercased().contains(query) {
                // Match in filename
                results.append(SearchResult(
                    entry: entry,
                    filename: entry.filename,
                    preview: entry.previewText,
                    matchRange: nil
                ))
            }
        }
        
        searchResults = results
        selectedSearchIndex = 0
    }
    
    private func exitSearchMode() {
        isSearchMode = false
        searchQuery = ""
        searchResults = []
    }
    
    private func selectSearchResult(_ result: SearchResult) {
        // Exit search mode
        isSearchMode = false
        searchQuery = ""
        searchResults = []
        
        // Load the selected entry
        selectedProjectPath = nil
        selectedEntryId = result.entry.id
        loadEntry(entry: result.entry)
    }
    
    // MARK: - Todo Extraction
    private func extractTodos() {
        var extractedTodos: [TodoItem] = []
        let documentsDirectory = getDocumentsDirectory()
        
        for entry in entries {
            let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
            
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            
            let (_, bodyContent) = parseFrontmatter(from: content)
            let lines = bodyContent.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Check for @todo tag
                if trimmed.contains("@todo") {
                    let isDone = trimmed.contains("@done") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]")
                    let cleanText = trimmed
                        .replacingOccurrences(of: "@todo", with: "")
                        .replacingOccurrences(of: "@done", with: "")
                        .replacingOccurrences(of: "- [ ]", with: "")
                        .replacingOccurrences(of: "- [x]", with: "")
                        .replacingOccurrences(of: "- [X]", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !cleanText.isEmpty {
                        extractedTodos.append(TodoItem(
                            entryId: entry.id,
                            entryFilename: entry.filename,
                            text: cleanText,
                            isDone: isDone
                        ))
                    }
                }
            }
        }
        
        todos = extractedTodos
        print("Extracted \(todos.count) todos from \(entries.count) entries")
    }
    
    private func saveEntry(entry: HumanEntry) {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        // Parse existing frontmatter
        let (existingMetadata, bodyContent) = parseFrontmatter(from: text)
        
        // Build metadata
        var metadata: [String: String] = [:]
        
        // Preserve created date or set new
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let nowString = dateFormatter.string(from: Date())
        
        if let created = existingMetadata["created"] {
            metadata["created"] = created
        } else {
            metadata["created"] = nowString
        }
        metadata["modified"] = nowString
        
        // Extract tags
        let extractedTags = extractTags(from: bodyContent)
        if !extractedTags.isEmpty {
            metadata["tags"] = extractedTags.joined(separator: ", ")
        }
        
        // Preserve existing summary if any
        if let existingSummary = existingMetadata["summary"] {
            metadata["summary"] = existingSummary
        }
        
        // Generate new content to save
        let frontmatter = generateFrontmatter(metadata: metadata)
        let contentToSave = frontmatter.isEmpty ? bodyContent : frontmatter + "\n\n" + bodyContent
        
        do {
            try contentToSave.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved entry: \(entry.filename)")
            backupEntryFile(from: fileURL)
            
            // Update preview with summary or body
            if let summary = metadata["summary"] {
                updatePreviewFromMemory(for: entry, content: summary)
            } else {
                updatePreviewFromMemory(for: entry, content: bodyContent)
            }
            
            // Trigger Ollama summarization in background
            generateSummary(for: contentToSave) { summary in
                guard let summary = summary else { return }
                
                // Update metadata with summary
                var updatedMetadata = metadata
                updatedMetadata["summary"] = summary
                
                // Regenerate file with summary
                let newFrontmatter = generateFrontmatter(metadata: updatedMetadata)
                let newContent = newFrontmatter + "\n\n" + bodyContent
                
                do {
                    try newContent.write(to: fileURL, atomically: true, encoding: .utf8)
                    print("Updated entry with AI summary: \(entry.filename)")
                    
                    // Note: Can't update self.text here due to struct semantics
                    // The summary will show on next load or sidebar refresh
                    
                    // Update preview
                    DispatchQueue.main.async {
                        // Reload entry to show summary
                        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                            entries[index].previewText = summary
                            entryDictionary[entry.id] = entries[index]
                        }
                    }
                } catch {
                    print("Error saving summary: \(error)")
                }
            }
        } catch {
            print("Error saving entry: \(error)")
        }
    }
    
    private func loadEntry(entry: HumanEntry) {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                let fullContent = try String(contentsOf: fileURL, encoding: .utf8)
                // Strip frontmatter - UI shows body only
                let (_, bodyContent) = parseFrontmatter(from: fullContent)
                text = bodyContent
                print("Successfully loaded entry: \(entry.filename)")
            }
        } catch {
            print("Error loading entry: \(error)")
        }
    }
    
    private func createNewEntry() {
        let newEntry = HumanEntry.createNew()
        entries.insert(newEntry, at: 0) // Add to the beginning
        entryDictionary[newEntry.id] = newEntry
        selectedEntryId = newEntry.id
        
        // If this is the first entry (entries was empty before adding this one)
        if entries.count == 1 {
            // Read welcome message from default.md
            if let defaultMessageURL = Bundle.main.url(forResource: "default", withExtension: "md"),
               let defaultMessage = try? String(contentsOf: defaultMessageURL, encoding: .utf8) {
                text = "\n\n" + defaultMessage
            }
            // Save the welcome message immediately
            saveEntry(entry: newEntry)
            // Update the preview text
            updatePreviewText(for: newEntry)
        } else {
            // Regular new entry starts with newlines
            text = "\n\n"
            // Save the empty entry
            saveEntry(entry: newEntry)
        }
    }
    
    private func openChatGPT() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = aiChatPrompt + "\n\n" + trimmedText
        
        if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://chat.openai.com/?prompt=" + encodedText) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openClaude() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = claudePrompt + "\n\n" + trimmedText
        
        if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://claude.ai/new?q=" + encodedText) {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyPromptToClipboard() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = aiChatPrompt + "\n\n" + trimmedText

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullText, forType: .string)
        print("Prompt copied to clipboard")
    }
    
    private func deleteEntry(entry: HumanEntry) {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        // Create trash directory if it doesn't exist
        let trashDirectory = documentsDirectory.appendingPathComponent(".trash")
        if !fileManager.fileExists(atPath: trashDirectory.path) {
            do {
                try fileManager.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
            } catch {
                print("Error creating trash directory: \(error)")
                return
            }
        }
        
        // Move to trash instead of deleting
        let trashURL = trashDirectory.appendingPathComponent(entry.filename)
        
        do {
            // If file already exists in trash, remove it first
            if fileManager.fileExists(atPath: trashURL.path) {
                try fileManager.removeItem(at: trashURL)
            }
            
            try fileManager.moveItem(at: fileURL, to: trashURL)
            print("Successfully moved to trash: \(entry.filename)")
            
            // Remove the entry from the array and dictionary
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries.remove(at: index)
                entryDictionary.removeValue(forKey: entry.id)
                
                // Remove any todos from this entry
                todos.removeAll { $0.entryId == entry.id }
                
                // If the deleted entry was selected, select the first entry or create a new one
                if selectedEntryId == entry.id {
                    if let firstEntry = entries.first {
                        selectedEntryId = firstEntry.id
                        loadEntry(entry: firstEntry)
                    } else {
                        createNewEntry()
                    }
                }
            }
        } catch {
            print("Error moving to trash: \(error)")
        }
    }
    
    private func backupEntryFile(from fileURL: URL) {
        let timestamp = DateFormatterCache.shared.string(from: Date(), format: "yyyyMMdd-HHmmssSSS")
        let backupFilename = "\(timestamp)-\(fileURL.lastPathComponent)"
        let backupURL = backupDirectory.appendingPathComponent(backupFilename)
        
        do {
            try fileManager.copyItem(at: fileURL, to: backupURL)
            print("Stored backup at: \(backupURL.path)")
        } catch {
            print("Error creating backup: \(error)")
        }
    }
    
    // Extract a title from entry content for PDF export
    private func extractTitleFromContent(_ content: String, date: String) -> String {
        // Clean up content by removing leading/trailing whitespace and newlines
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If content is empty, just use the date
        if trimmedContent.isEmpty {
            return "Entry \(date)"
        }
        
        // Split content into words, ignoring newlines and removing punctuation
        let words = trimmedContent
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { word in
                word.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"'()[]{}<>"))
                    .lowercased()
            }
            .filter { !$0.isEmpty }
        
        // If we have at least 4 words, use them
        if words.count >= 4 {
            return "\(words[0])-\(words[1])-\(words[2])-\(words[3])"
        }
        
        // If we have fewer than 4 words, use what we have
        if !words.isEmpty {
            return words.joined(separator: "-")
        }
        
        // Fallback to date if no words found
        return "Entry \(date)"
    }
    
    private func exportEntryAsPDF(entry: HumanEntry) {
        // First make sure the current entry is saved
        if selectedEntryId == entry.id {
            saveEntry(entry: entry)
        }
        
        // Get entry content
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            // Read the content of the entry
            let entryContent = try String(contentsOf: fileURL, encoding: .utf8)
            
            // Extract a title from the entry content and add .pdf extension
            let suggestedFilename = extractTitleFromContent(entryContent, date: entry.date) + ".pdf"
            
            // Create save panel
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType.pdf]
            savePanel.nameFieldStringValue = suggestedFilename
            savePanel.isExtensionHidden = false  // Make sure extension is visible
            
            // Show save dialog
            if savePanel.runModal() == .OK, let url = savePanel.url {
                // Create PDF data
                if let pdfData = createPDFFromText(text: entryContent) {
                    try pdfData.write(to: url)
                    print("Successfully exported PDF to: \(url.path)")
                }
            }
        } catch {
            print("Error in PDF export: \(error)")
        }
    }
    
    private func createPDFFromText(text: String) -> Data? {
        // Letter size page dimensions
        let pageWidth: CGFloat = 612.0  // 8.5 x 72
        let pageHeight: CGFloat = 792.0 // 11 x 72
        let margin: CGFloat = 72.0      // 1-inch margins
        
        // Calculate content area
        let contentRect = CGRect(
            x: margin,
            y: margin,
            width: pageWidth - (margin * 2),
            height: pageHeight - (margin * 2)
        )
        
        // Create PDF data container
        let pdfData = NSMutableData()
        
        // Configure text formatting attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineHeight
        
        let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]
        
        // Trim the initial newlines before creating the PDF
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create the attributed string with formatting
        let attributedString = NSAttributedString(string: trimmedText, attributes: textAttributes)
        
        // Create a Core Text framesetter for text layout
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // Create a PDF context with the data consumer
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!, mediaBox: nil, nil) else {
            print("Failed to create PDF context")
            return nil
        }
        
        // Track position within text
        var currentRange = CFRange(location: 0, length: 0)
        var pageIndex = 0
        
        // Create a path for the text frame
        let framePath = CGMutablePath()
        framePath.addRect(contentRect)
        
        // Continue creating pages until all text is processed
        while currentRange.location < attributedString.length {
            // Begin a new PDF page
            pdfContext.beginPage(mediaBox: nil)
            
            // Fill the page with white background
            pdfContext.setFillColor(NSColor.white.cgColor)
            pdfContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
            
            // Create a frame for this page's text
            let frame = CTFramesetterCreateFrame(
                framesetter, 
                currentRange, 
                framePath, 
                nil
            )
            
            // Draw the text frame
            CTFrameDraw(frame, pdfContext)
            
            // Get the range of text that was actually displayed in this frame
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            
            // Move to the next block of text for the next page
            currentRange.location += visibleRange.length
            
            // Finish the page
            pdfContext.endPage()
            pageIndex += 1
            
            // Safety check - don't allow infinite loops
            if pageIndex > 1000 {
                print("Safety limit reached - stopping PDF generation")
                break
            }
        }
        
        // Finalize the PDF document
        pdfContext.closePDF()
        
        return pdfData as Data
    }
    
    // MARK: - Ollama Summarization
    
    /// Generates a one-line summary of the entry content using local Ollama
    private func generateSummary(for content: String, completion: @escaping (String?) -> Void) {
        // Strip frontmatter for summarization
        let (_, bodyContent) = parseFrontmatter(from: content)
        
        // Skip if content is too short
        let trimmedContent = bodyContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContent.count < 50 {
            completion(nil)
            return
        }
        
        // Truncate if too long
        let maxChars = 2000
        let textToSummarize = trimmedContent.count > maxChars 
            ? String(trimmedContent.prefix(maxChars)) + "..."
            : trimmedContent
        
        // Ollama API request
        let prompt = "Summarize the following text in one concise sentence (max 10 words):\n\n\(textToSummarize)"
        
        let requestBody: [String: Any] = [
            "model": "llama3.2",
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.3,
                "num_predict": 50
            ]
        ]
        
        guard let url = URL(string: "http://localhost:11434/api/generate"),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Async call
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Ollama request failed: \(error?.localizedDescription ?? "unknown error")")
                completion(nil)
                return
            }
            
            // Parse response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? String {
                let summary = response.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                completion(summary.isEmpty ? nil : summary)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    // MARK: - Frontmatter Helpers
    
    /// Parses existing YAML frontmatter from content
    private func parseFrontmatter(from content: String) -> (metadata: [String: String], body: String) {
        let lines = content.components(separatedBy: .newlines)
        var metadata: [String: String] = [:]
        var bodyStartIndex = 0
        
        // Check for frontmatter delimiter
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
            // Find closing delimiter
            if let closeIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
                // Parse metadata lines between delimiters
                let metadataLines = lines[1..<closeIndex]
                for line in metadataLines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if let colonIndex = trimmed.firstIndex(of: ":") {
                        let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                        let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        metadata[key] = value
                    }
                }
                bodyStartIndex = closeIndex + 1
            }
        }
        
        let body = lines[bodyStartIndex...].joined(separator: "\n")
        return (metadata, body)
    }
    
    /// Generates YAML frontmatter from metadata
    private func generateFrontmatter(metadata: [String: String]) -> String {
        guard !metadata.isEmpty else { return "" }
        
        var lines = ["---"]
        for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
            // Handle array values (tags)
            if key == "tags" && value.contains(",") {
                lines.append("\(key):")
                let tags = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                for tag in tags {
                    lines.append("  - \(tag)")
                }
            } else {
                lines.append("\(key): \(value)")
            }
        }
        lines.append("---")
        return lines.joined(separator: "\n")
    }
    
    /// Extracts inline tags from text (e.g., @todo, @decision, @idea)
    private func extractTags(from content: String) -> [String] {
        let tagPattern = "@(\\w+)"
        let regex = try? NSRegularExpression(pattern: tagPattern, options: [])
        let range = NSRange(content.startIndex..., in: content)
        
        let matches = regex?.matches(in: content, options: [], range: range) ?? []
        let tags = matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: content) else { return nil }
            let tag = String(content[range])
            // Filter to known tags only
            return ["todo", "decision", "idea", "question", "note", "work", "personal"].contains(tag) ? tag : nil
        }
        
        return Array(Set(tags)) // Remove duplicates
    }
}

// Helper function to calculate line height
func getLineHeight(font: NSFont) -> CGFloat {
    return font.ascender - font.descender + font.leading
}

// Add helper extension to find NSTextView
extension NSView {
    func findTextView() -> NSView? {
        if self is NSTextView {
            return self
        }
        for subview in subviews {
            if let textView = subview.findTextView() {
                return textView
            }
        }
        return nil
    }
}

// Add helper extension for finding subviews of a specific type
extension NSView {
    func findSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let typedSelf = self as? T {
            return typedSelf
        }
        for subview in subviews {
            if let found = subview.findSubview(ofType: type) {
                return found
            }
        }
        return nil
    }
}

#Preview {
    ContentView()
}
