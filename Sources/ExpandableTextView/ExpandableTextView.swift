import UIKit

/**
 * The delegate of ExpandableTextView.
 */
public protocol ExpandableTextViewDelegate: NSObjectProtocol {
    /**
     * Called when to expand the text.
     * - parameter textView: The ExpandableTextView for which the delegate call was issued.
     */
    func willExpandTextView(_ textView: ExpandableTextView)
    /**
     * Called after expanding the text.
     * - parameter textView: The ExpandableTextView for which the delegate call was issued.
     */
    func didExpandTextView(_ textView: ExpandableTextView)
    /**
     * Called when to collapse the text.
     * - parameter textView: The ExpandableTextView for which the delegate call was issued.
     */
    func willCollapseTextView(_ textView: ExpandableTextView)
    /**
     * Called after collapsing the text.
     * - parameter textView: The ExpandableTextView for which the delegate call was issued.
     */
    func didCollapseTextView(_ textView: ExpandableTextView)

    /**
     * Asks the delegate whether the specified text view allows the specified type of user interaction with the specified URL in the specified range of text.
     * - parameter textView: The ExpandableTextView for which the delegate call was issued.
     * -                       URL: The URL to be processed
     * -                       characterRange: The character range containing the URL.
     * -                       interaction: The type of interaction that is occurring
     * - returns     true if interaction with the URL should be allowed; false if interaction should not be allowed.
     */
    func expandableTextView(_ textView: ExpandableTextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool

    /**
     * Called if the height is changed after setting the text (without collapse/expand status change).
     * - parameter textView: The ExpandableTextView for which the delegate call was issued.
     */
    func expandableTextViewUpdateHeight(_ textView: ExpandableTextView)
}

public extension ExpandableTextViewDelegate {
    func willExpandTextView(_ textView: ExpandableTextView) {}
    func didExpandTextView(_ textView: ExpandableTextView) {}
    func willCollapseTextView(_ textView: ExpandableTextView) {}
    func didCollapseTextView(_ textView: ExpandableTextView) {}

    func expandableTextView(_ textView: ExpandableTextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        return true
    }
    func expandableTextViewUpdateHeight(_ textView: ExpandableTextView) {}
}

/**
 * ExpandableTextView
 */
open class ExpandableTextView: UITextView, UITextViewDelegate {
    public enum TextReplacementType {
        case character
        case word
    }
    public enum LinkPosition:String {
        case space = "  "
        case newline = "\n"
        case automatic
    }
    typealias LineIndexTuple = (line: CTLine, index: Int)

    /// The delegate of ExpandableTextView
    weak open var delegateExppanable: ExpandableTextViewDelegate?

    /// Set 'true' if the label should be collapsed or 'false' for expanded.
    @IBInspectable open var collapsed: Bool = true {
        didSet {
            super.attributedText = (collapsed) ? self.collapsedText : self.expandedText
        }
    }

    open override var font: UIFont? {
        didSet {
            if let font = font {
                _collapsedAttributedLink = _collapsedAttributedLink.copyWithAddedFontAttribute(font)
                _expandedAttributedLink = _expandedAttributedLink?.copyWithAddedFontAttribute(font)
                _ellipsis = _ellipsis?.copyWithAddedFontAttribute(font)
            }
        }
    }

    open var lessText: String? = "Less" {
        didSet {
            if let lessText = lessText, !lessText.isEmpty {
                let less = NSMutableAttributedString(string: lessText)
                expandedAttributedLink = less

            } else {
                expandedAttributedLink = nil
            }
        }
    }

    open var moreText: String = "More" {
        didSet {
            var moreStr = moreText
            if moreStr.isEmpty {
                moreStr = "More"
            }
            let more = NSMutableAttributedString(string: moreStr)
            collapsedAttributedLink = more
        }
    }

    open var ellipsisText: String? = "..." {
        didSet {
            if let ellipsisText = ellipsisText, !ellipsisText.isEmpty {
                ellipsis = NSMutableAttributedString(string: ellipsisText)

            } else {
                ellipsis = nil
            }
        }
    }

