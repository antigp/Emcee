import Foundation

public final class TestException {
    public let reason: String
    public let filePathInProject: String
    public let lineNumber: Int32

    public init(reason: String, filePathInProject: String, lineNumber: Int32) {
        self.reason = reason
        self.filePathInProject = filePathInProject
        self.lineNumber = lineNumber
    }
}
