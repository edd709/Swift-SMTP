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

import Foundation

/// Represents an email that can be sent through an `SMTP` instance.
public struct Mail {
	/// A UUID for the mail.
	public let uuid = UUID().uuidString

	/// El `User` remitente.
	public let from: User

	/// Lista de destinatarios principales (`to`).
	public let to: [User]

	/// Lista de destinatarios en copia (`cc`). Por defecto vacío.
	public let cc: [User]

	/// Lista de destinatarios en copia oculta (`bcc`). Por defecto vacío.
	public let bcc: [User]

	/// Asunto del correo. Por defecto vacío.
	public let subject: String

	/// Texto en **formato plano** del correo. Por defecto vacío.
	public let text: String

	/// **NUEVO PARÁMETRO**: Texto en **formato HTML** del correo. Por defecto `nil`.
	/// Si está presente, el contenido se incluirá como alternativa (multipart/alternative)
	/// junto con la versión en texto plano.
	public let html: String?

	/// Lista de adjuntos. Por defecto vacío.
	public let attachments: [Attachment]

	/// Adjunto que se usará como alternativa (por ejemplo, HTML). Internamente gestionado.
	public let alternative: Attachment?

	/// Encabezados adicionales para el correo. Claves en mayúsculas y se sobreescriben si se repiten.
	/// Por defecto vacío. No se consideran `CONTENT-TYPE`, `CONTENT-DISPOSITION`, `CONTENT-TRANSFER-ENCODING`.
	public let additionalHeaders: [String: String]

	/// message-id https://tools.ietf.org/html/rfc5322#section-3.6.4
	public var id: String {
		return "<\(uuid).Swift-SMTP@\(hostname)>"
	}

	/// Hostname del correo remitente.
	public var hostname: String {
		let fullEmail = from.email
		#if swift(>=4.2)
		let atIndex = fullEmail.firstIndex(of: "@")
		#else
		let atIndex = fullEmail.index(of: "@")
		#endif
		let hostStart = fullEmail.index(after: atIndex!)
		return String(fullEmail[hostStart...])
	}

	/// Inicializa un `Mail`.
	///
	/// - Parameters:
	///   - from: Remitente.
	///   - to: Lista de destinatarios principales.
	///   - cc: Lista de destinatarios en copia. Por defecto vacío.
	///   - bcc: Lista de destinatarios en copia oculta. Por defecto vacío.
	///   - subject: Asunto. Por defecto vacío.
	///   - text: Texto en formato plano. Por defecto vacío.
	///   - html: **NUEVO**. Texto en formato HTML. Por defecto `nil`.
	///   - attachments: Lista de adjuntos. Si hay varios adjuntos marcados como
	///     alternativa a texto plano, solo el último se usa como `alternative`.
	///   - additionalHeaders: Encabezados adicionales. Por defecto vacío.
	public init(from: User,
				to: [User],
				cc: [User] = [],
				bcc: [User] = [],
				subject: String = "",
				text: String = "",
				html: String? = nil,                 // <--- NUEVO PARÁMETRO
				attachments: [Attachment] = [],
				additionalHeaders: [String: String] = [:]) {
		self.from = from
		self.to = to
		self.cc = cc
		self.bcc = bcc
		self.subject = subject
		self.text = text
		self.html = html
		// Se determinan "alternative" y la lista final de adjuntos
		let (alt, finalAttachments) = Mail.getAlternative(attachments, html: html)
		self.alternative = alt
		self.attachments = finalAttachments

		self.additionalHeaders = additionalHeaders
	}

	/// Retorna una tupla con el adjunto de tipo "alternative" (HTML) y la lista de adjuntos sin ese "alternative".
	///
	/// - Parameters:
	///   - attachments: Lista inicial de adjuntos.
	///   - html: Texto en HTML (si existe).
	///
	/// - Returns: `(Attachment?, [Attachment])` El adjunto alternativo y la lista de adjuntos filtrada.
	private static func getAlternative(_ attachments: [Attachment],
									   html: String?) -> (Attachment?, [Attachment]) {
		// Si el usuario proporciona html, creamos un Attachment HTML
		// y removemos cualquier otro que sea "alternative".
		if let htmlContent = html {
			// Filtramos los adjuntos que no sean "alternative"
			let filtered = attachments.filter { !$0.isAlternative }
			// Creamos un nuevo Attachment HTML
			let newHTMLAttachment = Attachment(htmlContent: htmlContent,
											   alternative: true)
			return (newHTMLAttachment, filtered)
		} else {
			// No hay html adicional, mantenemos la lógica previa:
			// se busca el último adjunto "alternative" si lo hubiera.
			var reversed: [Attachment] = attachments.reversed()
			#if swift(>=4.2)
			let index = reversed.firstIndex(where: { $0.isAlternative })
			#else
			let index = reversed.index(where: { $0.isAlternative })
			#endif
			if let index = index {
				return (reversed.remove(at: index), reversed.reversed())
			}
			return (nil, attachments)
		}
	}

	private var headersDictionary: [String: String] {
		var dictionary = [String: String]()
		dictionary["MESSAGE-ID"] = id
		dictionary["DATE"] = Date().smtpFormatted
		dictionary["FROM"] = from.mime
		dictionary["TO"] = to.map { $0.mime }.joined(separator: ", ")

		if !cc.isEmpty {
			dictionary["CC"] = cc.map { $0.mime }.joined(separator: ", ")
		}

		dictionary["SUBJECT"] = subject.mimeEncoded ?? ""
		dictionary["MIME-VERSION"] = "1.0 (Swift-SMTP)"

		for (key, value) in additionalHeaders {
			let keyUppercased = key.uppercased()
			if  keyUppercased != "CONTENT-TYPE" &&
				keyUppercased != "CONTENT-DISPOSITION" &&
				keyUppercased != "CONTENT-TRANSFER-ENCODING" {
				dictionary[keyUppercased] = value
			}
		}

		return dictionary
	}

	var headersString: String {
		return headersDictionary.map { (key, value) in
			return "\(key): \(value)"
		}.joined(separator: CRLF)
	}

	var hasAttachment: Bool {
		return !attachments.isEmpty || alternative != nil
	}
}

extension Mail {
	/// Representa un usuario (remitente o destinatario).
	public struct User {
		/// Nombre visible (opcional).
		public let name: String?

		/// Correo electrónico.
		public let email: String

		/// Inicializa un `User`.
		///
		/// - Parameters:
		///   - name: Nombre a mostrar (opcional).
		///   - email: Dirección de correo del usuario.
		public init(name: String? = nil, email: String) {
			self.name = name
			self.email = email
		}

		var mime: String {
			if let name = name, let nameEncoded = name.mimeEncoded {
				return "\(nameEncoded) <\(email)>"
			} else {
				return email
			}
		}
	}
}

extension DateFormatter {
	static let smtpDateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss ZZZ"
		return formatter
	}()
}

extension Date {
	var smtpFormatted: String {
		return DateFormatter.smtpDateFormatter.string(from: self)
	}
}
