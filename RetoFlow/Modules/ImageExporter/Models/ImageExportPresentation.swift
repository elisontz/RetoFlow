import Foundation

struct ExportAlertPresentation: Sendable {
    let message: String
}

struct ExportCompletionPresentation: Sendable {
    let alertMessage: String
    let debugSummary: String
}
