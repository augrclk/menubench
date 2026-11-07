// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// How many columns and rows a tile covers in the bento grid.
struct BentoSpan: Equatable {
    var columns: Int
    var rows: Int

    static let small = BentoSpan(columns: 1, rows: 1)
    static let wide = BentoSpan(columns: 2, rows: 1)
    static let large = BentoSpan(columns: 2, rows: 2)
    static let banner = BentoSpan(columns: 4, rows: 1)
}

private struct BentoSpanKey: LayoutValueKey {
    static let defaultValue = BentoSpan.small
}

extension View {
    func bentoSpan(_ span: BentoSpan) -> some View {
        layoutValue(key: BentoSpanKey.self, value: span)
    }
}

/// Packs tiles of mixed sizes into a fixed-column grid, densely: each tile
/// takes the first free slot (top to bottom, left to right) it fits in, so a
/// hidden tile never leaves a hole and small tiles back-fill gaps beside
/// large ones. Positions animate when tiles come and go.
struct BentoLayout: Layout {
    var columns: Int = Aurora.Panel.bentoColumns
    var spacing: CGFloat = Aurora.Panel.bentoSpacing
    var rowHeight: CGFloat = Aurora.Panel.bentoRow

    struct Cache {
        var slots: [(column: Int, row: Int, span: BentoSpan)] = []
        var rowCount = 0
    }

    func makeCache(subviews: Subviews) -> Cache {
        pack(subviews.map { $0[BentoSpanKey.self] })
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = pack(subviews.map { $0[BentoSpanKey.self] })
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? Aurora.Panel.contentWidth
        let rows = CGFloat(cache.rowCount)
        let height = rows > 0 ? rows * rowHeight + (rows - 1) * spacing : 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let unit = (bounds.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        for (index, subview) in subviews.enumerated() where index < cache.slots.count {
            let slot = cache.slots[index]
            let width = unit * CGFloat(slot.span.columns) + spacing * CGFloat(slot.span.columns - 1)
            let height = rowHeight * CGFloat(slot.span.rows) + spacing * CGFloat(slot.span.rows - 1)
            let origin = CGPoint(x: bounds.minX + CGFloat(slot.column) * (unit + spacing),
                                 y: bounds.minY + CGFloat(slot.row) * (rowHeight + spacing))
            subview.place(at: origin, anchor: .topLeading,
                          proposal: ProposedViewSize(width: width, height: height))
        }
    }

    private func pack(_ spans: [BentoSpan]) -> Cache {
        var occupied: [[Bool]] = []
        var cache = Cache()

        func fits(_ span: BentoSpan, column: Int, row: Int) -> Bool {
            guard column + span.columns <= columns else { return false }
            for r in row..<(row + span.rows) {
                guard r < occupied.count else { continue }
                for c in column..<(column + span.columns) where occupied[r][c] { return false }
            }
            return true
        }

        for raw in spans {
            let span = BentoSpan(columns: min(max(raw.columns, 1), columns), rows: max(raw.rows, 1))
            var row = 0
            var placed = false
            while !placed {
                for column in 0..<columns where fits(span, column: column, row: row) {
                    while occupied.count < row + span.rows {
                        occupied.append(Array(repeating: false, count: columns))
                    }
                    for r in row..<(row + span.rows) {
                        for c in column..<(column + span.columns) { occupied[r][c] = true }
                    }
                    cache.slots.append((column, row, span))
                    placed = true
                    break
                }
                row += 1
            }
        }
        cache.rowCount = occupied.count
        return cache
    }
}
