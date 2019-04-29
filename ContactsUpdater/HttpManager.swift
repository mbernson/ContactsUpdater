//
//  ContactListController.swift
//  ContactsUpdater
//
//  Created by Mathijs Bernson on 29/04/2019.
//  Copyright © 2019 Q42. All rights reserved.
//

import Foundation
import Promissum

public class HttpManager {

  public typealias HTTPHeaders = [String : String]

  public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case options = "OPTIONS"
  }

  public typealias Parameters = [String : Any]

  public struct ServerError: Swift.Error {
    public let request: URLRequest
    public let response: HTTPURLResponse?
  }

  let session: URLSession

  public init(configuration: URLSessionConfiguration) {
    self.session = URLSession(configuration: configuration)
  }

  func dataRequest(
    url: URL,
    method: HTTPMethod = .get,
    body: Data? = nil,
    headers: HTTPHeaders? = nil
  ) -> Promise<Data, Error> {
    let promiseSource = PromiseSource<Data, Error>()

    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.allHTTPHeaderFields = headers
    request.httpBody = body

    let dataTask = session.dataTask(with: request) { (data, response, error) in
      do {
        if let error = error {
          throw error // Client error occurred
        }
        if let data = data, let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) {
          promiseSource.resolve(data)
          return
        } else {
          throw ServerError(request: request, response: response as? HTTPURLResponse) // Server error occurred
        }
      } catch {
        promiseSource.reject(error)
      }
    }

    dataTask.resume()

    return promiseSource.promise
  }
}
