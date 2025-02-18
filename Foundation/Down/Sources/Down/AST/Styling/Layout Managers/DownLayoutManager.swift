//
//  DownLayoutManager.swift
//  Down
//
//  Created by John Nguyen on 02.08.19.
//  Copyright © 2016-2019 Down. All rights reserved.
//

#if !os(watchOS) && !os(Linux)

    #if canImport(UIKit)

        import UIKit

    #elseif canImport(AppKit)

        import AppKit

    #endif

    /// A layout manager capable of drawing the custom attributes set by the `DownStyler`.
    ///
    /// Insert this into a TextKit stack manually, or use the provided `DownTextView`.

    public class DownLayoutManager: NSLayoutManager {
        // MARK: - Graphic context

        #if canImport(UIKit)
            var context: CGContext? {
                UIGraphicsGetCurrentContext()
            }

            func push(context: CGContext) {
                UIGraphicsPushContext(context)
            }

            func popContext() {
                UIGraphicsPopContext()
            }

        #elseif canImport(AppKit)
            var context: CGContext? {
                NSGraphicsContext.current?.cgContext
            }

            func push(context _: CGContext) {
                NSGraphicsContext.saveGraphicsState()
            }

            func popContext() {
                NSGraphicsContext.restoreGraphicsState()
            }

        #endif

        // MARK: - Drawing

        override public func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
            drawCustomBackgrounds(forGlyphRange: glyphsToShow, at: origin)
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            drawCustomAttributes(forGlyphRange: glyphsToShow, at: origin)
        }

        private func drawCustomBackgrounds(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
            guard let context else { return }
            push(context: context)
            defer { popContext() }

            guard let textStorage else { return }

            let characterRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)

            textStorage.enumerateAttributes(for: .blockBackgroundColor,
                                            in: characterRange)
            { (attr: BlockBackgroundColorAttribute, blockRange) in
                let inset = attr.inset

                context.setFillColor(attr.color.cgColor)

                let allBlockColorRanges = glyphRanges(for: .blockBackgroundColor,
                                                      in: textStorage,
                                                      inCharacterRange: blockRange)

                let glyphRange = self.glyphRange(forCharacterRange: blockRange, actualCharacterRange: nil)

                enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, lineUsedRect, container, lineGlyphRange, _ in
                    let isLineStartOfBlock = allBlockColorRanges.contains {
                        lineGlyphRange.overlapsStart(of: $0)
                    }

                    let isLineEndOfBlock = allBlockColorRanges.contains {
                        lineGlyphRange.overlapsEnd(of: $0)
                    }

                    let minX = lineUsedRect.minX + container.lineFragmentPadding - inset
                    let maxX = lineRect.maxX
                    let minY = isLineStartOfBlock ? lineUsedRect.minY - inset : lineRect.minY
                    let maxY = isLineEndOfBlock ? lineUsedRect.maxY + inset : lineUsedRect.maxY
                    let blockRect = CGRect(minX: minX, minY: minY, maxX: maxX, maxY: maxY).translated(by: origin)

                    context.fill(blockRect)
                }
            }
        }

        private func drawCustomAttributes(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
            let characterRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
            drawThematicBreakIfNeeded(in: characterRange, at: origin)
            drawQuoteStripeIfNeeded(in: characterRange, at: origin)
        }

        private func drawThematicBreakIfNeeded(in characterRange: NSRange, at origin: CGPoint) {
            guard let context else { return }
            push(context: context)
            defer { popContext() }

            textStorage?.enumerateAttributes(for: .thematicBreak,
                                             in: characterRange)
            { (attr: ThematicBreakAttribute, range) in

                let firstGlyphIndex = glyphIndexForCharacter(at: range.lowerBound)

                let lineRect = lineFragmentRect(forGlyphAt: firstGlyphIndex, effectiveRange: nil)
                let usedRect = lineFragmentUsedRect(forGlyphAt: firstGlyphIndex, effectiveRange: nil)

                let lineStart = usedRect.minX + fragmentPadding(forGlyphAt: firstGlyphIndex)

                let width = lineRect.width - lineStart
                let height = lineRect.height

                let boundingRect = CGRect(x: lineStart, y: lineRect.minY, width: width, height: height)
                let adjustedLineRect = boundingRect.translated(by: origin)

                drawThematicBreak(with: context, in: adjustedLineRect, attr: attr)
            }
        }

        private func fragmentPadding(forGlyphAt glyphIndex: Int) -> CGFloat {
            let textContainer = textContainer(forGlyphAt: glyphIndex, effectiveRange: nil)
            return textContainer?.lineFragmentPadding ?? 0
        }

        private func drawThematicBreak(with context: CGContext, in rect: CGRect, attr: ThematicBreakAttribute) {
            context.setStrokeColor(attr.color.cgColor)
            context.setLineWidth(attr.thickness)
            context.move(to: CGPoint(x: rect.minX, y: rect.midY))
            context.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            context.strokePath()
        }

        private func drawQuoteStripeIfNeeded(in characterRange: NSRange, at origin: CGPoint) {
            guard let context else { return }
            push(context: context)
            defer { popContext() }

            textStorage?.enumerateAttributes(for: .quoteStripe,
                                             in: characterRange)
            { (attr: QuoteStripeAttribute, quoteRange) in

                context.setFillColor(attr.color.cgColor)

                let glyphRangeOfQuote = self.glyphRange(forCharacterRange: quoteRange, actualCharacterRange: nil)

                enumerateLineFragments(forGlyphRange: glyphRangeOfQuote) { lineRect, _, container, _, _ in
                    let locations = attr.locations.map {
                        CGPoint(x: $0 + container.lineFragmentPadding, y: 0)
                            .translated(by: lineRect.origin)
                            .translated(by: origin)
                    }

                    let stripeSize = CGSize(width: attr.thickness, height: lineRect.height)
                    self.drawQuoteStripes(with: context, locations: locations, size: stripeSize)
                }
            }
        }

        private func drawQuoteStripes(with context: CGContext, locations: [CGPoint], size: CGSize) {
            for location in locations {
                let stripeRect = CGRect(origin: location, size: size)
                context.fill(stripeRect)
            }
        }

        private func glyphRanges(for key: NSAttributedString.Key,
                                 in storage: NSTextStorage,
                                 inCharacterRange range: NSRange) -> [NSRange]
        {
            storage
                .ranges(of: key, in: range)
                .map { self.glyphRange(forCharacterRange: $0, actualCharacterRange: nil) }
                .mergeNeighbors()
        }
    }

    // MARK: - Helpers

    private extension NSRange {
        func overlapsStart(of range: NSRange) -> Bool {
            lowerBound <= range.lowerBound && upperBound > range.lowerBound
        }

        func overlapsEnd(of range: NSRange) -> Bool {
            lowerBound < range.upperBound && upperBound >= range.upperBound
        }
    }

    private extension [NSRange] {
        func mergeNeighbors() -> [Element] {
            let sorted = sorted { $0.lowerBound <= $1.lowerBound }

            let result = sorted.reduce(into: [NSRange]()) { acc, next in
                guard let last = acc.popLast() else {
                    acc.append(next)
                    return
                }

                guard last.upperBound == next.lowerBound else {
                    acc.append(contentsOf: [last, next])
                    return
                }

                acc.append(NSRange(location: last.lowerBound, length: next.upperBound - last.lowerBound))
            }

            return result
        }
    }

#endif
