package com.ross.android.alpha

import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import java.io.File
import java.util.UUID

data class AlphaExportDraft(
    val title: String,
    val bodyLines: List<String>,
)

fun interface AlphaPdfWriter {
    fun write(file: File, draft: AlphaExportDraft)
}

class AndroidAlphaPdfWriter : AlphaPdfWriter {
    override fun write(file: File, draft: AlphaExportDraft) {
        val document = PdfDocument()
        try {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 12f }
            val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                textSize = 18f
                isFakeBoldText = true
            }
            val wrappedBody = wrapLines(draft.bodyLines, 86)
            val linesPerPage = 42
            val pages = wrappedBody.chunked(linesPerPage).ifEmpty { listOf(emptyList()) }

            pages.forEachIndexed { index, pageLines ->
                val pageInfo = PdfDocument.PageInfo.Builder(612, 792, index + 1).create()
                val page = document.startPage(pageInfo)
                var y = 56f
                if (index == 0) {
                    page.canvas.drawText(draft.title, 40f, y, titlePaint)
                    y += 28f
                }
                pageLines.forEach { line ->
                    page.canvas.drawText(line, 40f, y, paint)
                    y += 16f
                }
                document.finishPage(page)
            }

            file.outputStream().use(document::writeTo)
        } finally {
            document.close()
        }
    }
}

class AlphaExportService(
    private val rootDir: File,
    private val exportsDir: File,
    private val pdfWriter: AlphaPdfWriter = AndroidAlphaPdfWriter(),
    private val now: () -> String = ::nowIso,
) {
    fun generate(kind: String, case: AlphaCaseMatter?): AlphaExportRecord {
        exportsDir.mkdirs()
        val titleBase = case?.title ?: "Ross Report"
        val draft = buildDraft(kind, case, titleBase)
        val file = File(exportsDir, "${slug(titleBase)}-${kind}-${UUID.randomUUID().toString().take(8)}.pdf")
        pdfWriter.write(file, draft)
        return AlphaExportRecord(
            caseId = case?.id,
            title = "$titleBase ${kind.replace('_', ' ')}",
            kind = kind,
            relativePath = file.relativeTo(rootDir).path,
            createdAt = now(),
        )
    }

    internal fun buildDraft(kind: String, case: AlphaCaseMatter?, titleBase: String): AlphaExportDraft {
        val lines = buildList {
            add("Generated: ${now()}")
            add("Draft for advocate review")
            add("")
            add("Report type: ${kind.replace('_', ' ')}")
            add("")
            add("Summary")
            add(case?.summary ?: "No case selected.")
            add("")
            add("Issue highlights")
            val issueHighlights = case?.issueHighlights.orEmpty()
            if (issueHighlights.isEmpty()) {
                add("- No issue highlights available yet.")
            } else {
                issueHighlights.forEach { add("- $it") }
            }
            add("")
            add("Source references")
            val sourceRefs = case?.sourceRefs.orEmpty()
            if (sourceRefs.isEmpty()) {
                add("- No source references available yet.")
            } else {
                sourceRefs.take(6).forEach { add("- ${it.label}: ${it.detail}") }
            }
            add("")
            add("Generated locally for advocate review. Verify all citations.")
        }
        return AlphaExportDraft(title = titleBase, bodyLines = lines)
    }

    private fun slug(value: String) = value.lowercase().replace(Regex("[^a-z0-9]+"), "-").trim('-')
}

internal fun wrapLines(lines: List<String>, maxWidth: Int): List<String> = buildList {
    lines.forEach { line ->
        if (line.length <= maxWidth) {
            add(line)
            return@forEach
        }

        var remaining = line
        while (remaining.length > maxWidth) {
            val split = remaining.lastIndexOf(' ', maxWidth).takeIf { it > 0 } ?: maxWidth
            add(remaining.substring(0, split).trimEnd())
            remaining = remaining.substring(split).trimStart()
        }
        add(remaining)
    }
}
