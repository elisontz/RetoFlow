import Foundation

struct GenerateRenamePreviewUseCase: Sendable {
    nonisolated init() {}

    nonisolated func execute(files: [RenamableFile], rules: [RenameRule]) -> [RenamableFile] {
        var resultFiles = files

        for index in resultFiles.indices {
            var name = resultFiles[index].originalURL.deletingPathExtension().lastPathComponent
            let ext = resultFiles[index].originalURL.pathExtension
            var newExt = ext

            for rule in rules where rule.isEnabled {
                switch rule.type {
                case .replace:
                    if !rule.findText.isEmpty {
                        name = name.replacingOccurrences(of: rule.findText, with: rule.replaceText)
                    }
                case .regex:
                    if !rule.regexPattern.isEmpty,
                       let regex = try? NSRegularExpression(pattern: rule.regexPattern) {
                        let range = NSRange(name.startIndex..<name.endIndex, in: name)
                        name = regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: rule.replaceText)
                    }
                case .remove:
                    switch rule.removeType {
                    case .range:
                        if name.count >= rule.removeStart {
                            let startIndex = name.index(name.startIndex, offsetBy: max(0, rule.removeStart - 1))
                            let endIndex = name.index(startIndex, offsetBy: min(rule.removeLength, name.distance(from: startIndex, to: name.endIndex)))
                            name.removeSubrange(startIndex..<endIndex)
                        }
                    case .wildcard:
                        if !rule.removeText.isEmpty {
                            let escaped = NSRegularExpression.escapedPattern(for: rule.removeText)
                            let regexPattern = escaped
                                .replacingOccurrences(of: "\\*", with: ".*")
                                .replacingOccurrences(of: "\\?", with: ".")

                            if let regex = try? NSRegularExpression(pattern: regexPattern) {
                                let range = NSRange(name.startIndex..<name.endIndex, in: name)
                                name = regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: "")
                            }
                        }
                    case .after:
                        if !rule.removeText.isEmpty, let range = name.range(of: rule.removeText) {
                            name = String(name[..<range.upperBound])
                        }
                    case .before:
                        if !rule.removeText.isEmpty, let range = name.range(of: rule.removeText) {
                            name = String(name[range.lowerBound...])
                        }
                    case .filename:
                        name = ""
                    }
                case .prefix:
                    name = rule.prefixText + name
                case .suffix:
                    name = name + rule.suffixText
                case .sequence:
                    let number = rule.sequenceStart + index
                    let format = "%0\(rule.sequencePadding)d"
                    let seqStr = String(format: format, number)
                    name = rule.sequencePosition == .start ? seqStr + name : name + seqStr
                case .caseChange:
                    switch rule.caseConversion {
                    case .lowercase: name = name.lowercased()
                    case .uppercase: name = name.uppercased()
                    case .titleCase: name = name.capitalized
                    }
                case .extensionChange:
                    if !rule.newExtension.isEmpty {
                        newExt = rule.newExtension
                    }
                }
            }

            resultFiles[index].newFilename = newExt.isEmpty ? name : "\(name).\(newExt)"
        }

        return resultFiles
    }
}
