/*
 * The MIT License
 *
 * Copyright 2017 Stephan Knitelius.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation

import Kitura
import LoggerAPI
import SwiftyJSON

class AllRemoteOriginMiddleware: RouterMiddleware {
    func handle(request: RouterRequest, response: RouterResponse, next: @escaping () -> Swift.Void) {
        response.headers["Access-Control-Allow-Origin"] = "*"
        next()
    }
}

public final class MessageController {
    public let messagePath = "message"
    public let messageDatabase: MessageDatabase
    public let router = Router()

    public init(backend: MessageDatabase) {
        self.messageDatabase = backend
        setupRoutes()
    }

    private func setupRoutes() {
        router.all("/api/message/*", middleware: BodyParser())
        router.get("/api/messages/", handler: onGetMessages)
        router.get("/api/message/:id", handler: onGetByID)
        router.put("/api/message/", handler: onAddMessage)
    }

    private func onGetMessages(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        messageDatabase.getAll() {
            messages, error in
            do {
                guard error == nil else {
                    try response.status(.badRequest).end()
                    Log.error(error.debugDescription)
                    return
                }
                if let messages = messages {
                    let json = JSON(messages.toDictionary())
                    try response.status(.OK).send(json: json).end()
                } else {
                    try response.status(.internalServerError).end()
                }
            } catch {
                Log.error("Communication error")
            }
        }
    }

    private func onGetByID(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        guard let id = request.parameters["id"] else {
            response.status(.badRequest)
            Log.error("Request does not contain ID")
            return
        }

        messageDatabase.get(id: id) {
            message, error in
            do {
                guard error == nil else {
                    try response.status(.badRequest).end()
                    Log.error(error.debugDescription)
                    return
                }
                if let message = message {
                    let result = JSON(message.toDictionary())
                    try response.status(.OK).send(json: result).end()
                } else {
                    Log.warning("Could not find the item")
                    response.status(.badRequest)
                    return
                }
            } catch {
                Log.error("Communication error")
            }
        }
    }

    private func onAddMessage(request: RouterRequest, response: RouterResponse, next: () -> Void) {
        guard let body = request.body else {
            response.status(.badRequest)
            Log.error("No body found in request")
            return
        }

        guard case let .json(json) = body else {
            response.status(.badRequest)
            Log.error("Body contains invalid JSON")
            return
        }

        let message = json["message"].stringValue
        let usr = json["usr"].stringValue

        guard message != "",
              usr != "" else {
            response.status(.badRequest)
            Log.error("Request missing contents.")
            return
        }

        messageDatabase.add(message: message, user: usr) {
            newMessage, error in
            do {
                guard error == nil else {
                    try response.status(.badRequest).end()
                    Log.error(error.debugDescription)
                    return
                }

                guard let newMessage = newMessage else {
                    try response.status(.internalServerError).end()
                    Log.error("Item not found")
                    return
                }

                let result = JSON(newMessage.toDictionary())
                Log.info("\(message) for \(usr) added.")
                do {
                    try response.status(.OK).send(json: result).end()
                } catch {
                    Log.error("Error sending response")
                }
            } catch {
                Log.error("Communication error")
            }
        }
    }

}
