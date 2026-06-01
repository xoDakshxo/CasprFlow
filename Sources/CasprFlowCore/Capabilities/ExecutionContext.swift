import Foundation

public struct ExecutionContext: Sendable {
    public let rawText: String
    public let frontmostAppBundleID: String?
    public var priorResults: [CapabilityResult]
    public let clarify: @Sendable (String) async -> String?
    public let confirm: @Sendable (String) async -> Bool

    public init(
        rawText: String,
        frontmostAppBundleID: String? = nil,
        priorResults: [CapabilityResult] = [],
        clarify: @escaping @Sendable (String) async -> String? = { _ in nil },
        confirm: @escaping @Sendable (String) async -> Bool = { _ in false }
    ) {
        self.rawText = rawText
        self.frontmostAppBundleID = frontmostAppBundleID
        self.priorResults = priorResults
        self.clarify = clarify
        self.confirm = confirm
    }
}
