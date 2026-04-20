package com.ross.android.feature

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ross.android.core.model.AdvocateCaseSummary
import com.ross.android.core.model.CaptureDraft
import com.ross.android.core.model.PrivacyLedgerEntry
import com.ross.android.core.model.SettingsSnapshot
import com.ross.android.core.model.WorkbenchSection

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
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = state.activeSection == WorkbenchSection.Cases,
                    onClick = { onSectionSelected(WorkbenchSection.Cases) },
                    icon = { Icon(Icons.Default.Folder, contentDescription = null) },
                    label = { Text("Cases") },
                )
                NavigationBarItem(
                    selected = state.activeSection == WorkbenchSection.Capture,
                    onClick = { onSectionSelected(WorkbenchSection.Capture) },
                    icon = { Icon(Icons.Default.Edit, contentDescription = null) },
                    label = { Text("Capture") },
                )
                NavigationBarItem(
                    selected = state.activeSection in listOf(
                        WorkbenchSection.Law,
                        WorkbenchSection.Ledger,
                        WorkbenchSection.Settings,
                    ),
                    onClick = { onSectionSelected(WorkbenchSection.Settings) },
                    icon = { Icon(Icons.Default.MoreHoriz, contentDescription = null) },
                    label = { Text("More") },
                )
            }
        },
    ) { innerPadding ->
        when (state.activeSection) {
            WorkbenchSection.Cases -> CasesPane(
                state = state,
                onCaseSelected = onCaseSelected,
                onSectionSelected = onSectionSelected,
                modifier = Modifier.padding(innerPadding),
            )

            WorkbenchSection.Capture -> CapturePane(
                state = state,
                onHeadlineChanged = onCaptureHeadlineChanged,
                onBodyChanged = onCaptureBodyChanged,
                onSave = onSaveCapture,
                modifier = Modifier.padding(innerPadding),
            )

            WorkbenchSection.Law,
            WorkbenchSection.Ledger,
            WorkbenchSection.Settings -> MorePane(
                state = state,
                onNavigate = onSectionSelected,
                onLawQueryChanged = onLawQueryChanged,
                onRunLawPreview = onRunLawPreview,
                onUpdateSettings = onUpdateSettings,
                modifier = Modifier.padding(innerPadding),
            )
        }
    }
}

// ── Cases pane — no scroll, single screen ─────────────────────────────────────

@Composable
private fun CasesPane(
    state: WorkbenchUiState,
    onCaseSelected: (String) -> Unit,
    onSectionSelected: (WorkbenchSection) -> Unit,
    modifier: Modifier = Modifier,
) {
    val selectedCase = state.cases.firstOrNull { it.id == state.selectedCaseId }
        ?: state.cases.firstOrNull()

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp),
    ) {
        // Court · Stage line
        Text(
            text = (selectedCase?.urgencyLabel ?: "").uppercase(),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
            letterSpacing = 0.6.sp,
            modifier = Modifier.padding(top = 20.dp),
        )

        Spacer(modifier = Modifier.weight(1f))

        // Case title
        Text(
            text = selectedCase?.title ?: "No matter selected",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )

        Spacer(modifier = Modifier.height(4.dp))

        // Next step as the primary content
        Text(
            text = selectedCase?.nextStep ?: "Select a matter to get started.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(modifier = Modifier.weight(1f))

        HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp), alpha = 0.3f)

        Spacer(modifier = Modifier.weight(1f))

        // Things to do label
        Text(
            text = "THINGS TO DO",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
            letterSpacing = 0.6.sp,
        )
        Spacer(modifier = Modifier.height(8.dp))

        state.workspace.upcomingTasks.take(2).forEach { task ->
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(bottom = 6.dp),
            ) {
                Text("·", color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f))
                Text(task, style = MaterialTheme.typography.bodyMedium)
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp), alpha = 0.3f)

        Spacer(modifier = Modifier.height(16.dp))

        // Primary action
        Button(
            onClick = { /* Ask Ross — handled by the host via a dialog/bottom sheet */ },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
        ) {
            Text("Ask Ross", style = MaterialTheme.typography.titleSmall)
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Secondary text links
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(onClick = { onSectionSelected(WorkbenchSection.Capture) }) {
                Text("Capture a note", style = MaterialTheme.typography.bodySmall)
            }
            Text(
                "·",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
            )
            TextButton(onClick = { onSectionSelected(WorkbenchSection.Law) }) {
                Text("Documents", style = MaterialTheme.typography.bodySmall)
            }
        }

        Spacer(modifier = Modifier.height(8.dp))
    }
}

// ── Capture pane — keyboard-first, no scroll ──────────────────────────────────

@Composable
private fun CapturePane(
    state: WorkbenchUiState,
    onHeadlineChanged: (String) -> Unit,
    onBodyChanged: (String) -> Unit,
    onSave: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        OutlinedTextField(
            value = state.captureDraft.body,
            onValueChange = onBodyChanged,
            placeholder = {
                Text(
                    "What happened?",
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                )
            },
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            shape = RoundedCornerShape(12.dp),
        )

        // Case selector — inline, minimal
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Filing to:",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            )
            Text(
                state.cases.firstOrNull { it.id == state.selectedCaseId }?.title
                    ?: "Select a matter",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.primary,
            )
        }

        Button(
            onClick = onSave,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
        ) {
            Text("Save to case")
        }

        TextButton(
            onClick = { /* save for later */ },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(
                "Save for later",
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.45f),
            )
        }
    }
}

