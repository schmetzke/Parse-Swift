//
//  ParseFileManager.swift
//  ParseSwift
//
//  Created by Corey Baker on 12/20/20.
//  Copyright © 2020 Parse Community. All rights reserved.
//

import Foundation

internal struct ParseFileManager {

    private var defaultDirectoryAttributes: [FileAttributeKey: Any]? {
        #if !os(macOS) || !os(Linux)
        return [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        #else
        return nil
        #endif
    }

    private var defaultDataWritingOptions: Data.WritingOptions {
        var options = Data.WritingOptions.atomic
        #if !os(macOS) || !os(Linux)
        if #available(OSX 11.0, *) {
            options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        }
        #endif
        return options
    }

    private var localSandBoxDataDirectoryPath: URL? {
        #if !os(macOS) || !os(Linux)
        return self.defaultDataDirectoryPath
        #else
        let directoryPath = NSHomeDirectory()
            .append(ParseConstants.fileManagementLibraryDirectory)
            .append(ParseConstants.fileManagementPrivateDocumentsDirectory)
            .append(ParseConstants.fileManagementDirectory)
        return createDirectoryIfNeeded(directoryPath)
        #endif
    }

    private let synchronizationQueue = DispatchQueue(label: "com.parse.file",
                                                     qos: .default,
                                                     attributes: .concurrent,
                                                     autoreleaseFrequency: .inherit,
                                                     target: nil)

    private let applicationIdentifier: String
    private let applicationGroupIdentifer: String?

    public var defaultDataDirectoryPath: URL? {
        var directoryPath: String!
        #if !os(macOS) || !os(Linux)
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        guard let directory = paths.first else {
            return nil
        }
        directoryPath = directory
        directoryPath += "\(ParseConstants.fileManagementDirectory)\(applicationIdentifier)"

        #else
        if let groupIdentifier = applicationGroupIdentifer {
            let paths = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
            guard var directory = paths.first else {
                return nil
            }
            directoryPath = directory
            directoryPath += "\(ParseConstants.fileManagementDirectory)\(applicationIdentifier)"
        } else {
            return self.localSandBoxDataDirectoryPath
        }
        #endif

        return URL(fileURLWithPath: directoryPath, isDirectory: true)
    }

    public func dataItemPathForPathComponent(_ component: String) -> URL? {
        guard var path = self.defaultDataDirectoryPath else {
            return nil
        }
        path.appendPathComponent(component)
        return path
    }

    init?() {
        if let identifier = Bundle.main.bundleIdentifier {
            applicationIdentifier = identifier
        } else {
            return nil
        }
        applicationGroupIdentifer = nil
    }

    func createDirectoryIfNeeded(_ path: String) throws {
        if !FileManager.default.fileExists(atPath: path) {
            try FileManager.default.createDirectory(atPath: path,
                                                    withIntermediateDirectories: true,
                                                    attributes: defaultDirectoryAttributes)
        }
    }

    func writeString(_ string: String, filePath: URL, completion: @escaping(Error?) -> Void) {
        synchronizationQueue.async {
            do {
                guard let data = string.data(using: .utf8) else {
                    completion(ParseError(code: .unknownError, message: "Couldn't convert string to utf8"))
                    return
                }
                try data.write(to: filePath, options: defaultDataWritingOptions)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    func writeData(_ data: Data, filePath: URL, completion: @escaping(Error?) -> Void) {
        synchronizationQueue.async {
            do {
                try data.write(to: filePath, options: defaultDataWritingOptions)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    func copyItem(_ fromPath: URL, toPath: URL, completion: @escaping(Error?) -> Void) {
        synchronizationQueue.async {
            do {
                try FileManager.default.copyItem(at: fromPath, to: toPath)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    func moveItem(_ fromPath: URL, toPath: URL, completion: @escaping(Error?) -> Void) {
        synchronizationQueue.async {
            do {
                try FileManager.default.moveItem(at: fromPath, to: toPath)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    func moveContentsOfDirectory(_ fromPath: URL, toPath: URL, completion: @escaping(Error?) -> Void) {
        synchronizationQueue.async {
            do {
                if fromPath == toPath {
                    completion(nil)
                    return
                }

                try createDirectoryIfNeeded(toPath.path)
                let contents = try FileManager.default.contentsOfDirectory(atPath: fromPath.path)
                if contents.count == 0 {
                    completion(nil)
                    return
                }
                try contents.forEach {
                    let fromFilePath = fromPath.appendingPathComponent($0)
                    let toFilePath = toPath.appendingPathComponent($0)
                    try FileManager.default.moveItem(at: fromFilePath, to: toFilePath)
                }
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    func removeDirectoryContents(_ path: URL, completion: @escaping(Error?) -> Void) {
        synchronizationQueue.async {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: path.path)
                if contents.count == 0 {
                    completion(nil)
                    return
                }
                try contents.forEach {
                    let filePath = path.appendingPathComponent($0)
                    try FileManager.default.removeItem(at: filePath)
                }
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}
