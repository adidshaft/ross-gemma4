package com.ross.android.alpha

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AlphaSourceRoutingTest {
    @Test
    fun `source routing clamps page and reports missing document safely`() {
        val refs = listOf(
            AlphaSourceRef(
                caseId = "case-1",
                documentId = "doc-1",
                documentTitle = "Impugned Notice",
                pageNumber = 2,
                textSnippet = "Inspection grounds",
            )
        )

        val resolved = AlphaSourceNavigator.resolve(
            document = null,
            refs = refs,
            requestedPage = 9,
        )

        assertEquals(2, resolved.resolvedPage)
        assertTrue(resolved.fallbackMessage?.contains("not available on the device", ignoreCase = true) == true)
    }
}
