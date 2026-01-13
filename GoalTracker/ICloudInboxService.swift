import Foundation
import Combine

/// Watches an iCloud Drive folder for incoming goal JSON files from iOS Shortcuts.
/// NOTE: Requires "Full Disk Access" permission in System Settings > Privacy & Security
class ICloudInboxService: ObservableObject {
    static let shared = ICloudInboxService()

    private var folderMonitor: DispatchSourceFileSystemObject?
    private var folderDescriptor: Int32 = -1
    private let fileManager = FileManager.default
    private var isWatching = false
    private var pollTimer: Timer?

    // iCloud Drive inbox path
    private var inboxURL: URL? {
        guard let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir else {
            return nil
        }
        let homeDir = String(cString: home)
        return URL(fileURLWithPath: "\(homeDir)/Library/Mobile Documents/com~apple~CloudDocs/GoalTracker/inbox")
    }

    init() {
        setupInboxFolder()
    }

    // MARK: - Setup

    private func setupInboxFolder() {
        guard let inboxURL = inboxURL else {
            print("[ICloudInbox] Could not determine inbox URL")
            return
        }

        // Create inbox folder if it doesn't exist
        if !fileManager.fileExists(atPath: inboxURL.path) {
            do {
                try fileManager.createDirectory(at: inboxURL, withIntermediateDirectories: true)
                print("[ICloudInbox] Created inbox folder at: \(inboxURL.path)")
            } catch {
                print("[ICloudInbox] Failed to create inbox folder: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Start/Stop Watching

    func startWatching() {
        guard !isWatching else { return }
        guard let inboxURL = inboxURL else {
            print("[ICloudInbox] Cannot start watching - no inbox URL")
            return
        }

        // Process any existing files first
        processExistingFiles()

        // Open folder descriptor for monitoring
        folderDescriptor = open(inboxURL.path, O_EVTONLY)
        if folderDescriptor >= 0 {
            // Create dispatch source for file system events
            folderMonitor = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: folderDescriptor,
                eventMask: .write,
                queue: DispatchQueue.global(qos: .utility)
            )

            folderMonitor?.setEventHandler { [weak self] in
                self?.handleFolderChange()
            }

            folderMonitor?.setCancelHandler { [weak self] in
                if let fd = self?.folderDescriptor, fd >= 0 {
                    close(fd)
                }
                self?.folderDescriptor = -1
            }

            folderMonitor?.resume()
        }

        // Also poll periodically (iCloud sync may not trigger DispatchSource)
        DispatchQueue.main.async { [weak self] in
            self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.processExistingFiles()
            }
        }

        isWatching = true
        print("[ICloudInbox] Started watching: \(inboxURL.path)")
    }

    func stopWatching() {
        folderMonitor?.cancel()
        folderMonitor = nil
        pollTimer?.invalidate()
        pollTimer = nil
        isWatching = false
    }

    // MARK: - File Processing

    private func handleFolderChange() {
        // Small delay to let file writing complete
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.processExistingFiles()
        }
    }

    private func processExistingFiles() {
        guard let inboxURL = inboxURL else { return }

        do {
            let files = try fileManager.contentsOfDirectory(
                at: inboxURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let jsonFiles = files.filter { $0.pathExtension == "json" }

            for file in jsonFiles {
                processGoalFile(at: file)
            }
        } catch {
            // Permission error is expected without Full Disk Access - don't spam console
            return
        }
    }

    private func processGoalFile(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let goalData = try JSONDecoder().decode(IncomingGoal.self, from: data)

            // Create goal on main thread
            DispatchQueue.main.async {
                self.createGoal(from: goalData)
            }

            // Delete the file after processing
            try fileManager.removeItem(at: url)
            print("[ICloudInbox] Imported goal: \(goalData.title)")

        } catch {
            print("[ICloudInbox] Failed to process \(url.lastPathComponent): \(error.localizedDescription)")
            // Rename bad files to avoid repeated processing
            let badFileURL = url.deletingPathExtension().appendingPathExtension("bad.json")
            try? fileManager.moveItem(at: url, to: badFileURL)
        }
    }

    private func createGoal(from incoming: IncomingGoal) {
        let category = GoalCategory(rawValue: incoming.category) ?? .personal
        let weekStart = WeekService.shared.currentWeekStart

        _ = DataService.shared.createGoal(
            title: incoming.title,
            category: category,
            weekStart: weekStart,
            notes: incoming.notes
        )
    }
}

// MARK: - Incoming Goal Model

struct IncomingGoal: Codable {
    let title: String
    let category: String
    var notes: String?
}
