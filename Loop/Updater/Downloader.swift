//
//  Downloader.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import AppKit
import Foundation
import Scribe

@Loggable(style: .static)
@MainActor
public final class Downloader: NSObject, Sendable {
    // MARK: - Types

    public typealias RelocationHandler = @MainActor () async -> Bool
    public typealias RelocationErrorHandler = @MainActor (Error) async -> ()

    // MARK: - Properties

    private let config: UpdaterConfig
    private let fileManager: FileManager
    private let workspace: NSWorkspace

    private let relocationHandler: RelocationHandler?
    private let relocationErrorHandler: RelocationErrorHandler?

    private var urlSession: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var progressHandler: ((UpdateProgress) -> ())?
    private var completionHandler: ((Result<URL, Error>) -> ())?
    private var downloadState: DownloadState = .idle
    private var performanceTracker: PerformanceTracker = .init()

    // Computed once and cached
    private lazy var paths: SystemPaths = .init()
    private lazy var currentAppLocation: AppLocation = AppLocationManager.determineLocation()

    // MARK: - Initialization

    public init(
        config: UpdaterConfig,
        relocationHandler: RelocationHandler? = nil,
        relocationErrorHandler: RelocationErrorHandler? = nil
    ) {
        self.config = config
        self.fileManager = .default
        self.workspace = .shared
        self.relocationHandler = relocationHandler
        self.relocationErrorHandler = relocationErrorHandler
        super.init()
    }

    deinit {
        downloadTask?.cancel()
        downloadTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    // MARK: - Public Interface

    public var currentDownloadState: DownloadState {
        downloadState
    }

    public func downloadUpdate(
        manifest: UpdateManifest,
        progress: @escaping (UpdateProgress) -> (),
        completion: @escaping (Result<URL, Error>) -> ()
    ) {
        guard downloadState == .idle else {
            completion(.failure(DownloadError.downloadInProgress))
            return
        }

        guard let downloadURL = URL(string: manifest.downloadUrl) else {
            completion(.failure(DownloadError.invalidURL(manifest.downloadUrl)))
            return
        }

        Log.info("Starting download - URL: \(manifest.downloadUrl), Version: \(manifest.version)")

        do {
            try EnvironmentValidator.validate(at: paths.patchworkDirectory)
            setupDownload(url: downloadURL, progress: progress, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }

    public func cancel() {
        Log.info("Cancelling download")
        downloadState = .cancelled
        downloadTask?.cancel()
        Task { await cleanup() }
    }

    public func checkAndHandleAppLocation() async {
        await AppLocationManager.handleLocationIfNeeded(
            currentLocation: currentAppLocation,
            relocationHandler: relocationHandler,
            relocationErrorHandler: relocationErrorHandler
        )
    }

    public var appLocation: AppLocation { currentAppLocation }
    public var isInSuitableLocation: Bool { currentAppLocation.isInApplicationsFolder }

    // MARK: - Private Implementation

    private func setupDownload(
        url: URL,
        progress: @escaping (UpdateProgress) -> (),
        completion: @escaping (Result<URL, Error>) -> ()
    ) {
        downloadState = .downloading
        progressHandler = progress
        completionHandler = completion
        performanceTracker.reset()

        let sessionConfig = SessionConfigurationFactory.create(from: config.networkConfig)
        urlSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        downloadTask = urlSession?.downloadTask(with: url)
        downloadTask?.resume()
    }

    private nonisolated func handleDownloadCompletion(at location: URL, originalURL: URL) {
        Log.info("Download completed - Temp Location: \(location.path)")

        do {
            let finalURL = try FileOperations.moveDownloadedFile(
                from: location,
                originalURL: originalURL,
                to: SystemPaths().patchworkDirectory
            )
            try FileValidator.validateDownloadedFile(at: finalURL)

            Task { @MainActor in
                await self.handleAppLocationAndComplete(with: finalURL)
            }
        } catch {
            Task { @MainActor in
                self.handleError(error)
            }
        }
    }

    private func handleAppLocationAndComplete(with url: URL) async {
        await checkAndHandleAppLocation()
        downloadState = .completed
        completionHandler?(.success(url))
        await cleanup()
    }

    private func handleError(_ error: Error) {
        downloadState = .failed
        completionHandler?(.failure(error))
        Task { await cleanup() }
    }

    private func cleanup() async {
        downloadTask?.cancel()
        downloadTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        progressHandler = nil
        completionHandler = nil
        performanceTracker.reset()
    }
}

// MARK: URLSessionDownloadDelegate

extension Downloader: URLSessionDownloadDelegate {
    public nonisolated func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let originalURL = downloadTask.originalRequest?.url else {
            Task { @MainActor in
                self.handleError(DownloadError.unknown(NSError(domain: "MissingOriginalURL", code: -1)))
            }
            return
        }
        handleDownloadCompletion(at: location, originalURL: originalURL)
    }

    public nonisolated func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            guard downloadState == .downloading else { return }

            let progress = performanceTracker.updateProgress(
                bytesWritten: bytesWritten,
                totalBytesWritten: totalBytesWritten,
                totalBytesExpectedToWrite: totalBytesExpectedToWrite
            )

            progressHandler?(progress)
        }
    }

