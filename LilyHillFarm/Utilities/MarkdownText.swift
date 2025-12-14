//
//  MarkdownText.swift
//  LilyHillFarm
//
//  Simple markdown renderer for chat messages
//

import SwiftUI

/// A view that renders markdown text with basic formatting support
struct MarkdownText: View {
    let content: String
    let fontSize: CGFloat
    let textColor: Color

    init(_ content: String, fontSize: CGFloat = 17, textColor: Color = .primary) {
        self.content = content
        self.fontSize = fontSize
        self.textColor = textColor
    }

    var body: some View {
        Text(parseMarkdown(content))
            .font(.system(size: fontSize))
            .foregroundColor(textColor)
    }

    /// Parse markdown and return AttributedString with formatting
    private func parseMarkdown(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)

        // Apply link formatting first [text](url)
        applyLinkFormatting(&attributedString)

        // Apply bold formatting (**text**)
        applyBoldFormatting(&attributedString)

        // Apply italic formatting (*text*)
        applyItalicFormatting(&attributedString)

        return attributedString
    }

    /// Apply bold formatting for **text**
    private func applyBoldFormatting(_ attributedString: inout AttributedString) {
        let pattern = "\\*\\*(.+?)\\*\\*"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }

        let nsString = attributedString.description as NSString
        let matches = regex.matches(in: attributedString.description, options: [], range: NSRange(location: 0, length: nsString.length))

        // Process matches in reverse to maintain correct indices
        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else { continue }

            let fullRange = match.range(at: 0)
            let contentRange = match.range(at: 1)

            guard let fullSwiftRange = Range(fullRange, in: attributedString.description),
                  let contentSwiftRange = Range(contentRange, in: attributedString.description) else {
                continue
            }

            // Get the content without the ** markers
            let boldText = String(attributedString.description[contentSwiftRange])

            // Find the position in the AttributedString
            if let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: fullRange.location),
               let endIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: fullRange.location + fullRange.length) {

                // Remove the full match (including **)
                attributedString.removeSubrange(startIndex..<endIndex)

                // Insert the bold text
                var boldAttributed = AttributedString(boldText)
                boldAttributed.font = .system(size: fontSize, weight: .semibold)
                attributedString.insert(boldAttributed, at: startIndex)
            }
        }
    }

    /// Apply link formatting for [text](url)
    private func applyLinkFormatting(_ attributedString: inout AttributedString) {
        let pattern = "\\[(.+?)\\]\\((.+?)\\)"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }

        let nsString = attributedString.description as NSString
        let matches = regex.matches(in: attributedString.description, options: [], range: NSRange(location: 0, length: nsString.length))

        // Process matches in reverse to maintain correct indices
        for match in matches.reversed() {
            guard match.numberOfRanges > 2 else { continue }

            let fullRange = match.range(at: 0)
            let textRange = match.range(at: 1)
            let urlRange = match.range(at: 2)

            guard let fullSwiftRange = Range(fullRange, in: attributedString.description),
                  let textSwiftRange = Range(textRange, in: attributedString.description),
                  let urlSwiftRange = Range(urlRange, in: attributedString.description) else {
                continue
            }

            // Get the link text and URL
            let linkText = String(attributedString.description[textSwiftRange])
            let urlString = String(attributedString.description[urlSwiftRange])

            // Find the position in the AttributedString
            if let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: fullRange.location),
               let endIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: fullRange.location + fullRange.length),
               let url = URL(string: urlString) {

                // Remove the full match (including markdown syntax)
                attributedString.removeSubrange(startIndex..<endIndex)

                // Insert the link text with URL
                var linkAttributed = AttributedString(linkText)
                linkAttributed.link = url
                linkAttributed.foregroundColor = .blue
                linkAttributed.underlineStyle = .single
                attributedString.insert(linkAttributed, at: startIndex)
            }
        }
    }

    /// Apply italic formatting for *text*
    private func applyItalicFormatting(_ attributedString: inout AttributedString) {
        // Match single asterisk but not double (already handled by bold)
        let pattern = "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }

        let nsString = attributedString.description as NSString
        let matches = regex.matches(in: attributedString.description, options: [], range: NSRange(location: 0, length: nsString.length))

        // Process matches in reverse to maintain correct indices
        for match in matches.reversed() {
            guard match.numberOfRanges > 1 else { continue }

            let fullRange = match.range(at: 0)
            let contentRange = match.range(at: 1)

            guard let fullSwiftRange = Range(fullRange, in: attributedString.description),
                  let contentSwiftRange = Range(contentRange, in: attributedString.description) else {
                continue
            }

            // Get the content without the * markers
            let italicText = String(attributedString.description[contentSwiftRange])

            // Find the position in the AttributedString
            if let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: fullRange.location),
               let endIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: fullRange.location + fullRange.length) {

                // Remove the full match (including *)
                attributedString.removeSubrange(startIndex..<endIndex)

                // Insert the italic text
                var italicAttributed = AttributedString(italicText)
                italicAttributed.font = .system(size: fontSize).italic()
                attributedString.insert(italicAttributed, at: startIndex)
            }
        }
    }
}

// MARK: - AttributedString Extension
extension AttributedString {
    func index(_ i: Index, offsetByCharacters offset: Int) -> Index? {
        // Convert to string to perform offset calculation
        let str = String(self.characters)
        guard let stringIndex = str.index(str.startIndex, offsetBy: offset, limitedBy: str.endIndex) else {
            return nil
        }

        // Convert string index back to AttributedString index
        let characterOffset = str.distance(from: str.startIndex, to: stringIndex)
        var currentIndex = self.startIndex

        for _ in 0..<characterOffset {
            guard currentIndex < self.endIndex else {
                return nil
            }
            currentIndex = self.index(afterCharacter: currentIndex)
        }

        return currentIndex
    }
}

// MARK: - Preview
struct MarkdownText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 20) {
            MarkdownText("This is **bold** text")
            MarkdownText("This is *italic* text")
            MarkdownText("This is **bold** and *italic* text")
            MarkdownText("Cow 2011 was **bred** on June 10, 2025 via AI")
            MarkdownText("**Warning**: This is important")
            MarkdownText("Check out [this link](https://www.example.com)")
            MarkdownText("Visit [Lily Hill Farm](https://app.lilyhillcattle.com) for more info")
        }
        .padding()
    }
}
