import SwiftUI
import PlainDomain
import PlainDesignSystem

/// Reading view for a note. Blocks are laid out by hand so headings, callouts,
/// ordered steps and code all get their own treatment.
struct MarkdownRenderedView: View {
    let document: MarkdownDocument
    var bodySize: CGFloat = 15
    /// Set by the reading screen so a tapped box edits the note. Left nil when
    /// the view is only being drawn (PDF export, previews).
    var onToggleTask: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(headingFont(level))
                .foregroundStyle(PlainPalette.ink)
                .padding(.top, level == 1 ? 0 : 6)

        case .paragraph(let text) where MarkdownText.isTagLine(text):
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(MarkdownText.tags(in: text), id: \.self) { tag in
                    TagChip("#" + tag)
                }
            }

        case .paragraph(let text):
            Text(MarkdownInline.attributed(text, size: bodySize, color: PlainPalette.ink))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

        case .quote(let text):
            Text(MarkdownInline.attributed(text, size: bodySize - 1, color: PlainPalette.inkSecondary, codeBackground: PlainPalette.surface))
                .lineSpacing(3)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PlainPalette.fill, in: .rect(cornerRadius: Metrics.Radius.inner, style: .continuous))

        case .tasks(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    // Only the reading screen can edit the note, so elsewhere
                    // (preview, PDF) the row is drawn rather than made a
                    // disabled button that would grey itself out.
                    if let onToggleTask {
                        Button { onToggleTask(item.line) } label: { taskRow(item) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("task-\(item.line)")
                            .accessibilityValue(item.isDone ? "done" : "open")
                    } else {
                        taskRow(item)
                    }
                }
            }

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill(PlainPalette.inkTertiary)
                            .frame(width: 4, height: 4)
                            .padding(.top, 8)
                        Text(MarkdownInline.attributed(item, size: bodySize, color: PlainPalette.ink))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .ordered(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .center, spacing: 10) {
                        Text("\(index + 1)")
                            .font(PlainFont.sans(10.5, .bold))
                            .foregroundStyle(PlainPalette.onEmphasis)
                            .frame(width: 18, height: 18)
                            .background(PlainPalette.emphasis, in: .circle)
                        Text(MarkdownInline.attributed(item, size: bodySize - 1, color: PlainPalette.ink))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .code(let code, let language):
            VStack(alignment: .leading, spacing: 8) {
                if let language {
                    Text(language.uppercased())
                        .font(PlainFont.sans(9.5, .bold))
                        .tracking(0.8)
                        .foregroundStyle(PlainPalette.onCode.opacity(0.55))
                }
                ScrollView(.horizontal) {
                    Text(code)
                        .font(PlainFont.mono(bodySize - 3.5))
                        .foregroundStyle(PlainPalette.onCode)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(PlainPalette.code, in: .rect(cornerRadius: Metrics.Radius.inner, style: .continuous))

        case .table(let header, let rows):
            TableBlock(header: header, rows: rows, bodySize: bodySize)

        case .divider:
            PlainDivider(inset: 0)
        }
    }

    private func taskRow(_ item: TaskItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                .font(.system(size: bodySize, weight: .medium))
                .foregroundStyle(item.isDone ? PlainPalette.ink : PlainPalette.inkTertiary)
                .frame(width: bodySize + 2)
            Text(MarkdownInline.attributed(item.text, size: bodySize, color: item.isDone ? PlainPalette.inkTertiary : PlainPalette.ink))
                .strikethrough(item.isDone, color: PlainPalette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: PlainFont.sans(bodySize + 8, .bold, relativeTo: .title2)
        case 2: PlainFont.sans(bodySize, .semibold, relativeTo: .headline)
        default: PlainFont.sans(bodySize - 1.5, .semibold, relativeTo: .subheadline)
        }
    }
}

/// A markdown table. Columns share the width evenly and wrap rather than
/// scroll, which suits the narrow phone layout better than a grid that slides.
private struct TableBlock: View {
    let header: [String]
    let rows: [[String]]
    let bodySize: CGFloat

    private var columns: Int { max(header.count, rows.map(\.count).max() ?? 0) }

    var body: some View {
        VStack(spacing: 0) {
            row(header, isHeader: true)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, cells in
                PlainDivider(inset: 0)
                row(cells, isHeader: false)
            }
        }
        .background(PlainPalette.fill, in: .rect(cornerRadius: Metrics.Radius.inner, style: .continuous))
    }

    private func row(_ cells: [String], isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(0..<columns, id: \.self) { index in
                Text(MarkdownInline.attributed(
                    index < cells.count ? cells[index] : "",
                    size: bodySize - 1.5,
                    color: isHeader ? PlainPalette.ink : PlainPalette.inkSecondary
                ))
                .font(isHeader ? PlainFont.sans(bodySize - 1.5, .semibold) : nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
