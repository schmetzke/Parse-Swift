//
//  URLSession+extensions.swift
//  ParseSwift
//
//  Original file, URLSession+sync.swift, created by Florent Vilmart on 17-09-24.
//  Name change to URLSession+extensions.swift and support for sync/async by Corey Baker on 7/25/20.
//  Copyright © 2020 Parse Community. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

class ParseURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate
{

    var progress: ((Int64, Int64, Int64) -> Void)?

    init (progress: ((Int64, Int64, Int64) -> Void)? = nil) {
        super.init()
        self.progress = progress
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        progress?(bytesSent, totalBytesSent, totalBytesExpectedToSend)
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        progress = nil
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        progress?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
    }
}

extension URLSession {

    internal func makeResult<U>(responseData: Data?,
                                urlResponse: URLResponse?,
                                responseError: Error?,
                                mapper: @escaping (Data) throws -> U) -> Result<U, ParseError> {
        if let responseData = responseData {
            do {
                return try .success(mapper(responseData))
            } catch {
                let parseError = try? ParseCoding.jsonDecoder().decode(ParseError.self, from: responseData)
                return .failure(parseError ?? ParseError(code: .unknownError,
                                                         // swiftlint:disable:next line_length
                                                         message: "Error decoding parse-server response: \(error.localizedDescription)"))
            }
        } else if let responseError = responseError {
            return .failure(ParseError(code: .unknownError,
                                       message: "Unable to sync with parse-server: \(responseError)"))
        } else {
            return .failure(ParseError(code: .unknownError,
                                       // swiftlint:disable:next line_length
                                       message: "Unable to sync with parse-server: \(String(describing: urlResponse))."))
        }
    }

    internal func dataTask<U>(
        with request: URLRequest,
        mapper: @escaping (Data) throws -> U,
        completion: @escaping(Result<U, ParseError>) -> Void
    ) {

        dataTask(with: request) { (responseData, urlResponse, responseError) in
            completion(self.makeResult(responseData: responseData,
                                  urlResponse: urlResponse,
                                  responseError: responseError, mapper: mapper))
        }.resume()
    }
}

extension URLSession {

    internal func uploadTask<U>(
        with request: URLRequest,
        from data: Data?,
        mapper: @escaping (Data) throws -> U,
        completion: @escaping(Result<U, ParseError>) -> Void
    ) {

        uploadTask(with: request, from: data) { (responseData, urlResponse, responseError) in
            completion(self.makeResult(responseData: responseData,
                                  urlResponse: urlResponse,
                                  responseError: responseError, mapper: mapper))
        }.resume()
    }
/*
    internal func uploadTask<U>(
        withStreamedRequest request: URLRequest,
        mapper: @escaping (Data) throws -> U,
        completion: @escaping(Result<U, ParseError>) -> Void
    ) {

        let task = uploadTask(withStreamedRequest: request)

        /*
        { (responseData, urlResponse, responseError) in
            completion(self.makeResult(responseData: responseData,
                                  urlResponse: urlResponse,
                                  responseError: responseError, mapper: mapper))
        }.resume()*/
    }*/

    internal func downloadTask<U>(
        with request: URLRequest,
        mapper: @escaping (Data) throws -> U,
        completion: @escaping(Result<U, ParseError>) -> Void
    ) {

        downloadTask(with: request) { (_, _, _) in
            /*completion(self.makeResult(responseData: responseData,
                                  urlResponse: urlResponse,
                                  responseError: responseError, mapper: mapper))*/
        }.resume()
    }
}