    /// Set the link name (and attributes) that is shown when collapsed.
    /// The default value is "More".
    open var collapsedAttributedLink: NSAttributedString {
        set(value) {
            let more = NSMutableAttributedString(attributedString: value)
            let range = NSRange(location: 0, length: more.length)
            more.removeAttribute(.link, range: range)
            more.addAttribute(.link, value: "etv://more", range: range)
            _collapsedAttributedLink = more
            if let font = font {
                _collapsedAttributedLink = _collapsedAttributedLink.copyWithAddedFontAttribute(font)
            }
        }
        get {
            return _collapsedAttributedLink
        }
    }
    private var _collapsedAttributedLink: NSAttributedString!

    
    /// Set the link name (and attributes) that is shown when expanded.
    /// The default value is "Less".
    open var expandedAttributedLink: NSAttributedString? {
        set(value) {
            if let value = value {
                let less = NSMutableAttributedString(attributedString: value)
                let range = NSRange(location: 0, length: less.length)
                less.removeAttribute(.link, range: range)
                less.addAttribute(.link, value: "etv://less", range: range)
                _expandedAttributedLink = less
                if let font = font {
                    _expandedAttributedLink = _expandedAttributedLink?.copyWithAddedFontAttribute(font)
                }
            } else {
                _expandedAttributedLink = nil
            }
        }
        get {
            return _expandedAttributedLink
        }
    }
    private var _expandedAttributedLink: NSAttributedString?

    /// Set the ellipsis that appears just after the text and before the link.
    /// The default value is "...".
    open var ellipsis: NSAttributedString? {
        set(value) {
            if let value = value {
                _ellipsis = value
                if let font = font {
                    _ellipsis = _ellipsis?.copyWithAddedFontAttribute(font)
                }
            } else {
                _ellipsis = nil
            }
        }
        get {
            return _ellipsis
        }
    }
    private var _ellipsis: NSAttributedString?

    open var textReplacementType: TextReplacementType = .word
    open var linkPosition: LinkPosition = .automatic

    private var collapsedText: NSAttributedString?

    open var numberOfLines: Int = 0

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
                    if abs(size.height - newSize.height) > 1 {
                        self.delegateExppanable?.expandableTextViewUpdateHeight(self)
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
        var attributedText = fullAttributedText
        if let font = self.font {
             attributedText = fullAttributedText?.copyWithAddedFontAttribute(font).copyWithParagraphAttribute(font)
        }
        if let attributedText = attributedText, attributedText.length > 0 {
            self.collapsedText = getCollapsedText(for: attributedText, link: self.collapsedAttributedLink)
            self.expandedText = getExpandedText(for: attributedText, link: self.expandedAttributedLink)
            super.attributedText = (self.collapsed) ? self.collapsedText : self.expandedText
        } else {
            self.expandedText = nil
            self.collapsedText = nil
            super.attributedText = nil
        }
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        // update the text based on the textview width
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
        if URL.scheme == "etv" {
            if URL.absoluteString == "etv://less" {
                delegateExppanable?.willCollapseTextView(self)
                collapsed = true
                delegateExppanable?.didCollapseTextView(self)
                return false
            } else if URL.absoluteString == "etv://more"  {
                delegateExppanable?.willExpandTextView(self)
                collapsed = false
                delegateExppanable?.didExpandTextView(self)
                return false
            }
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
        delegate = self
        isScrollEnabled = false
        dataDetectorTypes = .all
        isUserInteractionEnabled = true
        isSelectable = true
        isEditable = false
        textAlignment = .left
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byClipping
        lessText = "Less"
        moreText = "More"
        ellipsisText = "..."
        font = .systemFont(ofSize: 16)
    }

    private func textReplaceWordWithLink(text: NSAttributedString, linkName: NSAttributedString) -> NSAttributedString {
        var lineTextWithLink = text
        (text.string as NSString).enumerateSubstrings(in: NSRange(location: 0, length: text.length), options: [.byWords, .reverse]) { (word, subRange, enclosingRange, stop) -> Void in
            let lineTextWithLastWordRemoved = text.attributedSubstring(from: NSRange(location: 0, length: subRange.location))
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
                stop.pointee = true
            }
        }
        return lineTextWithLink
    }

