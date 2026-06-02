import CryptoKit
import Observation
import SwiftUI
import UserNotifications
import UniformTypeIdentifiers
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

#if canImport(PDFKit)
struct AlphaPDFPreview: View {
    let document: AlphaCaseDocument
    let initialPage: Int

    private var url: URL {
        alphaAbsoluteURL(for: document.storedRelativePath)
    }

    private var canUseNativePDF: Bool {
        FileManager.default.fileExists(atPath: url.path())
            && ((PDFDocument(url: url)?.pageCount ?? 0) > 0)
    }

    var body: some View {
        RossSectionCard(title: rossLocalized("preview"), subtitle: alphaPageLabel(max(initialPage, 1))) {
            if canUseNativePDF {
                PDFRepresentedView(url: url, initialPage: initialPage)
                    .frame(minHeight: 360)
                    .rossGlassSurface(cornerRadius: 14, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3, fillOpacity: 0.8, strokeOpacity: 0.48)
            } else {
                AlphaDocumentTextPreview(document: document, initialPage: initialPage)
            }
        }
    }
}

#if canImport(UIKit)
struct PDFRepresentedView: UIViewRepresentable {
    let url: URL
    let initialPage: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
        if let document = uiView.document, document.pageCount > 0 {
            let target = document.page(at: min(max(initialPage - 1, 0), document.pageCount - 1))
            if let target {
                uiView.go(to: target)
            }
        }
    }
}
#elseif canImport(AppKit)
struct PDFRepresentedView: NSViewRepresentable {
    let url: URL
    let initialPage: Int

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = PDFDocument(url: url)
        if let document = nsView.document, document.pageCount > 0 {
            let target = document.page(at: min(max(initialPage - 1, 0), document.pageCount - 1))
            if let target {
                nsView.go(to: target)
            }
        }
    }
}
#endif
#endif

struct AlphaDocumentTextPreview: View {
    let document: AlphaCaseDocument
    let initialPage: Int

    private var sortedPages: [AlphaDocumentPage] {
        let pages = document.pages.sorted { $0.pageNumber < $1.pageNumber }
        guard !pages.isEmpty else { return [] }
        let target = max(initialPage, 1)
        if let index = pages.firstIndex(where: { $0.pageNumber == target }) {
            return Array(pages[index...]) + Array(pages[..<index])
        }
        return pages
    }

    private var fallbackText: String {
        document.extractedText?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? document.dominantSourceSnippet?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? rossLocalized("no_readable_preview")
    }

    private func previewText(for page: AlphaDocumentPage) -> String {
        guard let candidate = page.extractedText.flatMap(\.nilIfEmpty) ?? page.snippet.flatMap(\.nilIfEmpty) else {
            return fallbackText
        }
        let genericSeedSnippet = candidate.count < 80
            && candidate.localizedCaseInsensitiveContains("page \(page.pageNumber)")
        return genericSeedSnippet ? fallbackText : candidate
    }

    var body: some View {
        ScrollView {
            RossGlassGroup(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    if sortedPages.isEmpty {
                        AlphaDocumentPreviewPage(
                            pageNumber: max(initialPage, 1),
                            text: fallbackText
                        )
                    } else {
                        ForEach(sortedPages.prefix(3), id: \.pageNumber) { page in
                            AlphaDocumentPreviewPage(
                                pageNumber: page.pageNumber,
                                text: previewText(for: page)
                            )
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(minHeight: 320, maxHeight: 420)
        .rossGlassSurface(cornerRadius: 14, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3, fillOpacity: 0.8, strokeOpacity: 0.48)
    }
}

struct AlphaDocumentPreviewPage: View {
    let pageNumber: Int
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(alphaPageLabel(pageNumber))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Color.rossInk.opacity(0.52))

            Text(text)
                .font(.footnote)
                .lineSpacing(3)
                .foregroundStyle(Color.rossInk.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .rossGlassSurface(cornerRadius: 12, strokeOpacity: 0.48)
    }
}

struct AlphaImagePreview: View {
    let relativePath: String

    var body: some View {
        RossSectionCard(title: rossLocalized("preview")) {
            let url = alphaAbsoluteURL(for: relativePath)
            #if canImport(UIKit)
            if let image = UIImage(contentsOfFile: url.path()) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .rossGlassSurface(cornerRadius: 14, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3, fillOpacity: 0.8, strokeOpacity: 0.48)
            } else {
                Text(rossLocalized("image_preview_unavailable"))
            }
            #elseif canImport(AppKit)
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .rossGlassSurface(cornerRadius: 14, shadowOpacity: 0.08, shadowRadius: 8, shadowY: 3, fillOpacity: 0.8, strokeOpacity: 0.48)
            } else {
                Text(rossLocalized("image_preview_unavailable"))
            }
            #else
            Text(rossLocalized("image_preview_unavailable"))
            #endif
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