    public nonisolated func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }

        Task { @MainActor in
            guard downloadState == .downloading else { return }

            Log.error("Download failed: \(error.localizedDescription)")

            let downloadError: DownloadError = (error as? URLError).map(DownloadError.networkError) ?? .unknown(error)
            handleError(downloadError)
        }
    }
}

// MARK: - DownloadState

public enum DownloadState {
    case idle, downloading, completed, failed, cancelled
}

// MARK: - SystemPaths

private struct SystemPaths {
    let appSupportDirectory: URL
    let patchworkDirectory: URL

    init() {
        self.appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.patchworkDirectory = appSupportDirectory.appendingPathComponent("Loop", isDirectory: true)
    }
}

// MARK: - PerformanceTracker

private struct PerformanceTracker {
    private var startTime: Date?
    private var lastProgressUpdate: Date?
    private var speedSamples: CircularBuffer<SpeedSample> = .init(capacity: 10)

    mutating func reset() {
        startTime = Date()
        lastProgressUpdate = Date()
        speedSamples.clear()
    }

    mutating func updateProgress(
        bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) -> UpdateProgress {
        let now = Date()
        let percentage = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        updateSpeedSamples(bytesWritten: bytesWritten, now: now)

        let downloadSpeed = calculateSmoothedSpeed()
        let estimatedTimeRemaining = calculateETA(
            speed: downloadSpeed,
            remainingBytes: totalBytesExpectedToWrite - totalBytesWritten
        )

        return UpdateProgress(
            phase: .downloading,
            percentage: percentage,
            bytesDownloaded: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite,
            estimatedTimeRemaining: estimatedTimeRemaining,
            downloadSpeed: downloadSpeed
        )
    }

    private mutating func updateSpeedSamples(bytesWritten: Int64, now: Date) {
        guard let lastUpdate = lastProgressUpdate else { return }

        let timeDelta = now.timeIntervalSince(lastUpdate)
        if timeDelta > 0.1 {
            let speed = Double(bytesWritten) / timeDelta / 1_048_576
            speedSamples.append(SpeedSample(timestamp: now, speed: speed))
            lastProgressUpdate = now
        }
    }

    private func calculateSmoothedSpeed() -> Double? {
        guard speedSamples.count >= 2 else { return nil }

        let samples = speedSamples.elements
        let weights = (0 ..< samples.count).map { Double($0 + 1) }
        let totalWeight = weights.reduce(0, +)

        let weightedSum = zip(samples, weights).reduce(0.0) { sum, pair in
            sum + (pair.0.speed * pair.1)
        }

        return weightedSum / totalWeight
    }

