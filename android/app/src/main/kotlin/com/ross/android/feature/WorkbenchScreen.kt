package com.ross.android.feature

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.ross.android.core.model.AdvocateCaseSummary
import com.ross.android.core.model.CaseWorkspace
import com.ross.android.core.model.DownloadSession
import com.ross.android.core.model.InstantModeBanner
import com.ross.android.core.model.PrivacyLedgerEntry
import com.ross.android.core.model.PublicLawPreview
import com.ross.android.core.model.SettingsSnapshot
import com.ross.android.core.model.WorkbenchSection
import com.ross.android.theme.RossHighlight

@Composable
fun WorkbenchScreen(
    state: WorkbenchUiState,
    onSectionSelected: (WorkbenchSection) -> Unit,
    onCaseSelected: (String) -> Unit,
    onCaptureHeadlineChanged: (String) -> Unit,
    onCaptureBodyChanged: (String) -> Unit,
    onSaveCapture: () -> Unit,
    onLawQueryChanged: (String) -> Unit,
    onRunLawPreview: () -> Unit,
    onUpdateSettings: ((SettingsSnapshot) -> SettingsSnapshot) -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Ross Workbench", style = MaterialTheme.typography.titleLarge)
                        Text(
                            text = "Private-first case operations",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
            )
        },
    ) { innerPadding ->
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .padding(innerPadding),
        ) {
            val wideLayout = maxWidth >= 900.dp
            val contentModifier = Modifier
                .fillMaxWidth()
                .widthIn(max = 1180.dp)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 20.dp)

            if (wideLayout) {
                Row(
                    modifier = contentModifier,
                    horizontalArrangement = Arrangement.spacedBy(32.dp),
                ) {
                    Column(
                        modifier = Modifier.weight(1.2f),
                        verticalArrangement = Arrangement.spacedBy(24.dp),
                    ) {
                        WorkbenchHeaderDeck(
                            instantModeBanner = state.instantModeBanner,
                            downloadSession = state.downloadSession,
                        )
                        SectionSelector(
                            activeSection = state.activeSection,
                            onSectionSelected = onSectionSelected,
                        )
                    }

                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(24.dp),
                    ) {
                        ActiveSectionPane(
                            state = state,
                            onSectionSelected = onSectionSelected,
                            onCaseSelected = onCaseSelected,
                            onCaptureHeadlineChanged = onCaptureHeadlineChanged,
                            onCaptureBodyChanged = onCaptureBodyChanged,
                            onSaveCapture = onSaveCapture,
                            onLawQueryChanged = onLawQueryChanged,
                            onRunLawPreview = onRunLawPreview,
                            onUpdateSettings = onUpdateSettings,
                        )
                    }
                }
            } else {
                Column(
                    modifier = contentModifier.widthIn(max = 720.dp),
                    verticalArrangement = Arrangement.spacedBy(24.dp),
                ) {
                    WorkbenchHeaderDeck(
                        instantModeBanner = state.instantModeBanner,
                        downloadSession = state.downloadSession,
                    )
                    SectionSelector(
                        activeSection = state.activeSection,
                        onSectionSelected = onSectionSelected,
                    )
                    ActiveSectionPane(
                        state = state,
                        onSectionSelected = onSectionSelected,
                        onCaseSelected = onCaseSelected,
                        onCaptureHeadlineChanged = onCaptureHeadlineChanged,
                        onCaptureBodyChanged = onCaptureBodyChanged,
                        onSaveCapture = onSaveCapture,
                        onLawQueryChanged = onLawQueryChanged,
                        onRunLawPreview = onRunLawPreview,
                        onUpdateSettings = onUpdateSettings,
                    )
                }
            }
        }
    }
}

