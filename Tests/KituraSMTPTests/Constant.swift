/**
 * Copyright IBM Corporation 2017
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import KituraSMTP

let junoSMTP = "smtp.juno.com"
let junoUser = "kitura-smtp@juno.com"
let gmailSMTP = "smtp.gmail.com"
let gmailUser = "kiturasmtp@gmail.com"
let password = "ibm12345"

let chainFilePath = #file.replacingOccurrences(of: "Constant.swift", with: "cert.pfx")
let chainFilePassword = "kitura"
let selfSignedCerts = true

let smtp = SMTP(hostname: "smtp.gmail.com", user: gmailUser, password: password, port: 0, chainFilePath: chainFilePath, chainFilePassword: chainFilePassword, selfSignedCerts: selfSignedCerts)

let user = User(email: gmailUser)
let from = User(name: "Dr. Light", email: gmailUser)
let to1 = User(name: "Megaman", email: gmailUser)
let to2 = User(name: "Roll", email: junoUser)

let text = "Humans and robots living together in harmony and equality. That was my ultimate wish."
let html = "<html><img src=\"http://vignette2.wikia.nocookie.net/megaman/images/4/40/StH250RobotMasters.jpg/revision/latest?cb=20130711161323\"/></html>"
let imgFilePath = #file.replacingOccurrences(of: "Constant.swift", with: "x.png")
