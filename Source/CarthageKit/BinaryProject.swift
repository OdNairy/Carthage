import Foundation
import Result

/// Represents a binary dependency 
public struct BinaryProject: Equatable {
	private static let jsonDecoder = JSONDecoder()

	public var versions: [PinnedVersion: [URL]]

	public static func from(jsonData: Data) -> Result<BinaryProject, BinaryJSONError> {
		return Result<[String: String], AnyError>(attempt: { try jsonDecoder.decode([String: String].self, from: jsonData) })
			.mapError { .invalidJSON($0.error) }
			.flatMap { json -> Result<BinaryProject, BinaryJSONError> in
				var versions = [PinnedVersion: [URL]]()

				for (key, value) in json {
					let pinnedVersion: PinnedVersion
					switch SemanticVersion.from(Scanner(string: key)) {
					case .success:
						pinnedVersion = PinnedVersion(key)
					case let .failure(error):
						return .failure(BinaryJSONError.invalidVersion(error))
					}
					
					var urlStrings: [String] = []
					guard var components = URLComponents(string: value) else {
						return .failure(BinaryJSONError.invalidURL(value))
					}
					if let split = components.queryItems?.partition(by: { $0.name == "alt" }) {
						urlStrings.append(contentsOf: components.queryItems![split...].compactMap { $0.value })
						components.queryItems!.removeSubrange(split...)
						if components.queryItems!.isEmpty {
							components.queryItems = nil
						}
					}
					guard let string = components.string else {
						return .failure(BinaryJSONError.invalidURL(value))
					}
					urlStrings.append(string)
					
					var binaryURLs: [URL] = []
					for string in urlStrings {
						guard let binaryURL = URL(string: string) else {
							return .failure(BinaryJSONError.invalidURL(string))
						}
						guard binaryURL.scheme == "file" || binaryURL.scheme == "https" else {
							return .failure(BinaryJSONError.nonHTTPSURL(binaryURL))
						}
						binaryURLs.append(binaryURL)
					}
					
					versions[pinnedVersion] = binaryURLs
				}

				return .success(BinaryProject(versions: versions))
			}
	}
}