@Composable
private fun WorkbenchHeaderDeck(
    instantModeBanner: InstantModeBanner?,
    downloadSession: DownloadSession?,
) {
    instantModeBanner?.let { banner ->
        HeroCard(
            eyebrow = "Instant Mode",
            title = banner.title,
            body = banner.body,
        )
    }

    downloadSession?.let { session ->
        SectionCard(
            title = "Private AI Pack",
            subtitle = "Background delivery stays visible and resumable.",
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                MetricCard(
                    label = "Pack",
                    value = session.publicName,
                    modifier = Modifier.weight(1f),
                )
                MetricCard(
                    label = "State",
                    value = session.phase.name.lowercase().replaceFirstChar(Char::titlecase),
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = session.progressNote,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = if (session.resumable) "Resumable after interruptions." else "Restart may be required if the transfer fails.",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.secondary,
            )
        }
    }
}

@Composable
private fun SectionSelector(
    activeSection: WorkbenchSection,
    onSectionSelected: (WorkbenchSection) -> Unit,
) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        items(WorkbenchSection.entries) { section ->
            FilterChip(
                selected = activeSection == section,
                onClick = { onSectionSelected(section) },
                label = { Text(section.label) },
                shape = RoundedCornerShape(8.dp)
            )
        }
    }
}

@Composable
private fun ActiveSectionPane(
    state: WorkbenchUiState,
    onSectionSelected: (WorkbenchSection) -> Unit,
    onCaseSelected: (String) -> Unit,
    onCaptureHeadlineChanged: (String) -> Unit,
    onCaptureBodyChanged: (String) -> Unit,
    onSaveCapture: () -> Unit,
    onLawQueryChanged: (String) -> Unit,
    onRunLawPreview: () -> Unit,
    onUpdateSettings: ((SettingsSnapshot) -> SettingsSnapshot) -> Unit,
) {
    when (state.activeSection) {
        WorkbenchSection.Cases -> CasesPane(
            state = state,
            onCaseSelected = onCaseSelected,
            onSectionSelected = onSectionSelected,
        )

        WorkbenchSection.Capture -> CapturePane(
            state = state,
            onHeadlineChanged = onCaptureHeadlineChanged,
            onBodyChanged = onCaptureBodyChanged,
            onSave = onSaveCapture,
        )

        WorkbenchSection.Law -> LawPane(
            state = state,
            onLawQueryChanged = onLawQueryChanged,
            onRunLawPreview = onRunLawPreview,
        )

        WorkbenchSection.Ledger -> LedgerPane(state = state)
        WorkbenchSection.Settings -> SettingsPane(
            settings = state.settings,
            onUpdateSettings = onUpdateSettings,
        )
    }
}

@Composable
private fun CasesPane(
    state: WorkbenchUiState,
    onCaseSelected: (String) -> Unit,
    onSectionSelected: (WorkbenchSection) -> Unit,
) {
    val selectedCase = state.cases.firstOrNull { it.id == state.selectedCaseId } ?: state.cases.firstOrNull()

    Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
        HeroCard(
            eyebrow = selectedCase?.urgencyLabel ?: "Case desk",
            title = selectedCase?.title ?: "No active matter selected",
            body = selectedCase?.nextStep
                ?: "Pick a matter to open the local dashboard and review the current next step.",
        )

        SectionCard(
            title = "Open matters",
            subtitle = "Switch quickly between active files without losing the current dashboard context.",
        ) {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                items(state.cases) { caseSummary ->
                    CaseRailCard(
                        caseSummary = caseSummary,
                        selected = caseSummary.id == state.selectedCaseId,
                        onSelect = { onCaseSelected(caseSummary.id) },
                    )
                }
            }
        }

        selectedCase?.let { caseSummary ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                MetricCard(
                    label = "Sensitivity",
                    value = caseSummary.sensitivity,
                    modifier = Modifier.weight(1f),
                )
                MetricCard(
                    label = "Urgency",
                    value = caseSummary.urgencyLabel,
                    modifier = Modifier.weight(1f),
                )
            }
        }

        SectionCard(
            title = "Active workspace",
            subtitle = "A concise working view of the matter, with the next actions closer than the raw bundle.",
        ) {
            Text(
                text = state.workspace.summary,
                style = MaterialTheme.typography.bodyLarge,
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Parties: ${state.workspace.parties}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(20.dp))
            TwoColumnLists(
                leftTitle = "Upcoming tasks",
                leftItems = state.workspace.upcomingTasks,
                rightTitle = "Legal questions",
                rightItems = state.workspace.legalQuestions,
            )
        }

        SectionCard(
            title = "Next actions",
            subtitle = "Move directly into the two common follow-up tasks for the selected case.",
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Button(
                    onClick = { onSectionSelected(WorkbenchSection.Capture) },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("Open Quick Capture")
                }
                Button(
                    onClick = { onSectionSelected(WorkbenchSection.Law) },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("Check Public Law")
                }
            }
        }
    }
}

