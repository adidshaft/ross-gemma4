package com.ross.android.alpha

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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

private val alphaScreenPadding = 16.dp
private val alphaSectionSpacing = 14.dp

private data class AlphaBackgroundWorkItem(
    val id: String,
    val title: String,
    val detail: String,
)

private data class AlphaRecentDocumentItem(
    val caseId: String,
    val caseTitle: String,
    val document: AlphaCaseDocument,
)

@Composable
fun AlphaRossApp() {
    val context = LocalContext.current.applicationContext
    val controller = remember(context) { AlphaRossController(context) }
    val backStack = remember { mutableStateListOf(controller.startRoute()) }
    val currentRoute = backStack.lastOrNull() ?: controller.startRoute()
    val rootRoute = when (currentRoute) {
        AndroidAlphaRoute.Home -> AndroidAlphaRoute.Home
        AndroidAlphaRoute.Capture -> AndroidAlphaRoute.Capture
        AndroidAlphaRoute.AskRoss -> AndroidAlphaRoute.AskRoss
        AndroidAlphaRoute.Settings, AndroidAlphaRoute.PrivateAiSettings -> AndroidAlphaRoute.Settings
        AndroidAlphaRoute.CaseList -> AndroidAlphaRoute.CaseList
        else -> AndroidAlphaRoute.Home
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
                replaceWith(AndroidAlphaRoute.Home)
            },
            onSkip = {
                controller.skipPackSetup()
                replaceWith(AndroidAlphaRoute.Home)
            },
        )

        AndroidAlphaRoute.Home -> AlphaHomeScreen(
            controller = controller,
            selectedRoot = rootRoute,
            onRootSelected = { replaceWith(it) },
            onOpenAsk = { push(AndroidAlphaRoute.AskRoss) },
            onCreateCase = { push(AndroidAlphaRoute.CreateCase) },
            onOpenCase = { caseId ->
                controller.selectedCaseId = caseId
                push(AndroidAlphaRoute.CaseWorkspace(caseId))
            },
        )

        AndroidAlphaRoute.CaseList -> AlphaCaseListScreen(
            controller = controller,
            selectedRoot = rootRoute,
            onRootSelected = { replaceWith(it) },
            onOpenAsk = { push(AndroidAlphaRoute.AskRoss) },
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
            onAskCase = { push(AndroidAlphaRoute.AskCase(currentRoute.caseId)) },
        )

        is AndroidAlphaRoute.DocumentViewer -> AlphaDocumentViewerScreen(
            controller = controller,
            caseId = currentRoute.caseId,
            documentId = currentRoute.documentId,
            pageNumber = currentRoute.pageNumber,
            onOpenPrivateAi = { push(AndroidAlphaRoute.PrivateAiSettings) },
            onAskCase = { push(AndroidAlphaRoute.AskCase(currentRoute.caseId)) },
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

        AndroidAlphaRoute.Capture -> AlphaCaptureScreen(
            controller = controller,
            selectedRoot = rootRoute,
            onRootSelected = { replaceWith(it) },
            onOpenAsk = { push(AndroidAlphaRoute.AskRoss) },
        )

        AndroidAlphaRoute.AskRoss -> AlphaAskRossScreen(
            controller = controller,
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
            onOpenAsk = { push(AndroidAlphaRoute.AskRoss) },
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
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    bottomBar: (@Composable () -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    Scaffold(
        topBar = {
            AlphaTopBar(title = title, showBack = showBack, onBack = onBack, actionLabel = actionLabel, onAction = onAction)
        },
        bottomBar = {
            bottomBar?.invoke()
        },
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
private fun AlphaTopBar(title: String, showBack: Boolean, onBack: (() -> Unit)?, actionLabel: String?, onAction: (() -> Unit)?) {
    TopAppBar(
        title = { Text(title, style = MaterialTheme.typography.titleLarge) },
        navigationIcon = {
            if (showBack && onBack != null) {
                Button(onClick = onBack, modifier = Modifier.padding(start = 12.dp)) { Text("Back") }
            }
        },
        actions = {
            if (actionLabel != null && onAction != null) {
                OutlinedCard(
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.82f)),
                    onClick = onAction,
                ) {
                    Text(
                        actionLabel,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
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
            AndroidAlphaRoute.Home to "Home",
            AndroidAlphaRoute.CaseList to "Cases",
            AndroidAlphaRoute.Capture to "Capture",
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
                eyebrow = "Ross",
                title = "A private case workbench for daily legal work",
                body = "Create a matter, add the first file, and let Ross keep dates, tasks, and source-backed drafts together on this device."
            )
            AlphaCard("What happens next", "Create one matter now or skip and start from Home.") {
                AlphaBullet("Choose a private assistant or keep using the lighter local mode for now.")
                AlphaBullet("Use Home for dates, tasks, review items, and direct next actions.")
                AlphaBullet("Turn on Web only when you want a sanitized public-law search.")
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
                eyebrow = "Assistant setup",
                title = "Choose the private assistant for this device.",
                body = "Ross starts the setup after you continue. You can keep working while the download finishes in the background."
            )
            AlphaCapabilityTier.values().forEach { tier ->
                AlphaSelectableCard(
                    title = tier.title,
                    body = tier.summary,
                    selected = controller.selectedTier == tier,
                    footer = "${tier.downloadSizeLabel} download • ${tier.installedSizeLabel} installed"
                ) { controller.selectedTier = tier }
            }
            AlphaCard("What happens next") {
                AlphaBullet("Ross opens Home and keeps the assistant status visible while setup continues.")
                AlphaBullet("You can still import files, ask questions, and organize tasks right away.")
                AlphaBullet("If you skip setup, Ross stays in the lighter local mode until you return.")
            }
            Button(onClick = onContinue, modifier = Modifier.fillMaxWidth()) { Text("Start setup and open Home") }
            Button(onClick = onSkip, modifier = Modifier.fillMaxWidth()) { Text("Use basic local mode for now") }
        }
    }
}

@Composable
private fun AlphaHomeScreen(
    controller: AlphaRossController,
    selectedRoot: AndroidAlphaRoute,
    onRootSelected: (AndroidAlphaRoute) -> Unit,
    onOpenAsk: () -> Unit,
    onCreateCase: () -> Unit,
    onOpenCase: (String) -> Unit,
) {
    val todayDateLines = alphaTodayDateLines(controller.persisted.cases)
    val upcomingDateLines = alphaUpcomingDateLines(controller.persisted.cases)
    val recentDocuments = alphaRecentDocumentItems(controller.persisted.cases)
    val backgroundItems = alphaBackgroundItems(controller)
    val privateAssistantStatus = alphaPrivateAiStatus(controller)
    val selectedCase = controller.selectedCase()

    AlphaShell(
        title = "Home",
        actionLabel = "Ask",
        onAction = onOpenAsk,
    ) {
        AlphaRootStrip(selectedRoute = selectedRoot, onSelect = onRootSelected)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            AlphaHero(
                eyebrow = alphaGreeting(),
                title = selectedCase?.title ?: "Ready for private case work",
                body = "${alphaUpcomingDateCountThisWeek(controller.persisted.cases)} dates this week • ${controller.reviewQueue().size} items need review • ${privateAssistantStatus.first}"
            )
            AlphaCard("Start here", "Ross works best when the next steps stay obvious under pressure.") {
                AlphaAction(
                    title = privateAssistantStatus.first,
                    detail = privateAssistantStatus.second,
                    onClick = { controller.pendingRoute = AndroidAlphaRoute.PrivateAiSettings },
                )
                Spacer(modifier = Modifier.height(8.dp))
                when {
                    controller.persisted.cases.isEmpty() -> AlphaAction(
                        title = "Create your first matter",
                        detail = "Start a case so Ross has one place to keep files, dates, and draft work together.",
                        onClick = onCreateCase,
                    )
                    controller.reviewQueue().isNotEmpty() -> AlphaAction(
                        title = "Review the next uncertain field",
                        detail = "${controller.reviewQueue().first().title} is waiting for advocate confirmation.",
                        onClick = { onOpenCase(controller.reviewQueue().first().caseId) },
                    )
                    selectedCase != null -> AlphaAction(
                        title = "Open ${selectedCase.title}",
                        detail = "Continue with the matter Ross already has in focus.",
                        onClick = { onOpenCase(selectedCase.id) },
                    )
                }
            }
            AlphaCard("Quick actions", "The most common next steps during live matter work.") {
                AlphaAction(
                    title = if (controller.persisted.cases.isEmpty()) "Create a matter" else "Import a document",
                    detail = if (controller.persisted.cases.isEmpty()) {
                        "Create the first matter before you start importing orders, pleadings, or notes."
                    } else {
                        "Add a PDF, image, or text file and keep the source anchored to the right case."
                    },
                    onClick = {
                        if (controller.persisted.cases.isEmpty()) {
                            onCreateCase()
                        } else {
                            onRootSelected(AndroidAlphaRoute.Capture)
                        }
                    },
                )
                Spacer(modifier = Modifier.height(8.dp))
                AlphaAction(
                    title = "Ask what to prepare next",
                    detail = if (selectedCase == null) {
                        "Ask across all saved matters for the next date, open tasks, or review items."
                    } else {
                        "Ask Ross for the next hearing posture, missing work, or the strongest source-backed issue."
                    },
                    onClick = {
                        if (selectedCase == null) {
                            onOpenAsk()
                        } else {
                            controller.pendingRoute = AndroidAlphaRoute.AskCase(selectedCase.id)
                        }
                    },
                )
                Spacer(modifier = Modifier.height(8.dp))
                AlphaAction(
                    title = if (selectedCase == null) "Open local reports" else "Generate chronology note",
                    detail = if (selectedCase == null) {
                        "Review the local reports Ross has already prepared on this device."
                    } else {
                        "Create a local chronology draft you can refine before the next hearing."
                    },
                    onClick = {
                        if (selectedCase == null) {
                            controller.pendingRoute = AndroidAlphaRoute.DraftsExports(null)
                        } else {
                            controller.generateExport("chronology_report", selectedCase.id)
                        }
                    },
                )
            }
            AlphaCard("Today") {
                todayDateLines.take(2).forEach { line ->
                    AlphaSummaryRow(title = line, detail = "Needs attention today")
                }
                controller.todayTasks().take(3).forEach { task ->
                    AlphaTaskRow(task = task, onToggle = { controller.toggleTaskDone(task.id) })
                }
                controller.reviewQueue().take(2).forEach { item ->
                    AlphaReviewRow(item = item, onOpen = { onOpenCase(item.caseId) })
                }
                if (todayDateLines.isEmpty() && controller.todayTasks().isEmpty() && controller.reviewQueue().isEmpty()) {
                    Text("Nothing urgent is due today.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            AlphaCard("Upcoming") {
                upcomingDateLines.take(4).forEach { line ->
                    AlphaSummaryRow(title = line, detail = "Saved in your case dates")
                }
                controller.upcomingTasks().take(2).forEach { task ->
                    AlphaTaskRow(task = task, onToggle = { controller.toggleTaskDone(task.id) })
                }
                if (upcomingDateLines.isEmpty() && controller.upcomingTasks().isEmpty()) {
                    Text("No upcoming dates are saved yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }

            if (backgroundItems.isNotEmpty()) {
                AlphaCard("Background work") {
                    backgroundItems.take(4).forEach { item ->
                        AlphaSummaryRow(title = item.title, detail = item.detail)
                    }
                }
            }

            AlphaCard("Active cases") {
                if (controller.persisted.cases.isEmpty()) {
                    Text("No cases yet. Create one from the Cases tab.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                controller.persisted.cases.forEach { case ->
                    AlphaCaseSummaryRow(case = case, openTasks = controller.openTaskCount(case.id), reviewCount = controller.reviewQueue(case.id).size) {
                        onOpenCase(case.id)
                    }
                }
            }
            AlphaCard("Recent files") {
                if (recentDocuments.isEmpty()) {
                    Text("No files added yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                recentDocuments.take(4).forEach { entry ->
                    AlphaDocumentSummaryRow(
                        caseTitle = entry.caseTitle,
                        document = entry.document,
                        onOpen = { controller.pendingRoute = AndroidAlphaRoute.DocumentViewer(entry.caseId, entry.document.id, 1) },
                    )
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

@Composable
private fun AlphaCaseListScreen(
    controller: AlphaRossController,
    selectedRoot: AndroidAlphaRoute,
    onRootSelected: (AndroidAlphaRoute) -> Unit,
    onOpenAsk: () -> Unit,
    onCreateCase: () -> Unit,
    onOpenCase: (String) -> Unit,
) {
    AlphaShell(title = "Cases", actionLabel = "Ask", onAction = onOpenAsk) {
        AlphaRootStrip(selectedRoute = selectedRoot, onSelect = onRootSelected)
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            item {
                AlphaInlineHeader(
                    eyebrow = "Cases",
                    title = "Case management",
                    detail = "${controller.persisted.cases.size} case(s) on this device",
                )
            }
            item {
                Button(onClick = onCreateCase, modifier = Modifier.fillMaxWidth()) { Text("Create case") }
            }
            if (controller.persisted.cases.isEmpty()) {
                item {
                    AlphaCard("No cases yet") {
                        Text("Create a case to start adding documents, dates, and tasks.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            items(controller.persisted.cases) { case ->
                AlphaCaseSummaryRow(
                    case = case,
                    openTasks = controller.openTaskCount(case.id),
                    reviewCount = controller.reviewQueue(case.id).size,
                    onOpen = { onOpenCase(case.id) },
                )
            }
        }
    }
}

@Composable
private fun AlphaCaptureScreen(
    controller: AlphaRossController,
    selectedRoot: AndroidAlphaRoute,
    onRootSelected: (AndroidAlphaRoute) -> Unit,
    onOpenAsk: () -> Unit,
) {
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        val caseId = controller.selectedCaseId ?: controller.persisted.cases.firstOrNull()?.id
        if (uri != null && caseId != null) controller.importDocument(caseId, uri)
    }
    val activeCase = controller.persisted.cases.firstOrNull { it.id == controller.selectedCaseId }
        ?: controller.persisted.cases.firstOrNull()
    AlphaShell(title = "Capture / Import", actionLabel = "Ask", onAction = onOpenAsk) {
        AlphaRootStrip(selectedRoute = selectedRoot, onSelect = onRootSelected)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            AlphaInlineHeader(
                eyebrow = "Capture / Import",
                title = if (activeCase == null) "Start with a matter" else "Bring a file into the matter",
                detail = if (activeCase == null) {
                    "Ross files each document into a specific matter, so create one before you import."
                } else {
                    "Ross copies the file into private storage, opens review, and keeps the source linked to the selected matter."
                },
            )
            if (activeCase != null) {
                AlphaCard("Import into", activeCase.title) {
                    AlphaCaseScopeSelector(
                        selectedCaseId = controller.selectedCaseId ?: controller.persisted.cases.firstOrNull()?.id,
                        cases = controller.persisted.cases,
                        allLabel = "Select case",
                        includeAllCases = false,
                    ) { selected ->
                        controller.selectedCaseId = selected
                    }
                    Spacer(modifier = Modifier.height(10.dp))
                    Text("PDF, image, or text • stays on this device • opens review after import", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Button(onClick = { launcher.launch(arrayOf("application/pdf", "image/*", "text/plain")) }, modifier = Modifier.fillMaxWidth()) {
                    Text("Import document")
                }
            } else {
                AlphaCard("Start with a matter first", "This keeps imported files, dates, and review notes together in the right place.") {
                    Button(
                        onClick = { controller.pendingRoute = AndroidAlphaRoute.CreateCase },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Create matter")
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        "After you create a matter, Ross will let you import a PDF, image, or text file directly into it.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            if (activeCase != null) {
                AlphaCard("What Ross will do") {
                    AlphaBullet("Copy the file into app-private storage.")
                    AlphaBullet("Open the review screen for that document.")
                    AlphaBullet("Keep extracted dates, issues, and source anchors in the same matter.")
                }
            }
            AlphaCard("Recent files") {
                val recentDocuments = alphaRecentDocumentItems(
                    controller.persisted.cases,
                    controller.selectedCaseId,
                )
                if (recentDocuments.isEmpty()) {
                    Text("No files added yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                recentDocuments.take(6).forEach { entry ->
                    AlphaDocumentSummaryRow(
                        caseTitle = entry.caseTitle,
                        document = entry.document,
                        onOpen = { controller.pendingRoute = AndroidAlphaRoute.DocumentViewer(entry.caseId, entry.document.id, 1) },
                    )
                }
            }
        }
    }
}

@Composable
private fun AlphaAskRossScreen(
    controller: AlphaRossController,
    onBack: () -> Unit,
    onOpenSource: (AlphaSourceRef) -> Unit,
) {
    AlphaAskConversationScreen(
        controller = controller,
        fixedScopeCaseId = null,
        onBack = onBack,
        onOpenSource = onOpenSource,
    )
}

@Composable
private fun AlphaCreateCaseScreen(controller: AlphaRossController, onCreated: (String) -> Unit, onBack: () -> Unit) {
    AlphaShell(title = "Create Case", showBack = true, onBack = onBack) {
        Column(modifier = Modifier.padding(alphaScreenPadding), verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)) {
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
                onClick = { controller.createCase(openWorkspace = false)?.let(onCreated) },
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
    AlphaShell(
        title = "Case",
        showBack = true,
        onBack = onBack,
        actionLabel = "Ask",
        onAction = onAskCase,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            case?.let {
                AlphaInlineHeader(
                    eyebrow = it.forum,
                    title = it.title,
                    detail = "${it.stage.name.lowercase().replaceFirstChar(Char::titlecase)} · ${it.documents.size} documents · ${controller.openTaskCount(caseId)} open tasks",
                )
                AlphaCard("What needs attention", "The quickest way to move this matter forward.") {
                    it.nextHearing?.let { nextDate ->
                        AlphaSummaryRow(title = "Next date", detail = alphaDateLabel(nextDate))
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                    if (it.draftTasks.isEmpty()) {
                        Text(
                            "No next-step note is saved yet. Import another file or ask Ross for the next preparation step.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    } else {
                        it.draftTasks.take(3).forEach { task ->
                            AlphaBullet(task)
                        }
                    }
                }
                AlphaCard("Workbench actions", "Use the shortest path to the next useful outcome.") {
                    AlphaAction(
                        title = if (it.documents.isEmpty()) "Import the first document" else "Review case documents",
                        detail = if (it.documents.isEmpty()) {
                            "Bring in the first order, pleading, notice, or note so Ross can start building source-backed work."
                        } else {
                            "Open the document list, import another file, or jump into review from the source pages."
                        },
                        onClick = onOpenDocuments,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    AlphaAction(
                        title = "Ask about this matter",
                        detail = "Keep the answer tied to this case, its dates, its tasks, and the files Ross has already read.",
                        onClick = onAskCase,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    AlphaAction(
                        title = "Generate chronology note",
                        detail = "Create a local draft you can refine before the next hearing.",
                        onClick = { controller.generateExport("chronology_report", caseId) },
                    )
                }
                AlphaCard("Overview") {
                    it.nextHearing?.let { nextDate ->
                        Text("Next date: ${alphaDateLabel(nextDate)}", fontWeight = FontWeight.SemiBold)
                    }
                    Text("Open tasks: ${controller.openTaskCount(caseId)}")
                    Text("Review items: ${controller.reviewQueue(caseId).size}")
                    Text("Documents: ${it.documents.size}")
                    Spacer(modifier = Modifier.height(8.dp))
                    it.issueHighlights.take(3).forEach { item -> AlphaBullet(item) }
                }
                AlphaCard("Documents") {
                    Button(onClick = onOpenDocuments, modifier = Modifier.fillMaxWidth()) { Text("Import or open documents") }
                    Spacer(modifier = Modifier.height(12.dp))
                    if (it.documents.isEmpty()) {
                        Text("No documents yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    it.documents.forEach { document ->
                        AlphaDocumentSummaryRow(
                            caseTitle = null,
                            document = document,
                            onOpen = { controller.pendingRoute = AndroidAlphaRoute.DocumentViewer(caseId, document.id, 1) },
                        )
                    }
                }
                AlphaCard("Tasks") {
                    AlphaTaskQuickAdd(onAdd = { title, dueDate ->
                        controller.addTask(title = title, caseId = caseId, dueDate = dueDate)
                    })
                    controller.tasks(caseId).forEach { task ->
                        AlphaTaskRow(task = task, onToggle = { controller.toggleTaskDone(task.id) })
                    }
                }
                AlphaCard("Review") {
                    controller.reviewQueue(caseId).forEach { item ->
                        AlphaReviewRow(item = item, onOpen = {
                            val source = item.sourceRef
                            if (source != null) {
                                onOpenSource(source)
                            } else {
                                onOpenDocuments()
                            }
                        })
                    }
                    if (controller.reviewQueue(caseId).isEmpty()) {
                        Text("No review items are waiting for this case.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                AlphaCard("Notes / Exports") {
                    Button(onClick = onOpenExports, modifier = Modifier.fillMaxWidth()) { Text("Open exports") }
                }
                if (it.caseMemoryUpdates.isNotEmpty()) {
                    AlphaCard("Recent activity") {
                        it.caseMemoryUpdates.take(4).forEach { update ->
                            Text(update.summary, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
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
    onAskCase: () -> Unit,
) {
    val case = controller.persisted.cases.firstOrNull { it.id == caseId }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) controller.importDocument(caseId, uri)
    }
    AlphaShell(title = "Documents", showBack = true, onBack = onBack, actionLabel = "Ask", onAction = onAskCase) {
        Column(modifier = Modifier.fillMaxSize().padding(alphaScreenPadding), verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)) {
            AlphaInlineHeader(
                eyebrow = case?.forum ?: "Documents",
                title = case?.title ?: "Documents",
                detail = "${case?.documents?.size ?: 0} file(s) in this case",
            )
            AlphaCard("Matter file room", "Keep source files, review work, and exports together for this matter.") {
                Text(
                    "${case?.documents?.size ?: 0} files • ${controller.reviewQueue(caseId).size} need review • ${controller.openTaskCount(caseId)} open tasks",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            AlphaCard("Next actions") {
                AlphaAction(
                    title = "Import another file",
                    detail = "Add a PDF, image, or text file and open its review screen immediately.",
                    onClick = { launcher.launch(arrayOf("application/pdf", "image/*", "text/plain")) },
                )
                Spacer(modifier = Modifier.height(8.dp))
                AlphaAction(
                    title = "Ask about this matter",
                    detail = "Use the current file room as the source-backed context for your question.",
                    onClick = onAskCase,
                )
                Spacer(modifier = Modifier.height(8.dp))
                AlphaAction(
                    title = "Generate case note",
                    detail = "Create a local draft note from the current matter before the next hearing.",
                    onClick = { controller.generateExport("case_note", caseId) },
                )
            }
            if (case?.documents.isNullOrEmpty()) {
                AlphaCard("No documents yet") {
                    Text("Import the first order, pleading, notice, or note for this matter.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                items(case?.documents ?: emptyList()) { document ->
                    AlphaDocumentSummaryRow(caseTitle = null, document = document, onOpen = { onOpenDocument(document.id) })
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
    onAskCase: () -> Unit,
    onBack: () -> Unit,
) {
    val document = controller.document(caseId, documentId)
    val sourcePanel = controller.documentSourcePanel(caseId, documentId, pageNumber)
    var editingFieldId by remember(documentId) { mutableStateOf<String?>(null) }
    var draftFieldValue by remember(documentId) { mutableStateOf("") }
    var editingClassification by remember(documentId) { mutableStateOf(false) }
    AlphaShell(title = "Document", showBack = true, onBack = onBack, actionLabel = "Ask", onAction = onAskCase) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            if (document == null) {
                AlphaCard("Source unavailable") {
                    Text(
                        sourcePanel.fallbackMessage
                            ?: "The source document is unavailable, but the saved source metadata is still visible here.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                val doc = document
                val reviewCount = controller.visibleExtractedFields(caseId, documentId).count { it.needsReview }
                AlphaInlineHeader(
                    eyebrow = doc.kind.title,
                    title = doc.title,
                    detail = "Status: ${doc.lawyerStatusTitle()} · ${doc.pageCount} page(s) · $reviewCount need review",
                )
                AlphaCard(
                    "Review snapshot",
                    controller.reviewSummary(caseId, documentId)
                        ?: if (reviewCount > 0) "Ross found details that still need advocate review." else "This document is ready for normal use in the matter.",
                ) {
                    Text(
                        "${controller.visibleExtractedFields(caseId, documentId).size} fields found • $reviewCount need review • page ${sourcePanel.resolvedPage} of ${sourcePanel.pageCount}",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
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
                        AlphaCard("Preview") {
                            Text("Ross is showing source metadata while a rich preview is unavailable for this file.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                AlphaCard("Actions") {
                    AlphaAction("Ask about this document", "Open the case ask view with this document already in mind.", onClick = onAskCase)
                    Spacer(modifier = Modifier.height(8.dp))
                    AlphaAction(
                        "Create review task",
                        "Save a follow-up task linked to this case and its next date.",
                        onClick = {
                            controller.addTask(
                                title = "Review ${doc.title}",
                                caseId = caseId,
                                dueDate = java.time.Instant.now().plusSeconds(86_400).toString(),
                                priority = AlphaTaskPriority.Normal,
                                notes = "Created from document viewer.",
                            )
                        },
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    AlphaAction("Export note", "Generate a local case note for advocate review.") {
                        controller.generateExport("case_note", caseId)
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    AlphaAction("Re-run review", "Review this document again using the current assistant and source rules.") {
                        controller.rerunReview(caseId, documentId)
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    AlphaAction("Delete document", "Remove this document from the case workspace.") {
                        controller.deleteDocument(caseId, documentId)
                        onBack()
                    }
                }
                AlphaCard("Text found") {
                    Text(doc.extractedText ?: "No extracted text yet. Ross will keep source references visible even when exact highlights are still pending.")
                }
                AlphaCard(
                    "Review details",
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
                            doc.extractionRuns.firstOrNull()?.status == AlphaExtractionRunStatus.Running -> "Ross is still reading this file on this device."
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
                        Button(onClick = onOpenPrivateAi, modifier = Modifier.fillMaxWidth()) { Text("Open Private AI") }
                    }
                }
                AlphaCard("Sources", sourcePanel.fallbackMessage ?: "Ross shows the best source metadata available for this page.") {
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
    AlphaAskConversationScreen(
        controller = controller,
        fixedScopeCaseId = caseId,
        onBack = onBack,
        onOpenSource = onOpenSource,
    )
}

@Composable
private fun AlphaPublicLawScreen(controller: AlphaRossController, selectedRoot: AndroidAlphaRoute, onRootSelected: (AndroidAlphaRoute) -> Unit) {
    AlphaShell(title = "Public Law") {
        AlphaRootStrip(selectedRoute = selectedRoot, onSelect = onRootSelected)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            AlphaInlineHeader(
                eyebrow = "Public law",
                title = "Sanitized law search",
                detail = "Ross only sends a generic public-law query after you review it.",
            )
            AlphaCard("Query preview") {
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
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            AlphaInlineHeader(
                eyebrow = "Exports",
                title = "Drafts and reports",
                detail = "Generate local reports for advocate review.",
            )
            AlphaCard("Generate") {
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
    onOpenAsk: () -> Unit,
    onOpenLedger: () -> Unit,
    onOpenPrivateAi: () -> Unit,
) {
    AlphaShell(title = "Settings", actionLabel = "Ask", onAction = onOpenAsk) {
        AlphaRootStrip(selectedRoute = selectedRoot, onSelect = onRootSelected)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            val privateAiStatus = alphaPrivateAiStatus(controller)
            AlphaCard("Privacy", "Case files stay on this device. Public-law search is always explicit and sanitized.") {
                AlphaToggleRow("Ask before public-law search", controller.persisted.settings.requirePublicLawApproval) {
                    controller.persisted = controller.persisted.copy(settings = controller.persisted.settings.copy(requirePublicLawApproval = it))
                    controller.save()
                }
                AlphaToggleRow("Private by default", controller.persisted.settings.privateByDefault) {
                    controller.persisted = controller.persisted.copy(settings = controller.persisted.settings.copy(privateByDefault = it))
                    controller.save()
                }
            }
            AlphaCard("Private assistant", privateAiStatus.first) {
                Text(privateAiStatus.second, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(8.dp))
                Button(onClick = onOpenPrivateAi, modifier = Modifier.fillMaxWidth()) { Text("Open assistant setup") }
            }
            AlphaCard("Privacy ledger", "Review visible network and local actions.") {
                Button(onClick = onOpenLedger, modifier = Modifier.fillMaxWidth()) { Text("Open Privacy Ledger") }
            }
            AlphaCard("Exports", "${controller.persisted.exports.size} saved items") {
                Text("Chronologies, case notes, order summaries, and transcripts are saved locally.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun AlphaPrivateAiSettingsScreen(controller: AlphaRossController, onBack: () -> Unit) {
    var showTechnicalDiagnostics by remember { mutableStateOf(false) }
    val privateAiStatus = alphaPrivateAiStatus(controller)
    AlphaShell(title = "Private Assistant", showBack = true, onBack = onBack) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            AlphaCard("Private assistant", privateAiStatus.first) {
                Text(privateAiStatus.second, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            AlphaCard("Download preferences", "Downloads can wait for Wi-Fi or use mobile data explicitly.") {
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
                    Text("${tier.downloadSizeLabel} download • ${tier.installedSizeLabel} installed • Wi-Fi recommended")
                    Spacer(modifier = Modifier.height(8.dp))
                    Button(
                        onClick = { controller.startPackInstall(tier, controller.persisted.settings.allowMobileDataForLargePacks || tier == AlphaCapabilityTier.QuickStart) },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text("Set up / Resume") }
                }
            }
            controller.persisted.modelJobs.forEach { job ->
                AlphaCard(job.tier.title, alphaJobStatusLabel(job.state)) {
                    Text(alphaJobStatusLabel(job.state), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = { controller.pauseJob(job.id) }) { Text("Pause") }
                        Button(onClick = { controller.resumeJob(job) }) { Text("Resume") }
                    }
                }
            }
            controller.persisted.installedPacks.forEach { pack ->
                AlphaCard(pack.tier.title, "Ready on this device") {
                    Text("Extraction quality: ${AlphaExtractionMode.fromInstalledPack(pack).qualityLabel}")
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        when (pack.tier) {
                            AlphaCapabilityTier.QuickStart -> "Best for shorter documents. Longer files may use basic local review."
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
            AlphaCard("Advanced", "Technical diagnostics stay hidden from normal use.") {
                Button(
                    onClick = { showTechnicalDiagnostics = !showTechnicalDiagnostics },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(if (showTechnicalDiagnostics) "Hide technical diagnostics" else "Show technical diagnostics")
                }
                if (showTechnicalDiagnostics) {
                    controller.activeRuntimeHealth()?.let { health ->
                        Spacer(modifier = Modifier.height(12.dp))
                        Text("Runtime mode: ${health.runtimeMode.wireValue}")
                        Text("Artifact kind: ${controller.activePack()?.artifactKind ?: "Missing"}")
                        Text("Checksum verified: ${if (health.checksumVerified) "yes" else "no"}")
                        Text("Fallback active: ${if (health.fallbackActive) "yes" else "no"}")
                        Text("Model path: ${if (health.modelPathPresent) "Configured" else "Missing"}")
                        health.modelPathLabel?.let { Text("Model file: $it") }
                        health.lastErrorCategory?.let { Text("Last error category: $it") }
                        controller.lastModelInvocationRuntimeMode()?.let { Text("Last invocation runtime: $it") }
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(
                            onClick = { controller.runLocalInferenceSmoke() },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !controller.localInferenceSmokeRunning,
                        ) {
                            Text(if (controller.localInferenceSmokeRunning) "Running local inference smoke..." else "Run local inference smoke")
                        }
                    }
                    controller.localInferenceSmokeReport?.let { report ->
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("Runtime used: ${report.runtimeUsed}")
                        Text("Schema valid: ${if (report.schemaValid) "yes" else "no"}")
                        Text("Fields found: ${report.fieldsFound}")
                        Text("Fields verified: ${report.fieldsVerified}")
                        Text("Fields needing review: ${report.fieldsNeedingReview}")
                        Text("Unsupported accepted: ${report.unsupportedAccepted}")
                        report.exportRelativePath?.let { Text("Export: $it") }
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
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(controller.persisted.ledgerEntries) { entry ->
                AlphaCard(entry.lawyerTitle(), entry.success.thenCompleted()) {
                    Text(entry.lawyerDetail(), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(entry.purpose.name.replace('_', ' ').lowercase().replaceFirstChar(Char::titlecase), style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
private fun AlphaHero(eyebrow: String, title: String, body: String) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(eyebrow.uppercase(), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.secondary)
            Text(title, style = MaterialTheme.typography.headlineSmall)
            Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun AlphaInlineHeader(eyebrow: String, title: String, detail: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(eyebrow.uppercase(), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.secondary)
        Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        Text(detail, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun AlphaCard(title: String, subtitle: String? = null, content: @Composable ColumnScope.() -> Unit) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            subtitle?.takeIf { it.isNotBlank() }?.let {
                Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(2.dp))
            }
            content()
        }
    }
}

@Composable
private fun AlphaSelectableCard(title: String, body: String, selected: Boolean, footer: String, onClick: () -> Unit) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(),
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

@Composable
private fun AlphaTaskQuickAdd(onAdd: (String, String?) -> Unit) {
    var title by remember { mutableStateOf("") }
    var dueToday by remember { mutableStateOf(false) }

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Add task") },
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                FilterChip(
                    selected = dueToday,
                    onClick = { dueToday = !dueToday },
                    label = { Text("Due today") },
                )
                Button(
                    onClick = {
                        onAdd(title.trim(), if (dueToday) java.time.Instant.now().toString() else null)
                        title = ""
                        dueToday = false
                    },
                    enabled = title.isNotBlank(),
                ) {
                    Text("Add")
                }
            }
        }
    }
}

@Composable
private fun AlphaTaskRow(task: AlphaTaskItem, onToggle: () -> Unit) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.28f)),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(task.title, style = MaterialTheme.typography.titleMedium)
                Text(
                    if (task.status == AlphaTaskStatus.Done) "Done" else task.priority.name.lowercase().replaceFirstChar(Char::titlecase),
                    color = MaterialTheme.colorScheme.secondary,
                    style = MaterialTheme.typography.labelLarge,
                )
            }
            task.notes?.takeIf { it.startsWith("review-sync::").not() }?.let { note ->
                Text(note, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
            }
            task.dueDate?.let { dueDate ->
                Text("Due ${alphaDateLabel(dueDate)}", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
            }
            Button(onClick = onToggle, modifier = Modifier.fillMaxWidth()) {
                Text(if (task.status == AlphaTaskStatus.Done) "Mark open" else "Mark done")
            }
        }
    }
}

@Composable
private fun AlphaReviewRow(item: AlphaReviewQueueItem, onOpen: () -> Unit) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.28f)),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(item.title, style = MaterialTheme.typography.titleMedium)
            Text(item.detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(item.caseTitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
            Button(onClick = onOpen, modifier = Modifier.fillMaxWidth()) { Text("Open") }
        }
    }
}

@Composable
private fun AlphaCaseSummaryRow(case: AlphaCaseMatter, openTasks: Int, reviewCount: Int, onOpen: () -> Unit) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        onClick = onOpen,
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(case.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text("${case.forum} • ${case.stage.name.lowercase().replaceFirstChar(Char::titlecase)}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                case.nextHearing?.let { nextDate ->
                    Text(alphaDateLabel(nextDate), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.secondary)
                }
            }
            Text(
                "$openTasks open tasks • $reviewCount review items • ${case.documents.size} documents",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall,
            )
            Text(case.localNotice, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun AlphaSummaryRow(title: String, detail: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun AlphaDocumentSummaryRow(caseTitle: String?, document: AlphaCaseDocument, onOpen: () -> Unit) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        onClick = onOpen,
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(document.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            caseTitle?.let {
                Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text(document.lawyerStatusTitle(), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.secondary)
        }
    }
}

@Composable
private fun AlphaAskResultCard(result: AlphaAskResult, onOpenSource: (AlphaSourceRef) -> Unit) {
    AlphaCard(result.answerTitle, result.scopeLabel) {
        result.answerSections.forEach { section ->
            AlphaBullet(section)
        }
        result.statusNote?.let { note ->
            Text(note, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.secondary)
        }
        result.needsReviewWarning?.let { warning ->
            Text(warning, color = MaterialTheme.colorScheme.tertiary, style = MaterialTheme.typography.bodySmall)
        }
        if (result.caseFileSources.isNotEmpty()) {
            Text("Case-file sources", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
            result.caseFileSources.forEach { source ->
                Button(onClick = { onOpenSource(source) }, modifier = Modifier.fillMaxWidth()) { Text(source.label) }
            }
        }
        result.publicLawPreview?.let { preview ->
            Text("Web search preview", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(preview.query, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (result.publicLawResults.isNotEmpty()) {
            Text("Public-law results", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
            result.publicLawResults.forEach { publicResult ->
                OutlinedCard(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.24f)),
                ) {
                    Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(publicResult.title, style = MaterialTheme.typography.titleMedium)
                        Text(publicResult.citation, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
                        Text(publicResult.snippet, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@Composable
private fun AlphaAskConversationScreen(
    controller: AlphaRossController,
    fixedScopeCaseId: String?,
    onBack: () -> Unit,
    onOpenSource: (AlphaSourceRef) -> Unit,
) {
    val activeScopeCaseId = fixedScopeCaseId ?: controller.askSelectedScopeCaseId
    val conversation = controller.askConversation(activeScopeCaseId)
    val introDetail = if (activeScopeCaseId == null) {
        "Ask about your case dates, recent files, tasks, and anything Ross has read on this device."
    } else {
        "Ask about this case, its dates, tasks, and important files."
    }

    AlphaShell(title = "Ask Ross", showBack = true, onBack = onBack, bottomBar = {
        AlphaAskComposerPanel(controller = controller, fixedScopeCaseId = fixedScopeCaseId)
    }) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            if (conversation.isEmpty()) {
                AlphaAskEmptyState(
                    detail = introDetail,
                    suggestions = alphaAskSuggestions(if (activeScopeCaseId == null) null else controller.scopeLabel(activeScopeCaseId)),
                    onSelectSuggestion = { controller.setAskDraft(activeScopeCaseId, it) },
                )
                Spacer(modifier = Modifier.height(32.dp))
            } else {
                Spacer(modifier = Modifier.height(8.dp))
                conversation.forEach { result ->
                    AlphaAskTurnCard(result = result, onOpenSource = onOpenSource)
                }
                Spacer(modifier = Modifier.height(12.dp))
            }
        }
    }
}

@Composable
private fun AlphaAskEmptyState(detail: String, suggestions: List<String>, onSelectSuggestion: (String) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 72.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Ask about the work in front of you", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(
            detail,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            suggestions.forEach { suggestion ->
                OutlinedCard(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(18.dp),
                    colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.78f)),
                    onClick = { onSelectSuggestion(suggestion) },
                ) {
                    Text(
                        suggestion,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }
        }
    }
}

@Composable
private fun AlphaAskTurnCard(result: AlphaAskResult, onOpenSource: (AlphaSourceRef) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            OutlinedCard(
                modifier = Modifier.widthIn(max = 320.dp),
                shape = RoundedCornerShape(22.dp),
                colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
            ) {
                Text(
                    result.question,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }

        OutlinedCard(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(26.dp),
            colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.82f)),
        ) {
            Column(modifier = Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(result.answerTitle, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                result.answerSections.forEach { section ->
                    Text(section, color = MaterialTheme.colorScheme.onSurface, style = MaterialTheme.typography.bodyMedium)
                }
                result.statusNote?.let { note ->
                    Text(note, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.secondary)
                }
                result.needsReviewWarning?.let { warning ->
                    Text(warning, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.tertiary)
                }
                if (result.caseFileSources.isNotEmpty()) {
                    Text("Case-file sources", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    result.caseFileSources.forEach { source ->
                        OutlinedCard(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(14.dp),
                            colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)),
                            onClick = { onOpenSource(source) },
                        ) {
                            Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(source.label, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
                                Text(source.detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
                result.publicLawPreview?.let { preview ->
                    Text("Web search preview", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(preview.query, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if (result.publicLawResults.isNotEmpty()) {
                    Text("Public-law results", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    result.publicLawResults.forEach { publicResult ->
                        OutlinedCard(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.26f)),
                        ) {
                            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Text(publicResult.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                                Text(publicResult.citation, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
                                Text(publicResult.snippet, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AlphaAskComposerPanel(controller: AlphaRossController, fixedScopeCaseId: String?) {
    val activeScopeCaseId = fixedScopeCaseId ?: controller.askSelectedScopeCaseId
    var attachExpanded by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = 12.dp, vertical = 10.dp),
    ) {
        OutlinedCard(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(26.dp),
            colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f)),
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (fixedScopeCaseId == null) {
                    AlphaCaseScopeSelector(
                        selectedCaseId = controller.askSelectedScopeCaseId,
                        cases = controller.persisted.cases,
                        allLabel = "All cases",
                        includeAllCases = true,
                    ) { selectedCaseId ->
                        controller.askSelectedScopeCaseId = selectedCaseId
                    }
                } else {
                    Text(
                        controller.scopeLabel(fixedScopeCaseId),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    OutlinedTextField(
                        value = controller.askDraft(activeScopeCaseId),
                        onValueChange = { controller.setAskDraft(activeScopeCaseId, it) },
                        modifier = Modifier.weight(1f),
                        label = { Text("Ask about dates, issues, files, or next steps") },
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                        minLines = 2,
                        maxLines = 4,
                    )
                    Spacer(modifier = Modifier.size(10.dp))
                    AlphaAskMiniButton(label = "Go") {
                        controller.submitAsk(
                            question = controller.askDraft(activeScopeCaseId),
                            scopeCaseId = activeScopeCaseId,
                            webEnabled = controller.askWebEnabled,
                        )
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box {
                        AlphaAskMiniButton(label = "+") {
                            attachExpanded = true
                        }
                        DropdownMenu(expanded = attachExpanded, onDismissRequest = { attachExpanded = false }) {
                            DropdownMenuItem(
                                text = { Text("Open capture / import") },
                                onClick = {
                                    controller.pendingRoute = if (fixedScopeCaseId != null) {
                                        AndroidAlphaRoute.DocumentList(fixedScopeCaseId)
                                    } else {
                                        AndroidAlphaRoute.Capture
                                    }
                                    attachExpanded = false
                                },
                            )
                            if (activeScopeCaseId != null) {
                                DropdownMenuItem(
                                    text = { Text("Upload to selected case") },
                                    onClick = {
                                        controller.pendingRoute = AndroidAlphaRoute.DocumentList(activeScopeCaseId)
                                        attachExpanded = false
                                    },
                                )
                            }
                        }
                    }
                    AlphaAskMiniButton(label = "Web", selected = controller.askWebEnabled) {
                        controller.askWebEnabled = !controller.askWebEnabled
                    }
                }
                if (controller.askWebEnabled) {
                    Text(
                        "Web search only sends a generic public-law query. Your case files stay on this device.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }
    }

    if (controller.publicLawPreview != null && controller.pendingPublicLawQuestion != null) {
        val preview = controller.publicLawPreview ?: return
        AlertDialog(
            onDismissRequest = { controller.cancelPendingPublicLawSearch() },
            title = { Text("Public-law query to be sent") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(preview.query, fontWeight = FontWeight.SemiBold)
                    Text("No case files or document text will be sent.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    preview.removed.forEach { removed -> AlphaBullet(removed) }
                }
            },
            confirmButton = {
                TextButton(onClick = { controller.confirmPendingPublicLawSearch() }) {
                    Text("Search public law")
                }
            },
            dismissButton = {
                TextButton(onClick = { controller.cancelPendingPublicLawSearch() }) {
                    Text("Cancel")
                }
            },
        )
    }
}

@Composable
private fun AlphaAskMiniButton(label: String, selected: Boolean = false, onClick: () -> Unit) {
    OutlinedCard(
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.outlinedCardColors(
            containerColor = if (selected) MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.86f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.34f),
        ),
        onClick = onClick,
    ) {
        Text(
            label,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) MaterialTheme.colorScheme.onSecondaryContainer else MaterialTheme.colorScheme.onSurface,
        )
    }
}

private fun alphaAskSuggestions(scopeLabel: String?): List<String> =
    if (scopeLabel.isNullOrBlank()) {
        listOf(
            "What needs my attention today?",
            "Which matter has the next date?",
            "Which files still need review?",
        )
    } else {
        listOf(
            "Summarise $scopeLabel in one hearing note.",
            "What is the next court date and why does it matter?",
            "What should I prepare next for this matter?",
        )
    }

@Composable
private fun AlphaCaseScopeSelector(
    selectedCaseId: String?,
    cases: List<AlphaCaseMatter>,
    allLabel: String,
    includeAllCases: Boolean,
    onSelect: (String?) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val label = selectedCaseId?.let { selectedId ->
        cases.firstOrNull { it.id == selectedId }?.title
    } ?: allLabel

    Box {
        Button(onClick = { expanded = true }) { Text(label) }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            if (includeAllCases) {
                DropdownMenuItem(
                    text = { Text(allLabel) },
                    onClick = {
                        onSelect(null)
                        expanded = false
                    },
                )
            }
            cases.forEach { case ->
                DropdownMenuItem(
                    text = { Text(case.title) },
                    onClick = {
                        onSelect(case.id)
                        expanded = false
                    },
                )
            }
        }
    }
}

private fun alphaGreeting(): String {
    val hour = java.time.LocalTime.now().hour
    return when {
        hour < 12 -> "Good morning"
        hour < 17 -> "Good afternoon"
        else -> "Good evening"
    }
}

private fun alphaTodayDateLines(cases: List<AlphaCaseMatter>): List<String> =
    cases.mapNotNull { matter ->
        matter.nextHearing?.takeIf { alphaIsToday(it) }?.let { "Hearing today: ${matter.title}" }
    }

private fun alphaUpcomingDateLines(cases: List<AlphaCaseMatter>): List<String> =
    cases.mapNotNull { matter ->
        val rawDate = matter.nextHearing ?: return@mapNotNull null
        val instant = alphaParsedInstant(rawDate) ?: return@mapNotNull null
        matter.title to instant
    }
        .sortedBy { it.second }
        .map { (title, instant) ->
            "$title: ${alphaDateLabel(instant.toString())}"
        }

private fun alphaUpcomingDateCountThisWeek(cases: List<AlphaCaseMatter>): Int {
    val now = java.time.Instant.now()
    val weekAhead = now.plus(java.time.Duration.ofDays(7))
    return cases.count { matter ->
        val instant = alphaParsedInstant(matter.nextHearing) ?: return@count false
        instant >= now && instant <= weekAhead
    }
}

private fun alphaIsToday(rawDate: String?): Boolean {
    val instant = alphaParsedInstant(rawDate) ?: return false
    val zoneId = java.time.ZoneId.systemDefault()
    return instant.atZone(zoneId).toLocalDate() == java.time.LocalDate.now(zoneId)
}

private fun alphaDateLabel(rawDate: String): String {
    val instant = alphaParsedInstant(rawDate) ?: return rawDate.take(10)
    val formatter = java.time.format.DateTimeFormatter.ofPattern("d MMM yyyy")
    return instant.atZone(java.time.ZoneId.systemDefault()).format(formatter)
}

private fun alphaParsedInstant(rawDate: String?): java.time.Instant? {
    val value = rawDate?.trim().orEmpty()
    if (value.isEmpty()) return null
    runCatching { return java.time.Instant.parse(value) }

    val patterns = listOf(
        "yyyy-MM-dd",
        "d/M/yyyy",
        "dd/MM/yyyy",
        "d-M-yyyy",
        "dd-MM-yyyy",
        "d MMM yyyy",
        "dd MMM yyyy",
        "d MMMM yyyy",
        "dd MMMM yyyy",
    )
    val normalized = value.replace(",", "").replace(Regex("\\s+"), " ").trim()
    val zoneId = java.time.ZoneId.systemDefault()
    patterns.forEach { pattern ->
        val formatter = java.time.format.DateTimeFormatter.ofPattern(pattern, java.util.Locale.ENGLISH)
        runCatching {
            return java.time.LocalDate.parse(normalized, formatter).atStartOfDay(zoneId).toInstant()
        }
    }
    return null
}

private fun alphaRecentDocumentItems(cases: List<AlphaCaseMatter>, caseId: String? = null): List<AlphaRecentDocumentItem> {
    val visibleCases = caseId?.let { selectedId ->
        cases.filter { it.id == selectedId }
    } ?: cases

    return visibleCases
        .flatMap { caseMatter ->
            caseMatter.documents.map { document ->
                AlphaRecentDocumentItem(caseId = caseMatter.id, caseTitle = caseMatter.title, document = document)
            }
        }
        .sortedByDescending { it.document.importedAt }
}

private fun alphaBackgroundItems(controller: AlphaRossController): List<AlphaBackgroundWorkItem> {
    val packItems = controller.persisted.modelJobs.mapNotNull { job ->
        when (job.state) {
            AlphaDownloadState.Queued -> AlphaBackgroundWorkItem(
                id = job.id,
                title = "Setting up ${job.tier.title}",
                detail = "Ross has queued this assistant on this device.",
            )
            AlphaDownloadState.Downloading -> AlphaBackgroundWorkItem(
                id = job.id,
                title = "Downloading ${job.tier.title}",
                detail = "Ross is preparing this assistant while you keep working.",
            )
            AlphaDownloadState.Verifying -> AlphaBackgroundWorkItem(
                id = job.id,
                title = "Checking ${job.tier.title}",
                detail = "Ross is finishing the setup before the assistant becomes ready.",
            )
            AlphaDownloadState.PausedWaitingForWifi -> AlphaBackgroundWorkItem(
                id = job.id,
                title = "Waiting for Wi-Fi",
                detail = "${job.tier.title} will continue when Wi-Fi is available.",
            )
            else -> null
        }
    }

    val documentItems = controller.persisted.cases.flatMap { caseMatter ->
        caseMatter.documents.mapNotNull { document ->
            when (document.extractionRuns.firstOrNull()?.status) {
                AlphaExtractionRunStatus.Queued -> AlphaBackgroundWorkItem(
                    id = document.id,
                    title = "Waiting to read ${document.title}",
                    detail = "Ross will read this file for ${caseMatter.title} on this device.",
                )
                AlphaExtractionRunStatus.Running -> AlphaBackgroundWorkItem(
                    id = document.id,
                    title = "Reading ${document.title}",
                    detail = "Ross is reviewing this file for ${caseMatter.title}.",
                )
                else -> null
            }
        }
    }

    return packItems + documentItems
}

private fun alphaPrivateAiStatus(controller: AlphaRossController): Pair<String, String> {
    val activePack = controller.activePack()
    val activeJob = controller.persisted.modelJobs.firstOrNull()
    val runtimeHealth = controller.activeRuntimeHealth()

    return when {
        activeJob?.state == AlphaDownloadState.Downloading ->
            "Setting up assistant" to "Ross is preparing a private assistant on this device. You can keep working while it finishes."
        activeJob?.state == AlphaDownloadState.PausedWaitingForWifi ->
            "Waiting for Wi-Fi" to "Ross will resume the private assistant setup when Wi-Fi is available."
        activeJob?.state == AlphaDownloadState.Failed ->
            "Assistant needs attention" to "Ross could not finish the private assistant setup."
        activePack != null && runtimeHealth?.fallbackActive == true ->
            "Basic local mode" to "A private assistant is installed, but Ross is using the lighter local mode right now."
        activePack != null ->
            "Assistant ready" to "${activePack.tier.title} is ready for private on-device review."
        else ->
            "Basic local mode" to "Ross can organize files now. Install the assistant for stronger private review on this device."
    }
}

private fun alphaJobStatusLabel(state: AlphaDownloadState): String = when (state) {
    AlphaDownloadState.Downloading -> "Downloading"
    AlphaDownloadState.PausedWaitingForWifi -> "Waiting for Wi-Fi"
    AlphaDownloadState.Verifying -> "Checking download"
    AlphaDownloadState.Installed -> "Ready"
    AlphaDownloadState.Failed, AlphaDownloadState.PausedError -> "Needs attention"
    AlphaDownloadState.Queued -> "Queued"
    AlphaDownloadState.PausedUser -> "Paused"
    AlphaDownloadState.PausedNoStorage -> "Needs storage"
    AlphaDownloadState.Cancelled -> "Cancelled"
    AlphaDownloadState.NotStarted -> "Not installed"
}

private fun Boolean.thenCompleted(): String = if (this) "Completed" else "Needs attention"
