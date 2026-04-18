package com.privatedigitalclerk.android.feature

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CardDefaults
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
import com.privatedigitalclerk.android.core.model.SettingsSnapshot
import com.privatedigitalclerk.android.core.model.WorkbenchSection

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
                        Text("Advocate Workbench")
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .verticalScroll(rememberScrollState())
                .padding(innerPadding)
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            state.instantModeBanner?.let { banner ->
                Surface(
                    color = MaterialTheme.colorScheme.secondaryContainer,
                    shape = RoundedCornerShape(24.dp),
                ) {
                    Column(
                        modifier = Modifier.padding(18.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Text(
                            text = banner.title,
                            style = MaterialTheme.typography.titleMedium,
                        )
                        Text(
                            text = banner.body,
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
            }

            state.downloadSession?.let { session ->
                OutlinedCard(
                    colors = CardDefaults.outlinedCardColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
                ) {
                    Column(
                        modifier = Modifier.padding(18.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = "Local pack setup: ${session.publicName}",
                            style = MaterialTheme.typography.titleMedium,
                        )
                        Text(
                            text = session.progressNote,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(
                            text = "Resumable: ${if (session.resumable) "Yes" else "No"}",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.tertiary,
                        )
                    }
                }
            }

            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(WorkbenchSection.entries) { section ->
                    FilterChip(
                        selected = state.activeSection == section,
                        onClick = { onSectionSelected(section) },
                        label = { Text(section.label) },
                    )
                }
            }

            when (state.activeSection) {
                WorkbenchSection.Cases -> CasesPane(
                    state = state,
                    onCaseSelected = onCaseSelected,
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
    }
}

@Composable
private fun CasesPane(
    state: WorkbenchUiState,
    onCaseSelected: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            text = "Case list",
            style = MaterialTheme.typography.titleLarge,
        )
        state.cases.forEach { caseSummary ->
            val selected = caseSummary.id == state.selectedCaseId
            OutlinedCard(
                modifier = Modifier.fillMaxWidth(),
                onClick = { onCaseSelected(caseSummary.id) },
            ) {
                Column(
                    modifier = Modifier.padding(18.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = caseSummary.title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                    )
                    Text(
                        text = "${caseSummary.urgencyLabel} • ${caseSummary.sensitivity}",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                    Text(
                        text = caseSummary.nextStep,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }
        }

        HorizontalDivider()

        Text(
            text = "Active workspace",
            style = MaterialTheme.typography.titleLarge,
        )
        OutlinedCard {
            Column(
                modifier = Modifier.padding(18.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    text = state.workspace.summary,
                    style = MaterialTheme.typography.bodyLarge,
                )
                Text(
                    text = "Parties: ${state.workspace.parties}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = "Upcoming tasks",
                    style = MaterialTheme.typography.titleMedium,
                )
                state.workspace.upcomingTasks.forEach { task ->
                    Text("• $task", style = MaterialTheme.typography.bodyMedium)
                }
                Text(
                    text = "Legal questions",
                    style = MaterialTheme.typography.titleMedium,
                )
                state.workspace.legalQuestions.forEach { question ->
                    Text("• $question", style = MaterialTheme.typography.bodyMedium)
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
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            text = "Quick capture",
            style = MaterialTheme.typography.titleLarge,
        )
        Text(
            text = state.captureDraft.promptHint,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        OutlinedTextField(
            value = state.captureDraft.headline,
            onValueChange = onHeadlineChanged,
            label = { Text("Capture label") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
        OutlinedTextField(
            value = state.captureDraft.body,
            onValueChange = onBodyChanged,
            label = { Text("Notes") },
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp),
        )
        Text(
            text = state.captureDraft.sensitivityLabel,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.tertiary,
        )
        Button(onClick = onSave) {
            Text("Save locally")
        }
    }
}

@Composable
private fun LawPane(
    state: WorkbenchUiState,
    onLawQueryChanged: (String) -> Unit,
    onRunLawPreview: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            text = "Public-law preview",
            style = MaterialTheme.typography.titleLarge,
        )
        Text(
            text = "This surface crosses the network boundary without carrying case notes or client identifiers.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        OutlinedTextField(
            value = state.lawQuery,
            onValueChange = onLawQueryChanged,
            label = { Text("Preview topic") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
        Button(onClick = onRunLawPreview) {
            Text("Run safe preview")
        }
        OutlinedCard {
            Column(
                modifier = Modifier.padding(18.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = state.lawPreview.title,
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = state.lawPreview.jurisdiction,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.secondary,
                )
                Text(
                    text = state.lawPreview.summary,
                    style = MaterialTheme.typography.bodyMedium,
                )
                state.lawPreview.highlights.forEach { highlight ->
                    Text("• $highlight", style = MaterialTheme.typography.bodyMedium)
                }
                Text(
                    text = state.lawPreview.cautionLabel,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.tertiary,
                )
            }
        }
    }
}

@Composable
private fun LedgerPane(state: WorkbenchUiState) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            text = "Privacy ledger",
            style = MaterialTheme.typography.titleLarge,
        )
        state.ledgerEntries.forEach { entry ->
            OutlinedCard {
                Column(
                    modifier = Modifier.padding(18.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        text = entry.title,
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Text(
                        text = "${entry.occurredAt} • ${entry.locality.label}",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.secondary,
                    )
                    Text(
                        text = entry.detail,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }
        }
    }
}

@Composable
private fun SettingsPane(
    settings: SettingsSnapshot,
    onUpdateSettings: ((SettingsSnapshot) -> SettingsSnapshot) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
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
    OutlinedCard {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(18.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(text = title, style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = body,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            Switch(
                checked = checked,
                onCheckedChange = onCheckedChange,
            )
        }
    }
}
