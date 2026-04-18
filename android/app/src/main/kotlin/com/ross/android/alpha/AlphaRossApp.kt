package com.ross.android.alpha

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalContext
import java.io.File

@Composable
fun AlphaRossApp() {
    val context = LocalContext.current.applicationContext
    val controller = remember(context) { AlphaRossController(context) }
    val backStack = remember { mutableStateListOf(controller.startRoute()) }
    val currentRoute = backStack.lastOrNull() ?: controller.startRoute()
    val rootRoute = when (currentRoute) {
        AndroidAlphaRoute.PublicLawPreview -> AndroidAlphaRoute.PublicLawPreview
        is AndroidAlphaRoute.DraftsExports -> AndroidAlphaRoute.DraftsExports(controller.selectedCaseId)
        AndroidAlphaRoute.Settings, AndroidAlphaRoute.PrivateAiSettings -> AndroidAlphaRoute.Settings
        else -> AndroidAlphaRoute.CaseList
    }

    fun push(route: AndroidAlphaRoute) {
        backStack += route
    }

    fun replaceWith(route: AndroidAlphaRoute) {
        backStack.clear()
        backStack += route
    }

    LaunchedEffect(controller.pendingRoute) {
        controller.pendingRoute?.let { route ->
            backStack += route
            controller.consumePendingRoute()
        }
    }

    BackHandler(enabled = backStack.size > 1) {
        backStack.removeLast()
    }

    when (currentRoute) {
        AndroidAlphaRoute.Onboarding -> AlphaOnboardingScreen(onContinue = {
            controller.advanceOnboarding()
            replaceWith(AndroidAlphaRoute.PrivateAiPack)
        })

        AndroidAlphaRoute.PrivateAiPack -> AlphaPackSetupScreen(
            controller = controller,
            onContinue = {
                controller.finishPackSetup()
                replaceWith(AndroidAlphaRoute.CaseList)
            },
            onSkip = {
                controller.skipPackSetup()
                replaceWith(AndroidAlphaRoute.CaseList)
            },
        )

        AndroidAlphaRoute.CaseList -> AlphaCaseListScreen(
            controller = controller,
            selectedRoot = rootRoute,
            onRootSelected = { replaceWith(it) },
            onCreateCase = { push(AndroidAlphaRoute.CreateCase) },
            onOpenCase = { caseId ->
                controller.selectedCaseId = caseId
                push(AndroidAlphaRoute.CaseWorkspace(caseId))
            },
        )

        AndroidAlphaRoute.CreateCase -> AlphaCreateCaseScreen(
            controller = controller,
            onCreated = { caseId ->
                replaceWith(AndroidAlphaRoute.CaseList)
                push(AndroidAlphaRoute.CaseWorkspace(caseId))
            },
            onBack = { backStack.removeLast() },
        )

        is AndroidAlphaRoute.CaseWorkspace -> AlphaCaseWorkspaceScreen(
            controller = controller,
            caseId = currentRoute.caseId,
            onBack = { backStack.removeLast() },
            onOpenDocuments = { push(AndroidAlphaRoute.DocumentList(currentRoute.caseId)) },
            onAskCase = { push(AndroidAlphaRoute.AskCase(currentRoute.caseId)) },
            onOpenExports = { push(AndroidAlphaRoute.DraftsExports(currentRoute.caseId)) },
            onOpenSource = { source ->
                push(AndroidAlphaRoute.DocumentViewer(source.caseId, source.documentId, source.pageNumber))
            },
        )

        is AndroidAlphaRoute.DocumentList -> AlphaDocumentListScreen(
            controller = controller,
            caseId = currentRoute.caseId,
            onBack = { backStack.removeLast() },
            onOpenDocument = { docId -> push(AndroidAlphaRoute.DocumentViewer(currentRoute.caseId, docId, 1)) },
        )

        is AndroidAlphaRoute.DocumentViewer -> AlphaDocumentViewerScreen(
            controller = controller,
            caseId = currentRoute.caseId,
            documentId = currentRoute.documentId,
            pageNumber = currentRoute.pageNumber,
            onOpenPrivateAi = { push(AndroidAlphaRoute.PrivateAiSettings) },
            onBack = { backStack.removeLast() },
        )

        is AndroidAlphaRoute.AskCase -> AlphaAskCaseScreen(
            controller = controller,
            caseId = currentRoute.caseId,
            onBack = { backStack.removeLast() },
            onOpenSource = { source ->
                push(AndroidAlphaRoute.DocumentViewer(source.caseId, source.documentId, source.pageNumber))
            },
        )

        AndroidAlphaRoute.PublicLawPreview -> AlphaPublicLawScreen(
            controller = controller,
            selectedRoot = rootRoute,
            onRootSelected = { replaceWith(it) },
        )

        is AndroidAlphaRoute.DraftsExports -> AlphaExportsScreen(
            controller = controller,
            caseId = currentRoute.caseId,
            selectedRoot = rootRoute,
            onRootSelected = { replaceWith(it) },
        )

        AndroidAlphaRoute.PrivacyLedger -> AlphaPrivacyLedgerScreen(
            controller = controller,
            onBack = { backStack.removeLast() },
        )

        AndroidAlphaRoute.Settings -> AlphaSettingsScreen(
            controller = controller,
            selectedRoot = rootRoute,
            onRootSelected = { replaceWith(it) },
            onOpenLedger = { push(AndroidAlphaRoute.PrivacyLedger) },
            onOpenPrivateAi = { push(AndroidAlphaRoute.PrivateAiSettings) },
        )

        AndroidAlphaRoute.PrivateAiSettings -> AlphaPrivateAiSettingsScreen(
            controller = controller,
            onBack = { backStack.removeLast() },
        )
    }
}