@Composable
private fun CapturePane(
    state: WorkbenchUiState,
    onHeadlineChanged: (String) -> Unit,
    onBodyChanged: (String) -> Unit,
    onSave: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
        HeroCard(
            eyebrow = "Quick capture",
            title = "Stage paper notes and annexure details before they disappear into the day.",
            body = state.captureDraft.promptHint,
        )

        SectionCard(
            title = "Capture draft",
            subtitle = "Keep the note terse and local, then file it back into the matter.",
        ) {
            OutlinedTextField(
                value = state.captureDraft.headline,
                onValueChange = onHeadlineChanged,
                label = { Text("Capture label") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                shape = RoundedCornerShape(8.dp)
            )
            Spacer(modifier = Modifier.height(16.dp))
            OutlinedTextField(
                value = state.captureDraft.body,
                onValueChange = onBodyChanged,
                label = { Text("Notes") },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp),
                shape = RoundedCornerShape(8.dp)
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = state.captureDraft.sensitivityLabel,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.tertiary,
            )
            Spacer(modifier = Modifier.height(16.dp))
            Button(
                onClick = onSave,
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("Save locally")
            }
        }
    }
}

@Composable
private fun LawPane(
    state: WorkbenchUiState,
    onLawQueryChanged: (String) -> Unit,
    onRunLawPreview: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
        HeroCard(
            eyebrow = "Public boundary",
            title = "Preview the public-law query before any network request leaves the device.",
            body = "This surface is for neutral legal topics only. It stays separate from the private case workspace.",
        )

        SectionCard(
            title = "Sanitized query preview",
            subtitle = "Use neutral legal language instead of case facts, names, or file content.",
        ) {
            OutlinedTextField(
                value = state.lawQuery,
                onValueChange = onLawQueryChanged,
                label = { Text("Preview topic") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                shape = RoundedCornerShape(8.dp)
            )
            Spacer(modifier = Modifier.height(16.dp))
            Button(
                onClick = onRunLawPreview,
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("Run safe preview")
            }
        }

        PublicLawResultCard(preview = state.lawPreview)
    }
}

@Composable
private fun LedgerPane(state: WorkbenchUiState) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            text = "Privacy ledger",
            style = MaterialTheme.typography.titleLarge,
        )
        state.ledgerEntries.forEach { entry ->
            SectionCard(
                title = entry.title,
                subtitle = "${entry.occurredAt} • ${entry.locality.label}",
            ) {
                Text(
                    text = entry.detail,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
    }
}

@Composable
private fun SettingsPane(
    settings: SettingsSnapshot,
    onUpdateSettings: ((SettingsSnapshot) -> SettingsSnapshot) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            text = "Settings",
            style = MaterialTheme.typography.titleLarge,
        )
        SettingToggleRow(
            title = "Allow instant mode",
            body = "Keep lightweight intake tools available while heavier packs stage in the background.",
            checked = settings.instantModeAllowed,
            onCheckedChange = { checked ->
                onUpdateSettings { current -> current.copy(instantModeAllowed = checked) }
            },
        )
        SettingToggleRow(
            title = "Require biometric gate",
            body = "Prompt for device auth before returning to the workbench after backgrounding.",
            checked = settings.biometricGateEnabled,
            onCheckedChange = { checked ->
                onUpdateSettings { current -> current.copy(biometricGateEnabled = checked) }
            },
        )
        SettingToggleRow(
            title = "Escort network requests",
            body = "Keep outward requests limited to law previews and setup checks that exclude case facts.",
            checked = settings.escortNetworkRequests,
            onCheckedChange = { checked ->
                onUpdateSettings { current -> current.copy(escortNetworkRequests = checked) }
            },
        )
        SettingToggleRow(
            title = "Wi-Fi only downloads",
            body = "Reserve staged local pack downloads for unmetered connections when possible.",
            checked = settings.wifiOnlyDownloads,
            onCheckedChange = { checked ->
                onUpdateSettings { current -> current.copy(wifiOnlyDownloads = checked) }
            },
        )
    }
}