    private func textReplaceWithLink(text: NSAttributedString, linkName: NSAttributedString) -> NSAttributedString {
        let lineTextTrimmedNewLines = NSMutableAttributedString()
        lineTextTrimmedNewLines.append(text)
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

    private func appendLink(for text: NSAttributedString, link: NSAttributedString?, sep: String) -> NSMutableAttributedString {
        let expandedText = NSMutableAttributedString()
        expandedText.append(text)
        if let link = link, link.length > 0 {
            // first try to add the les link in the same line
            expandedText.append(NSAttributedString(string: sep))
            expandedText.append(NSMutableAttributedString(string: "\(link.string)", attributes: link.attributes(at: 0, effectiveRange: nil)).copyWithAddedFontAttribute(font!))
        }
        return expandedText
    }

    private func appendLink(for text: NSAttributedString?, link: NSAttributedString?) -> NSMutableAttributedString? {
        guard let text = text else { return nil }
        if linkPosition == .space || linkPosition == .newline {
            return appendLink(for: text, link: link, sep: linkPosition.rawValue)
        } else {
            var expandedText = NSMutableAttributedString()
            expandedText.append(text)
            let rect = expandedText.boundingRect(for: self.bounds.width)
            expandedText = appendLink(for: text, link: link, sep: LinkPosition.space.rawValue)
            if abs(rect.height - expandedText.boundingRect(for: self.bounds.width).height) > 1 {
                expandedText = appendLink(for: text, link: link, sep: LinkPosition.newline.rawValue)
            }
            return expandedText
        }
    }

    private func getExpandedText(for text: NSAttributedString?, link: NSAttributedString?) -> NSAttributedString? {
        guard let text = text else { return nil }
        if textWillBeTruncated(text) {
            return appendLink(for: text, link: link)
        }
        return text
    }

    private func getCollapsedText(for text: NSAttributedString?, link: NSAttributedString) -> NSAttributedString? {
        guard let text = text else { return nil }
        let lines = text.lines(for: frame.size.width)
        if numberOfLines > 0 && numberOfLines < lines.count {
            let lastLineRef = lines[numberOfLines-1] as CTLine
            var lineIndex: LineIndexTuple?
            var modifiedLastLineText: NSAttributedString?

            // get the index of last line
            if self.textReplacementType == .word {
                lineIndex = findLineWithWords(lastLine: lastLineRef, text: text, lines: lines)
            } else {
                lineIndex = (lastLineRef, numberOfLines - 1)
            }
            // get the last line
            if let lineIndex = lineIndex {
                modifiedLastLineText = text.text(for: lineIndex.line)
            }

            // append the link to last line if necessary
            if linkPosition != .newline, let lastline = modifiedLastLineText {
                if self.textReplacementType == .word {
                    modifiedLastLineText = textReplaceWordWithLink(text: lastline, linkName: link)
                } else {
                    modifiedLastLineText = textReplaceWithLink(text: lastline, linkName: link)
                }
            }

            if let lineIndex = lineIndex, let modifiedLastLineText = modifiedLastLineText {
                var collapsedLines: NSMutableAttributedString? = NSMutableAttributedString()
                for index in 0..<lineIndex.index {
                    collapsedLines?.append(text.text(for:lines[index]))
                }
                collapsedLines?.append(modifiedLastLineText)
                // append the link if it hasn't be there yet
                if linkPosition == .newline {
                    collapsedLines = appendLink(for: collapsedLines, link: link)
                }

                return collapsedLines
            } else {
                return nil
            }
        }
        return text
    }

    private func findLineWithWords(lastLine: CTLine, text: NSAttributedString, lines: [CTLine]) -> LineIndexTuple {
        let lastLineRef = lastLine
        let lastLineIndex = numberOfLines - 1
        return (lastLineRef, lastLineIndex)
    }

    private func textFitsWidth(_ text: NSAttributedString) -> Bool {
        return (text.boundingRect(for: frame.size.width).size.height <= font!.lineHeight) as Bool
    }

    private func textWillBeTruncated(_ text: NSAttributedString) -> Bool {
        let lines = text.lines(for: frame.size.width)
        return numberOfLines > 0 && numberOfLines < lines.count
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
