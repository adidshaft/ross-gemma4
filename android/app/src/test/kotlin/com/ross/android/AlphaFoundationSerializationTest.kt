package com.ross.android

import com.google.gson.Gson
import com.ross.android.alpha.AlphaSourceRef
import org.junit.Assert.assertEquals
import org.junit.Test

class AlphaFoundationSerializationTest {
    private val gson = Gson()

    @Test
    fun `source ref round trips through json`() {
        val sourceRef = AlphaSourceRef(
            caseId = "case-001",
            documentId = "doc-001",
            documentTitle = "Impugned Notice",
            pageNumber = 2,
            paragraphRange = "¶1",
            textSnippet = "Inspection grounds and compliance window.",
            ocrConfidence = 0.91,
        )

        val encoded = gson.toJson(sourceRef)
        val decoded = gson.fromJson(encoded, AlphaSourceRef::class.java)

        assertEquals(sourceRef, decoded)
        assertEquals("Impugned Notice p. 2", decoded.label)
    }
}
