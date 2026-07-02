//
//  LyricTimelineView+Actions.swift
//  MuseAmp
//
//  Created by qaq on 14/4/2026.
//

import UIKit

// MARK: - Actions

extension LyricTimelineView {
    func seekToLine(at row: Int) {
        guard let timeline = currentTimeline(),
              case let .line(index, _, _) = items[row],
              timeline.lines.indices.contains(index)
        else { return }
        let time = timeline.lines[index].time
        environment.playbackController.seek(to: time)
        environment.playbackController.play()
    }

    func makeLineContextMenu(at row: Int) -> UIMenu? {
        let lineIndex: Int
        let lineText: String
        var lineTime: TimeInterval?
        var allowedInteractionTypes: Set<LyricLineMenuProvider.InteractionType> = [
            .copyLine, .copyAllLyrics, .selectAndCopy,
        ]

        switch items[row] {
        case let .line(index, text, _):
            lineIndex = index
            lineText = text
            if let timeline = currentTimeline(), timeline.lines.indices.contains(index) {
                lineTime = timeline.lines[index].time
                allowedInteractionTypes.insert(.playFromLine)
            }
        case let .staticLine(index, text):
            lineIndex = index
            lineText = text
        case .spacer, .message:
            return nil
        }

        let selection = makeSelectionContext(preferredLineIndex: lineIndex)
        return lineMenuProvider.menu(context: .init(
            allowedInteractionTypes: allowedInteractionTypes,
            lineText: lineText,
            lineTime: lineTime,
            allLines: selection.lines,
            selectedLineIndex: selection.selectedIndex,
        ))
    }

    func presentLyricSelectionSheet(lyrics: [String], activeIndex: Int?) {
        guard !lyrics.isEmpty else { return }
        guard let viewController = sequence(first: self as UIResponder, next: \.next)
            .compactMap({ $0 as? UIViewController })
            .first
        else { return }
        guard viewController.presentedViewController == nil else { return }

        let controller = LyricSelectionSheetViewController(lyrics: lyrics, activeIndex: activeIndex)
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .formSheet
        if let sheet = nav.sheetPresentationController {
            sheet.prefersGrabberVisible = true
        }
        viewController.present(nav, animated: true)
    }

    private func currentTimeline() -> LyricTimeline? {
        renderedTimeline
    }

    private struct LyricSelectionContext {
        let lines: [String]
        let selectedIndex: Int?
    }

    /// Builds the non-empty lyric lines handed to the selection sheet, tracking
    /// where `preferredLineIndex` lands after empty lines are filtered out so the
    /// sheet pre-selects the pressed line, not a shifted one.
    private func makeSelectionContext(preferredLineIndex: Int?) -> LyricSelectionContext {
        var lines: [String] = []
        var selectedIndex: Int?
        for item in items {
            let lineIndex: Int
            let rawText: String
            switch item {
            case let .line(index, text, _):
                lineIndex = index
                rawText = text
            case let .staticLine(index, text):
                lineIndex = index
                rawText = text
            case .spacer, .message:
                continue
            }
            let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if lineIndex == preferredLineIndex {
                selectedIndex = lines.count
            }
            lines.append(text)
        }
        return LyricSelectionContext(lines: lines, selectedIndex: selectedIndex)
    }
}