@Composable
private fun SettingToggleRow(
    title: String,
    body: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    SectionCard(
        title = title,
        subtitle = body,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
        ) {
            Text(
                text = if (checked) "Enabled" else "Disabled",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.secondary,
            )
            Switch(
                checked = checked,
                onCheckedChange = onCheckedChange,
            )
        }
    }
}

@Composable
private fun SectionCard(
    title: String,
    subtitle: String,
    content: @Composable () -> Unit,
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth().animateContentSize(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.outlinedCardColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
    ) {
        Column(
            modifier = Modifier.padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(8.dp))
            content()
        }
    }
}

@Composable
private fun HeroCard(
    eyebrow: String,
    title: String,
    body: String,
) {
    Surface(
        color = MaterialTheme.colorScheme.primaryContainer,
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(28.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = eyebrow.uppercase(),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.secondary,
            )
            Text(
                text = title,
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.onPrimaryContainer,
            )
            Text(
                text = body,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.88f),
            )
        }
    }
}

@Composable
private fun MetricCard(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier,
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
        shape = RoundedCornerShape(12.dp),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = label.uppercase(),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}

@Composable
private fun CaseRailCard(
    caseSummary: AdvocateCaseSummary,
    selected: Boolean,
    onSelect: () -> Unit,
) {
    val containerColor = if (selected) {
        MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
    } else {
        MaterialTheme.colorScheme.surface
    }

    OutlinedCard(
        modifier = Modifier.widthIn(min = 260.dp, max = 280.dp),
        onClick = onSelect,
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = containerColor),
        border = BorderStroke(
            width = if (selected) 2.dp else 1.dp,
            color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline.copy(alpha = 0.5f),
        ),
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = caseSummary.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = "${caseSummary.urgencyLabel} • ${caseSummary.sensitivity}",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.secondary,
            )
            Text(
                text = caseSummary.nextStep,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun TwoColumnLists(
    leftTitle: String,
    leftItems: List<String>,
    rightTitle: String,
    rightItems: List<String>,
) {
    BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
        val wideLayout = maxWidth >= 700.dp

        if (wideLayout) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                BulletListCard(
                    title = leftTitle,
                    items = leftItems,
                    modifier = Modifier.weight(1f),
                )
                BulletListCard(
                    title = rightTitle,
                    items = rightItems,
                    modifier = Modifier.weight(1f),
                )
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                BulletListCard(
                    title = leftTitle,
                    items = leftItems,
                )
                BulletListCard(
                    title = rightTitle,
                    items = rightItems,
                )
            }
        }
    }
}

@Composable
private fun BulletListCard(
    title: String,
    items: List<String>,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
        shape = RoundedCornerShape(12.dp),
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            items.forEach { item ->
                Text(
                    text = "• $item",
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
    }
}

@Composable
private fun PublicLawResultCard(preview: PublicLawPreview) {
    SectionCard(
        title = preview.title,
        subtitle = preview.jurisdiction,
    ) {
        Text(
            text = preview.summary,
            style = MaterialTheme.typography.bodyMedium,
        )
        Spacer(modifier = Modifier.height(12.dp))
        preview.highlights.forEach { highlight ->
            Text("• $highlight", style = MaterialTheme.typography.bodyMedium)
        }
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = preview.cautionLabel,
            style = MaterialTheme.typography.labelLarge,
            color = RossHighlight,
        )
    }
}