@Composable
private fun AlphaShell(
    title: String,
    showBack: Boolean = false,
    onBack: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    Scaffold(
        topBar = {
            AlphaTopBar(title = title, showBack = showBack, onBack = onBack)
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .padding(padding)
        ) {
            content()
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AlphaTopBar(title: String, showBack: Boolean, onBack: (() -> Unit)?) {
    TopAppBar(
        title = { Text(title, style = MaterialTheme.typography.titleLarge) },
        navigationIcon = {
            if (showBack && onBack != null) {
                Button(onClick = onBack, modifier = Modifier.padding(start = 12.dp)) { Text("Back") }
            }
        }
    )
}

@Composable
private fun AlphaRootStrip(selectedRoute: AndroidAlphaRoute, onSelect: (AndroidAlphaRoute) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        listOf(
            AndroidAlphaRoute.CaseList to "Cases",
            AndroidAlphaRoute.PublicLawPreview to "Public Law",
            AndroidAlphaRoute.DraftsExports(null) to "Exports",
            AndroidAlphaRoute.Settings to "Settings",
        ).forEach { (route, label) ->
            FilterChip(
                selected = selectedRoute::class == route::class,
                onClick = { onSelect(route) },
                label = { Text(label) }
            )
        }
    }
}

@Composable
private fun AlphaOnboardingScreen(onContinue: () -> Unit) {
    AlphaShell(title = "Ross") {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            AlphaHero(
                eyebrow = "Private setup",
                title = "Your case files stay on this device",
                body = "Ross is a private legal workbench. It keeps case work local, shows a visible privacy ledger, and treats every output as a draft for advocate review."
            )
            AlphaCard("What happens next", "Keep setup calm and outcome-focused.") {
                AlphaBullet("Pick a Private AI Pack that matches this device.")
                AlphaBullet("Continue setting up cases while the pack prepares in the background.")
                AlphaBullet("Reach the Privacy Ledger at any time from settings.")
            }
            Button(onClick = onContinue, modifier = Modifier.fillMaxWidth()) { Text("Continue") }
        }
    }
}

@Composable
private fun AlphaPackSetupScreen(controller: AlphaRossController, onContinue: () -> Unit, onSkip: () -> Unit) {
    AlphaShell(title = "Private AI Pack") {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            AlphaHero(
                eyebrow = "Private AI Pack",
                title = "This is the private AI brain of Ross.",
                body = "It stays on your phone. You can continue setting up cases while this downloads, and larger case analysis will be available after the Private AI Pack is ready."
            )
            AlphaCapabilityTier.values().forEach { tier ->
                AlphaSelectableCard(
                    title = tier.title,
                    body = tier.summary,
                    selected = controller.selectedTier == tier,
                    footer = "${tier.downloadSizeLabel} download • ${tier.installedSizeLabel} installed"
                ) { controller.selectedTier = tier }
            }
            Button(onClick = onContinue, modifier = Modifier.fillMaxWidth()) { Text("Continue to Case List") }
            Button(onClick = onSkip, modifier = Modifier.fillMaxWidth()) { Text("Skip for now") }
        }
    }
}

