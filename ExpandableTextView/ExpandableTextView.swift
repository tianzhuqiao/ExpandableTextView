import UIKit

typealias LineIndexTuple = (line: CTLine, index: Int)
/**
 * The delegate of ExpandableTextView.
 */
public protocol ExpandableTextViewDelegate: NSObjectProtocol {
    func willExpandTextView(_ textView: ExpandableTextView)
    func didExpandTextView(_ textView: ExpandableTextView)
    func willCollapseTextView(_ textView: ExpandableTextView)
    func didCollapseTextView(_ textView: ExpandableTextView)

    func expandableTextView(_ textView: ExpandableTextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool
    func expandableTextView(_ textView: ExpandableTextView, shallUpdateHeight: Bool)
}

/**
 * ExpandableTextView
 */
open class ExpandableTextView: UITextView, UITextViewDelegate {
    public enum TextReplacementType {
        case character
        case word
    }

    /// The delegate of ExpandableTextView
    weak open var delegateExppanable: ExpandableTextViewDelegate?

    /// Set 'true' if the label should be collapsed or 'false' for expanded.
    @IBInspectable open var collapsed: Bool = true {
        didSet {
            super.attributedText = (collapsed) ? self.collapsedText : self.expandedText
        }
    }

    /// Set 'true' if the label can be expanded or 'false' if not.
    /// The default value is 'true'.
    @IBInspectable open var shouldExpand: Bool = true

    /// Set 'true' if the label can be collapsed or 'false' if not.
    /// The default value is 'false'.
    @IBInspectable open var shouldCollapse: Bool = false

    open override var font: UIFont? {
        didSet {
            if let font = font {
                self.collapsedAttributedLink = collapsedAttributedLink.copyWithAddedFontAttribute(font)
                self.expandedAttributedLink = expandedAttributedLink.copyWithAddedFontAttribute(font)
                self.ellipsis = ellipsis.copyWithAddedFontAttribute(font)
            }
        }
    }

    open var lessText: String = "Less" {
        didSet {
            let less = NSMutableAttributedString(string: lessText)
            let linkRange = less.mutableString.range(of: lessText)
            less.addAttribute(NSAttributedString.Key.link, value: "flytask://less", range: linkRange)
            less.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: linkRange)
            expandedAttributedLink = less
        }
    }

