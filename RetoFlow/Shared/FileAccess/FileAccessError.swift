import Foundation

enum FileAccessError: Error, Equatable, AppPresentableError {
    case destinationAlreadyExists(URL)
    case createDirectoryFailed(URL)
    case copyFailed(source: URL, destination: URL)
    case moveFailed(source: URL, destination: URL)
    case trashFailed(URL)
}
