import Foundation
import Observation

@MainActor
protocol ModelDownloadManaging: AnyObject {
    var jobs: [ModelDownloadJob] { get }
    func queueDownload(for pack: ModelPack)
    func pause(jobID: UUID)
    func resume(jobID: UUID)
}

@MainActor
@Observable
final class BackgroundModelDownloadService: NSObject, ModelDownloadManaging, URLSessionDownloadDelegate {
    var jobs: [ModelDownloadJob] = []

    @ObservationIgnored private let settingsStore: LocalSettingsStore
    @ObservationIgnored private let privacyLedger: PrivacyLedgerService
    @ObservationIgnored private let startTransfersAutomatically: Bool
    @ObservationIgnored private var resumeDataByJobID: [UUID: Data] = [:]
    @ObservationIgnored private var sourceURLByJobID: [UUID: URL] = [:]
    @ObservationIgnored private var tasksByJobID: [UUID: URLSessionDownloadTask] = [:]
    @ObservationIgnored private var jobIDByTaskIdentifier: [Int: UUID] = [:]
    @ObservationIgnored private lazy var session: URLSession = makeSession()

    init(
        settingsStore: LocalSettingsStore,
        privacyLedger: PrivacyLedgerService,
        startTransfersAutomatically: Bool
    ) {
        self.settingsStore = settingsStore
        self.privacyLedger = privacyLedger
        self.startTransfersAutomatically = startTransfersAutomatically
    }

    func queueDownload(for pack: ModelPack) {
        jobs.removeAll { $0.packTier == pack.tier && $0.phase != .completed }

        let job = ModelDownloadJob(
            packTier: pack.tier,
            plannedSize: pack.downloadSize,
            phase: .failed,
            progress: 0,
            deliveryNote: "This download path is retired. Open My assistant to finish setup with the current private assistant installer.",
            isBackgroundEligible: true
        )

        jobs.insert(job, at: 0)

        privacyLedger.recordNetwork(
            title: "Old assistant download blocked",
            detail: "Ross stopped an outdated assistant setup path before any transfer started.",
            boundary: .modelDelivery,
            dataClass: .noCaseData,
            direction: .outbound
        )
    }

    func pause(jobID: UUID) {
        guard let task = tasksByJobID[jobID] else {
            updateJob(jobID) { job in
                job.phase = .paused
                job.deliveryNote = "Transfer is paused and ready to resume on the next trusted network."
            }
            return
        }

        task.cancel { [weak self] resumeData in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                self.resumeDataByJobID[jobID] = resumeData
                self.tasksByJobID[jobID] = nil
                self.jobIDByTaskIdentifier[task.taskIdentifier] = nil
                self.updateJob(jobID) { job in
                    job.phase = .paused
                    job.deliveryNote = "Transfer paused with resume data preserved."
                }
            }
        }
    }

    func resume(jobID: UUID) {
        updateJob(jobID) { job in
            job.phase = .queued
            job.deliveryNote = "Resume requested. The pack will continue when background delivery is permitted."
        }
        startDownload(for: jobID)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.background(
            withIdentifier: "com.privateDigitalClerk.modelDelivery"
        )
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.allowsCellularAccess = !settingsStore.settings.wifiOnlyDownloads
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    private func startDownload(for jobID: UUID) {
        guard settingsStore.settings.backgroundModelDownloadsEnabled else {
            updateJob(jobID) { job in
                job.phase = .queued
                job.deliveryNote = "Background delivery is disabled in settings."
            }
            return
        }

        let task: URLSessionDownloadTask
        if let resumeData = resumeDataByJobID[jobID] {
            task = session.downloadTask(withResumeData: resumeData)
        } else if let url = sourceURLByJobID[jobID] {
            task = session.downloadTask(with: url)
        } else {
            updateJob(jobID) { job in
                job.phase = .failed
                job.deliveryNote = "Download source is unavailable."
            }
            return
        }

        tasksByJobID[jobID] = task
        jobIDByTaskIdentifier[task.taskIdentifier] = jobID
        task.resume()

        updateJob(jobID) { job in
            job.phase = .scheduled
            job.deliveryNote = "Background delivery scheduled. The transfer can resume if interrupted."
        }
    }

    private func updateJob(_ jobID: UUID, transform: (inout ModelDownloadJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == jobID }) else {
            return
        }

        transform(&jobs[index])
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else {
            return
        }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        Task { @MainActor in
            guard let jobID = self.jobIDByTaskIdentifier[downloadTask.taskIdentifier] else {
                return
            }

            self.updateJob(jobID) { job in
                job.phase = .running
                job.progress = progress
                job.deliveryNote = "Background delivery is in progress and can resume if interrupted."
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        Task { @MainActor in
            guard let jobID = self.jobIDByTaskIdentifier[downloadTask.taskIdentifier] else {
                return
            }

            self.tasksByJobID[jobID] = nil
            self.jobIDByTaskIdentifier[downloadTask.taskIdentifier] = nil
            self.resumeDataByJobID[jobID] = nil

            self.updateJob(jobID) { job in
                job.phase = .completed
                job.progress = 1
                job.deliveryNote = "Pack download completed and is ready for local preparation."
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard error != nil else {
            return
        }

        Task { @MainActor in
            guard let jobID = self.jobIDByTaskIdentifier[task.taskIdentifier] else {
                return
            }

            self.tasksByJobID[jobID] = nil
            self.jobIDByTaskIdentifier[task.taskIdentifier] = nil
            self.updateJob(jobID) { job in
                job.phase = .failed
                job.deliveryNote = "Transfer stopped before completion. Resume is available if supported by the source."
            }
        }
    }
}
