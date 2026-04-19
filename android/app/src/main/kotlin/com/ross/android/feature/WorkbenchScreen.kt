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
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
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

@OptIn(ExperimentalMaterial3Api::class)
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
            eyebrow = "Quick responses",
            title = banner.title,
            body = banner.body,
        )
    }

    downloadSession?.let { session ->
        SectionCard(
            title = "Assistant setup",
            subtitle = "Your assistant is downloading. You can use Ross in the meantime.",
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                MetricCard(
                    label = "Assistant",
                    value = session.publicName,
                    modifier = Modifier.weight(1f),
                )
                MetricCard(
                    label = "State",
                    value = session.phase.displayTitle,
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
                text = if (session.resumable) {
                    "Download will continue automatically."
                } else {
                    "If it stops, open Settings to restart."
                },
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
        items(WorkbenchSection.entries.filterNot { it == WorkbenchSection.Law }) { section ->
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
                ?: "Tap any matter below to open it.",
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

        SectionCard(
            title = "Case summary",
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
            subtitle = null,
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
                    Text("File a note")
                }
                Button(
                    onClick = { onSectionSelected(WorkbenchSection.Law) },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("Look up a law")
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
            title = "Jot something down before you forget it.",
            body = "You can move it into the right case later.",
        )

        SectionCard(
            title = "New note",
            subtitle = "Write a quick note now and file it to a case later.",
        ) {
            OutlinedTextField(
                value = state.captureDraft.headline,
                onValueChange = onHeadlineChanged,
                label = { Text("What is this about?") },
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
            eyebrow = "Look up a law",
            title = "Preview what Ross will search before anything goes online.",
            body = "This screen is only for general legal topics. Your case notes stay on this phone.",
        )

        SectionCard(
            title = "What legal topic do you want to look up?",
            subtitle = "Ross removes your case details before searching.",
        ) {
            OutlinedTextField(
                value = state.lawQuery,
                onValueChange = onLawQueryChanged,
                label = { Text("Law topic") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                shape = RoundedCornerShape(8.dp)
            )
            Spacer(modifier = Modifier.height(16.dp))
            Button(
                onClick = onRunLawPreview,
                shape = RoundedCornerShape(12.dp)
            ) {
                Text("Check before searching")
            }
        }

        PublicLawResultCard(preview = state.lawPreview)
    }
}

@Composable
private fun LedgerPane(state: WorkbenchUiState) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            text = "Activity",
            style = MaterialTheme.typography.titleLarge,
        )
        state.ledgerEntries.forEachIndexed { index, entry ->
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = entry.title,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium,
                    )
                    Text(
                        text = entry.occurredAt,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(
                    text = entry.locality.label,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.secondary,
                )
                Text(
                    text = entry.detail,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (index != state.ledgerEntries.lastIndex) {
                HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.35f))
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
            title = "Enable quick responses",
            body = "Keeps Ross responsive while larger files load in the background.",
            checked = settings.instantModeAllowed,
            onCheckedChange = { checked ->
                onUpdateSettings { current -> current.copy(instantModeAllowed = checked) }
            },
        )
        SettingToggleRow(
            title = "Lock with fingerprint / Face unlock",
            body = "Asks for device unlock when returning to Ross.",
            checked = settings.biometricGateEnabled,
            onCheckedChange = { checked ->
                onUpdateSettings { current -> current.copy(biometricGateEnabled = checked) }
            },
        )
        SettingToggleRow(
            title = "Only use internet for law search",
            body = "Ross will not send anything online except when you look up a law.",
            checked = settings.escortNetworkRequests,
            onCheckedChange = { checked ->
                onUpdateSettings { current -> current.copy(escortNetworkRequests = checked) }
            },
        )
        SettingToggleRow(
            title = "Download on Wi-Fi only",
            body = "Ross will only download its assistant files on Wi-Fi.",
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
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(end = 16.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
            )
            Text(
                text = body,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
        )
    }
}

@Composable
private fun SectionCard(
    title: String,
    subtitle: String? = null,
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
            if (!subtitle.isNullOrBlank()) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(modifier = Modifier.height(8.dp))
            }
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
            color = MaterialTheme.colorScheme.secondary,
        )
    }
}