// ── More pane — plain list of destinations ────────────────────────────────────

@Composable
private fun MorePane(
    state: WorkbenchUiState,
    onNavigate: (WorkbenchSection) -> Unit,
    onLawQueryChanged: (String) -> Unit,
    onRunLawPreview: () -> Unit,
    onUpdateSettings: ((SettingsSnapshot) -> SettingsSnapshot) -> Unit,
    modifier: Modifier = Modifier,
) {
    // Show nested content when a sub-section is active, otherwise show the list
    when (state.activeSection) {
        WorkbenchSection.Law -> LawPane(
            state = state,
            onLawQueryChanged = onLawQueryChanged,
            onRunLawPreview = onRunLawPreview,
            modifier = modifier,
        )
        WorkbenchSection.Ledger -> LedgerPane(state = state, modifier = modifier)
        WorkbenchSection.Settings -> SettingsPane(
            settings = state.settings,
            onUpdateSettings = onUpdateSettings,
            modifier = modifier,
        )
        else -> MoreMenuPane(onNavigate = onNavigate, modifier = modifier)
    }
}

@Composable
private fun MoreMenuPane(
    onNavigate: (WorkbenchSection) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 24.dp),
    ) {
        MoreRow("Documents", Icons.Default.Description, onClick = { onNavigate(WorkbenchSection.Law) })
        HorizontalDivider(alpha = 0.2f)
        MoreRow("Look up a law", Icons.Default.Search, onClick = { onNavigate(WorkbenchSection.Law) })
        HorizontalDivider(alpha = 0.2f)
        MoreRow("Activity log", Icons.Default.History, onClick = { onNavigate(WorkbenchSection.Ledger) })
        Spacer(modifier = Modifier.height(24.dp))
        HorizontalDivider(alpha = 0.2f)
        MoreRow("Settings", Icons.Default.Settings, onClick = { onNavigate(WorkbenchSection.Settings) })
    }
}

@Composable
private fun MoreRow(
    title: String,
    icon: ImageVector,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                icon,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            )
            Text(title, style = MaterialTheme.typography.bodyLarge)
        }
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
        )
    }
}

// ── Law pane ──────────────────────────────────────────────────────────────────

@Composable
private fun LawPane(
    state: WorkbenchUiState,
    onLawQueryChanged: (String) -> Unit,
    onRunLawPreview: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = "Look up a law",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = "Ross removes your case details before searching.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        OutlinedTextField(
            value = state.lawQuery,
            onValueChange = onLawQueryChanged,
            label = { Text("What legal topic do you want to look up?") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            shape = RoundedCornerShape(8.dp),
        )
        Button(
            onClick = onRunLawPreview,
            shape = RoundedCornerShape(12.dp),
        ) {
            Text("Check before searching")
        }
        Text(
            text = state.lawPreview.summary,
            style = MaterialTheme.typography.bodyMedium,
        )
        state.lawPreview.highlights.forEach { highlight ->
            Text("· $highlight", style = MaterialTheme.typography.bodyMedium)
        }
        Text(
            text = state.lawPreview.cautionLabel,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.secondary,
        )
    }
}

// ── Ledger pane ───────────────────────────────────────────────────────────────

@Composable
private fun LedgerPane(
    state: WorkbenchUiState,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp),
    ) {
        Text(
            text = "Activity",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(bottom = 16.dp),
        )
        LazyColumn(verticalArrangement = Arrangement.spacedBy(0.dp)) {
            items(state.ledgerEntries) { entry ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(entry.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                        Text(
                            "${entry.occurredAt} · ${entry.locality.label}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                HorizontalDivider(alpha = 0.15f)
            }
        }
    }
}

// ── Settings pane ─────────────────────────────────────────────────────────────

@Composable
private fun SettingsPane(
    settings: SettingsSnapshot,
    onUpdateSettings: ((SettingsSnapshot) -> SettingsSnapshot) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp),
    ) {
        Text(
            text = "Settings",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(bottom = 16.dp),
        )
        SettingToggleRow(
            title = "Enable quick responses",
            body = "Keeps Ross responsive while larger files load in the background.",
            checked = settings.instantModeAllowed,
            onCheckedChange = { checked ->
                onUpdateSettings { current -> current.copy(instantModeAllowed = checked) }
            },
        )
        HorizontalDivider(alpha = 0.15f)
        SettingToggleRow(
            title = "Lock with fingerprint / Face unlock",
            body = "Asks for device unlock when returning to Ross.",
            checked = settings.biometricGateEnabled,
            onCheckedChange = { checked ->
                onUpdateSettings { current -> current.copy(biometricGateEnabled = checked) }
            },
        )
        HorizontalDivider(alpha = 0.15f)
        SettingToggleRow(
            title = "Only use internet for law search",
            body = "Ross will not send anything online except when you look up a law.",
            checked = settings.escortNetworkRequests,
            onCheckedChange = { checked ->
                onUpdateSettings { current -> current.copy(escortNetworkRequests = checked) }
            },
        )
        HorizontalDivider(alpha = 0.15f)
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
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 16.dp)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
            Text(body, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
