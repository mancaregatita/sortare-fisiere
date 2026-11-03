import Foundation

/// Anunță când se schimbă ceva în folder (fișier adăugat, redenumit, șters).
final class FolderWatcher {
    let path: String
    private let queue: DispatchQueue
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?

    init(path: String, queue: DispatchQueue, onChange: @escaping () -> Void) {
        self.path = path
        self.queue = queue
        self.onChange = onChange
    }

    @discardableResult
    func start() -> Bool {
        stop()
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return false }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .extend, .link],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            self?.onChange()
        }
        src.setCancelHandler {
            close(descriptor)
        }
        source = src
        src.resume()
        return true
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