    open var moreText: String = "More" {
        didSet {
            let more = NSMutableAttributedString(string: moreText)
            let linkRange = more.mutableString.range(of: moreText)
            more.addAttribute(NSAttributedString.Key.link, value: "flytask://more", range: linkRange)
            more.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: linkRange)
            collapsedAttributedLink = more
        }
    }
    /// Set the link name (and attributes) that is shown when collapsed.
    /// The default value is "More". Cannot be nil.
    open var collapsedAttributedLink: NSAttributedString!
    
    /// Set the link name (and attributes) that is shown when expanded.
    /// The default value is "Less". Can be nil.
    open var expandedAttributedLink: NSAttributedString!

    /// Set the ellipsis that appears just after the text and before the link.
    /// The default value is "...". Can be nil.
    open var ellipsis: NSAttributedString!

    open var textReplacementType: TextReplacementType = .word

    private var collapsedText: NSAttributedString?
    private var linkHighlighted: Bool = false
    private var linkRect: CGRect?
    private var collapsedNumberOfLines: NSInteger = 0
    private var expandedLinkPosition: NSTextAlignment?
    private var collapsedLinkTextRange: NSRange?
    private var expandedLinkTextRange: NSRange?

    open var numberOfLines: Int = 0 {
        didSet {
            collapsedNumberOfLines = numberOfLines
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        self.commonInit()
    }

    open override var text: String? {
        set(text) {
            if let text = text {
                DispatchQueue.main.async {
                    let size = self.bounds.size
                    self.attributedText = NSAttributedString(string: text)
                    let newSize = self.sizeThatFits(CGSize(width: size.width, height: CGFloat.greatestFiniteMagnitude))
                    if size.height != newSize.height {
                        self.delegateExppanable?.expandableTextView(self, shallUpdateHeight: true)
                    }
                }
            } else {
                self.attributedText = nil
            }
        }
        get {
            return self.attributedText?.string
        }
    }

    private func updateText() {
        if let attributedText = fullAttributedText?.copyWithAddedFontAttribute(font!).copyWithParagraphAttribute(font!),
            attributedText.length > 0 {
            self.collapsedText = getCollapsedText(for: attributedText, link: (linkHighlighted) ? collapsedAttributedLink.copyWithHighlightedColor() : self.collapsedAttributedLink)
            self.expandedText = getExpandedText(for: attributedText, link: (linkHighlighted) ? expandedAttributedLink?.copyWithHighlightedColor() : self.expandedAttributedLink)
            super.attributedText = (self.collapsed) ? self.collapsedText : self.expandedText
        } else {
            self.expandedText = nil
            self.collapsedText = nil
            super.attributedText = nil
        }
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        // update the text based on the width
        updateText()
    }
    open private(set) var expandedText: NSAttributedString?

    private var fullAttributedText: NSAttributedString?
    open override var attributedText: NSAttributedString? {
        set(attributedText) {
            fullAttributedText = attributedText
            updateText()
        }
        get {
            return super.attributedText
        }
    }

    public func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL.scheme == "flytask" {
            if URL.absoluteString == "flytask://less" {
                delegateExppanable?.willCollapseTextView(self)
                collapsed = true
                delegateExppanable?.didCollapseTextView(self)
            } else {
                delegateExppanable?.willExpandTextView(self)
                collapsed = false
                delegateExppanable?.didExpandTextView(self)
            }
            return false
        }
        return delegateExppanable?.expandableTextView(self, shouldInteractWith: URL, in: characterRange, interaction: interaction) ?? true
    }

    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let glyphIndex = self.layoutManager.glyphIndex(for: point, in: self.textContainer)

        //Ensure the glyphIndex actually matches the point and isn't just the closest glyph to the point
        let glyphRect = self.layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: self.textContainer)

        if glyphIndex < self.textStorage.length,
           glyphRect.contains(point),
           self.textStorage.attribute(NSAttributedString.Key.link, at: glyphIndex, effectiveRange: nil) != nil {

            return self
        } else {
            return nil
        }
    }
}

// MARK: Privates
extension ExpandableTextView {

    private func commonInit() {
        self.delegate = self
        isScrollEnabled = false
        dataDetectorTypes = .all
        isUserInteractionEnabled = true
        isSelectable = true
        isEditable = false
        self.textContainer.lineBreakMode = .byClipping
        self.lessText = "Less"
        self.moreText = "More"
        collapsedNumberOfLines = numberOfLines
        ellipsis = NSAttributedString(string: "...")
    }

    private func textReplaceWordWithLink(_ lineIndex: LineIndexTuple, text: NSAttributedString, linkName: NSAttributedString) -> NSAttributedString {
        let lineText = text.text(for: lineIndex.line)
        var lineTextWithLink = lineText
        (lineText.string as NSString).enumerateSubstrings(in: NSRange(location: 0, length: lineText.length), options: [.byWords, .reverse]) { (word, subRange, enclosingRange, stop) -> Void in
            let lineTextWithLastWordRemoved = lineText.attributedSubstring(from: NSRange(location: 0, length: subRange.location))
            let lineTextWithAddedLink = NSMutableAttributedString(attributedString: lineTextWithLastWordRemoved)
            if let ellipsis = self.ellipsis {
                lineTextWithAddedLink.append(ellipsis)
                if let font = self.font {
                    lineTextWithAddedLink.append(NSAttributedString(string: " ", attributes: [.font: font]))
                }
            }
            lineTextWithAddedLink.append(linkName)
            let fits = self.textFitsWidth(lineTextWithAddedLink)
            if fits {
                lineTextWithLink = lineTextWithAddedLink
                let lineTextWithLastWordRemovedRect = lineTextWithLastWordRemoved.boundingRect(for: self.frame.size.width)
                let wordRect = linkName.boundingRect(for: self.frame.size.width)
                let width = lineTextWithLastWordRemoved.string == "" ? self.frame.width : wordRect.size.width
                self.linkRect = CGRect(x: lineTextWithLastWordRemovedRect.size.width, y: self.font!.lineHeight * CGFloat(lineIndex.index), width: width, height: wordRect.size.height)
                stop.pointee = true
            }
        }
        return lineTextWithLink
    }

