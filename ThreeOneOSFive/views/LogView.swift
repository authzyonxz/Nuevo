import SwiftUI

struct LogView: View {
    @ObservedObject var appLog = AppLog.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appLanguage) private var language
    @State private var copied = false

    private var importantLogs: [ImportantLog] {
        appLog.entries.compactMap(ImportantLog.init(entry:))
    }

    private var shareText: String {
        var lines: [String] = []
        lines.append("3105 Important Log")
        lines.append("iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) — \(AppInfo.machineName)")
        lines.append("Generated: \(Date())")
        lines.append("")
        lines.append(contentsOf: importantLogs.map { "[\($0.timestamp)] \($0.detail)" })
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            Group {
                if importantLogs.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: AppTheme.emptyIconSize, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(language.text("logs.empty_title"))
                            .font(.title3.bold())
                        Text(language.text("logs.empty_message"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(32)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(importantLogs) { item in
                                    importantLogCard(item)
                                        .id(item.id)
                                }
                            }
                            .padding(AppTheme.pageInset)
                        }
                        .onChange(of: importantLogs.count) { _ in
                            guard let last = importantLogs.last else { return }
                            if reduceMotion {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .background(AppTheme.consoleBackground.ignoresSafeArea())
            .navigationTitle(language.text("logs.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(language.text("logs.clear"), role: .destructive) { appLog.clear() }
                        .disabled(importantLogs.isEmpty)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = shareText
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .disabled(importantLogs.isEmpty)
                    .accessibilityLabel(language.text("logs.copy"))

                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(importantLogs.isEmpty)
                    .accessibilityLabel(language.text("logs.share"))
                }
            }
        }
    }

    private func importantLogCard(_ item: ImportantLog) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.kind.icon)
                .font(.headline)
                .foregroundStyle(color(for: item.kind))
                .frame(width: 30, height: 30)
                .background(color(for: item.kind).opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(language.text(item.kind.titleKey))
                        .font(.subheadline.weight(.bold))
                    Spacer(minLength: 8)
                    Text(item.timestamp)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Text(item.detail)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(color(for: item.kind).opacity(0.22), lineWidth: 0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(language.text("accessibility.log_entry", 0, item.detail))
    }

    private func color(for kind: ImportantLog.Kind) -> Color {
        switch kind {
        case .starting: return .blue
        case .success: return .green
        case .failure: return .red
        case .container: return .orange
        }
    }
}

private struct ImportantLog: Identifiable {
    enum Kind {
        case starting, success, failure, container

        var titleKey: String {
            switch self {
            case .starting: return "logs.event_starting"
            case .success: return "logs.event_success"
            case .failure: return "logs.event_failure"
            case .container: return "logs.event_container"
            }
        }

        var icon: String {
            switch self {
            case .starting: return "play.fill"
            case .success: return "checkmark.shield.fill"
            case .failure: return "xmark.octagon.fill"
            case .container: return "shippingbox.fill"
            }
        }
    }

    let id = UUID()
    let timestamp: String
    let detail: String
    let kind: Kind

    init?(entry: String) {
        let lower = entry.lowercased()

        let parts = entry.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        if parts.count >= 3, parts[0].contains("T") {
            timestamp = "\(parts[0]) \(parts[1])"
            detail = String(parts[2]).replacingOccurrences(of: "[3105] ", with: "")
        } else {
            timestamp = ""
            detail = entry.replacingOccurrences(of: "[3105] ", with: "")
        }

        if lower.contains("manual exploit start") || lower.contains("stage 1/2") || lower.contains("starting…") {
            kind = .starting
        } else if lower.contains("failed") || lower.contains("could not resolve") || lower.contains("unavailable") || lower.contains("not active") {
            kind = .failure
        } else if lower.contains("manual exploit success") || lower.contains("complete") || lower.contains("sandbox escaped") || lower.contains("sandbox access active") || lower.contains("kernel access active") || lower.contains("access check ok") {
            kind = .success
        } else if lower.contains("container")
                    || lower.contains("mha-c2")
                    || lower.contains("mcm")
                    || lower.contains("resolution")
                    || lower.contains("metadata scan")
                    || lower.contains("access check") {
            kind = .container
        } else {
            return nil
        }
    }
}
