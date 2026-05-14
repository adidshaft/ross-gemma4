package com.ross.android.alpha

import android.content.Context
import android.net.Uri
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

internal data class AlphaCopiedImport(
    val document: AlphaCaseDocument,
    val sourceRef: AlphaSourceRef,
)

internal object AlphaImportPipeline {
    fun copyDocument(
        context: Context,
        rootDir: File,
        targetCaseId: String,
        caseFolder: File,
        uri: Uri,
        extractionMode: AlphaExtractionMode,
        inferPdfPageCount: (File) -> Int,
    ): AlphaCopiedImport? {
        val extension = context.contentResolver.getType(uri)?.let {
            MimeTypeMap.getSingleton().getExtensionFromMimeType(it)
        } ?: uri.lastPathSegment?.substringAfterLast('.', "") ?: "bin"
        val target = File(caseFolder, "${UUID.randomUUID()}.$extension")
        val copied = runCatching {
            context.contentResolver.openInputStream(uri).use { input ->
                FileOutputStream(target).use { output -> input?.copyTo(output) ?: error("Missing input stream") }
            }
        }.isSuccess
        if (!copied) return null

        val kind = when (extension.lowercase()) {
            "pdf" -> AlphaDocumentKind.Pdf
            "png", "jpg", "jpeg", "heic" -> AlphaDocumentKind.Image
            "txt", "md" -> AlphaDocumentKind.Text
            else -> AlphaDocumentKind.Unknown
        }
        val pageCount = if (kind == AlphaDocumentKind.Pdf) inferPdfPageCount(target) else 1
        val seedSnippet = when (kind) {
            AlphaDocumentKind.Text -> runCatching { target.readText().replace(Regex("\\s+"), " ").take(180) }.getOrNull()
            AlphaDocumentKind.Image -> "Imported image page. Ross is reading the text on this page."
            AlphaDocumentKind.Pdf -> "Imported PDF. Ross is reading the pages now."
            AlphaDocumentKind.Unknown -> "Imported source reference."
        }
        val documentId = UUID.randomUUID().toString()
        val document = AlphaCaseDocument(
            id = documentId,
            title = uri.lastPathSegment?.substringBeforeLast('.') ?: "Imported document",
            fileName = uri.lastPathSegment ?: target.name,
            kind = kind,
            storedRelativePath = target.relativeTo(rootDir).path,
            pageCount = pageCount,
            fileStatus = AlphaFileStatus.Copied,
            ocrStatus = when (kind) {
                AlphaDocumentKind.Text -> AlphaOcrStatus.NativeText
                AlphaDocumentKind.Image, AlphaDocumentKind.Pdf -> AlphaOcrStatus.Placeholder
                AlphaDocumentKind.Unknown -> AlphaOcrStatus.Placeholder
            },
            extractionStatus = when (kind) {
                AlphaDocumentKind.Text -> AlphaDocumentExtractionStatus.Complete
                AlphaDocumentKind.Image, AlphaDocumentKind.Pdf -> AlphaDocumentExtractionStatus.Running
                AlphaDocumentKind.Unknown -> AlphaDocumentExtractionStatus.NotStarted
            },
            extractedText = if (kind == AlphaDocumentKind.Text) seedSnippet else null,
            indexingStatus = when (kind) {
                AlphaDocumentKind.Text -> AlphaIndexingStatus.Indexed
                AlphaDocumentKind.Image, AlphaDocumentKind.Pdf -> AlphaIndexingStatus.Extracting
                AlphaDocumentKind.Unknown -> AlphaIndexingStatus.NotStarted
            },
            dominantSourceSnippet = seedSnippet,
            lastIndexedAt = if (kind == AlphaDocumentKind.Text) nowIso() else null,
            pages = (1..pageCount).map { page ->
                AlphaDocumentPage(
                    pageNumber = page,
                    snippet = if (page == 1) seedSnippet else "Imported page $page.",
                    extractedText = if (page == 1 && kind == AlphaDocumentKind.Text) seedSnippet else null,
                    anchorText = if (page == 1) seedSnippet else null,
                    ocrConfidence = if (kind == AlphaDocumentKind.Text) 0.99 else null,
                    ocrStatus = if (kind == AlphaDocumentKind.Text) AlphaOcrStatus.NativeText else AlphaOcrStatus.Placeholder,
                    indexingStatus = if (kind == AlphaDocumentKind.Text) AlphaIndexingStatus.Indexed else AlphaIndexingStatus.Extracting,
                )
            },
            extractionRuns = listOf(
                AlphaExtractionRun(
                    caseId = targetCaseId,
                    documentId = documentId,
                    mode = extractionMode,
                    status = AlphaExtractionRunStatus.Running,
                    progressState = AlphaExtractionProgressState.AcquiringText,
                    startedAt = nowIso(),
                    pagesProcessed = 0,
                    totalPages = pageCount,
                    fieldsExtracted = 0,
                    fieldsNeedingReview = 0,
                    warnings = emptyList(),
                )
            ),
        )
        val sourceRef = AlphaSourceRef(
            caseId = targetCaseId,
            documentId = document.id,
            documentTitle = document.title,
            pageNumber = 1,
            textSnippet = document.extractedText ?: "Imported source reference",
            ocrConfidence = if (kind == AlphaDocumentKind.Text) 0.99 else null,
        )
        return AlphaCopiedImport(document, sourceRef)
    }
}