    private func calculateETA(speed: Double?, remainingBytes: Int64) -> TimeInterval? {
        guard let speed, speed > 0 else { return nil }
        return Double(remainingBytes) / (speed * 1_048_576)
    }
}

// MARK: - SpeedSample

private struct SpeedSample {
    let timestamp: Date
    let speed: Double
}

// MARK: - EnvironmentValidator

private enum EnvironmentValidator {
    static func validate(at directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

// MARK: - SessionConfigurationFactory

private enum SessionConfigurationFactory {
    static func create(from networkConfig: UpdaterConfig.NetworkConfig) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default

        config.timeoutIntervalForRequest = networkConfig.timeout
        config.timeoutIntervalForResource = networkConfig.timeout * 3
        config.allowsCellularAccess = networkConfig.allowsCellularAccess
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true

        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpMaximumConnectionsPerHost = 1
        config.httpShouldUsePipelining = false

        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never

        return config
    }
}

// MARK: - FileOperations

private enum FileOperations {
    static func moveDownloadedFile(from tempLocation: URL, originalURL: URL, to loopDir: URL) throws -> URL {
        // Preserve original filename instead of renaming to "LoopUpdate.zip"
        let originalFilename = originalURL.lastPathComponent
        let finalURL = loopDir.appendingPathComponent(originalFilename)
        let tempFinalURL = loopDir.appendingPathComponent("\(originalFilename).tmp")

        Log
            .info(
                "Moving downloaded file - From: \(tempLocation.path), To: \(finalURL.path), Original: \(originalURL.absoluteString)"
            )

        try? FileManager.default.removeItem(at: tempFinalURL)
        try FileManager.default.moveItem(at: tempLocation, to: tempFinalURL)
        try? FileManager.default.removeItem(at: finalURL)
        try FileManager.default.moveItem(at: tempFinalURL, to: finalURL)

        Log.info("File moved successfully - Final Location: \(finalURL.path), Filename: \(finalURL.lastPathComponent)")

        return finalURL
    }
}

// MARK: - FileValidator

private enum FileValidator {
    static func validateDownloadedFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DownloadError.fileValidationFailed("Downloaded file does not exist")
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? Int64, fileSize > 0 else {
            throw DownloadError.fileValidationFailed("Downloaded file is empty")
        }
    }
}

// MARK: - AppLocationManager

private enum AppLocationManager {
    static func determineLocation() -> AppLocation {
        let bundlePath = Bundle.main.bundlePath
        let userAppsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        let systemAppsPath = "/Applications"

        if bundlePath.hasPrefix(systemAppsPath) {
            return .systemApplications
        } else if bundlePath.hasPrefix(userAppsPath) {
            return .userApplications
        } else {
            return .other(bundlePath)
        }
    }

    static func handleLocationIfNeeded(
        currentLocation: AppLocation,
        relocationHandler: Downloader.RelocationHandler?,
        relocationErrorHandler: Downloader.RelocationErrorHandler?
    ) async {
        switch currentLocation {
        case .systemApplications,
             .userApplications:
            Log.info("App is in Applications folder - Location: \(currentLocation)")
        case let .other(path):
            Log.warn("App is not in Applications folder - Current Path: \(path)")
            await handleRelocation(relocationHandler: relocationHandler, relocationErrorHandler: relocationErrorHandler)
        }
    }

    private static func handleRelocation(
        relocationHandler: Downloader.RelocationHandler?,
        relocationErrorHandler: Downloader.RelocationErrorHandler?
    ) async {
        do {
            let shouldMove = await askUserForRelocation(relocationHandler: relocationHandler)
            guard shouldMove else {
                Log.info("User declined app relocation")
                return
            }

            try await relocateApplication()
        } catch {
            Log.error("Failed to relocate application: \(error.localizedDescription)")
            await showRelocationError(error, relocationErrorHandler: relocationErrorHandler)
        }
    }

