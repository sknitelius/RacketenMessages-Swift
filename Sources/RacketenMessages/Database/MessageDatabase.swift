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
import SwiftKuery

public final class MessageDatabase {

    var connection: Connection


    public init(connection: Connection) {
        self.connection = connection

        self.connection.connect() { error in
            if let error = error {
                print("Connection to database failed: \(error)")
                return
            }

            defer {
                self.connection.closeConnection()
            }
        }

    }

    func executeQuery(query: Query, oncompletion: @escaping (QueryResult?) -> ()) {
        self.connection.connect() { error in

            guard error == nil else {
                oncompletion(nil)
                return
            }

            self.connection.execute(query: query) { result in
                defer {
                    self.connection.closeConnection()
                }
                oncompletion(result)
            }
        }
    }

    public func getAll(oncompletion: @escaping ([Message]?, Error?) -> Void) {

        let table = MessageTable()

        let select = Select(from: table)

        executeQuery(query: select) { queryResult in

            guard let result = queryResult,
                  result.success == true,
                  let resultSet = result.asResultSet else {
                oncompletion(nil, MessageError.parseError)
                return
            }

            let fields = resultToRows(resultSet: resultSet)

            guard let messages = try? fields.flatMap(Message.init(fields:)) else {
                oncompletion(nil, MessageError.parseError)
                return
            }

            oncompletion(messages, nil)
        }
    }

    public func get(id: String, oncompletion: @escaping (Message?, Error?) -> Void) {

        let table = MessageTable()

        let select = Select(from: table).where((table.id == id))

        executeQuery(query: select) { queryResult in

            guard let result = queryResult,
                  result.success == true,
                  let resultSet = result.asResultSet else {
                oncompletion(nil, MessageError.parseError)
                return
            }

            let fields = resultToRows(resultSet: resultSet)

            guard let messages = try? fields.flatMap(Message.init(fields:)) else {
                oncompletion(nil, MessageError.parseError)
                return
            }

            guard messages.count == 1 else {
                oncompletion(nil, MessageError.parseError)
                return
            }

            oncompletion(messages[0], nil)
        }
    }

    public func add(message: String, user: String,
                    oncompletion: @escaping (Message?, Error?) -> Void) {

        let table = MessageTable()

        let insert = Insert(into: table,
                            columns: [
                                    table.message,
                                    table.user
                            ],
                            values: [
                                    message,
                                    user
                            ])

        executeQuery(query: insert) { queryResult in

            guard let result = queryResult,
                  result.success == true,
                  let resultSet = result.asResultSet else {

                oncompletion(nil, MessageError.parseError)
                return
            }

            let fields = resultToRows(resultSet: resultSet)
            let msgId = fields[0]["id"] as! String

            let todoItem = Message(id: msgId,
                                   message: message,
                                   usr: user)
            oncompletion(todoItem, nil)
        }
    }
}

