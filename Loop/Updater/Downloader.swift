//
//  Downloader.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import AppKit
import Foundation
import Scribe

@Loggable
final class Downloader: NSObject {
    // MARK: - Properties

    private let config: UpdaterConfig

    private var urlSession: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private weak var progressHandler: AnyObject?
    private weak var completionHandler: AnyObject?
    private var progressClosure: ((UpdateProgress) -> ())?
    private var completionClosure: ((Result<URL, Error>) -> ())?
    private(set) var downloadState: DownloadState = .idle
    private var performanceTracker: PerformanceTracker = .init()

    private lazy var paths: SystemPaths = .init()

    // MARK: - Initialization

    init(config: UpdaterConfig) {
        self.config = config
        super.init()
    }

    deinit {
        downloadTask?.cancel()
        downloadTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    // MARK: - Public Interface

    func downloadUpdate(
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

        log.info("Starting download - URL: \(manifest.downloadUrl), Version: \(manifest.version)")

        do {
            try FileManager.default.createDirectory(at: paths.patchworkDirectory, withIntermediateDirectories: true)
            setupDownload(url: downloadURL, progress: progress, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }

    func cancel() {
        log.info("Cancelling download")
        downloadState = .cancelled
        downloadTask?.cancel()
        // Cancel any pending operations and clean up immediately
        Task { @MainActor in
            await cleanup()
        }
    }

    // MARK: - Private Implementation

    private func setupDownload(
        url: URL,
        progress: @escaping (UpdateProgress) -> (),
        completion: @escaping (Result<URL, Error>) -> ()
    ) {
        downloadState = .downloading
        progressClosure = progress
        completionClosure = completion
        performanceTracker.reset()

        let sessionConfig = SessionConfigurationFactory.create(from: config.networkConfig)
        urlSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        downloadTask = urlSession?.downloadTask(with: url)
        downloadTask?.resume()
    }

    private nonisolated func handleDownloadCompletion(at location: URL, originalURL: URL) {
        log.info("Download completed - Temp Location: \(location.path)")

        var finalURL: URL

        do {
            finalURL = try FileOperations.moveDownloadedFile(
                from: location,
                originalURL: originalURL,
                to: SystemPaths().patchworkDirectory
            )
            try FileValidator.validateDownloadedFile(at: finalURL)
        } catch {
            handleError(error)
            return
        }

        // Now that the file has been moved synchronously, we can launch a task to complete the update.

        Task {
            do {
                try await handleCompletion(with: finalURL)
            } catch {
                handleError(error)
            }
        }
    }

    private func handleCompletion(with url: URL) async throws {
        downloadState = .completed
        completionClosure?(.success(url))
        await cleanup()
    }

    private func handleError(_ error: Error) {
        downloadState = .failed
        completionClosure?(.failure(error))
        Task { await cleanup() }
    }

    private func cleanup() async {
        downloadTask?.cancel()
        downloadTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        progressClosure = nil
        completionClosure = nil
        performanceTracker.reset()
    }
}

// MARK: URLSessionDownloadDelegate

extension Downloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let httpResponse = downloadTask.response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            handleError(DownloadError.networkError(.init(URLError.Code(rawValue: httpResponse.statusCode))))
            return
        }

        guard let originalURL = downloadTask.originalRequest?.url else {
            handleError(DownloadError.unknown(NSError(domain: "MissingOriginalURL", code: -1)))
            return
        }

        handleDownloadCompletion(at: location, originalURL: originalURL)
    }

    nonisolated func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            guard self.downloadState == .downloading else { return }

            let progress = self.performanceTracker.updateProgress(
                bytesWritten: bytesWritten,
                totalBytesWritten: totalBytesWritten,
                totalBytesExpectedToWrite: totalBytesExpectedToWrite
            )

            self.progressClosure?(progress)
        }
    }

    nonisolated func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }

        Task { @MainActor in
            guard self.downloadState == .downloading else { return }

            log.error("Download failed: \(error.localizedDescription)")

            let downloadError: DownloadError = (error as? URLError).map(DownloadError.networkError) ?? .unknown(error)
            self.handleError(downloadError)
        }
    }
}

// MARK: - DownloadState

enum DownloadState {
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
    private var lastProgressUpdate: Date?
    private var speedSamples: CircularBuffer<Double> = .init(capacity: 5)

    mutating func reset() {
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

        // Update speed calculation
        if let lastUpdate = lastProgressUpdate {
            let timeDelta = now.timeIntervalSince(lastUpdate)
            if timeDelta > 0.5 { // Update every 500ms
                let speed = Double(bytesWritten) / timeDelta / 1_048_576 // MB/s
                speedSamples.append(speed)
                lastProgressUpdate = now
            }
        } else {
            lastProgressUpdate = now
        }

        let downloadSpeed = calculateAverageSpeed()
        let estimatedTimeRemaining = calculateETA(speed: downloadSpeed, remainingBytes: totalBytesExpectedToWrite - totalBytesWritten)

        return UpdateProgress(
            phase: .downloading,
            percentage: percentage,
            bytesDownloaded: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite,
            estimatedTimeRemaining: estimatedTimeRemaining,
            downloadSpeed: downloadSpeed
        )
    }

    private func calculateAverageSpeed() -> Double? {
        let samples = speedSamples.elements
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0, +) / Double(samples.count)
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

// MARK: - SessionConfigurationFactory

private enum SessionConfigurationFactory {
    static func create(from networkConfig: UpdaterConfig.NetworkConfig) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default

        config.timeoutIntervalForRequest = networkConfig.timeout
        config.timeoutIntervalForResource = networkConfig.timeout * 2
        config.allowsCellularAccess = networkConfig.allowsCellularAccess

        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 1

        return config
    }
}

// MARK: - FileOperations

@Loggable(style: .static)
private enum FileOperations {
    static func moveDownloadedFile(from tempLocation: URL, originalURL: URL, to loopDir: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: tempLocation.path) else {
            log.error("Downloaded file does not exist at \(tempLocation.path)")
            throw DownloadError.fileValidationFailed("File doesn't exist at temporary download directory")
        }

        // Preserve original filename instead of renaming to "LoopUpdate.zip"
        let originalFilename = originalURL.lastPathComponent
        let finalURL = loopDir.appendingPathComponent(originalFilename)
        let tempFinalURL = loopDir.appendingPathComponent("\(originalFilename).tmp")

        log.info("Moving downloaded file - From: \(tempLocation.path), To: \(finalURL.path), Original: \(originalURL.absoluteString)")

        // Move to Application Support/Loop/Loop.zip.tmp
        try? FileManager.default.removeItem(at: tempFinalURL)
        try FileManager.default.moveItem(at: tempLocation, to: tempFinalURL)

        // Rename to to Application Support/Loop/Loop.zip
        try? FileManager.default.removeItem(at: finalURL)
        try FileManager.default.moveItem(at: tempFinalURL, to: finalURL)

        log.info("File moved successfully - Final Location: \(finalURL.path), Filename: \(finalURL.lastPathComponent)")

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

// MARK: - DownloadError

enum DownloadError: LocalizedError, Sendable {
    case downloadInProgress
    case invalidURL(String)
    case environmentError(String)
    case insufficientDiskSpace(available: Int64, required: Int64)
    case fileValidationFailed(String)
    case networkError(URLError)
    case unknown(Error)

    var errorDescription: String? {
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
    private var buffer: [T] = []
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
    }

    var elements: [T] { buffer }

    mutating func append(_ element: T) {
        buffer.append(element)
        if buffer.count > capacity {
            buffer.removeFirst()
        }
    }

    mutating func clear() {
        buffer.removeAll()
    }
}