    private func textReplaceWithLink(_ lineIndex: LineIndexTuple, text: NSAttributedString, linkName: NSAttributedString) -> NSAttributedString {
        let lineText = text.text(for: lineIndex.line)
        let lineTextTrimmedNewLines = NSMutableAttributedString()
        lineTextTrimmedNewLines.append(lineText)
        let nsString = lineTextTrimmedNewLines.string as NSString
        let range = nsString.rangeOfCharacter(from: CharacterSet.newlines)
        if range.length > 0 {
            lineTextTrimmedNewLines.replaceCharacters(in: range, with: "")
        }
        let linkText = NSMutableAttributedString()
        if let ellipsis = self.ellipsis {
            linkText.append(ellipsis)
            if let font = self.font {
                linkText.append(NSAttributedString(string: " ", attributes: [.font: font]))
            }
        }
        linkText.append(linkName)

        let lengthDifference = lineTextTrimmedNewLines.string.composedCount - linkText.string.composedCount
        let truncatedString = lineTextTrimmedNewLines.attributedSubstring(
            from: NSMakeRange(0, lengthDifference >= 0 ? lengthDifference : lineTextTrimmedNewLines.string.composedCount))
        let lineTextWithLink = NSMutableAttributedString(attributedString: truncatedString)
        lineTextWithLink.append(linkText)
        return lineTextWithLink
    }

    private func getExpandedText(for text: NSAttributedString?, link: NSAttributedString?) -> NSAttributedString? {
        guard let text = text else { return nil }
        let expandedText = NSMutableAttributedString()
        expandedText.append(text)
        if let link = link, textWillBeTruncated(expandedText) {
            let spaceOrNewLine = expandedLinkPosition == nil ? "  " : "\n"
            expandedText.append(NSAttributedString(string: "\(spaceOrNewLine)"))
            expandedText.append(NSMutableAttributedString(string: "\(link.string)", attributes: link.attributes(at: 0, effectiveRange: nil)).copyWithAddedFontAttribute(font!))
            expandedLinkTextRange = NSMakeRange(expandedText.length - link.length, link.length)
        }

        return expandedText
    }

    private func getCollapsedText(for text: NSAttributedString?, link: NSAttributedString) -> NSAttributedString? {
        guard let text = text else { return nil }
        let lines = text.lines(for: frame.size.width)
        if collapsedNumberOfLines > 0 && collapsedNumberOfLines < lines.count {
            let lastLineRef = lines[collapsedNumberOfLines-1] as CTLine
            var lineIndex: LineIndexTuple?
            var modifiedLastLineText: NSAttributedString?

            if self.textReplacementType == .word {
                lineIndex = findLineWithWords(lastLine: lastLineRef, text: text, lines: lines)
                if let lineIndex = lineIndex {
                    modifiedLastLineText = textReplaceWordWithLink(lineIndex, text: text, linkName: link)
                }
            } else {
                lineIndex = (lastLineRef, collapsedNumberOfLines - 1)
                if let lineIndex = lineIndex {
                    modifiedLastLineText = textReplaceWithLink(lineIndex, text: text, linkName: link)
                }
            }

            if let lineIndex = lineIndex, let modifiedLastLineText = modifiedLastLineText {
                let collapsedLines = NSMutableAttributedString()
                for index in 0..<lineIndex.index {
                    collapsedLines.append(text.text(for:lines[index]))
                }
                collapsedLines.append(modifiedLastLineText)

                collapsedLinkTextRange = NSRange(location: collapsedLines.length - link.length, length: link.length)
                return collapsedLines
            } else {
                return nil
            }
        }
        return text
    }

