package com.ross.android.alpha

import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files

class AlphaExportsTest {
    @Test
    fun `export service writes pdf record and required footer`() {
        val rootDir = Files.createTempDirectory("ross-alpha-export").toFile()
        val exportDir = rootDir.resolve("exports")
        var capturedDraft: AlphaExportDraft? = null
        val writer = AlphaPdfWriter { file, draft ->
            capturedDraft = draft
            file.writeBytes("pdf".toByteArray())
        }
        val service = AlphaExportService(rootDir, exportDir, writer)

        val report = service.generate("chronology_report", null)

        assertTrue(rootDir.resolve(report.relativePath).exists())
        assertTrue(rootDir.resolve(report.relativePath).length() > 0)
        assertTrue(capturedDraft!!.bodyLines.any { it.contains("Generated locally for advocate review. Verify all citations.") })
    }
}