    private static func askUserForRelocation(relocationHandler: Downloader.RelocationHandler?) async -> Bool {
        if let customHandler = relocationHandler {
            return await customHandler()
        }
        return await defaultAskUserForRelocation()
    }

    @MainActor
    private static func defaultAskUserForRelocation() async -> Bool {
        let alert = NSAlert()
        alert.messageText = "Move to Applications Folder?"
        alert.informativeText = """
        For automatic updates to work properly, this application should be in your Applications folder.

        Would you like to move it now? The app will restart from the new location.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Keep Current Location")

        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func relocateApplication() async throws {
        let currentURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        let userAppsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        let destinationURL = userAppsURL.appendingPathComponent(currentURL.lastPathComponent)

        try FileManager.default.createDirectory(at: userAppsURL, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: currentURL, to: destinationURL)
        try NSWorkspace.shared.launchApplication(at: destinationURL, options: [.newInstance], configuration: [:])

        try await Task.sleep(nanoseconds: 2_000_000_000)
        await NSApplication.shared.terminate(nil)
    }

    private static func showRelocationError(
        _ error: Error,
        relocationErrorHandler: Downloader.RelocationErrorHandler?
    ) async {
        if let customErrorHandler = relocationErrorHandler {
            await customErrorHandler(error)
        } else {
            await defaultShowRelocationError(error)
        }
    }

    @MainActor
    private static func defaultShowRelocationError(_ error: Error) async {
        let alert = NSAlert()
        alert.messageText = "Failed to Move Application"
        alert.informativeText = """
        Could not automatically move the application to the Applications folder.

        Please manually drag the app to your Applications folder for automatic updates to work.

        Error: \(error.localizedDescription)
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - AppLocation

public enum AppLocation: CustomStringConvertible, Sendable {
    case systemApplications, userApplications, other(String)

    public var description: String {
        switch self {
        case .systemApplications: "/Applications"
        case .userApplications: "~/Applications"
        case let .other(path): path
        }
    }

    public var isInApplicationsFolder: Bool {
        switch self {
        case .systemApplications,
             .userApplications: true
        case .other: false
        }
    }
}

// MARK: - DownloadError

public enum DownloadError: LocalizedError, Sendable {
    case downloadInProgress
    case invalidURL(String)
    case environmentError(String)
    case insufficientDiskSpace(available: Int64, required: Int64)
    case fileValidationFailed(String)
    case networkError(URLError)
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .downloadInProgress:
            return "A download is already in progress"
        case let .invalidURL(url):
            return "Invalid download URL: \(url)"
        case let .environmentError(message):
            return "Environment error: \(message)"
        case let .insufficientDiskSpace(available, required):
            let availableMB = available / 1_048_576
            let requiredMB = required / 1_048_576
            return "Insufficient disk space: \(availableMB)MB available, \(requiredMB)MB required"
        case let .fileValidationFailed(reason):
            return "File validation failed: \(reason)"
        case let .networkError(urlError):
            return "Network error: \(urlError.localizedDescription)"
        case let .unknown(error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - CircularBuffer

private struct CircularBuffer<T> {
    private var buffer: [T?]
    private var head = 0
    private var tail = 0
    private var _count = 0
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    var count: Int { _count }

    var elements: [T] {
        guard !isEmpty else { return [] }

        var result: [T] = []
        var index = head
        for _ in 0 ..< _count {
            if let element = buffer[index] {
                result.append(element)
            }
            index = (index + 1) % capacity
        }
        return result
    }

    var isEmpty: Bool { _count == 0 }

    mutating func append(_ element: T) {
        buffer[tail] = element
        tail = (tail + 1) % capacity

        if _count < capacity {
            _count += 1
        } else {
            head = (head + 1) % capacity
        }
    }

    mutating func clear() {
        head = 0
        tail = 0
        _count = 0
        buffer = Array(repeating: nil, count: capacity)
    }
}