    private func findLineWithWords(lastLine: CTLine, text: NSAttributedString, lines: [CTLine]) -> LineIndexTuple {
        var lastLineRef = lastLine
        var lastLineIndex = collapsedNumberOfLines - 1
        var lineWords = spiltIntoWords(str: text.text(for: lastLineRef).string as NSString)
        while false {//lineWords.count < 2 && lastLineIndex > 0 {
            lastLineIndex -=  1
            lastLineRef = lines[lastLineIndex] as CTLine
            lineWords = spiltIntoWords(str: text.text(for: lastLineRef).string as NSString)
        }
        return (lastLineRef, lastLineIndex)
    }

    private func spiltIntoWords(str: NSString) -> [String] {
        var strings: [String] = []
        str.enumerateSubstrings(in: NSRange(location: 0, length: str.length), options: [.byWords, .reverse]) { (word, subRange, enclosingRange, stop) -> Void in
            if let unwrappedWord = word {
                strings.append(unwrappedWord)
            }
            if strings.count > 1 { stop.pointee = true }
        }
        return strings
    }

    private func textFitsWidth(_ text: NSAttributedString) -> Bool {
        return (text.boundingRect(for: frame.size.width).size.height <= font!.lineHeight) as Bool
    }

    private func textWillBeTruncated(_ text: NSAttributedString) -> Bool {
        let lines = text.lines(for: frame.size.width)
        return collapsedNumberOfLines > 0 && collapsedNumberOfLines < lines.count
    }
}

// MARK: Convenience Methods

private extension NSAttributedString {
    func hasFontAttribute() -> Bool {
        guard !self.string.isEmpty else { return false }
        let font = self.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        return font != nil
    }

    func copyWithParagraphAttribute(_ font: UIFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.05
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 0.0
        paragraphStyle.minimumLineHeight = font.lineHeight
        paragraphStyle.maximumLineHeight = font.lineHeight

        let copy = NSMutableAttributedString(attributedString: self)
        let range = NSRange(location: 0, length: copy.length)
        copy.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        copy.addAttribute(.baselineOffset, value: font.pointSize * 0.08, range: range)
        return copy
    }

    func copyWithAddedFontAttribute(_ font: UIFont) -> NSAttributedString {
        if !hasFontAttribute() {
            let copy = NSMutableAttributedString(attributedString: self)
            copy.addAttribute(.font, value: font, range: NSRange(location: 0, length: copy.length))
            return copy
        }
        return self.copy() as! NSAttributedString
    }

    func copyWithHighlightedColor() -> NSAttributedString {
        let alphaComponent = CGFloat(0.5)
        let baseColor: UIColor = (self.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)?.withAlphaComponent(alphaComponent) ??
            UIColor.black.withAlphaComponent(alphaComponent)
        let highlightedCopy = NSMutableAttributedString(attributedString: self)
        let range = NSRange(location: 0, length: highlightedCopy.length)
        highlightedCopy.removeAttribute(.foregroundColor, range: range)
        highlightedCopy.addAttribute(.foregroundColor, value: baseColor, range: range)
        return highlightedCopy
    }

    func lines(for width: CGFloat) -> [CTLine] {
        let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude))
        let frameSetterRef: CTFramesetter = CTFramesetterCreateWithAttributedString(self as CFAttributedString)
        let frameRef: CTFrame = CTFramesetterCreateFrame(frameSetterRef, CFRange(location: 0, length: 0), path.cgPath, nil)

        let linesNS: NSArray  = CTFrameGetLines(frameRef)
        let linesAO: [AnyObject] = linesNS as [AnyObject]
        let lines: [CTLine] = linesAO as! [CTLine]

        return lines
    }

    func text(for lineRef: CTLine) -> NSAttributedString {
        let lineRangeRef: CFRange = CTLineGetStringRange(lineRef)
        let range: NSRange = NSRange(location: lineRangeRef.location, length: lineRangeRef.length)
        return self.attributedSubstring(from: range)
    }

    func boundingRect(for width: CGFloat) -> CGRect {
        return self.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                 options: .usesLineFragmentOrigin, context: nil)
    }
}

extension String {
    var composedCount : Int {
        var count = 0
        enumerateSubstrings(in: startIndex..<endIndex, options: .byComposedCharacterSequences) { _,_,_,_  in count += 1 }
        return count
    }
}