@Composable
private fun AlphaCaseListScreen(
    controller: AlphaRossController,
    selectedRoot: AndroidAlphaRoute,
    onRootSelected: (AndroidAlphaRoute) -> Unit,
    onCreateCase: () -> Unit,
    onOpenCase: (String) -> Unit,
) {
    AlphaShell(title = "Case List") {
        AlphaRootStrip(selectedRoute = selectedRoot, onSelect = onRootSelected)
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                AlphaHero(
                    eyebrow = "Case List",
                    title = "Private case matters",
                    body = "Create a case, import source documents, and move straight into a case workspace without leaving the device."
                )
            }
            item {
                Button(onClick = onCreateCase, modifier = Modifier.fillMaxWidth()) { Text("Create Case") }
            }
            items(controller.persisted.cases) { case ->
                AlphaCard(case.title, "${case.forum} • ${case.stage.name.lowercase().replaceFirstChar(Char::titlecase)}") {
                    Text(case.summary, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("${case.documents.size} docs • ${case.sourceRefs.size} source refs")
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(onClick = { onOpenCase(case.id) }) { Text("Open Case Workspace") }
                }
            }
        }
    }
}

@Composable
private fun AlphaCreateCaseScreen(controller: AlphaRossController, onCreated: (String) -> Unit, onBack: () -> Unit) {
    AlphaShell(title = "Create Case", showBack = true, onBack = onBack) {
        Column(modifier = Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            OutlinedTextField(
                value = controller.caseDraftTitle,
                onValueChange = { controller.caseDraftTitle = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Case title") },
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences)
            )
            OutlinedTextField(
                value = controller.caseDraftForum,
                onValueChange = { controller.caseDraftForum = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Forum") },
            )
            Button(
                onClick = { controller.createCase()?.let(onCreated) },
                modifier = Modifier.fillMaxWidth(),
                enabled = controller.caseDraftTitle.isNotBlank()
            ) { Text("Create") }
        }
    }
}

@Composable
private fun AlphaCaseWorkspaceScreen(
    controller: AlphaRossController,
    caseId: String,
    onBack: () -> Unit,
    onOpenDocuments: () -> Unit,
    onAskCase: () -> Unit,
    onOpenExports: () -> Unit,
    onOpenSource: (AlphaSourceRef) -> Unit,
) {
    val case = controller.persisted.cases.firstOrNull { it.id == caseId }
    AlphaShell(title = "Case Workspace", showBack = true, onBack = onBack) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            case?.let {
                AlphaHero(eyebrow = it.forum, title = it.title, body = it.summary)
                AlphaCard("Workspace actions", "Move between documents, source-backed review, and exports.") {
                    AlphaAction("Documents", "Import or open case documents.", onOpenDocuments)
                    AlphaAction("Ask Case", "Run a local, source-backed review.", onAskCase)
                    AlphaAction("Drafts / Exports", "Generate chronology, case note, or chat transcript reports.", onOpenExports)
                }
                AlphaCard("Issue highlights", "Keep the next hearing posture visible.") {
                    it.issueHighlights.forEach { item -> AlphaBullet(item) }
                }
                AlphaCard("Source chips", "Tap to jump into the referenced document page.") {
                    it.sourceRefs.take(5).forEach { ref ->
                        Button(onClick = { onOpenSource(ref) }, modifier = Modifier.fillMaxWidth()) { Text(ref.label) }
                        Text(ref.detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun AlphaDocumentListScreen(
    controller: AlphaRossController,
    caseId: String,
    onBack: () -> Unit,
    onOpenDocument: (String) -> Unit,
) {
    val case = controller.persisted.cases.firstOrNull { it.id == caseId }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) controller.importDocument(caseId, uri)
    }
    AlphaShell(title = "Documents", showBack = true, onBack = onBack) {
        Column(modifier = Modifier.fillMaxSize().padding(24.dp)) {
            Button(onClick = { launcher.launch(arrayOf("application/pdf", "image/*", "text/plain")) }, modifier = Modifier.fillMaxWidth()) {
                Text("Import Document")
            }
            Spacer(modifier = Modifier.height(16.dp))
            LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                items(case?.documents ?: emptyList()) { document ->
                    AlphaCard(document.title, "${document.kind.name} • ${document.pageCount} page(s)") {
                        Text(document.ocrStatus.name)
                        Text(document.extractedText ?: "Extracted text will appear here when available.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(onClick = { onOpenDocument(document.id) }) { Text("Open Viewer") }
                    }
                }
            }
        }
    }
}

@Composable
private fun AlphaDocumentViewerScreen(
    controller: AlphaRossController,
    caseId: String,
    documentId: String,
    pageNumber: Int?,
    onOpenPrivateAi: () -> Unit,
    onBack: () -> Unit,
) {
    val document = controller.document(caseId, documentId)
    val sourcePanel = controller.documentSourcePanel(caseId, documentId, pageNumber)
    var editingFieldId by remember(documentId) { mutableStateOf<String?>(null) }
    var draftFieldValue by remember(documentId) { mutableStateOf("") }
    var editingClassification by remember(documentId) { mutableStateOf(false) }
    AlphaShell(title = "Document Viewer", showBack = true, onBack = onBack) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            if (document == null) {
                AlphaCard("Source unavailable", "Ross could not find this document in app-private storage.") {
                    Text(
                        sourcePanel.fallbackMessage
                            ?: "The source document is unavailable, but the saved source metadata is still visible here.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                val doc = document
                val reviewCount = controller.visibleExtractedFields(caseId, documentId).count { it.needsReview }
                AlphaHero(
                    eyebrow = doc.kind.name.uppercase(),
                    title = doc.title,
                    body = "Page count: ${doc.pageCount} • OCR/indexing: ${doc.ocrStatus.name} • Extraction: ${(doc.extractionRuns.firstOrNull()?.mode?.qualityLabel ?: controller.activeExtractionMode().qualityLabel)} • Needs review: $reviewCount"
                )
                val file = controller.absoluteFile(doc.storedRelativePath).takeIf { it.exists() }
                when {
                    doc.kind == AlphaDocumentKind.Image && file != null -> {
                        BitmapFactory.decodeFile(file.absolutePath)?.let { bitmap ->
                            Image(
                                bitmap = bitmap.asImageBitmap(),
                                contentDescription = doc.title,
                                modifier = Modifier.fillMaxWidth(),
                                contentScale = ContentScale.FillWidth,
                            )
                        }
                    }

                    doc.kind == AlphaDocumentKind.Pdf && file != null -> {
                        AlphaPdfPagePreview(file = file, pageNumber = sourcePanel.resolvedPage, title = doc.title)
                    }

                    else -> {
                        AlphaCard("Preview", "Page preview or placeholder") {
                            Text("Ross is showing source metadata while a rich preview is unavailable for this file.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                AlphaCard("Extracted text", "Text available so far for this document.") {
                    Text(doc.extractedText ?: "No extracted text yet. Ross will keep source references visible even when exact highlights are still pending.")
                }
                AlphaCard(
                    "Review extracted details",
                    controller.reviewSummary(caseId, documentId)
                        ?: doc.extractionRuns.firstOrNull()?.let { run ->
                            when (run.status) {
                                AlphaExtractionRunStatus.Running, AlphaExtractionRunStatus.Queued -> "Ross is reviewing this document locally."
                                else -> "Ross found key details. Please review the uncertain ones."
                            }
                        }
                        ?: "Ross found key details. Please review the uncertain ones."
                ) {
                    Text(
                        when {
                            doc.extractionRuns.firstOrNull()?.status == AlphaExtractionRunStatus.Running -> "Ross is extracting text, checking language, and preparing source-backed fields locally."
                            else -> "Ross found key details. Please review the uncertain ones."
                        },
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(modifier = Modifier.height(12.dp))

                    doc.classification?.let { classification ->
                        AlphaCard("Document type", classification.type.name) {
                            Text("Confidence: ${if (classification.needsReview || classification.confidence < 0.64) "Needs review" else if (classification.confidence >= 0.84) "High" else "Medium"}")
                            Spacer(modifier = Modifier.height(8.dp))
                            if (editingClassification) {
                                AlphaLegalDocumentType.values().forEach { type ->
                                    Button(
                                        onClick = {
                                            controller.updateDocumentClassification(caseId, documentId, type)
                                            editingClassification = false
                                        },
                                        modifier = Modifier.fillMaxWidth(),
                                    ) { Text(type.name) }
                                    Spacer(modifier = Modifier.height(6.dp))
                                }
                            } else {
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Button(onClick = { editingClassification = true }) { Text("Edit") }
                                    Button(onClick = {
                                        controller.updateDocumentClassification(caseId, documentId, classification.type)
                                        editingClassification = false
                                    }) { Text("Accept") }
                                }
                            }
                        }
                    }

                    val reviewFields = controller.visibleExtractedFields(caseId, documentId)
                        .sortedBy { reviewPriority(it.fieldType) }
                    if (reviewFields.isEmpty()) {
                        Text("Not found yet. Ross will keep source anchors visible while local extraction improves.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    } else {
                        reviewFields.forEach { field ->
                            AlphaExtractedFieldReviewCard(
                                field = field,
                                isEditing = editingFieldId == field.id,
                                draftValue = draftFieldValue,
                                onStartEdit = {
                                    editingFieldId = field.id
                                    draftFieldValue = field.value
                                },
                                onDraftChange = { draftFieldValue = it },
                                onAccept = { controller.acceptExtractedField(caseId, documentId, field.id) },
                                onApply = {
                                    controller.applyFieldCorrection(caseId, documentId, field.id, draftFieldValue)
                                    editingFieldId = null
                                },
                                onCancel = { editingFieldId = null },
                                onIgnore = {
                                    controller.ignoreExtractedField(caseId, documentId, field.id)
                                    editingFieldId = null
                                },
                            )
                        }
                    }

                    doc.extractionFindings.filterNot { it.resolved }.take(4).forEach { finding ->
                        Spacer(modifier = Modifier.height(8.dp))
                        AlphaCard("Needs review", finding.kind.name) {
                            Text(finding.message, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }

                    controller.strongerPackMessageFor(doc)?.let { message ->
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(message, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(onClick = onOpenPrivateAi, modifier = Modifier.fillMaxWidth()) { Text("Run better extraction") }
                    }
                }
                AlphaCard("Source reference", sourcePanel.fallbackMessage ?: "If exact highlight placement is not ready, Ross shows page and snippet metadata here.") {
                    Text("Target page ${sourcePanel.resolvedPage} of ${sourcePanel.pageCount}", fontWeight = FontWeight.SemiBold)
                    Spacer(modifier = Modifier.height(8.dp))
                    val visibleRefs = if (sourcePanel.currentPageRefs.isEmpty()) sourcePanel.otherRefs.take(3) else sourcePanel.currentPageRefs
                    visibleRefs.forEach { ref ->
                        Text(ref.label, fontWeight = FontWeight.SemiBold)
                        Text(ref.detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun AlphaExtractedFieldReviewCard(
    field: AlphaExtractedLegalField,
    isEditing: Boolean,
    draftValue: String,
    onStartEdit: () -> Unit,
    onDraftChange: (String) -> Unit,
    onAccept: () -> Unit,
    onApply: () -> Unit,
    onCancel: () -> Unit,
    onIgnore: () -> Unit,
) {
    AlphaCard(field.label, field.confidenceLabel) {
        Text(field.value, fontWeight = FontWeight.SemiBold)
        Spacer(modifier = Modifier.height(6.dp))
        Text(
            if (field.needsReview) "Needs advocate review" else "Verified from source",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            style = MaterialTheme.typography.bodySmall,
        )
        Spacer(modifier = Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            field.sourceRefs.take(2).forEach { source ->
                FilterChip(
                    selected = false,
                    onClick = {},
                    label = { Text(source.label) },
                )
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        if (isEditing) {
            OutlinedTextField(
                value = draftValue,
                onValueChange = onDraftChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Edit ${field.label.lowercase()}") },
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onApply) { Text("Apply") }
                Button(onClick = onCancel) { Text("Cancel") }
            }
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onAccept) { Text("Accept") }
                Button(onClick = onStartEdit) { Text("Edit") }
                Button(onClick = onIgnore) { Text("Ignore") }
            }
        }
    }
}

private fun reviewPriority(type: AlphaExtractedLegalFieldType): Int = when (type) {
    AlphaExtractedLegalFieldType.CaseNumber -> 0
    AlphaExtractedLegalFieldType.Court -> 1
    AlphaExtractedLegalFieldType.PartyName -> 2
    AlphaExtractedLegalFieldType.Date -> 3
    AlphaExtractedLegalFieldType.NextDate -> 4
    AlphaExtractedLegalFieldType.OrderDirection -> 5
    AlphaExtractedLegalFieldType.Section -> 6
    AlphaExtractedLegalFieldType.ExhibitNumber -> 7
    AlphaExtractedLegalFieldType.Relief, AlphaExtractedLegalFieldType.Prayer -> 8
    else -> 9
}

@Composable
private fun AlphaPdfPagePreview(file: File, pageNumber: Int, title: String) {
    val bitmap = remember(file.absolutePath, pageNumber) {
        runCatching {
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                PdfRenderer(descriptor).use { renderer ->
                    if (renderer.pageCount == 0) return@use null
                    val clampedPage = (pageNumber - 1).coerceIn(0, renderer.pageCount - 1)
                    renderer.openPage(clampedPage).use { page ->
                        val width = (page.width * 1.5f).toInt().coerceAtLeast(1)
                        val height = (page.height * 1.5f).toInt().coerceAtLeast(1)
                        Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { bitmap ->
                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        }
                    }
                }
            }
        }.getOrNull()
    }

    AlphaCard("Preview", "Rendered PDF page $pageNumber") {
        if (bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = "$title page $pageNumber",
                modifier = Modifier.fillMaxWidth(),
                contentScale = ContentScale.FillWidth,
            )
        } else {
            Text("PDF preview unavailable. Ross will keep the source panel and extracted text visible instead.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun AlphaAskCaseScreen(controller: AlphaRossController, caseId: String, onBack: () -> Unit, onOpenSource: (AlphaSourceRef) -> Unit) {
    val case = controller.persisted.cases.firstOrNull { it.id == caseId }
    val draftValue = controller.askDrafts[caseId] ?: "Summarize the next hearing posture and identify the strongest source-backed issue."
    AlphaShell(title = "Ask Case", showBack = true, onBack = onBack) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            AlphaCard("Ask Case", "Source-backed local review for the selected matter.") {
                OutlinedTextField(
                    value = draftValue,
                    onValueChange = { controller.askDrafts = controller.askDrafts + (caseId to it) },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 6,
                    label = { Text("Question") }
                )
                Spacer(modifier = Modifier.height(12.dp))
                Button(onClick = { controller.askCase(caseId) }, modifier = Modifier.fillMaxWidth()) { Text("Run Local Review") }
            }
            case?.chatTurns?.firstOrNull()?.let { turn ->
                AlphaCard(turn.answerTitle, "Draft for advocate review") {
                    turn.answerSections.forEach { section -> AlphaBullet(section) }
                    Spacer(modifier = Modifier.height(12.dp))
                    turn.sourceRefs.forEach { ref ->
                        Button(onClick = { onOpenSource(ref) }, modifier = Modifier.fillMaxWidth()) { Text(ref.label) }
                        Text(ref.detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun AlphaPublicLawScreen(controller: AlphaRossController, selectedRoot: AndroidAlphaRoute, onRootSelected: (AndroidAlphaRoute) -> Unit) {
    AlphaShell(title = "Public Law") {
        AlphaRootStrip(selectedRoute = selectedRoot, onSelect = onRootSelected)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            AlphaCard("Public Law Search Preview", "Public-law search sends only a sanitized query after explicit confirmation.") {
                OutlinedTextField(
                    value = controller.publicLawDraft,
                    onValueChange = { controller.publicLawDraft = it },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 6,
                    label = { Text("Query") }
                )
                Spacer(modifier = Modifier.height(12.dp))
                Text("Do not send case IDs, filenames, OCR text, chunk text, chat history, client names, party names, phone numbers, emails, or long factual narratives.")
                Spacer(modifier = Modifier.height(12.dp))
                Button(onClick = { controller.buildPublicLawPreview() }, modifier = Modifier.fillMaxWidth()) { Text("Generate Query Preview") }
            }
            controller.publicLawPreview?.let { preview ->
                AlphaCard("Sanitized preview", preview.confirmationNote) {
                    Text(preview.query, fontWeight = FontWeight.SemiBold)
                    Spacer(modifier = Modifier.height(12.dp))
                    preview.removed.forEach { AlphaBullet(it) }
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(onClick = { controller.runPublicLawSearch() }, modifier = Modifier.fillMaxWidth()) { Text("Run Public-Law Search") }
                }
            }
            controller.publicLawResults.forEach { result ->
                AlphaCard(result.title, result.citation) {
                    Text(result.snippet, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(result.sourceName, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
private fun AlphaExportsScreen(controller: AlphaRossController, caseId: String?, selectedRoot: AndroidAlphaRoute, onRootSelected: (AndroidAlphaRoute) -> Unit) {
    AlphaShell(title = "Exports") {
        AlphaRootStrip(selectedRoute = selectedRoot, onSelect = onRootSelected)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            AlphaCard("Drafts / Exports", "Generate local reports for chronology, case note, or chat transcript review.") {
                Button(onClick = { controller.generateExport("chronology_report", caseId) }, modifier = Modifier.fillMaxWidth()) { Text("Generate Chronology Report") }
                Spacer(modifier = Modifier.height(8.dp))
                Button(onClick = { controller.generateExport("case_note", caseId) }, modifier = Modifier.fillMaxWidth()) { Text("Generate Case Note") }
                Spacer(modifier = Modifier.height(8.dp))
                Button(onClick = { controller.generateExport("order_summary", caseId) }, modifier = Modifier.fillMaxWidth()) { Text("Generate Order Summary") }
                Spacer(modifier = Modifier.height(8.dp))
                Button(onClick = { controller.generateExport("chat_transcript", caseId) }, modifier = Modifier.fillMaxWidth()) { Text("Generate Chat Transcript") }
            }
            controller.persisted.exports.forEach { report ->
                AlphaCard(report.title, report.kind.replace('_', ' ')) {
                    Text(report.relativePath, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
private fun AlphaSettingsScreen(
    controller: AlphaRossController,
    selectedRoot: AndroidAlphaRoute,
    onRootSelected: (AndroidAlphaRoute) -> Unit,
    onOpenLedger: () -> Unit,
    onOpenPrivateAi: () -> Unit,
) {
    AlphaShell(title = "Settings") {
        AlphaRootStrip(selectedRoute = selectedRoot, onSelect = onRootSelected)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            AlphaCard("Privacy defaults", "Keep boundary settings visible and explicit.") {
                AlphaToggleRow("Require public-law approval", controller.persisted.settings.requirePublicLawApproval) {
                    controller.persisted = controller.persisted.copy(settings = controller.persisted.settings.copy(requirePublicLawApproval = it))
                    controller.save()
                }
                AlphaToggleRow("Private by default", controller.persisted.settings.privateByDefault) {
                    controller.persisted = controller.persisted.copy(settings = controller.persisted.settings.copy(privateByDefault = it))
                    controller.save()
                }
                AlphaToggleRow("Instant Mode", controller.persisted.settings.instantModeEnabled) {
                    controller.persisted = controller.persisted.copy(settings = controller.persisted.settings.copy(instantModeEnabled = it))
                    controller.save()
                }
            }
            AlphaCard("Private AI", controller.activePack()?.tier?.title ?: "Not selected") {
                Button(onClick = onOpenPrivateAi, modifier = Modifier.fillMaxWidth()) { Text("Open Private AI Settings") }
            }
            AlphaCard("Privacy ledger", "Review visible network and local actions.") {
                Button(onClick = onOpenLedger, modifier = Modifier.fillMaxWidth()) { Text("Open Privacy Ledger") }
            }
        }
    }
}

@Composable
private fun AlphaPrivateAiSettingsScreen(controller: AlphaRossController, onBack: () -> Unit) {
    AlphaShell(title = "Private AI", showBack = true, onBack = onBack) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            AlphaCard(
                "Active pack",
                controller.activePack()?.tier?.title ?: "No pack selected"
            ) {
                val activeTier = controller.activePack()?.tier
                Text("Extraction quality: ${controller.activeExtractionMode().qualityLabel}")
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    when (activeTier) {
                        null -> "Basic extraction uses local text acquisition, OCR where available, and deterministic review."
                        AlphaCapabilityTier.QuickStart -> "Quick Start enables standard extraction for short documents and simple summaries."
                        AlphaCapabilityTier.CaseAssociate -> "Case Associate enables stronger field extraction, chronology support, and mixed English/Hindi review."
                        AlphaCapabilityTier.SeniorDraftingSupport -> "Senior Drafting Support enables deeper verification, longer bundles, and stronger bilingual workflows."
                    },
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            controller.activeRuntimeHealth()?.let { health ->
                AlphaCard("Technical details", "Collapsed runtime status for developer QA.") {
                    Text("Runtime mode: ${health.runtimeMode.wireValue}")
                    Text("Local runtime: ${if (health.available) "available" else "unavailable"}")
                    Text("Checksum verified: ${if (health.checksumVerified) "yes" else "no"}")
                    health.maxInputChars?.let { Text("Max input chars: $it") }
                    Text(
                        health.userFacingStatus,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            AlphaCard("Download policy", "Downloads can wait for Wi-Fi or use mobile data explicitly.") {
                AlphaToggleRow("Wi-Fi only downloads", controller.persisted.settings.wifiOnlyDownloads) {
                    controller.persisted = controller.persisted.copy(settings = controller.persisted.settings.copy(wifiOnlyDownloads = it))
                    controller.save()
                }
                AlphaToggleRow("Allow mobile data for large packs", controller.persisted.settings.allowMobileDataForLargePacks) {
                    controller.persisted = controller.persisted.copy(settings = controller.persisted.settings.copy(allowMobileDataForLargePacks = it))
                    controller.save()
                }
            }
            AlphaCapabilityTier.values().forEach { tier ->
                AlphaCard(tier.title, tier.summary) {
                    Text("${tier.downloadSizeLabel} download • ${tier.installedSizeLabel} installed")
                    Spacer(modifier = Modifier.height(8.dp))
                    Button(
                        onClick = { controller.startPackInstall(tier, controller.persisted.settings.allowMobileDataForLargePacks || tier == AlphaCapabilityTier.QuickStart) },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("Download / Resume") }
                }
            }
            controller.persisted.modelJobs.forEach { job ->
                AlphaCard(job.tier.title, job.state.name) {
                    Text("Checksum: ${job.checksumSha256.take(16)}…")
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = { controller.pauseJob(job.id) }) { Text("Pause") }
                        Button(onClick = { controller.resumeJob(job) }) { Text("Resume") }
                    }
                }
            }
            controller.persisted.installedPacks.forEach { pack ->
                AlphaCard(pack.tier.title, pack.installRelativePath) {
                    Text("Extraction quality: ${AlphaExtractionMode.fromInstalledPack(pack).qualityLabel}")
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        when (pack.tier) {
                            AlphaCapabilityTier.QuickStart -> "Best for shorter documents. Longer files fall back to cautious deterministic review."
                            AlphaCapabilityTier.CaseAssociate -> "Better extraction for mixed-language or poor scans."
                            AlphaCapabilityTier.SeniorDraftingSupport -> "Better extraction for mixed-language or poor scans, with deeper review passes."
                        },
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = { controller.activatePack(pack.id) }) { Text("Make Active") }
                        Button(onClick = { controller.removeInstalledPack(pack.id) }) { Text("Remove") }
                    }
                }
            }
        }
    }
}

@Composable
private fun AlphaPrivacyLedgerScreen(controller: AlphaRossController, onBack: () -> Unit) {
    AlphaShell(title = "Privacy Ledger", showBack = true, onBack = onBack) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(controller.persisted.ledgerEntries) { entry ->
                AlphaCard(entry.title, entry.purpose.name) {
                    Text(entry.detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(6.dp))
                    Text("${entry.payloadClass.name} • ${entry.endpointLabel}", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
private fun AlphaHero(eyebrow: String, title: String, body: String) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(eyebrow.uppercase(), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.secondary)
            Text(title, style = MaterialTheme.typography.headlineMedium)
            Text(body, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun AlphaCard(title: String, subtitle: String, content: @Composable ColumnScope.() -> Unit) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = MaterialTheme.typography.titleLarge)
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(modifier = Modifier.height(4.dp))
            content()
        }
    }
}

@Composable
private fun AlphaSelectableCard(title: String, body: String, selected: Boolean, footer: String, onClick: () -> Unit) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = if (selected) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surface),
        onClick = onClick
    ) {
        Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = MaterialTheme.typography.titleLarge)
            Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(footer, style = MaterialTheme.typography.labelLarge)
            if (selected) Text("Selected", color = MaterialTheme.colorScheme.secondary, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun AlphaAction(title: String, detail: String, onClick: () -> Unit) {
    Button(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Column(horizontalAlignment = Alignment.Start, modifier = Modifier.fillMaxWidth()) {
            Text(title)
            Text(detail, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun AlphaBullet(text: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
        Text("•", modifier = Modifier.size(16.dp))
        Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun AlphaToggleRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
