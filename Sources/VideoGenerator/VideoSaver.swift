//
//  VideoSaver.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/04.
//

import UIKit

final class VideoSaver: NSObject {
    var continuation: CheckedContinuation<Void, Error>?
    func save(destination: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            UISaveVideoAtPathToSavedPhotosAlbum(destination.path, self, #selector(video(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }

    @objc private func video(
        _ videoPath: String?,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        defer {
            continuation = nil
        }
        if let error = error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }
}
