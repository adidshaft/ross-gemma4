package com.ross.android.alpha

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import android.text.format.Formatter
import com.ross.android.R
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.annotation.DrawableRes
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.Button
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.ui.draw.shadow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.ross.android.theme.RossTheme
import java.io.File
import java.util.Locale
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val alphaScreenPadding = 18.dp
private val alphaSectionSpacing = 14.dp
private val alphaCardCornerRadius = 16.dp
private val alphaCompactCornerRadius = 14.dp
private val alphaGlassCornerRadius = 24.dp
private val alphaPillCornerRadius = 999.dp
private val AlphaAmberStatus = Color(0xFFC7A766)

private data class AlphaStorageSnapshot(
    val documentCount: Int,
    val exportCount: Int,
    val documentBytes: Long,
    val exportBytes: Long,
    val assistantBytes: Long,
) {
    val totalBytes: Long
        get() = documentBytes + exportBytes + assistantBytes
}
private val AlphaSuccessStatus = Color(0xFFA1BAAE)
private const val alphaUiPrefsName = "ross_alpha_ui_prefs"
private const val alphaMatterListSortModePrefKey = "matter_list_sort_mode"
private const val alphaMatterListViewModePrefKey = "matter_list_view_mode"

private fun alphaStoredMatterListSortMode(rawValue: String?): AlphaCaseSortMode =
    AlphaCaseSortMode.values().firstOrNull { it.storageValue == rawValue } ?: AlphaCaseSortMode.RecentlyViewed

private fun alphaStoredMatterListViewMode(rawValue: String?): AlphaMatterListViewMode =
    AlphaMatterListViewMode.values().firstOrNull { it.storageValue == rawValue } ?: AlphaMatterListViewMode.Expanded

private enum class RossGlassAsset(@DrawableRes val resId: Int) {
    BadgeSparkleAccent(R.drawable.ng_accent_badge_sparkle),
    CircleInfoHighlight(R.drawable.ng_highlight_circle_info),
    DocFolderNeutral(R.drawable.ng_neutral_doc_folder),
    EarthHighlight(R.drawable.ng_highlight_earth),
    EarthNeutral(R.drawable.ng_neutral_earth),
    FileNeutral(R.drawable.ng_neutral_file),
    FileUploadAccent(R.drawable.ng_accent_file_upload),
    FilesNeutral(R.drawable.ng_neutral_files),
    FolderNeutral(R.drawable.ng_neutral_folder),
    GearKeyholeAccent(R.drawable.ng_accent_gear_keyhole),
    GearKeyholeNeutral(R.drawable.ng_neutral_gear_keyhole),
    RefreshAccent(R.drawable.ng_accent_refresh),
    SparkleAccent(R.drawable.ng_accent_sparkle_3),
    TimelineVerticalNeutral(R.drawable.ng_neutral_timeline_vertical),
    BookOpenNeutral(R.drawable.ng_neutral_book_open),
    UserMsgAccent(R.drawable.ng_accent_user_msg),
}

@Composable
private fun RossGlassIcon(
    asset: RossGlassAsset,
    label: String? = null,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Fit,
) {
    Image(
        painter = painterResource(id = asset.resId),
        contentDescription = label,
        modifier = modifier,
        contentScale = contentScale,
    )
}

@Composable
private fun AlphaLaunchSplash() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .alphaAuthBackdrop(),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Image(
                painter = painterResource(id = R.drawable.ross_logo),
                contentDescription = "Ross",
                modifier = Modifier.size(112.dp),
                contentScale = ContentScale.Fit,
            )
            Text(
                "ROSS",
                style = MaterialTheme.typography.titleLarge.copy(letterSpacing = 3.sp),
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                "Private legal work, on this phone.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun Modifier.alphaAuthBackdrop(): Modifier =
    background(
        Brush.linearGradient(
            colors = listOf(
                MaterialTheme.colorScheme.background,
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.72f),
                MaterialTheme.colorScheme.background,
            )
        )
    )

@Composable
private fun AlphaAuthPanel(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    OutlinedCard(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(alphaGlassCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = alphaChromeBackgroundColor()),
        border = androidx.compose.foundation.BorderStroke(1.dp, alphaChromeStrokeColor()),
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = content,
        )
    }
}

@Composable
private fun AlphaAuthNotice(text: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.48f), RoundedCornerShape(alphaCompactCornerRadius))
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f), RoundedCornerShape(alphaCompactCornerRadius))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(
            imageVector = Icons.Outlined.WarningAmber,
            contentDescription = null,
            modifier = Modifier.size(18.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun AlphaAuthBrandRow(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            painter = painterResource(id = R.drawable.ross_logo),
            contentDescription = "Ross",
            modifier = Modifier.size(58.dp),
            contentScale = ContentScale.Fit,
        )
        Text(
            "ROSS",
            style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 3.2.sp),
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary,
        )
        Spacer(modifier = Modifier.weight(1f))
    }
}

@Composable
private fun AlphaAuthHeroCard(modifier: Modifier = Modifier) {
    AlphaAuthPanel(modifier = modifier) {
        Text(
            "Private legal work.\nOn this phone.",
            style = MaterialTheme.typography.displaySmall.copy(
                fontWeight = FontWeight.Normal,
                fontSize = 34.sp,
                lineHeight = 40.sp,
            ),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.96f),
        )
        Text(
            "Your matters stay private on this device.",
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

private data class AlphaRecentDocumentItem(
    val caseId: String,
    val caseTitle: String,
    val document: AlphaCaseDocument,
)

@Composable
fun AlphaRossApp() {
    val context = LocalContext.current.applicationContext
    val hostActivity = LocalContext.current as? FragmentActivity
    val lifecycleOwner = LocalLifecycleOwner.current
    val controller = remember(context) { AlphaRossController(context) }
    val darkTheme = when (controller.persisted.settings.appearanceMode) {
        AlphaAppearanceMode.Auto -> isSystemInDarkTheme()
        AlphaAppearanceMode.Dark -> true
        AlphaAppearanceMode.Light -> false
    }
    val latestController by rememberUpdatedState(controller)
    val backStack = remember { mutableStateListOf(controller.startRoute()) }
    var showLaunchSplash by rememberSaveable { mutableStateOf(true) }
    val currentRoute = backStack.lastOrNull() ?: controller.startRoute()

    fun push(route: AndroidAlphaRoute) {
        backStack += route
    }

    fun replaceWith(route: AndroidAlphaRoute) {
        backStack.clear()
        backStack += route
    }

    fun goBackOrHome() {
        if (backStack.size > 1) {
            backStack.removeLast()
        } else {
            replaceWith(AndroidAlphaRoute.Home)
        }
    }

    LaunchedEffect(controller.pendingRoute) {
        controller.pendingRoute?.let { route ->
            backStack += route
            controller.consumePendingRoute()
        }
    }

    LaunchedEffect(currentRoute) {
        controller.clearStaleAskState(currentRoute)
    }

    LaunchedEffect(Unit) {
        delay(1150)
        showLaunchSplash = false
    }

    LaunchedEffect(hostActivity?.intent?.dataString) {
        val redirect = hostActivity?.intent?.data
        if (latestController.consumeGoogleSignInRedirect(redirect)) {
            hostActivity?.intent?.let { intent -> intent.data = null }
        }
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) {
                latestController.lockSessionForQuickUnlock()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    BackHandler(enabled = backStack.size > 1 || currentRoute == AndroidAlphaRoute.Settings) {
        goBackOrHome()
    }

    RossTheme(darkTheme = darkTheme) {
        Box(modifier = Modifier.fillMaxSize()) {
            when (currentRoute) {
            AndroidAlphaRoute.Onboarding -> AlphaOnboardingScreen(
                onSetup = {
                    controller.selectedTier = controller.recommendedOnDeviceTier()
                    controller.finishPackSetup()
                    replaceWith(AndroidAlphaRoute.Home)
                },
                onSkip = {
                    controller.skipPackSetup()
                    replaceWith(AndroidAlphaRoute.Home)
                },
            )

            AndroidAlphaRoute.Home -> AlphaFeedScreen(
                    controller = controller,
                    onCreateCase = { push(AndroidAlphaRoute.CreateCase) },
                    onOpenAsk = { push(AndroidAlphaRoute.AskRoss) },
                    onOpenSettings = { push(AndroidAlphaRoute.Settings) },
                    onOpenCase = { caseId ->
                        controller.focusCase(caseId)
                        push(AndroidAlphaRoute.CaseWorkspace(caseId))
                    },
                )

            AndroidAlphaRoute.CreateCase -> AlphaCreateCaseScreen(
                controller = controller,
                onCreated = { _ ->
                    replaceWith(AndroidAlphaRoute.Home)
                },
                onBack = { backStack.removeLast() },
            )

            AndroidAlphaRoute.AskRoss -> AlphaAskConversationScreen(
                controller = controller,
                fixedScopeCaseId = null,
                showBack = true,
                onBack = { backStack.removeLast() },
                onOpenSource = { source ->
                    push(AndroidAlphaRoute.DocumentViewer(source.caseId, source.documentId, source.pageNumber))
                },
            )

            is AndroidAlphaRoute.CaseWorkspace -> AlphaCaseWorkspaceScreen(
                controller = controller,
                caseId = currentRoute.caseId,
                onBack = { backStack.removeLast() },
                onOpenDocuments = { push(AndroidAlphaRoute.DocumentList(currentRoute.caseId)) },
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
                onAskCase = { controller.openAsk(currentRoute.caseId) },
            )

            is AndroidAlphaRoute.DocumentViewer -> AlphaDocumentViewerScreen(
                controller = controller,
                caseId = currentRoute.caseId,
                documentId = currentRoute.documentId,
                pageNumber = currentRoute.pageNumber,
                onOpenPrivateAi = { push(AndroidAlphaRoute.PrivateAiSettings) },
                onAskCase = { controller.openAsk(currentRoute.caseId) },
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
                onBack = { backStack.removeLast() },
            )

            is AndroidAlphaRoute.DraftsExports -> AlphaExportsScreen(
                controller = controller,
                caseId = currentRoute.caseId,
                onBack = { backStack.removeLast() },
            )

            AndroidAlphaRoute.PrivacyLedger -> AlphaPrivacyLedgerScreen(
                controller = controller,
                onBack = { backStack.removeLast() },
            )

            AndroidAlphaRoute.Settings -> AlphaSettingsScreen(
                    controller = controller,
                    onBack = { goBackOrHome() },
                    onOpenLedger = { push(AndroidAlphaRoute.PrivacyLedger) },
                    onOpenPrivateAi = { push(AndroidAlphaRoute.PrivateAiSettings) },
                )

                AndroidAlphaRoute.PrivateAiSettings -> AlphaPrivateAiSettingsScreen(
                    controller = controller,
                    onBack = { backStack.removeLast() },
                )
            }

            AnimatedVisibility(
                visible = showLaunchSplash,
                exit = slideOutVertically(targetOffsetY = { -it }) + fadeOut(),
            ) {
                AlphaLaunchSplash()
            }

            if (!controller.persisted.accountSession.isSignedIn) {
                AlphaLaunchAuthGate(controller = controller)
            }

            if (controller.persisted.accountSession.locked && controller.persisted.accountSession.isSignedIn) {
                AlphaQuickUnlockGate(
                    session = controller.persisted.accountSession,
                    onUnlock = { controller.unlockSession() },
                    onSignOut = { controller.signOutAccountSession() },
                )
            }
        }
    }
}

@Composable
private fun AlphaShell(
    title: String,
    showTopBar: Boolean = true,
    showBack: Boolean = false,
    onBack: (() -> Unit)? = null,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    actions: (@Composable RowScope.() -> Unit)? = null,
    topContent: (@Composable () -> Unit)? = null,
    bottomBar: (@Composable () -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    Scaffold(
        topBar = {
            if (showTopBar) {
                AlphaTopBar(
                    title = title,
                    showBack = showBack,
                    onBack = onBack,
                    actionLabel = actionLabel,
                    onAction = onAction,
                    actions = actions,
                )
            }
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
            topContent?.invoke()
            Box(modifier = Modifier.weight(1f, fill = true)) {
                content()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AlphaTopBar(
    title: String,
    showBack: Boolean,
    onBack: (() -> Unit)?,
    actionLabel: String?,
    onAction: (() -> Unit)?,
    actions: (@Composable RowScope.() -> Unit)?,
) {
    TopAppBar(
        title = { Text(title, style = MaterialTheme.typography.titleLarge) },
        navigationIcon = {
            if (showBack && onBack != null) {
                AlphaChromeIconButton(
                    icon = Icons.AutoMirrored.Outlined.ArrowBack,
                    label = "Back",
                    onClick = onBack,
                    modifier = Modifier.padding(start = 12.dp),
                )
            }
        },
        actions = {
            if (actions != null) {
                actions()
            } else if (actionLabel != null && onAction != null) {
                AlphaChromeIconButton(
                    icon = if (actionLabel.equals("Ask", ignoreCase = true)) {
                        Icons.Outlined.ChatBubbleOutline
                    } else {
                        Icons.Outlined.ChevronRight
                    },
                    label = actionLabel,
                    onClick = onAction,
                    modifier = Modifier.padding(end = 6.dp),
                )
            }
        }
    )
}

@Composable
private fun AlphaChromeIconButton(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val haptics = LocalHapticFeedback.current
    OutlinedCard(
        modifier = modifier,
        shape = RoundedCornerShape(999.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = alphaChromeBackgroundColor().copy(alpha = 0.94f)),
        border = androidx.compose.foundation.BorderStroke(1.dp, alphaChromeStrokeColor()),
        onClick = {
            haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            onClick()
        },
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            tint = MaterialTheme.colorScheme.onSurface,
        )
    }
}

@Composable
private fun alphaChromeBackgroundColor(): Color =
    MaterialTheme.colorScheme.surface.copy(
        alpha = if (MaterialTheme.colorScheme.background.luminance() < 0.3f) 0.92f else 0.96f
    )

@Composable
private fun alphaChromeForegroundColor(): Color =
    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.96f)

@Composable
private fun alphaChromeMutedColor(): Color =
    MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.92f)

@Composable
private fun alphaChromeStrokeColor(): Color =
    MaterialTheme.colorScheme.outline.copy(
        alpha = if (MaterialTheme.colorScheme.background.luminance() < 0.3f) 0.4f else 0.22f
    )

@Composable
private fun AlphaRootTopRail(
    onOpenSettings: (() -> Unit)? = null,
    onCreateCase: (() -> Unit)? = null,
    onOpenAsk: (() -> Unit)? = null,
    showBack: Boolean = false,
    onBack: (() -> Unit)? = null,
    title: String = "Ross",
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = 12.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (showBack && onBack != null) {
            AlphaChromeIconButton(
                icon = Icons.AutoMirrored.Outlined.ArrowBack,
                label = "Back",
                onClick = onBack,
            )
            AlphaRootTitlePill(
                title = title,
                modifier = Modifier.weight(1f),
            )
        } else {
            AlphaRootStrip(
                modifier = Modifier.widthIn(min = 118.dp, max = 176.dp),
                title = title,
            )
            Spacer(modifier = Modifier.weight(1f))
            if (onOpenAsk != null) {
                AlphaChromeIconButton(
                    icon = Icons.Outlined.Edit,
                    label = "Compose",
                    onClick = onOpenAsk,
                )
            }
            if (onCreateCase != null) {
                AlphaChromeIconButton(
                    icon = Icons.Outlined.Add,
                    label = "Create matter",
                    onClick = onCreateCase,
                )
            }
            if (onOpenSettings != null) {
                AlphaChromeIconButton(
                    icon = Icons.Outlined.Settings,
                    label = "Settings",
                    onClick = onOpenSettings,
                )
            }
        }
    }
}

@Composable
private fun AlphaRootTitlePill(title: String, modifier: Modifier = Modifier) {
    OutlinedCard(
        modifier = modifier,
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = alphaChromeBackgroundColor()),
        border = androidx.compose.foundation.BorderStroke(1.dp, alphaChromeStrokeColor()),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp)
                .padding(horizontal = 14.dp),
            contentAlignment = Alignment.CenterStart,
        ) {
            Text(
                title,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = alphaChromeForegroundColor(),
            )
        }
    }
}

@Composable
private fun AlphaRootStrip(
    title: String,
    modifier: Modifier = Modifier,
) {
    val chromeBackground = alphaChromeBackgroundColor()
    val chromeForeground = alphaChromeForegroundColor()

    OutlinedCard(
        modifier = modifier,
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = chromeBackground),
        border = androidx.compose.foundation.BorderStroke(1.dp, alphaChromeStrokeColor()),
    ) {
        Box(
            modifier = Modifier
                .height(44.dp)
                .padding(horizontal = 14.dp),
            contentAlignment = Alignment.CenterStart,
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Image(
                    painter = painterResource(id = R.drawable.ross_logo),
                    contentDescription = null,
                    modifier = Modifier.size(22.dp),
                    contentScale = ContentScale.Fit,
                )
                Text(
                    title,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = chromeForeground,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AlphaRootAskDock(
    controller: AlphaRossController,
    fixedScopeCaseId: String? = null,
    fixedDocumentIds: Set<String> = emptySet(),
) {
    var showTools by remember { mutableStateOf(false) }
    var dismissedInlineQuestion by rememberSaveable { mutableStateOf<String?>(null) }
    var expandedComposer by rememberSaveable { mutableStateOf(false) }
    var dockExpanded by rememberSaveable { mutableStateOf(false) }
    var pendingCollapseQuestion by rememberSaveable { mutableStateOf<String?>(null) }
    var focusComposerAfterExpand by rememberSaveable { mutableStateOf(false) }
    var isComposerFocused by remember { mutableStateOf(false) }
    val focusRequester = remember { FocusRequester() }
    val keyboardController = LocalSoftwareKeyboardController.current
    val activeScopeCaseId = fixedScopeCaseId ?: controller.askSelectedScopeCaseId
    val activeSelectedDocuments = if (fixedDocumentIds.isEmpty()) {
        controller.selectedAskDocuments(activeScopeCaseId)
    } else {
        controller.selectedAskDocuments(activeScopeCaseId).filter { it.id in fixedDocumentIds }
    }
    val inlineResult = controller.latestAskResult?.takeUnless {
        dismissedInlineQuestion == it.question ||
            it.scopeCaseId != activeScopeCaseId ||
            (fixedDocumentIds.isNotEmpty() && it.selectedDocumentTitles.toSet() != activeSelectedDocuments.map { document -> document.title }.toSet())
    }
    val chromeBackground = alphaChromeBackgroundColor()
    val chromeForeground = alphaChromeForegroundColor()
    val chromeMuted = alphaChromeMutedColor()
    val isDarkTheme = MaterialTheme.colorScheme.background.luminance() < 0.3f
    val storedDraftText = controller.askDraft(activeScopeCaseId)
    val usesHindiUi = alphaUsesHindiUi()
    var localDraftText by rememberSaveable(
        activeScopeCaseId ?: "all_work",
        fixedDocumentIds.sorted().joinToString(","),
    ) {
        mutableStateOf(storedDraftText)
    }
    val draftText = localDraftText
    val composerPlaceholder = when {
        usesHindiUi && fixedDocumentIds.size == 1 -> "Ross से इस फ़ाइल के बारे में पूछें..."
        usesHindiUi && activeScopeCaseId != null -> "Ross से इस मामले के बारे में पूछें..."
        usesHindiUi -> "Ross से आज, किसी मामले, या किसी फ़ाइल के बारे में पूछें..."
        fixedDocumentIds.size == 1 -> "Ask Ross about this file..."
        activeScopeCaseId != null -> "Ask Ross about this matter..."
        else -> "Ask Ross about today, a matter, or a file..."
    }
    val collapsedDockTitle = when {
        usesHindiUi && fixedDocumentIds.size == 1 -> "Ross से इस फ़ाइल के बारे में पूछें..."
        usesHindiUi && activeScopeCaseId != null -> "Ross से इस मामले के बारे में पूछें..."
        usesHindiUi -> "Ross से पूछें..."
        fixedDocumentIds.size == 1 -> "Ask Ross about this file..."
        activeScopeCaseId != null -> "Ask Ross about this matter..."
        else -> "Ask Ross..."
    }
    val showsCollapsedDock = !dockExpanded &&
        !showTools &&
        !expandedComposer &&
        draftText.trim().isEmpty()
    val fileLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        controller.importDocuments(activeScopeCaseId, uris)
    }
    val imageLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetMultipleContents()) { uris ->
        controller.importDocuments(activeScopeCaseId, uris)
    }
    val activeAskStatus = controller.askWorkStatus?.takeIf { status ->
        status.scopeCaseId == activeScopeCaseId
    }
    val haptics = LocalHapticFeedback.current

    fun expandDock(focusComposer: Boolean = false) {
        haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
        dockExpanded = true
        if (focusComposer) {
            focusComposerAfterExpand = true
        }
    }

    fun collapseDock() {
        dockExpanded = false
    }

    fun send() {
        val question = draftText.trim()
        if (question.isBlank()) return
        haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
        controller.setAskDraft(activeScopeCaseId, question)
        fixedDocumentIds.forEach { documentId ->
            if (documentId !in controller.selectedAskDocumentIds(activeScopeCaseId)) {
                controller.toggleAskDocumentSelection(activeScopeCaseId, documentId)
            }
        }
        dismissedInlineQuestion = null
        pendingCollapseQuestion = question
        controller.submitDockInput(
            question = question,
            scopeCaseId = activeScopeCaseId,
            webEnabled = controller.askWebEnabled,
        )
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (!isComposerFocused) {
            inlineResult?.let { result ->
                AlphaInlineAskResponseCard(
                result = result,
                contextDocumentTitle = if (fixedDocumentIds.size == 1) activeSelectedDocuments.firstOrNull()?.title else null,
                onOpenSource = { source ->
                    controller.focusCase(source.caseId)
                    controller.pendingRoute = AndroidAlphaRoute.DocumentViewer(source.caseId, source.documentId, source.pageNumber)
                },
                onOpenConversation = { controller.openAsk(activeScopeCaseId, fixedDocumentIds.singleOrNull()) },
                onReport = { controller.reportAiOutput(result.question, result.scopeCaseId) },
                onClose = { dismissedInlineQuestion = result.question },
            )
        }
        }

        activeAskStatus?.let { status ->
            AlphaAssistantActivityStrip(
                title = status.message,
                detail = status.detail,
                statusLabel = "Working",
                tint = MaterialTheme.colorScheme.primary,
                showProgress = true,
            )
        } ?: alphaActiveSetupJob(controller)?.let { job ->
            AlphaAssistantActivityStrip(
                title = "Private assistant setup",
                detail = alphaAssistantActivityDetail(job.state),
                statusLabel = alphaJobStatusLabel(job.state),
                tint = AlphaAmberStatus,
                progress = alphaJobProgressFraction(job),
                showProgress = true,
            )
        }

        if (showsCollapsedDock) {
            AlphaCollapsedAskDockPill(
                title = collapsedDockTitle,
                chromeBackground = chromeBackground,
                chromeForeground = chromeForeground,
            ) { expandDock(focusComposer = true) }
        } else {
            OutlinedCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .animateContentSize()
                    .shadow(
                        elevation = if (isDarkTheme) 18.dp else 14.dp,
                        shape = RoundedCornerShape(alphaCardCornerRadius),
                        ambientColor = if (isDarkTheme) Color.Black.copy(alpha = 0.30f) else Color.White.copy(alpha = 0.34f),
                        spotColor = if (isDarkTheme) Color.Black.copy(alpha = 0.36f) else Color.Black.copy(alpha = 0.12f),
                    ),
                shape = RoundedCornerShape(alphaCardCornerRadius),
                colors = CardDefaults.outlinedCardColors(
                    containerColor = chromeBackground.copy(alpha = if (isDarkTheme) 0.94f else 0.98f),
                ),
                border = androidx.compose.foundation.BorderStroke(
                    1.dp,
                    alphaChromeStrokeColor().copy(alpha = if (isDarkTheme) 0.96f else 0.82f),
                ),
                elevation = CardDefaults.outlinedCardElevation(
                    defaultElevation = if (isDarkTheme) 12.dp else 10.dp,
                    pressedElevation = if (isDarkTheme) 9.dp else 8.dp,
                ),
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 11.dp, vertical = 9.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        if (fixedScopeCaseId == null) {
                            AlphaRootScopeButton(
                                label = controller.scopeLabel(activeScopeCaseId),
                                tint = chromeForeground,
                            ) {
                                showTools = true
                            }
                        } else {
                            AlphaStaticScopePill(
                                label = controller.scopeLabel(activeScopeCaseId),
                                tint = chromeForeground,
                            )
                        }

                        if (controller.askWebEnabled) {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                RossGlassIcon(
                                    asset = RossGlassAsset.EarthHighlight,
                                    modifier = Modifier.size(14.dp),
                                )
                                Text(
                                    "Legal Search",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = chromeMuted,
                                )
                            }
                        }
                    }

                    if (activeSelectedDocuments.isNotEmpty() && fixedDocumentIds.size != 1) {
                        Row(
                            modifier = Modifier.horizontalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            activeSelectedDocuments.forEach { document ->
                                AlphaAskSelectionChip(title = document.title, isShared = document.isShared)
                            }
                        }
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        AlphaDockIconButton(
                            icon = Icons.Outlined.Add,
                            label = "Add files or tools",
                            tint = chromeForeground,
                        ) {
                            showTools = true
                        }

                        BasicTextField(
                            value = draftText,
                            onValueChange = { localDraftText = it },
                            modifier = Modifier
                                .weight(1f)
                                .focusRequester(focusRequester)
                                .onFocusChanged { isComposerFocused = it.isFocused },
                            textStyle = MaterialTheme.typography.bodySmall.copy(color = chromeForeground, lineHeight = 18.sp),
                            keyboardOptions = KeyboardOptions(
                                capitalization = KeyboardCapitalization.Sentences,
                                imeAction = ImeAction.Send,
                            ),
                            maxLines = if (expandedComposer) 8 else 2,
                            decorationBox = { innerTextField ->
                                Box(modifier = Modifier.padding(vertical = 8.dp)) {
                                    if (draftText.isBlank()) {
                                        Text(
                                            composerPlaceholder,
                                            style = MaterialTheme.typography.bodySmall,
                                            color = chromeMuted,
                                        )
                                    }
                                    innerTextField()
                                }
                            },
                        )

                        AlphaDockIconButton(
                            icon = if (expandedComposer) Icons.Outlined.UnfoldLess else Icons.Outlined.UnfoldMore,
                            label = if (expandedComposer) "Collapse composer" else "Expand composer",
                            tint = chromeForeground,
                        ) {
                            expandedComposer = !expandedComposer
                        }

                        AlphaDockIconButton(
                            icon = Icons.Outlined.ArrowUpward,
                            label = "Send",
                            tint = MaterialTheme.colorScheme.onPrimary,
                            fill = MaterialTheme.colorScheme.primary,
                        ) {
                            send()
                        }

                        AlphaDockIconButton(
                            icon = Icons.Outlined.ChatBubbleOutline,
                            asset = RossGlassAsset.UserMsgAccent,
                            label = "Open Ask Ross conversation",
                            tint = chromeForeground,
                        ) {
                            controller.openAsk(activeScopeCaseId, fixedDocumentIds.singleOrNull())
                        }
                    }

                    val selectionSubtitle = controller.askSelectionSubtitle(activeScopeCaseId)?.takeIf { fixedDocumentIds.isEmpty() }
                    if (selectionSubtitle != null) {
                        Text(
                            selectionSubtitle,
                            style = MaterialTheme.typography.labelSmall,
                            color = chromeMuted,
                        )
                    } else if (fixedDocumentIds.isEmpty()) {
                        Text(
                            "Type @ to add a file, or say add task / save date.",
                            style = MaterialTheme.typography.labelSmall,
                            color = chromeMuted,
                        )
                    }

                    if (controller.askWebEnabled) {
                        Text(
                            "Legal Search stays separate. Ross will show a sanitized query for review before anything is sent.",
                            style = MaterialTheme.typography.labelSmall,
                            color = chromeMuted,
                        )
                    }
                }
            }
        }
    }

    LaunchedEffect(draftText, showTools, expandedComposer) {
        val trimmed = draftText.trim()
        when {
            trimmed.isNotEmpty() && !dockExpanded -> expandDock()
            trimmed.isEmpty() && pendingCollapseQuestion == null && !showTools && !expandedComposer -> collapseDock()
        }
    }

    LaunchedEffect(focusComposerAfterExpand, showsCollapsedDock) {
        if (focusComposerAfterExpand && !showsCollapsedDock) {
            delay(120)
            focusRequester.requestFocus()
            keyboardController?.show()
            focusComposerAfterExpand = false
        }
    }

    LaunchedEffect(controller.latestAskResult) {
        val latestResult = controller.latestAskResult ?: return@LaunchedEffect
        if (pendingCollapseQuestion == latestResult.question && latestResult.scopeCaseId == activeScopeCaseId) {
            pendingCollapseQuestion = null
            controller.setAskDraft(activeScopeCaseId, "")
            localDraftText = ""
            collapseDock()
        }
    }

    LaunchedEffect(storedDraftText, activeScopeCaseId) {
        if (storedDraftText.isNotBlank() && localDraftText.isBlank()) {
            localDraftText = storedDraftText
        }
    }

    if (showTools) {
        ModalBottomSheet(
            onDismissRequest = { showTools = false },
            containerColor = MaterialTheme.colorScheme.surface,
            dragHandle = null,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text("Ask Ross", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                Text(
                    "Choose where Ross should work, add a file, and keep Legal Search separate.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )

                if (fixedScopeCaseId == null) {
                    AlphaCaseScopeSelector(
                        selectedCaseId = controller.askSelectedScopeCaseId,
                        cases = controller.cases,
                        allLabel = "All work",
                        includeAllCases = true,
                    ) { selectedCaseId ->
                        controller.askSelectedScopeCaseId = selectedCaseId
                    }
                } else {
                    AlphaStaticScopePill(
                        label = controller.scopeLabel(fixedScopeCaseId),
                        tint = MaterialTheme.colorScheme.onSurface,
                    )
                }

                AlphaRootAskSheetAction(
                    title = "Add file",
                    detail = if (activeScopeCaseId == null) {
                        "Add a PDF or note to shared files."
                    } else {
                        "Add a PDF or note to this matter."
                    },
                    accent = "Open",
                    asset = RossGlassAsset.FileUploadAccent,
                ) {
                    showTools = false
                    fileLauncher.launch(arrayOf("application/pdf", "text/plain"))
                }

                AlphaRootAskSheetAction(
                    title = "Add image",
                    detail = if (activeScopeCaseId == null) {
                        "Add a photo, scan, or screenshot to shared files."
                    } else {
                        "Add a photo, scan, or screenshot to this matter."
                    },
                    accent = "Open",
                    asset = RossGlassAsset.FilesNeutral,
                ) {
                    showTools = false
                    imageLauncher.launch("image/*")
                }

                AlphaRootAskSheetAction(
                    title = "Legal Search",
                    detail = if (controller.askWebEnabled) {
                        "On. Ross will create a sanitized query for review."
                    } else {
                        "Off. Ross stays fully local until you turn it on."
                    },
                    accent = if (controller.askWebEnabled) "On" else "Off",
                    asset = if (controller.askWebEnabled) RossGlassAsset.EarthHighlight else RossGlassAsset.EarthNeutral,
                ) {
                    controller.askWebEnabled = !controller.askWebEnabled
                }

                if (fixedDocumentIds.isEmpty()) {
                    Text(
                        "Use uploaded files",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    val availableDocuments = controller.availableAskDocuments(activeScopeCaseId)
                    if (availableDocuments.isEmpty()) {
                        Text(
                            "No files are ready here yet.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    } else {
                        availableDocuments.forEach { document ->
                            AlphaRootAskDocumentRow(
                                title = document.title,
                                detail = when {
                                    document.isShared -> "Shared file"
                                    activeScopeCaseId == null -> document.caseTitle
                                    else -> "This matter"
                                },
                                isSelected = document.id in controller.selectedAskDocumentIds(activeScopeCaseId),
                                asset = alphaDocumentAsset(document.kind),
                            ) {
                                controller.toggleAskDocumentSelection(activeScopeCaseId, document.id)
                            }
                        }
                    }
                }

                Text(
                "Ross will only send a sanitized legal search query. Your case files stay on this device.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )

                Spacer(modifier = Modifier.height(6.dp))
            }
        }
    }
}

@Composable
private fun AlphaCollapsedAskDockPill(
    title: String,
    chromeBackground: Color,
    chromeForeground: Color,
    onClick: () -> Unit,
) {
    val isDarkTheme = MaterialTheme.colorScheme.background.luminance() < 0.3f
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = if (isDarkTheme) 14.dp else 10.dp,
                shape = RoundedCornerShape(999.dp),
                ambientColor = if (isDarkTheme) Color.Black.copy(alpha = 0.28f) else Color.White.copy(alpha = 0.30f),
                spotColor = if (isDarkTheme) Color.Black.copy(alpha = 0.34f) else Color.Black.copy(alpha = 0.10f),
            ),
        shape = RoundedCornerShape(999.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = chromeBackground.copy(alpha = if (isDarkTheme) 0.94f else 0.98f)),
        border = androidx.compose.foundation.BorderStroke(1.dp, alphaChromeStrokeColor().copy(alpha = if (isDarkTheme) 0.96f else 0.82f)),
        elevation = CardDefaults.outlinedCardElevation(
            defaultElevation = if (isDarkTheme) 10.dp else 8.dp,
            pressedElevation = if (isDarkTheme) 7.dp else 6.dp,
        ),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .background(Color.White.copy(alpha = 0.1f), shape = RoundedCornerShape(999.dp)),
                contentAlignment = Alignment.Center,
            ) {
                RossGlassIcon(
                    asset = RossGlassAsset.BadgeSparkleAccent,
                    modifier = Modifier.size(16.dp),
                )
            }

            Text(
                title,
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = chromeForeground,
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun AlphaAskSelectionChip(title: String, isShared: Boolean) {
    OutlinedCard(
        shape = RoundedCornerShape(999.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = Color.White.copy(alpha = 0.08f)),
        border = androidx.compose.foundation.BorderStroke(0.dp, Color.Transparent),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            RossGlassIcon(
                asset = if (isShared) RossGlassAsset.EarthHighlight else RossGlassAsset.FolderNeutral,
                modifier = Modifier.size(12.dp),
            )
            Text(
                title,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = Color.White.copy(alpha = 0.78f),
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun AlphaRootAskDocumentRow(
    title: String,
    detail: String,
    isSelected: Boolean,
    asset: RossGlassAsset,
    onClick: () -> Unit,
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.16f)),
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            if (isSelected) MaterialTheme.colorScheme.primary.copy(alpha = 0.32f) else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f),
        ),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            RossGlassIcon(asset = asset, modifier = Modifier.size(28.dp))
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                Text(
                    detail,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (isSelected) {
                Icon(
                    imageVector = Icons.Outlined.CheckCircle,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
private fun AlphaRootScopeButton(label: String, tint: Color, onClick: () -> Unit) {
    OutlinedCard(
        shape = RoundedCornerShape(999.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = Color.White.copy(alpha = 0.08f)),
        border = androidx.compose.foundation.BorderStroke(0.dp, Color.Transparent),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 11.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(5.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = tint,
                maxLines = 1,
            )
            Icon(
                imageVector = Icons.Outlined.KeyboardArrowDown,
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(14.dp),
            )
        }
    }
}

@Composable
private fun AlphaStaticScopePill(label: String, tint: Color) {
    OutlinedCard(
        shape = RoundedCornerShape(999.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = Color.White.copy(alpha = 0.08f)),
        border = androidx.compose.foundation.BorderStroke(0.dp, Color.Transparent),
    ) {
        Text(
            label,
            modifier = Modifier.padding(horizontal = 11.dp, vertical = 7.dp),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = tint,
            maxLines = 1,
        )
    }
}

@Composable
private fun AlphaDockIconButton(
    icon: ImageVector? = null,
    asset: RossGlassAsset? = null,
    label: String,
    tint: Color,
    fill: Color = Color.White.copy(alpha = 0.08f),
    onClick: () -> Unit,
) {
    OutlinedCard(
        modifier = Modifier.size(40.dp),
        shape = RoundedCornerShape(999.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = fill),
        border = androidx.compose.foundation.BorderStroke(0.dp, Color.Transparent),
        onClick = onClick,
    ) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            if (asset != null) {
                RossGlassIcon(
                    asset = asset,
                    label = label,
                    modifier = Modifier.size(20.dp),
                )
            } else if (icon != null) {
                Icon(
                    imageVector = icon,
                    contentDescription = label,
                    modifier = Modifier.size(20.dp),
                    tint = tint,
                )
            }
        }
    }
}

@Composable
private fun AlphaInlineAskResponseCard(
    result: AlphaAskResult,
    contextDocumentTitle: String?,
    onOpenSource: (AlphaSourceRef) -> Unit,
    onOpenConversation: () -> Unit,
    onReport: () -> Unit,
    onClose: () -> Unit,
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)),
        shape = RoundedCornerShape(alphaCardCornerRadius)
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(verticalAlignment = Alignment.Top) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(result.answerTitle, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                    result.statusNote?.let { note ->
                        Text(note, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.tertiary)
                    }
                }
                AlphaChromeIconButton(icon = Icons.Outlined.Close, label = "Dismiss latest answer", onClick = onClose)
            }
            result.answerSections.take(2).forEach { section ->
                Text(section, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (result.caseFileSources.isNotEmpty()) {
                Text(
                    alphaSourceLabel(result.caseFileSources.first(), contextDocumentTitle),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.secondary,
                    modifier = Modifier.clickable { onOpenSource(result.caseFileSources.first()) },
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(onClick = onOpenConversation) {
                    Text("View full answer", color = MaterialTheme.colorScheme.tertiary)
                }
            }
        }
    }
}

@Composable
private fun AlphaRootAskSheetAction(
    title: String,
    detail: String,
    accent: String,
    asset: RossGlassAsset,
    onClick: () -> Unit,
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.16f)),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            RossGlassIcon(
                asset = asset,
                modifier = Modifier.size(28.dp),
            )

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                Text(
                    detail,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Box(
                modifier = Modifier
                    .background(
                        MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                        RoundedCornerShape(999.dp)
                    )
                    .padding(horizontal = 10.dp, vertical = 4.dp)
            ) {
                Text(
                    accent,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
private fun AlphaOnboardingScreen(onSetup: () -> Unit, onSkip: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .alphaAuthBackdrop()
            .padding(horizontal = 18.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .widthIn(max = 430.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            AlphaAuthBrandRow()
            AlphaAuthHeroCard()
            Button(onClick = onSetup, modifier = Modifier.fillMaxWidth()) {
                Text("Set up Ross")
            }
            TextButton(onClick = onSkip, modifier = Modifier.fillMaxWidth()) {
                Text("Skip for now")
            }
            Text(
                "Ross keeps matter files local and asks before Legal Search.",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun AlphaFeedScreen(
    controller: AlphaRossController,
    onCreateCase: () -> Unit,
    onOpenAsk: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenCase: (String) -> Unit,
) {
    var dueTodayExpanded by rememberSaveable { mutableStateOf(false) }
    var upcomingExpanded by rememberSaveable { mutableStateOf(false) }
    var recentFilesExpanded by rememberSaveable { mutableStateOf(false) }
    val visibleCases = controller.cases
    val todayDateLines = alphaTodayDateLines(visibleCases)
    val upcomingDateLines = alphaUpcomingDateLines(visibleCases)
    val recentDocuments = alphaRecentDocumentItems(visibleCases)
    val todayTasks = controller.todayTasks()
    val upcomingTasks = controller.upcomingTasks()
    val reviewItems = controller.reviewQueue()
    val attentionCount = todayDateLines.size + todayTasks.size + reviewItems.size
    val hasDueTodayItems = todayDateLines.isNotEmpty() || todayTasks.isNotEmpty()
    val hasUpcomingItems = upcomingDateLines.isNotEmpty() || upcomingTasks.isNotEmpty()
    val hasReviewItems = reviewItems.isNotEmpty()
    val hasRecentFiles = recentDocuments.isNotEmpty()
    val sortedCases = remember(visibleCases, controller.persisted.tasks) {
        alphaSortedCases(AlphaCaseSortMode.RecentlyViewed, visibleCases, controller)
    }

    AlphaShell(
        title = "Ross",
        showTopBar = false,
        topContent = {
            AlphaRootTopRail(
                onOpenSettings = onOpenSettings,
                onCreateCase = onCreateCase,
                onOpenAsk = onOpenAsk,
            )
        },
        bottomBar = {
            AlphaRootAskDock(
                controller = controller,
                fixedScopeCaseId = null,
            )
        },
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            AlphaHero(
                eyebrow = alphaGreeting(),
                title = alphaAttentionHeadline(attentionCount),
                body = if (visibleCases.isEmpty()) {
                    "Start by adding your first matter below."
                } else if (attentionCount == 0) {
                    "Nothing urgent is waiting. Ross grouped the day so the next action stays easy to spot."
                } else {
                    "Ross grouped today, nearby dates, and matter activity below so the next action stays obvious."
                },
                showLogo = false,
            )
            alphaActiveSetupJob(controller)?.let { activeJob ->
                AlphaAssistantActivityStrip(
                    title = "${activeJob.tier.title} is still preparing",
                    detail = alphaAssistantActivityDetail(activeJob.state),
                    statusLabel = alphaJobStatusLabel(activeJob.state),
                    tint = AlphaAmberStatus,
                    progress = alphaJobProgressFraction(activeJob),
                    showProgress = true,
                )
            }

            if (visibleCases.isEmpty()) {
                AlphaMatterStarterCard(controller = controller)
            } else {
                AlphaCard {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                if (visibleCases.size == 1) "1 matter on this device" else "${visibleCases.size} matters on this device",
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.SemiBold,
                            )
                            TextButton(onClick = onCreateCase) {
                                Text("New")
                            }
                        }
                        sortedCases.forEach { case ->
                            key(case.id) {
                                AlphaCaseSummaryRow(
                                    case = case,
                                    openTasks = controller.openTaskCount(case.id),
                                    reviewCount = controller.reviewQueue(case.id).size,
                                    onOpen = { onOpenCase(case.id) },
                                    onLongPress = {},
                                )
                            }
                        }
                    }
                }
            }

            if (hasDueTodayItems) {
                AlphaExpandableCard(
                    title = "Today",
                    badge = "${todayDateLines.size + todayTasks.size}",
                    expanded = dueTodayExpanded,
                    onToggle = { dueTodayExpanded = !dueTodayExpanded },
                ) {
                    todayDateLines.take(3).forEach { line ->
                        AlphaSummaryRow(title = line, detail = "Needs attention today")
                    }
                    todayTasks.take(4 - todayDateLines.size.coerceAtMost(4)).forEach { task ->
                        AlphaTaskRow(task = task, onToggle = { controller.toggleTaskDone(task.id) })
                    }
                }
            }

            if (hasUpcomingItems) {
                AlphaExpandableCard(
                    title = "Upcoming dates",
                    badge = "${upcomingDateLines.size + upcomingTasks.size}",
                    expanded = upcomingExpanded,
                    onToggle = { upcomingExpanded = !upcomingExpanded },
                ) {
                    upcomingDateLines.take(4).forEach { line ->
                        AlphaSummaryRow(title = line, detail = "Saved in your matter dates")
                    }
                    upcomingTasks.take(2).forEach { task ->
                        AlphaTaskRow(task = task, onToggle = { controller.toggleTaskDone(task.id) })
                    }
                }
            }

            if (hasReviewItems) {
                AlphaCard {
                    AlphaSectionLabel("Needs review", "Accept, edit, or dismiss extracted facts before Ross relies on them.")
                    reviewItems.take(4).forEach { item ->
                        AlphaReviewNudgeCard(
                            item = item,
                            controller = controller,
                            onEditFallback = {
                                controller.pendingRoute = AndroidAlphaRoute.DocumentViewer(item.caseId, item.documentId, item.sourceRef?.pageNumber)
                            },
                        )
                    }
                }
            }

            if (hasRecentFiles) {
                AlphaExpandableCard(
                    title = "Recent files",
                    badge = "${recentDocuments.size}",
                    expanded = recentFilesExpanded,
                    onToggle = { recentFilesExpanded = !recentFilesExpanded },
                ) {
                    recentDocuments.take(4).forEach { entry ->
                        AlphaDocumentSummaryRow(
                            caseTitle = entry.caseTitle,
                            document = entry.document,
                            onOpen = {
                                controller.focusCase(entry.caseId)
                                controller.pendingRoute = AndroidAlphaRoute.DocumentViewer(entry.caseId, entry.document.id, 1)
                            },
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

@Composable
private fun AlphaCreateCaseScreen(controller: AlphaRossController, onCreated: (String) -> Unit, onBack: () -> Unit) {
    AlphaShell(title = "Create Matter", showBack = true, onBack = onBack) {
        Column(modifier = Modifier.padding(alphaScreenPadding), verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)) {
            OutlinedTextField(
                value = controller.caseDraftTitle,
                onValueChange = { controller.caseDraftTitle = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Matter name") },
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences)
            )
            Button(
                onClick = { controller.createCase(openWorkspace = false)?.let(onCreated) },
                modifier = Modifier.fillMaxWidth(),
                enabled = controller.caseDraftTitle.isNotBlank()
            ) { Text("Create matter") }
        }
    }
}

@Composable
private fun AlphaCaseWorkspaceScreen(
    controller: AlphaRossController,
    caseId: String,
    onBack: () -> Unit,
    onOpenDocuments: () -> Unit,
    onOpenExports: () -> Unit,
    onOpenSource: (AlphaSourceRef) -> Unit,
) {
    var documentLayoutMode by rememberSaveable { mutableStateOf(AlphaDocumentLayoutMode.Grid) }
    var expandedDocumentIds by rememberSaveable { mutableStateOf(setOf<String>()) }
    var selectedSection by rememberSaveable { mutableStateOf(AlphaWorkspaceSection.Documents) }
    val case = controller.persisted.cases.firstOrNull { it.id == caseId }
    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        controller.importDocuments(caseId, uris)
    }
    val haptics = LocalHapticFeedback.current
    AlphaShell(
        title = "Case",
        showBack = true,
        onBack = onBack,
        bottomBar = {
            AlphaRootAskDock(controller = controller, fixedScopeCaseId = caseId)
        },
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            case?.let {
                val reviewItems = controller.reviewQueue(caseId)
                val openTaskCount = controller.openTaskCount(caseId)
                val matterTasks = controller.tasks(caseId)
                val scheduledDates = controller.scheduledMatterDates(caseId)
                val matterExports = controller.persisted.exports.filter { export -> export.caseId == caseId }
                AlphaInlineHeader(
                    eyebrow = it.forum,
                    title = it.title,
                    detail = "${it.stage.displayTitle} · ${it.documents.size} documents · $openTaskCount open tasks",
                )

                AlphaMatterAttentionCard(
                    case = it,
                    matterTasks = matterTasks,
                    reviewItems = reviewItems,
                    isRefreshing = controller.isRefreshingCaseOverview(caseId),
                    onRefresh = { controller.refreshCaseOverview(caseId) },
                )

                AlphaWorkspaceSectionBar(
                    selectedSection = selectedSection,
                    onSelect = { section ->
                        haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        selectedSection = section
                    },
                    fileBadgeCount = it.documents.size,
                    taskBadgeCount = openTaskCount + scheduledDates.size,
                    reviewBadgeCount = reviewItems.size,
                    draftBadgeCount = matterExports.size,
                )

                if (selectedSection == AlphaWorkspaceSection.Documents) {
                AlphaCard {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                "${it.documents.size} file(s) on this matter",
                                modifier = Modifier.weight(1f),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            AlphaDocumentLayoutMenu(
                                layoutMode = documentLayoutMode,
                                onSelect = { documentLayoutMode = it },
                            )
                        }

                        Button(
                            onClick = { importer.launch(arrayOf("application/pdf", "image/*", "text/plain")) },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("Import document")
                        }

                        if (it.documents.isEmpty()) {
                            Text("No documents yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        } else {
                            AlphaDocumentBrowser(
                                documents = it.documents,
                                caseTitle = null,
                                layoutMode = documentLayoutMode,
                                expandedDocumentIds = expandedDocumentIds,
                                onExpandedDocumentIdsChange = { expandedDocumentIds = it },
                                onOpen = { documentId ->
                                    controller.pendingRoute = AndroidAlphaRoute.DocumentViewer(caseId, documentId, 1)
                                },
                                onMoveDocument = { documentId, offset ->
                                    controller.moveDocument(caseId, documentId, offset)
                                },
                            )
                        }
                    }
                }
                }

                if (selectedSection == AlphaWorkspaceSection.NotesExports) {
                AlphaCard {
                    if (scheduledDates.isEmpty() && matterTasks.isEmpty()) {
                        AlphaSectionCommandHintCard(
                            detail = "Use Ask Ross below to add tasks, save hearing dates, and draft notes.",
                            actionLabel = "Refresh matter overview with Ross",
                            actionIcon = Icons.Outlined.Refresh,
                            actionDisabled = controller.isRefreshingCaseOverview(caseId),
                            onAction = { controller.refreshCaseOverview(caseId) },
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                    }
                    AlphaSectionLabel("Dates & Tasks", "Hearings, filing deadlines, compliance dates, follow-ups, and local work items.")
                    if (scheduledDates.isEmpty()) {
                        Text("No dates saved yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    } else {
                        scheduledDates.forEach { matterDate ->
                            AlphaMatterDateRow(
                                matterDate = matterDate,
                                onMarkDone = { controller.setMatterDateStatus(caseId, matterDate.id, AlphaMatterDateStatus.Done) },
                                onCancel = { controller.setMatterDateStatus(caseId, matterDate.id, AlphaMatterDateStatus.Cancelled) },
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                        }
                    }
                    matterTasks.forEach { task ->
                        AlphaTaskRow(
                            task = task,
                            onToggle = {
                                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                controller.toggleTaskDone(task.id)
                            },
                            onSnooze = if (task.status == AlphaTaskStatus.Open) {
                                { controller.snoozeTask(task.id, 1) }
                            } else {
                                null
                            },
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                    if (matterTasks.isEmpty()) {
                        Text("No open tasks yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                }

                if (selectedSection == AlphaWorkspaceSection.NotesExports) {
                AlphaCard {
                    AlphaSectionLabel("Review", "Accept, edit, or ignore extracted facts before Ross can rely on them.")
                    reviewItems.forEach { item ->
                        AlphaReviewNudgeCard(
                            item = item,
                            controller = controller,
                            onEditFallback = {
                                val source = item.sourceRef
                                if (source != null) {
                                    onOpenSource(source)
                                } else {
                                    onOpenDocuments()
                                }
                            },
                        )
                    }
                    if (reviewItems.isEmpty()) {
                        Text("No review items are waiting for this case.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                }

                if (selectedSection == AlphaWorkspaceSection.NotesExports) {
                AlphaCard {
                    AlphaSectionLabel("Notes", "Secondary context kept out of the overview.")
                    Text(it.summary, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (it.caseMemoryUpdates.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Recent activity", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        it.caseMemoryUpdates.take(3).forEach { update ->
                            Text(update.summary, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                AlphaCard {
                    AlphaSectionLabel("Drafts", "Ask Ross to create local notes and drafts from this matter.")
                    AlphaSectionCommandHintCard(
                        detail = "Type requests like “draft a case note”, “make a chronology”, or “summarize the latest order” in Ask Ross below.",
                    )
                    matterExports.take(4).forEach { export ->
                        Text(export.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                        Text(export.kind.replace('_', ' '), color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                    Spacer(modifier = Modifier.height(10.dp))
                    TextButton(onClick = onOpenExports, modifier = Modifier.fillMaxWidth()) {
                        Text(if (matterExports.isEmpty()) "Open exports" else "Open ${matterExports.size} draft(s)")
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
    var documentLayoutMode by rememberSaveable { mutableStateOf(AlphaDocumentLayoutMode.Grid) }
    var expandedDocumentIds by rememberSaveable { mutableStateOf(setOf<String>()) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        controller.importDocuments(caseId, uris)
    }
    AlphaShell(title = "Documents", showBack = true, onBack = onBack, actionLabel = "Ask", onAction = onAskCase) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            AlphaInlineHeader(
                eyebrow = case?.forum ?: "Documents",
                title = case?.title ?: "Documents",
                detail = "${case?.documents?.size ?: 0} file(s) in this case",
            )
            AlphaCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        "${case?.documents?.size ?: 0} file(s) stored for this matter",
                        modifier = Modifier.weight(1f),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    AlphaDocumentLayoutMenu(
                        layoutMode = documentLayoutMode,
                        onSelect = { documentLayoutMode = it },
                    )
                }
            }
            Button(
                onClick = { launcher.launch(arrayOf("application/pdf", "image/*", "text/plain")) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Import document")
            }
            if (case?.documents.isNullOrEmpty()) {
                AlphaCard {
                    Text("Import the first order, pleading, notice, or note for this matter.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            if (case != null && case.documents.isNotEmpty()) {
                AlphaDocumentBrowser(
                    documents = case.documents,
                    caseTitle = null,
                    layoutMode = documentLayoutMode,
                    expandedDocumentIds = expandedDocumentIds,
                    onExpandedDocumentIdsChange = { expandedDocumentIds = it },
                    onOpen = { documentId -> onOpenDocument(documentId) },
                    onMoveDocument = { documentId, offset ->
                        controller.moveDocument(caseId, documentId, offset)
                    },
                )
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
    val isSharedDocument = caseId == ALPHA_SHARED_WORKSPACE_ID
    var editingFieldId by remember(documentId) { mutableStateOf<String?>(null) }
    var draftFieldValue by remember(documentId) { mutableStateOf("") }
    var editingClassification by remember(documentId) { mutableStateOf(false) }
    var inspectExpanded by rememberSaveable(documentId) { mutableStateOf(false) }
    var moreActionsExpanded by rememberSaveable(documentId) { mutableStateOf(false) }
    var confirmDelete by rememberSaveable(documentId) { mutableStateOf(false) }

    val deleteDocumentTitle = document?.title ?: "this document"
    if (confirmDelete && document != null) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete document?") },
            text = { Text("This removes $deleteDocumentTitle from this matter on this device.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        controller.deleteDocument(caseId, documentId)
                        confirmDelete = false
                        onBack()
                    }
                ) {
                    Text("Delete")
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) {
                    Text("Cancel")
                }
            },
        )
    }

    AlphaShell(
        title = document?.title ?: "Document",
        showBack = true,
        onBack = onBack,
        actionLabel = "Ask",
        onAction = onAskCase,
        bottomBar = {
            document?.let { doc ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    AlphaDocumentQuickAskStrip(
                        title = null,
                        detail = controller.reviewSummary(caseId, documentId)
                            ?: doc.extractedText?.lineSequence()?.firstOrNull()?.take(140)
                            ?: "Ross will answer from this file only while you stay here.",
                        isShared = isSharedDocument,
                    )
                    AlphaRootAskDock(
                        controller = controller,
                        fixedScopeCaseId = caseId,
                        fixedDocumentIds = setOf(documentId),
                    )
                }
            }
        },
    ) {
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
                val reviewFields = controller.visibleExtractedFields(caseId, documentId)
                    .sortedBy { reviewPriority(it.fieldType) }
                val importantReviewFields = reviewFields.filter { alphaIsImportantReviewField(it.fieldType) }
                val detailReviewFields = reviewFields.filterNot { alphaIsImportantReviewField(it.fieldType) }
                val reviewFindings = doc.extractionFindings.filterNot { it.resolved }.take(4)
                val reviewCount = reviewFields.count { it.needsReview } + reviewFindings.size
                val activeExtractionRun = doc.extractionRuns.firstOrNull {
                    it.status == AlphaExtractionRunStatus.Queued || it.status == AlphaExtractionRunStatus.Running
                }
                AlphaInlineHeader(
                    eyebrow = doc.kind.title,
                    detail = "Status: ${doc.lawyerStatusTitle()} · ${alphaPageCountLabel(doc.pageCount)} · ${alphaReviewNeedLabel(reviewCount)}",
                )
                AlphaDocumentStatusCard(
                    reviewCount = reviewCount,
                    detail = controller.reviewSummary(caseId, documentId)
                        ?: alphaDocumentFallbackReviewDetail(doc, reviewCount),
                    activeRun = activeExtractionRun,
                )
                AlphaCard(
                    "What Ross found",
                    controller.reviewSummary(caseId, documentId)
                        ?: doc.extractionRuns.firstOrNull()?.let { run ->
                            when (run.status) {
                                AlphaExtractionRunStatus.Running, AlphaExtractionRunStatus.Queued -> "Ross is reading this document and checking key details."
                                else -> alphaDocumentFallbackReviewDetail(doc, reviewCount)
                            }
                        }
                        ?: alphaDocumentFallbackReviewDetail(doc, reviewCount)
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
                            val confidenceLabel = alphaConfidenceLabel(classification.confidence, classification.needsReview)
                            Text(confidenceLabel)
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                alphaConfidenceSupportText(classification.confidence, classification.needsReview),
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.bodySmall,
                            )
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

                    if (importantReviewFields.isEmpty() && detailReviewFields.isEmpty() && reviewFindings.isEmpty()) {
                        Text("Not found yet. Ross will keep source anchors visible while local extraction improves.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    } else {
                        if (importantReviewFields.isNotEmpty() || reviewFindings.isNotEmpty()) {
                            Text("Important", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Text(
                                "Check the details that can change dates, parties, filing position, or what happens next.",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.bodySmall,
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            importantReviewFields.forEach { field ->
                                AlphaExtractedFieldReviewCard(
                                    field = field,
                                    contextDocumentTitle = doc.title,
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
                                    onOpenSource = { source ->
                                        controller.pendingRoute = AndroidAlphaRoute.DocumentViewer(source.caseId, source.documentId, source.pageNumber)
                                    },
                                )
                            }
                            reviewFindings.forEach { finding ->
                                Spacer(modifier = Modifier.height(8.dp))
                                AlphaCard("Please confirm", finding.kind.name) {
                                    Text(finding.message, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }

                        if (detailReviewFields.isNotEmpty()) {
                            Spacer(modifier = Modifier.height(12.dp))
                            Text("Other details", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Text(
                                "Helpful details you can accept, edit, or ignore after the essentials are clear.",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.bodySmall,
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            detailReviewFields.forEach { field ->
                                AlphaExtractedFieldReviewCard(
                                    field = field,
                                    contextDocumentTitle = doc.title,
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
                                    onOpenSource = { source ->
                                        controller.pendingRoute = AndroidAlphaRoute.DocumentViewer(source.caseId, source.documentId, source.pageNumber)
                                    },
                                )
                            }
                        }
                    }

                    controller.strongerPackMessageFor(doc)?.let { message ->
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(message, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(onClick = onOpenPrivateAi, modifier = Modifier.fillMaxWidth()) { Text("Open Private AI") }
                    }
                }
                AlphaDocumentPreviewPanel(
                    controller = controller,
                    document = doc,
                    sourcePanel = sourcePanel,
                )
                AlphaExpandableCard(
                    title = "Inspect",
                    subtitle = if (sourcePanel.currentPageRefs.isEmpty() && sourcePanel.otherRefs.isEmpty()) {
                        "Source not available for this page."
                    } else {
                        "Sources and raw text."
                    },
                    badge = if (inspectExpanded) "Hide" else "Show",
                    expanded = inspectExpanded,
                    onToggle = { inspectExpanded = !inspectExpanded },
                ) {
                    Text("Sources", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
                    Text("Target page ${sourcePanel.resolvedPage} of ${sourcePanel.pageCount}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(8.dp))
                    val visibleRefs = if (sourcePanel.currentPageRefs.isEmpty()) sourcePanel.otherRefs.take(3) else sourcePanel.currentPageRefs
                    if (visibleRefs.isEmpty()) {
                        Text("No source previews available for this page.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    } else {
                        visibleRefs.forEach { ref ->
                            Text(alphaSourceLabel(ref, doc.title), fontWeight = FontWeight.SemiBold)
                            Text(ref.detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(modifier = Modifier.height(8.dp))
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Raw text", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
                    Text(
                        doc.extractedText ?: "No extracted text is available for this page yet.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                AlphaExpandableCard(
                    title = "More actions",
                    subtitle = "Document actions kept out of the review path.",
                    badge = if (moreActionsExpanded) "Hide" else "More",
                    expanded = moreActionsExpanded,
                    onToggle = { moreActionsExpanded = !moreActionsExpanded },
                ) {
                    AlphaAction(
                        "Ask about this document",
                        "Open Ask with this file selected.",
                        onClick = {
                            controller.setAskDraft(caseId, "What should I note from ${doc.title}?")
                            controller.openAsk(caseId, doc.id)
                        },
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    AlphaAction(
                        "Create review task",
                        "Save a follow-up task for this matter.",
                        onClick = {
                            val dueDate = controller.persisted.cases.firstOrNull { it.id == caseId }?.nextHearing
                            controller.addTask(
                                title = "Review ${doc.title}",
                                caseId = caseId,
                                dueDate = dueDate,
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
                    AlphaAction("Re-run review", "Review this document again using current source rules.") {
                        controller.rerunReview(caseId, documentId)
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedButton(onClick = { confirmDelete = true }, modifier = Modifier.fillMaxWidth()) {
                        Text("Delete document")
                    }
                }
            }
        }
    }
}

@Composable
private fun AlphaDocumentPreviewPanel(
    controller: AlphaRossController,
    document: AlphaCaseDocument,
    sourcePanel: AlphaResolvedSourcePanel,
) {
    val file = controller.absoluteFile(document.storedRelativePath).takeIf { it.exists() }
    when {
        document.kind == AlphaDocumentKind.Image && file != null -> {
            BitmapFactory.decodeFile(file.absolutePath)?.let { bitmap ->
                Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = document.title,
                    modifier = Modifier.fillMaxWidth(),
                    contentScale = ContentScale.FillWidth,
                )
            }
        }

        document.kind == AlphaDocumentKind.Pdf && file != null -> {
            AlphaPdfPagePreview(file = file, pageNumber = sourcePanel.resolvedPage, title = document.title)
        }

        else -> {
            AlphaCard("Preview") {
                Text(
                    "Ross is showing source metadata while a rich preview is unavailable for this file.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun AlphaDocumentQuickAskStrip(title: String?, detail: String, isShared: Boolean) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.88f)),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f)),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top,
        ) {
            RossGlassIcon(
                asset = if (isShared) RossGlassAsset.EarthHighlight else RossGlassAsset.FileNeutral,
                modifier = Modifier.size(22.dp),
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                if (!title.isNullOrEmpty()) {
                    Text(title, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, maxLines = 1)
                }
                Text(
                    detail,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                )
                Text(
                    if (isShared) "Shared file" else "Using this file",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.secondary,
                )
            }
        }
    }
}

private fun alphaDocumentFallbackReviewDetail(document: AlphaCaseDocument, reviewCount: Int): String {
    val activeRun = document.extractionRuns.firstOrNull()
    val isReading = activeRun?.status == AlphaExtractionRunStatus.Queued ||
        activeRun?.status == AlphaExtractionRunStatus.Running ||
        document.extractionStatus == AlphaDocumentExtractionStatus.Running ||
        document.indexingStatus == AlphaIndexingStatus.Extracting
    val failed = document.fileStatus == AlphaFileStatus.CopyFailed ||
        document.indexingStatus == AlphaIndexingStatus.Failed ||
        document.ocrStatus == AlphaOcrStatus.Failed
    return when {
        isReading -> "Ross is still reading this file. Do not rely on full-document facts until review finishes."
        failed -> "Ross could not finish reading this file. Review the source manually before using it."
        document.extractionStatus == AlphaDocumentExtractionStatus.Skipped -> "Document saved. Set up the private assistant when you want Ross to extract legal fields."
        reviewCount > 0 -> "Check the highlighted items below before relying on this document in a note or export."
        document.indexingStatus == AlphaIndexingStatus.Indexed ||
            document.ocrStatus == AlphaOcrStatus.NativeText ||
            document.ocrStatus == AlphaOcrStatus.OcrComplete -> "Verified details can be used in notes, tasks, and exports for this matter."
        else -> "Ross is still reading this file. Do not rely on full-document facts until review finishes."
    }
}

@Composable
private fun AlphaDocumentStatusCard(reviewCount: Int, detail: String, activeRun: AlphaExtractionRun? = null) {
    val isReadingDetail = detail.startsWith("Ross is still reading")
    val isFailedDetail = detail.startsWith("Ross could not finish")
    val isActive = activeRun?.status == AlphaExtractionRunStatus.Queued ||
        activeRun?.status == AlphaExtractionRunStatus.Running ||
        isReadingDetail
    val tint = when {
        isActive -> MaterialTheme.colorScheme.primary
        isFailedDetail -> MaterialTheme.colorScheme.error
        reviewCount == 0 -> AlphaSuccessStatus
        else -> AlphaAmberStatus
    }
    val title = if (isActive) {
        "Ross is reading this document"
    } else if (isFailedDetail) {
        "Needs manual review"
    } else if (reviewCount == 0) {
        "Ready to use in this matter"
    } else if (reviewCount == 1) {
        "1 item needs your review below"
    } else {
        "$reviewCount items need your review below"
    }

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, tint.copy(alpha = 0.26f)),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 13.dp, vertical = 11.dp),
            horizontalArrangement = Arrangement.spacedBy(11.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .height(if (isActive) 58.dp else 48.dp)
                    .background(tint.copy(alpha = 0.82f), shape = RoundedCornerShape(alphaPillCornerRadius))
            )

            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                Text(
                    activeRun?.let(::alphaExtractionProgressDetail) ?: detail,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (isActive && activeRun != null) {
                    LinearProgressIndicator(
                        progress = { alphaExtractionProgressFraction(activeRun).coerceIn(0f, 1f) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 6.dp),
                        color = tint,
                        trackColor = tint.copy(alpha = 0.14f),
                    )
                    Text(
                        alphaExtractionProgressLabel(activeRun),
                        style = MaterialTheme.typography.labelSmall,
                        color = tint,
                    )
                }
            }
        }
    }
}

@Composable
private fun AlphaExtractedFieldReviewCard(
    field: AlphaExtractedLegalField,
    contextDocumentTitle: String?,
    isEditing: Boolean,
    draftValue: String,
    onStartEdit: () -> Unit,
    onDraftChange: (String) -> Unit,
    onAccept: () -> Unit,
    onApply: () -> Unit,
    onCancel: () -> Unit,
    onIgnore: () -> Unit,
    onOpenSource: (AlphaSourceRef) -> Unit,
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.18f)),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.58f)),
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(field.label, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(field.value, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                }
                AlphaTagChip(field.confidenceLabel)
            }
            Text(
                alphaConfidenceSupportText(field.confidence, field.needsReview),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall,
            )
            if (field.sourceRefs.isNotEmpty()) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    field.sourceRefs.take(2).forEach { source ->
                        FilterChip(
                            selected = false,
                            onClick = { onOpenSource(source) },
                            label = { Text(alphaSourceLabel(source, contextDocumentTitle)) },
                        )
                    }
                }
            }
            if (isEditing) {
                OutlinedTextField(
                    value = draftValue,
                    onValueChange = onDraftChange,
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Edit ${field.label.lowercase()}") },
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = onApply) { Text("Apply") }
                    OutlinedButton(onClick = onCancel) { Text("Cancel") }
                }
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = onAccept) { Text("Accept") }
                    OutlinedButton(onClick = onStartEdit) { Text("Edit") }
                    TextButton(onClick = onIgnore) { Text("Ignore") }
                }
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

private fun alphaAttentionHeadline(count: Int): String = when (count) {
    0 -> "Today is under control"
    1 -> "1 item needs attention"
    else -> "$count items need attention"
}

private fun alphaPageCountLabel(count: Int): String =
    if (count == 1) "1 page" else "$count pages"

private fun alphaReviewNeedLabel(count: Int): String =
    if (count == 1) "1 item needs your check" else "$count items need your check"

private fun alphaIsImportantReviewField(type: AlphaExtractedLegalFieldType): Boolean =
    reviewPriority(type) <= 8

private fun alphaConfidenceLabel(confidence: Double, needsReview: Boolean): String = when {
    needsReview -> "Please confirm"
    confidence < 0.84 -> "Low confidence"
    else -> "Verified"
}

private fun alphaConfidenceSupportText(confidence: Double, needsReview: Boolean): String =
    when (alphaConfidenceLabel(confidence, needsReview)) {
        "Verified" -> "Verified from the file"
        "Low confidence" -> "Ross found this, but the wording should be double-checked"
        else -> "Needs your confirmation before you rely on it"
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

    AlphaCard {
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
        showBack = true,
        onBack = onBack,
        onOpenSource = onOpenSource,
    )
}

@Composable
private fun AlphaPublicLawScreen(controller: AlphaRossController, onBack: () -> Unit) {
    AlphaShell(title = "Legal Search", showBack = true, onBack = onBack) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            AlphaInlineHeader(
                eyebrow = null,
                title = "Review before Legal Search",
                detail = "Ross will only send this legal search query. Your case files stay on this device.",
            )
            AlphaCard {
                OutlinedTextField(
                    value = controller.publicLawDraft,
                    onValueChange = { controller.publicLawDraft = it },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 6,
                    label = { Text("Query") },
                    placeholder = { Text("Example: Supreme Court guidance on delay condonation after a filing disruption") }
                )
                Spacer(modifier = Modifier.height(12.dp))
                Text("Ross removes case IDs, file names, client names, party names, phone numbers, email addresses, and text copied from your files before search.")
                Spacer(modifier = Modifier.height(8.dp))
                Text("Why this is safe: Ross only sends the sanitized legal search query allowed in Settings. Your matter files stay on this device.")
                Spacer(modifier = Modifier.height(12.dp))
                Button(onClick = { controller.buildPublicLawPreview() }, modifier = Modifier.fillMaxWidth()) { Text("Review sanitized query") }
            }
            controller.publicLawPreview?.let { preview ->
                AlphaCard("Legal Search query to be sent", "Ross will only send this legal search query. Your case files stay on this device.") {
                    Text(preview.query, fontWeight = FontWeight.SemiBold)
                    Spacer(modifier = Modifier.height(12.dp))
                    preview.removed.forEach { AlphaBullet(it) }
                    Spacer(modifier = Modifier.height(12.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        OutlinedButton(
                            onClick = {
                                controller.cancelPendingPublicLawSearch()
                                onBack()
                            },
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Cancel")
                        }
                        Button(
                            onClick = {
                                if (controller.pendingPublicLawQuestion != null) {
                                    controller.confirmPendingPublicLawSearch()
                                } else {
                                    controller.runPublicLawSearch()
                                }
                            },
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Search")
                        }
                    }
                }
            }
            if (controller.publicLawResults.isNotEmpty()) {
                AlphaCard("Legal Search results", "Separate from case-file context and limited to the sanitized legal search query.") {
                    controller.publicLawResults.forEach { result ->
                        AlphaPublicLawResultCard(result)
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                    AlphaPublicLawWarningsCard(
                        needsReviewWarning = null,
                        includePublicLawWarnings = true,
                    )
                }
            }
        }
    }
}

@Composable
private fun AlphaExportsScreen(controller: AlphaRossController, caseId: String?, onBack: () -> Unit) {
    val context = LocalContext.current
    AlphaShell(title = "Notes & Drafts", showBack = true, onBack = onBack) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            AlphaInlineHeader(
                eyebrow = null,
                title = "Notes & Drafts",
                detail = "Generate local notes and drafts for advocate review.",
            )
            AlphaCard("Generate") {
                Text(
                    "Use the compact actions here, or type “draft case note” in Ask Ross below.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(modifier = Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    AlphaCompactDraftActionButton(
                        title = "Chronology",
                        icon = Icons.Outlined.ViewTimeline,
                        modifier = Modifier.weight(1f),
                    ) {
                        controller.generateExport("chronology_report", caseId)
                    }
                    AlphaCompactDraftActionButton(
                        title = "Case note",
                        icon = Icons.Outlined.EditNote,
                        modifier = Modifier.weight(1f),
                    ) {
                        controller.generateExport("case_note", caseId)
                    }
                }
                Spacer(modifier = Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    AlphaCompactDraftActionButton(
                        title = "Order summary",
                        icon = Icons.Outlined.Description,
                        modifier = Modifier.weight(1f),
                    ) {
                        controller.generateExport("order_summary", caseId)
                    }
                    AlphaCompactDraftActionButton(
                        title = "Transcript",
                        icon = Icons.Outlined.ChatBubbleOutline,
                        modifier = Modifier.weight(1f),
                    ) {
                        controller.generateExport("chat_transcript", caseId)
                    }
                }
            }
            controller.persisted.exports.forEach { report ->
                AlphaCard(report.title, report.kind.replace('_', ' ')) {
                    Text(report.relativePath, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    controller.absoluteFile(report.relativePath).takeIf { it.exists() }?.let { exportFile ->
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(
                                onClick = { openLocalExport(context, exportFile) },
                                modifier = Modifier.weight(1f),
                            ) {
                                Text(if (exportFile.extension.equals("pdf", ignoreCase = true)) "Open PDF" else "Open draft")
                            }
                            Button(
                                onClick = { shareLocalExport(context, exportFile, preferWhatsApp = true) },
                                modifier = Modifier.weight(1f),
                            ) {
                                Text("Send in WhatsApp")
                            }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            TextButton(
                                onClick = { shareLocalExport(context, exportFile, preferWhatsApp = false) },
                                modifier = Modifier.weight(1f),
                            ) {
                                Text("Share")
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun exportMimeType(file: File): String =
    when (file.extension.lowercase()) {
        "pdf" -> "application/pdf"
        "txt" -> "text/plain"
        else -> "*/*"
    }

private fun exportUri(context: android.content.Context, file: File) =
    FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)

private fun openLocalExport(context: android.content.Context, file: File) {
    val uri = exportUri(context, file)
    val openIntent = Intent(Intent.ACTION_VIEW).apply {
        setDataAndType(uri, exportMimeType(file))
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    runCatching {
        context.startActivity(Intent.createChooser(openIntent, "Open local draft"))
    }.getOrElse {
        shareLocalExport(context, file, preferWhatsApp = false)
    }
}

private fun shareLocalExport(context: android.content.Context, file: File, preferWhatsApp: Boolean) {
    val uri = exportUri(context, file)
    val shareIntent = Intent(Intent.ACTION_SEND).apply {
        type = exportMimeType(file)
        putExtra(Intent.EXTRA_STREAM, uri)
        putExtra(Intent.EXTRA_TEXT, "Sharing ${file.nameWithoutExtension} from Ross.")
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    if (preferWhatsApp) {
        val whatsAppIntent = Intent(shareIntent).apply {
            `package` = "com.whatsapp"
        }
        runCatching {
            context.startActivity(whatsAppIntent)
        }.onSuccess {
            return
        }
    }
    context.startActivity(Intent.createChooser(shareIntent, "Share local draft"))
}

@Composable
private fun AlphaSettingsScreen(
    controller: AlphaRossController,
    onBack: () -> Unit,
    onOpenLedger: () -> Unit,
    onOpenPrivateAi: () -> Unit,
) {
    val context = LocalContext.current
    val biometricSupported = alphaCanUseDeviceUnlock(context as? FragmentActivity)
    val storageSnapshot = alphaStorageSnapshot(controller)
    var showAdvancedSettings by rememberSaveable { mutableStateOf(false) }
    var showTechnicalDiagnostics by rememberSaveable { mutableStateOf(false) }
    var backendAddressDraft by rememberSaveable { mutableStateOf(controller.backendBaseUrlOverride().orEmpty()) }
    AlphaShell(
        title = "Settings",
        showTopBar = false,
        topContent = {
            AlphaRootTopRail(
                showBack = true,
                onBack = onBack,
                title = "Settings",
            )
        },
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            AlphaCard("Appearance") {
                AlphaAppearanceMode.values().forEachIndexed { index, mode ->
                    AlphaSettingsSelectionRow(
                        title = mode.label,
                        detail = when (mode) {
                            AlphaAppearanceMode.Auto -> "Follow the phone setting."
                            AlphaAppearanceMode.Dark -> "Always use the dark interface."
                            AlphaAppearanceMode.Light -> "Always use the light interface."
                        },
                        selected = controller.persisted.settings.appearanceMode == mode,
                        onClick = { controller.setAppearanceMode(mode) },
                    )
                    if (index < AlphaAppearanceMode.values().lastIndex) {
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                }
            }

            AlphaCard("Privacy") {
                AlphaSettingsValueRow("Legal Search", "Review required")
                Spacer(modifier = Modifier.height(8.dp))
                AlphaToggleRow("Keep Ross private by default", controller.persisted.settings.privateByDefault) {
                    controller.persisted = controller.persisted.copy(settings = controller.persisted.settings.copy(privateByDefault = it))
                    controller.save()
                }
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    "Legal Search is separate from local Ask. Ross shows the sanitized query first and sends nothing until you approve it.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodySmall,
                )
            }

            AlphaCard("Account") {
                val session = controller.persisted.accountSession
                if (session.isSignedIn) {
                    AlphaSettingsValueRow(
                        label = "Signed in",
                        value = session.email ?: (session.displayName ?: session.providerLabel),
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    AlphaSettingsValueRow(
                        label = "Mode",
                        value = if (session.isDemoMode) "Demo mode" else session.providerLabel,
                    )
                    if (biometricSupported) {
                        Spacer(modifier = Modifier.height(8.dp))
                        AlphaToggleRow("Use device unlock", session.quickUnlockEnabled) {
                            controller.setQuickUnlockEnabled(it)
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        if (session.quickUnlockEnabled) {
                            "Ross locks again when the app leaves the screen."
                        } else {
                            "Turn on device unlock to reopen Ross with fingerprint, face, or passcode."
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    if (session.isDemoMode) {
                        Spacer(modifier = Modifier.height(12.dp))
                        Button(
                            onClick = { controller.resetDemoWorkspace(session.subject ?: "local_demo_advocate") },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("Reset demo data")
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            "Demo matter uses sample data only.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Button(
                            onClick = { controller.lockSessionForQuickUnlock() },
                            modifier = Modifier.weight(1f),
                            enabled = session.quickUnlockEnabled,
                        ) {
                            Text("Lock now")
                        }
                        TextButton(
                            onClick = { controller.signOutAccountSession() },
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Sign out")
                        }
                    }
                } else {
                    Text(
                        "Open demo mode with sample data, or sign in with Google.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    if (session.awaitingBrowserReturn) {
                        Spacer(modifier = Modifier.height(8.dp))
                        AlphaAssistantActivityStrip(
                            title = "Waiting for Google",
                            detail = "Return here after the browser finishes the sign-in step.",
                            statusLabel = "Browser",
                            tint = MaterialTheme.colorScheme.secondary,
                        )
                    }
                    controller.authStatusMessage?.let { message ->
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            message,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(onClick = { controller.signInDemoMode() }, modifier = Modifier.fillMaxWidth()) {
                        Text("Open demo mode")
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Button(
                        onClick = {
                            controller.markGoogleSignInStarted()
                            runCatching {
                                context.startActivity(Intent(Intent.ACTION_VIEW, controller.prepareGoogleSignInUri()))
                            }.onFailure {
                                controller.clearPendingGoogleSignIn()
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Sign in with Google")
                    }
                }
            }

            AlphaCard("On this device") {
                AlphaSettingsValueRow(label = "Status", value = alphaPrivateAiStatus(controller).first)
                Spacer(modifier = Modifier.height(8.dp))
                AlphaSettingsValueRow(label = "Notes & Drafts", value = "${controller.persisted.exports.size}")
                Spacer(modifier = Modifier.height(8.dp))
                AlphaSettingsNavigationRow(
                    title = "My assistant",
                    detail = "Set up local drafting and file answers.",
                    icon = Icons.Outlined.Memory,
                    onClick = onOpenPrivateAi,
                )
                Spacer(modifier = Modifier.height(8.dp))
                AlphaSettingsNavigationRow(
                    title = "Open Activity Log",
                    detail = "See what stayed on this phone and what Ross searched publicly.",
                    icon = Icons.AutoMirrored.Outlined.FactCheck,
                    onClick = onOpenLedger,
                )
            }

            AlphaCard("Advanced", "Storage, help, and technical diagnostics stay out of normal use.") {
                Button(
                    onClick = { showAdvancedSettings = !showAdvancedSettings },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(if (showAdvancedSettings) "Hide advanced settings" else "Show advanced settings")
                }
                if (showAdvancedSettings) {
                    Spacer(modifier = Modifier.height(12.dp))
                    AlphaSectionLabel("Storage", "Local files and generated drafts on this device.")
                    AlphaSettingsValueRow(
                        label = "Matter files",
                        value = "${storageSnapshot.documentCount} • ${alphaFileSizeLabel(context, storageSnapshot.documentBytes)}",
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    AlphaSettingsValueRow(
                        label = "Notes & Drafts",
                        value = "${storageSnapshot.exportCount} • ${alphaFileSizeLabel(context, storageSnapshot.exportBytes)}",
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    AlphaSettingsValueRow(
                        label = "Assistant files",
                        value = alphaFileSizeLabel(context, storageSnapshot.assistantBytes),
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    AlphaSettingsValueRow(
                        label = "Total",
                        value = alphaFileSizeLabel(context, storageSnapshot.totalBytes),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    AlphaSectionLabel("Help", "Plain reminders for first-time use.")
                    AlphaSettingsValueRow(label = "Quick start", value = "Add a matter, import a file, then ask Ross.")
                    Spacer(modifier = Modifier.height(8.dp))
                    AlphaSettingsValueRow(label = "Assistant setup", value = "If setup pauses, reopen My assistant and retry on Wi-Fi.")
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(
                        onClick = { showTechnicalDiagnostics = !showTechnicalDiagnostics },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(if (showTechnicalDiagnostics) "Hide technical diagnostics" else "Show technical diagnostics")
                    }
                }
                if (showAdvancedSettings && showTechnicalDiagnostics) {
                    Spacer(modifier = Modifier.height(12.dp))
                    AlphaSectionLabel("Technical diagnostics", "Internal runtime details for testing only.")
                    AlphaSettingsValueRow(
                        label = "Current server",
                        value = controller.effectiveBackendBaseUrl(),
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedTextField(
                        value = backendAddressDraft,
                        onValueChange = { backendAddressDraft = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Test server address") },
                        placeholder = { Text("http://10.0.2.2:8080") },
                        singleLine = true,
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        "For internal testing only. Android emulator usually uses 10.0.2.2, iPhone Simulator uses 127.0.0.1, and a physical device needs your computer's LAN IP.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Button(
                            onClick = {
                                controller.setBackendBaseUrlOverride(backendAddressDraft)
                                backendAddressDraft = controller.backendBaseUrlOverride().orEmpty()
                            },
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Save test server")
                        }
                        TextButton(
                            onClick = {
                                controller.setBackendBaseUrlOverride(null)
                                backendAddressDraft = ""
                            },
                            modifier = Modifier.weight(1f),
                        ) {
                            Text("Use default address")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AlphaLaunchAuthGate(controller: AlphaRossController) {
    val context = LocalContext.current
    val session = controller.persisted.accountSession
    var expanded by rememberSaveable { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .alphaAuthBackdrop(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(horizontal = 18.dp, vertical = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .widthIn(max = 430.dp),
                verticalArrangement = Arrangement.spacedBy(38.dp),
            ) {
                AlphaAuthBrandRow()
                AlphaAuthHeroCard()
            }

            AlphaAuthPanel(
                modifier = Modifier
                    .widthIn(max = 440.dp)
                    .clickable(enabled = !expanded) { expanded = true },
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        imageVector = if (expanded) Icons.Outlined.KeyboardArrowDown else Icons.Outlined.ArrowUpward,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.65f),
                    )
                    Text(
                        if (expanded) "Choose how to continue" else "Get Started",
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center,
                    )
                    Text(
                        if (expanded) "Open a local demo or sign in." else "Tap to sign in.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )
                }

                AnimatedVisibility(visible = expanded) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        if (session.awaitingBrowserReturn) {
                            AlphaAssistantActivityStrip(
                                title = "Waiting for Google",
                                detail = "Return here after the browser finishes sign-in.",
                                statusLabel = "Browser",
                                tint = MaterialTheme.colorScheme.secondary,
                            )
                        }
                        controller.authStatusMessage?.let { message ->
                            AlphaAuthNotice(message)
                        }
                        Button(
                            onClick = {
                                controller.clearAuthStatusMessage()
                                controller.signInDemoMode()
                            },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("Open demo mode")
                        }
                        Button(
                            onClick = {
                                controller.clearAuthStatusMessage()
                                controller.markGoogleSignInStarted()
                                runCatching {
                                    context.startActivity(Intent(Intent.ACTION_VIEW, controller.prepareGoogleSignInUri()))
                                }.onFailure {
                                    controller.clearPendingGoogleSignIn()
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("Sign in with Google")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AlphaSettingsValueRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            value,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun AlphaSettingsNavigationRow(
    title: String,
    detail: String,
    icon: ImageVector,
    onClick: () -> Unit,
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.22f)),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Box(
                modifier = Modifier
                    .size(30.dp)
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f), RoundedCornerShape(10.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(title, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                Text(detail, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }

            Icon(
                imageVector = Icons.Outlined.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun AlphaSettingsSelectionRow(
    title: String,
    detail: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(
            containerColor = if (selected) MaterialTheme.colorScheme.primary.copy(alpha = 0.08f) else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.16f),
        ),
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            if (selected) MaterialTheme.colorScheme.primary.copy(alpha = 0.32f) else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f),
        ),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Icon(
                imageVector = if (selected) Icons.Filled.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
                contentDescription = null,
                tint = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun AlphaPrivateAiSettingsScreen(controller: AlphaRossController, onBack: () -> Unit) {
    var showTechnicalDiagnostics by remember { mutableStateOf(false) }
    val privateAiStatus = alphaPrivateAiStatus(controller)
    AlphaShell(title = "My assistant", showBack = true, onBack = onBack) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(alphaSectionSpacing)
        ) {
            alphaActiveSetupJob(controller)?.let { activeJob ->
                AlphaCard("Assistant activity") {
                    AlphaAssistantActivityStrip(
                        title = "${activeJob.tier.title} is still preparing",
                        detail = alphaAssistantActivityDetail(activeJob.state),
                        statusLabel = alphaJobStatusLabel(activeJob.state),
                        tint = AlphaAmberStatus,
                        progress = alphaJobProgressFraction(activeJob),
                        showProgress = true,
                    )
                }
            }
            AlphaCard("Current status", privateAiStatus.first) {
                Text(privateAiStatus.second, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            AlphaCard("Download settings", "Downloads can wait for Wi-Fi or use mobile data explicitly.") {
                AlphaToggleRow("Wi-Fi only downloads", controller.persisted.settings.wifiOnlyDownloads) {
                    controller.persisted = controller.persisted.copy(settings = controller.persisted.settings.copy(wifiOnlyDownloads = it))
                    controller.save()
                }
                AlphaToggleRow("Allow mobile data for large packs", controller.persisted.settings.allowMobileDataForLargePacks) {
                    controller.persisted = controller.persisted.copy(settings = controller.persisted.settings.copy(allowMobileDataForLargePacks = it))
                    controller.save()
                }
            }
            AlphaCard("Choose level", "Pick how much help Ross keeps ready on this device.") {
                Text("You can switch later. Setup progress stays visible here and in Settings.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            AlphaCapabilityTier.values().forEach { tier ->
                val installedPack = controller.installedPackFor(tier)
                val setupJob = controller.setupJobFor(tier)
                val isActivePack = installedPack != null && installedPack.id == controller.activePack()?.id
                val actionLabel = when {
                    isActivePack -> "Active"
                    installedPack != null -> "Use this level"
                    setupJob != null -> alphaJobStatusLabel(setupJob.state)
                    else -> "Download this level"
                }
                val actionEnabled = !isActivePack && setupJob == null
                AlphaCard(tier.setupTitle, tier.summary) {
                    Text(tier.bestFor, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        AlphaTagChip(tier.downloadSizeLabel)
                        AlphaTagChip(tier.setupTimeLabel)
                    }
                    if (installedPack != null) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            if (isActivePack) "Ready on this device and currently active." else "Ready on this device.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                    if (setupJob != null) {
                        Spacer(modifier = Modifier.height(8.dp))
                        AlphaAssistantActivityStrip(
                            title = "${tier.title} setup",
                            detail = alphaAssistantActivityDetail(setupJob.state),
                            statusLabel = alphaJobProgressLabel(setupJob) ?: alphaJobStatusLabel(setupJob.state),
                            tint = AlphaAmberStatus,
                            progress = alphaJobProgressFraction(setupJob),
                            showProgress = true,
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Button(
                        onClick = {
                            if (installedPack != null) {
                                controller.activatePack(installedPack.id)
                            } else {
                                controller.startPackInstall(
                                    tier,
                                    controller.persisted.settings.allowMobileDataForLargePacks || tier == AlphaCapabilityTier.QuickStart
                                )
                            }
                        },
                        enabled = actionEnabled,
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(actionLabel) }
                }
            }
            controller.persisted.installedPacks.forEach { pack ->
                val runtimeHealth = controller.activeRuntimeHealth()
                val isActivePack = controller.activePack()?.id == pack.id
                val status = when {
                    isActivePack && runtimeHealth?.fallbackActive == true -> "Private assistant unavailable"
                    isActivePack && runtimeHealth?.available == false -> "Needs attention"
                    else -> "Private assistant is ready"
                }
                AlphaCard(pack.tier.title, status) {
                    Text(
                        when (pack.tier) {
                            AlphaCapabilityTier.QuickStart -> "Best for shorter documents after setup finishes."
                            AlphaCapabilityTier.CaseAssociate -> "Better extraction for mixed-language or poor scans."
                            AlphaCapabilityTier.SeniorDraftingSupport -> "Better extraction for mixed-language or poor scans, with deeper review passes."
                        },
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    AlphaSettingsValueRow(label = "Storage", value = pack.tier.installedSizeLabel)
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(
                            onClick = { controller.activatePack(pack.id) },
                            enabled = !isActivePack,
                        ) { Text(if (isActivePack) "Active" else "Use this level") }
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
                        val activePack = controller.activePack()
                        val artifact = activePack?.tier?.let(::alphaTechnicalModelArtifact)
                        val lastInvocation = controller.lastModelInvocation()
                        val lastMetric = controller.lastLocalInferenceMetrics()
                        val lastPreview = controller.publicLawPreview
                        val resetCount = controller.persisted.ledgerEntries.count { it.title.contains("reset", ignoreCase = true) }
                        Spacer(modifier = Modifier.height(12.dp))
                        AlphaSettingsValueRow("Runtime mode", health.runtimeMode.wireValue)
                        AlphaSettingsValueRow("Artifact kind", activePack?.artifactKind ?: "Missing")
                        AlphaSettingsValueRow("Checksum verified", if (health.checksumVerified) "yes" else "no")
                        AlphaSettingsValueRow("Runtime available", if (health.available && !health.fallbackActive) "yes" else "no")
                        AlphaSettingsValueRow("Model path", if (health.modelPathPresent) "Configured" else "Missing")
                        artifact?.let {
                            AlphaSettingsValueRow("Technical model", it.displayName)
                            AlphaSettingsValueRow("Repository", it.repository)
                            AlphaSettingsValueRow("File", it.fileName)
                            AlphaSettingsValueRow("Quantization", it.quantization)
                            AlphaSettingsValueRow("Checksum", it.sha256)
                        }
                        health.modelPathLabel?.let { AlphaSettingsValueRow("Model file", it) }
                        health.lastErrorCategory?.let { AlphaSettingsValueRow("Last error category", it) }
                        controller.lastModelInvocationRuntimeMode()?.let { AlphaSettingsValueRow("Last invocation runtime", it) }
                        lastInvocation?.let {
                            AlphaSettingsValueRow("Last task", it.task.wireValue)
                            AlphaSettingsValueRow("Last status", it.status.name)
                            AlphaSettingsValueRow("Prompt hash", it.promptHash)
                            AlphaSettingsValueRow("Input hash", it.inputHash)
                            it.outputHash?.let { outputHash -> AlphaSettingsValueRow("Output hash", outputHash) }
                        } ?: AlphaSettingsValueRow("Last local inference", "No model invocation recorded yet")
                        lastMetric?.let {
                            val tokenTotal = (it.estimatedTokens ?: 0) + ((it.outputChars ?: 0) / 4)
                            val speed = if (it.durationMs > 0) tokenTotal.toDouble() / (it.durationMs.toDouble() / 1_000.0) else 0.0
                            AlphaSettingsValueRow("Estimated input tokens", "${it.estimatedTokens ?: 0}")
                            AlphaSettingsValueRow("Output chars", "${it.outputChars ?: 0}")
                            AlphaSettingsValueRow("Last duration", "${it.durationMs} ms")
                            AlphaSettingsValueRow("Approx speed", "${"%.1f".format(speed)} tok/s")
                        }
                        if (lastPreview != null) {
                            AlphaSettingsValueRow("Last legal search query", lastPreview.query)
                            AlphaSettingsValueRow("Sanitizer removals", "${lastPreview.removed.size}")
                        } else {
                            AlphaSettingsValueRow("Last legal search query", "None")
                        }
                        AlphaSettingsValueRow("Workspace resets", "$resetCount")
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(
                            onClick = { controller.runLocalInferenceSmoke() },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !controller.localInferenceSmokeRunning,
                        ) {
                            Text(if (controller.localInferenceSmokeRunning) "Running local inference smoke..." else "Run local inference smoke")
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        AlphaSectionLabel("On-device remediation checks", "Developer-only checks for setup, import, chat grounding, bulk import, and matter refresh.")
                        controller.onDeviceRemediationDiagnostics().forEach { (label, value) ->
                            AlphaSettingsValueRow(label, value)
                            Spacer(modifier = Modifier.height(6.dp))
                        }
                    }
                    controller.localInferenceSmokeReport?.let { report ->
                        Spacer(modifier = Modifier.height(8.dp))
                        AlphaSettingsValueRow("Runtime used", report.runtimeUsed)
                        AlphaSettingsValueRow("Schema valid", if (report.schemaValid) "yes" else "no")
                        AlphaSettingsValueRow("Fields found", "${report.fieldsFound}")
                        AlphaSettingsValueRow("Fields verified", "${report.fieldsVerified}")
                        AlphaSettingsValueRow("Fields needing review", "${report.fieldsNeedingReview}")
                        AlphaSettingsValueRow("Unsupported accepted", "${report.unsupportedAccepted}")
                        report.exportRelativePath?.let { AlphaSettingsValueRow("Export", it) }
                    }
                }
            }

        }
    }
}

@Composable
private fun AlphaPrivacyLedgerScreen(controller: AlphaRossController, onBack: () -> Unit) {
    AlphaShell(title = "Activity Log", showBack = true, onBack = onBack) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(alphaScreenPadding),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                AlphaCard("Activity summary") {
                    Text(
                        "In the last 30 days, 0 case details left this phone. Legal Search only used sanitized legal search queries.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            items(controller.persisted.ledgerEntries, key = { it.id }) { entry ->
                AlphaCard(entry.lawyerTitle(), entry.success.thenCompleted()) {
                    Text(entry.lawyerDetail(), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(entry.lawyerPurposeLabel(), style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
private fun AlphaHero(eyebrow: String, title: String, body: String, showLogo: Boolean = true) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(),
        shape = RoundedCornerShape(alphaGlassCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column {
            if (showLogo) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(108.dp)
                        .background(
                            Brush.linearGradient(
                                colors = listOf(
                                    MaterialTheme.colorScheme.primaryContainer,
                                    MaterialTheme.colorScheme.surfaceVariant,
                                )
                            )
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Image(
                        painter = painterResource(id = R.drawable.ross_logo),
                        contentDescription = "Ross",
                        modifier = Modifier.size(66.dp),
                        contentScale = ContentScale.Fit
                    )
                }
            }

            Column(
                modifier = Modifier.padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    eyebrow.uppercase(),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.secondary
                )
                Text(title, style = MaterialTheme.typography.headlineMedium)
                Text(
                    body,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun AlphaInlineHeader(eyebrow: String? = null, title: String? = null, detail: String? = null) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        eyebrow?.takeIf { it.isNotBlank() }?.let {
            Text(it.uppercase(), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.secondary)
        }
        title?.takeIf { it.isNotBlank() }?.let {
            Text(it, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        }
        detail?.takeIf { it.isNotBlank() }?.let {
            Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun AlphaInfoChip(label: String, modifier: Modifier = Modifier) {
    OutlinedCard(
        modifier = modifier,
        shape = RoundedCornerShape(999.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f)),
    ) {
        Text(
            label,
            modifier = Modifier
                .fillMaxWidth()
                .defaultMinSize(minHeight = 42.dp)
                .padding(horizontal = 12.dp, vertical = 10.dp),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun AlphaCard(title: String? = null, subtitle: String? = null, content: @Composable ColumnScope.() -> Unit) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            title?.takeIf { it.isNotBlank() }?.let {
                Text(it, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            }
            subtitle?.takeIf { it.isNotBlank() }?.let {
                Text(it, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(2.dp))
            }
            content()
        }
    }
}

@Composable
private fun alphaTierTint(tier: AlphaCapabilityTier): Color =
    when (tier) {
        AlphaCapabilityTier.QuickStart -> MaterialTheme.colorScheme.tertiary
        AlphaCapabilityTier.CaseAssociate -> MaterialTheme.colorScheme.secondary
        AlphaCapabilityTier.SeniorDraftingSupport -> MaterialTheme.colorScheme.primary
    }

@Composable
private fun AlphaTierGlyph(tier: AlphaCapabilityTier) {
    val tint = alphaTierTint(tier)
    val asset = when (tier) {
        AlphaCapabilityTier.QuickStart -> RossGlassAsset.BadgeSparkleAccent
        AlphaCapabilityTier.CaseAssociate -> RossGlassAsset.BookOpenNeutral
        AlphaCapabilityTier.SeniorDraftingSupport -> RossGlassAsset.TimelineVerticalNeutral
    }

    Box(
        modifier = Modifier
            .background(tint.copy(alpha = 0.1f), shape = RoundedCornerShape(alphaCompactCornerRadius))
            .padding(horizontal = 9.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        RossGlassIcon(
            asset = asset,
            modifier = Modifier.size(20.dp),
        )
    }
}

@Composable
private fun AlphaSelectableBar(
    modifier: Modifier = Modifier,
    tier: AlphaCapabilityTier,
    selected: Boolean,
    isDownloaded: Boolean = false,
    isActive: Boolean = false,
    onSelect: () -> Unit,
    onInfo: () -> Unit,
) {
    val tint = alphaTierTint(tier)

    OutlinedCard(
        modifier = modifier
            .fillMaxWidth()
            .animateContentSize(),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = if (selected) tint.copy(alpha = 0.08f) else MaterialTheme.colorScheme.surface),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 9.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Row(
                modifier = Modifier
                    .weight(1f)
                    .clickable(onClick = onSelect),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.Top,
            ) {
                AlphaTierGlyph(tier = tier)
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            tier.setupTitle,
                            modifier = Modifier.weight(1f),
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                        if (isActive) {
                            Box(
                                modifier = Modifier
                                    .background(AlphaSuccessStatus.copy(alpha = 0.16f), RoundedCornerShape(alphaPillCornerRadius))
                                    .padding(horizontal = 10.dp, vertical = 4.dp),
                            ) {
                                Text(
                                    "In Use",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.SemiBold,
                                    color = AlphaSuccessStatus,
                                )
                            }
                        } else if (isDownloaded) {
                            Box(
                                modifier = Modifier
                                    .background(tint.copy(alpha = 0.16f), RoundedCornerShape(alphaPillCornerRadius))
                                    .padding(horizontal = 10.dp, vertical = 4.dp),
                            ) {
                                Text(
                                    "Downloaded",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.SemiBold,
                                    color = tint,
                                )
                            }
                        }

                        if (selected) {
                            Box(
                                modifier = Modifier
                                    .background(tint.copy(alpha = 0.16f), RoundedCornerShape(alphaPillCornerRadius))
                                    .padding(horizontal = 10.dp, vertical = 4.dp),
                            ) {
                                Text(
                                    "Selected",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.SemiBold,
                                    color = tint,
                                )
                            }
                        }
                    }
                    Text(
                        "${tier.compactSetupSummary} • On device • Change later",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 3,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }

            OutlinedCard(
                shape = RoundedCornerShape(alphaPillCornerRadius),
                colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.16f)),
                onClick = onInfo,
            ) {
                RossGlassIcon(
                    asset = RossGlassAsset.CircleInfoHighlight,
                    label = "About ${tier.setupTitle}",
                    modifier = Modifier
                        .padding(horizontal = 10.dp, vertical = 8.dp)
                        .size(20.dp),
                )
            }
        }
    }
}

@Composable
private fun AlphaPackTierSheetContent(
    tier: AlphaCapabilityTier,
    selected: Boolean,
    onUseTier: () -> Unit,
    onDismiss: () -> Unit,
) {
    val tint = alphaTierTint(tier)
    var showDownloadDetails by rememberSaveable(tier.tierId) { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top,
        ) {
            Row(
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.Top,
            ) {
                AlphaTierGlyph(tier = tier)
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(tier.setupTitle, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(tier.summary, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            TextButton(onClick = onDismiss) {
                Text("Close")
            }
        }

        if (selected) {
            Text(
                "Selected on this phone",
                modifier = Modifier
                    .background(tint.copy(alpha = 0.12f), shape = RoundedCornerShape(alphaPillCornerRadius))
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = tint,
            )
        }

        Text(tier.bestFor, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(
            "Setup keeps running after you continue. Ross keeps progress visible in Settings.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        TextButton(onClick = { showDownloadDetails = !showDownloadDetails }) {
            Text(if (showDownloadDetails) "Hide download details" else "Download details")
        }
        if (showDownloadDetails) {
            AlphaSettingsValueRow(label = "Download", value = tier.downloadSizeLabel)
            AlphaSettingsValueRow(label = "On-device storage", value = tier.installedSizeLabel)
            AlphaSettingsValueRow(label = "Setup estimate", value = tier.setupTimeLabel)
            AlphaSettingsValueRow(label = "Review depth", value = tier.extractionQuality)
        }

        Button(
            onClick = if (selected) onDismiss else onUseTier,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (selected) "Close" else "Use ${tier.title}")
        }
    }
}

private enum class AlphaCaseSortMode(val label: String, val storageValue: String) {
    RecentlyViewed("Recently Viewed", "recently_viewed"),
    LastAdded("Last Added", "last_added"),
    EarliestActionNeeded("Earliest Action Needed", "earliest_action_needed"),
}

private enum class AlphaMatterListViewMode(val label: String, val storageValue: String) {
    Expanded("Expanded", "expanded"),
    Summary("Summary", "summary"),
    Folder("Folder", "folder"),
}

private enum class AlphaDocumentLayoutMode(val label: String) {
    Grid("Grid"),
    List("List"),
}

private enum class AlphaWorkspaceSection(val label: String) {
    Documents("Documents"),
    NotesExports("Notes"),
}

@Composable
private fun AlphaMatterAttentionCard(
    case: AlphaCaseMatter,
    matterTasks: List<AlphaTaskItem>,
    reviewItems: List<AlphaReviewQueueItem>,
    isRefreshing: Boolean,
    onRefresh: () -> Unit,
    onOpenReview: (() -> Unit)? = null,
) {
    var expanded by rememberSaveable(case.id, reviewItems.size) { mutableStateOf(false) }
    val hasReview = reviewItems.isNotEmpty()
    val tint = if (hasReview) AlphaAmberStatus else MaterialTheme.colorScheme.primary
    val title = when {
        hasReview -> if (reviewItems.size == 1) "1 item needs review" else "${reviewItems.size} items need review"
        matterTasks.any { it.status == AlphaTaskStatus.Open } -> matterTasks.first { it.status == AlphaTaskStatus.Open }.title
        case.draftTasks.isNotEmpty() -> case.draftTasks.first()
        case.documents.isEmpty() -> "Import the first document"
        else -> "Review the latest file"
    }
    val detail = when {
        hasReview -> reviewItems.first().detail
        !case.nextHearing.isNullOrBlank() -> "Next date: ${alphaDateLabel(case.nextHearing)}"
        case.documents.isEmpty() -> "Ross will build the matter workbench after the first file is imported."
        else -> alphaCaseAttentionSummary(case)
    }

    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f)),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(enabled = hasReview) { expanded = !expanded }
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(if (expanded && hasReview) 10.dp else 0.dp),
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .width(2.dp)
                        .height(18.dp)
                        .background(tint.copy(alpha = if (hasReview) 0.78f else 0.48f), RoundedCornerShape(alphaPillCornerRadius))
                )
                Text(
                    if (hasReview) "Needs review" else "Next action",
                    style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 0.6.sp),
                    fontWeight = FontWeight.SemiBold,
                    color = tint,
                )
                Text(
                    title,
                    modifier = Modifier.weight(1f),
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (hasReview) {
                    Icon(
                        imageVector = if (expanded) Icons.Outlined.KeyboardArrowUp else Icons.Outlined.KeyboardArrowDown,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.72f),
                    )
                } else {
                    TextButton(
                        onClick = onRefresh,
                        enabled = !isRefreshing,
                    ) {
                        Text(if (isRefreshing) "Refreshing" else "Refresh")
                    }
                }
            }

            if (expanded && hasReview) {
                androidx.compose.material3.HorizontalDivider(
                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f),
                )
                reviewItems.take(4).forEach { item ->
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.Top,
                    ) {
                        Box(
                            modifier = Modifier
                                .padding(top = 7.dp)
                                .size(4.dp)
                                .background(tint, RoundedCornerShape(alphaPillCornerRadius))
                        )
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(item.title, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                            Text(
                                item.detail,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
                if (onOpenReview != null) {
                    TextButton(
                        onClick = onOpenReview,
                        modifier = Modifier.align(Alignment.End),
                    ) {
                        Text("Open review")
                    }
                }
            } else if (!hasReview) {
                Text(
                    detail,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun AlphaExpandableCard(
    title: String,
    subtitle: String? = null,
    badge: String,
    expanded: Boolean,
    onToggle: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(modifier = Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(onClick = onToggle, modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                        subtitle?.takeIf { it.isNotBlank() }?.let {
                            Text(it, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    Spacer(modifier = Modifier.size(10.dp))
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(badge, style = MaterialTheme.typography.labelMedium)
                        Icon(
                            imageVector = if (expanded) Icons.Outlined.KeyboardArrowUp else Icons.Outlined.KeyboardArrowDown,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
            if (expanded) {
                Spacer(modifier = Modifier.height(10.dp))
                content()
            }
        }
    }
}

@Composable
private fun AlphaAction(title: String, detail: String, onClick: () -> Unit) {
    Button(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Column(horizontalAlignment = Alignment.Start, modifier = Modifier.fillMaxWidth()) {
            Text(title, style = MaterialTheme.typography.bodyMedium)
            Text(detail, style = MaterialTheme.typography.labelMedium)
        }
    }
}

@Composable
private fun AlphaMatterStarterCard(controller: AlphaRossController) {
    AlphaCard("Start with one matter", "Name the matter. Ross can fill in more detail after files are added.") {
        OutlinedTextField(
            value = controller.caseDraftTitle,
            onValueChange = { controller.caseDraftTitle = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Matter name") },
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
        )
        Button(
            onClick = { controller.createCase(openWorkspace = false) },
            modifier = Modifier.fillMaxWidth(),
            enabled = controller.caseDraftTitle.isNotBlank(),
        ) {
            Text("Save matter")
        }
    }
}

@Composable
private fun AlphaAssistantActivityStrip(
    title: String,
    detail: String,
    statusLabel: String,
    tint: Color,
    progress: Float? = null,
    showProgress: Boolean = false,
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.18f)),
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.Top,
            ) {
                Box(
                    modifier = Modifier
                        .padding(top = 4.dp)
                        .size(10.dp)
                        .background(tint, shape = RoundedCornerShape(999.dp))
                )
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                    Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Text(
                    statusLabel,
                    style = MaterialTheme.typography.labelMedium,
                    color = tint,
                )
            }
            if (showProgress) {
                if (progress == null) {
                    LinearProgressIndicator(
                        modifier = Modifier.fillMaxWidth(),
                        color = tint,
                        trackColor = tint.copy(alpha = 0.14f),
                    )
                } else {
                    LinearProgressIndicator(
                        progress = { progress.coerceIn(0f, 1f) },
                        modifier = Modifier.fillMaxWidth(),
                        color = tint,
                        trackColor = tint.copy(alpha = 0.14f),
                    )
                }
            }
        }
    }
}

@Composable
private fun AlphaWorkspaceSectionBar(
    selectedSection: AlphaWorkspaceSection,
    onSelect: (AlphaWorkspaceSection) -> Unit,
    fileBadgeCount: Int = 0,
    taskBadgeCount: Int = 0,
    reviewBadgeCount: Int = 0,
    draftBadgeCount: Int = 0,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        AlphaWorkspaceSection.values().forEach { section ->
            val badgeCount = when (section) {
                AlphaWorkspaceSection.Documents -> fileBadgeCount
                AlphaWorkspaceSection.NotesExports -> taskBadgeCount + reviewBadgeCount + draftBadgeCount
            }
            FilterChip(
                selected = selectedSection == section,
                onClick = { onSelect(section) },
                label = {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(section.label, style = MaterialTheme.typography.labelMedium)
                        if (badgeCount > 0) {
                            Box(
                                modifier = Modifier
                                    .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.10f), RoundedCornerShape(999.dp))
                                    .padding(horizontal = 6.dp, vertical = 2.dp),
                            ) {
                                Text(
                                    badgeCount.coerceAtMost(99).toString(),
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.SemiBold,
                                )
                            }
                        }
                    }
                },
            )
        }
    }
}
@Composable
private fun AlphaBullet(text: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
        Text("•", modifier = Modifier.size(16.dp))
        Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
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
private fun AlphaQuickUnlockGate(
    session: AlphaAccountSession,
    onUnlock: () -> Unit,
    onSignOut: () -> Unit,
) {
    val activity = LocalContext.current as? FragmentActivity
    var promptMessage by remember { mutableStateOf<String?>(null) }
    var attemptedAutoUnlock by remember(session.email, session.locked) { mutableStateOf(false) }

    fun requestUnlock() {
        if (activity == null) {
            promptMessage = "Quick unlock is not available on this device."
            return
        }

        val authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL
        val availability = BiometricManager.from(activity).canAuthenticate(authenticators)
        if (availability != BiometricManager.BIOMETRIC_SUCCESS) {
            promptMessage = "Quick unlock is not available on this device."
            return
        }

        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    promptMessage = null
                    onUnlock()
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    promptMessage = "Could not unlock. Please try again."
                }

                override fun onAuthenticationFailed() {
                    promptMessage = "Ross could not verify the device unlock. Try again."
                }
            },
        )

        prompt.authenticate(
            BiometricPrompt.PromptInfo.Builder()
                .setTitle("Unlock Ross")
                .setSubtitle(session.email ?: "Continue with device unlock")
                .setAllowedAuthenticators(authenticators)
                .build()
        )
    }

    LaunchedEffect(session.locked) {
        if (session.locked && !attemptedAutoUnlock) {
            attemptedAutoUnlock = true
            requestUnlock()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .alphaAuthBackdrop(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(horizontal = 18.dp, vertical = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .widthIn(max = 430.dp),
                verticalArrangement = Arrangement.spacedBy(38.dp),
            ) {
                AlphaAuthBrandRow()
                AlphaAuthHeroCard()
            }
            AlphaAuthPanel(
                modifier = Modifier.widthIn(max = 440.dp),
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        imageVector = Icons.Outlined.Lock,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.65f),
                    )
                    Text("Ross is locked", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.SemiBold)
                    Text(
                        session.email ?: "Use device unlock to continue.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )
                }
                promptMessage?.let {
                    AlphaAuthNotice(it)
                }
                Button(onClick = { requestUnlock() }, modifier = Modifier.fillMaxWidth()) {
                    Text("Unlock with device")
                }
                TextButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) {
                    Text("Sign out")
                }
            }
        }
    }
}

private fun alphaCanUseDeviceUnlock(activity: FragmentActivity?): Boolean {
    if (activity == null) return false
    val authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL
    return BiometricManager.from(activity).canAuthenticate(authenticators) == BiometricManager.BIOMETRIC_SUCCESS
}

@Composable
private fun AlphaCompactRowActionButton(
    icon: ImageVector,
    label: String,
    tint: Color = MaterialTheme.colorScheme.onSurface,
    onClick: () -> Unit,
) {
    OutlinedCard(
        shape = RoundedCornerShape(999.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = alphaChromeBackgroundColor().copy(alpha = 0.92f)),
        border = androidx.compose.foundation.BorderStroke(1.dp, alphaChromeStrokeColor()),
        onClick = onClick,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 10.dp),
            tint = tint,
        )
    }
}

@Composable
private fun AlphaSectionCommandHintCard(
    detail: String,
    actionLabel: String? = null,
    actionIcon: ImageVector? = null,
    actionDisabled: Boolean = false,
    onAction: (() -> Unit)? = null,
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.22f)),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("Use Ask Ross below", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (actionLabel != null && actionIcon != null && onAction != null) {
                Box(modifier = Modifier.defaultMinSize(minWidth = 40.dp)) {
                    AlphaCompactRowActionButton(
                        icon = actionIcon,
                        label = actionLabel,
                        tint = if (actionDisabled) MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f) else MaterialTheme.colorScheme.onSurface,
                        onClick = { if (!actionDisabled) onAction() },
                    )
                }
            }
        }
    }
}

@Composable
private fun AlphaCompactDraftActionButton(
    title: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    OutlinedCard(
        modifier = modifier,
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.2f)),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.onSurface)
            Text(title, style = MaterialTheme.typography.titleSmall, maxLines = 1)
        }
    }
}

@Composable
private fun AlphaTaskRow(task: AlphaTaskItem, onToggle: () -> Unit, onSnooze: (() -> Unit)? = null) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.28f)),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top,
        ) {
            AlphaCompactRowActionButton(
                icon = if (task.status == AlphaTaskStatus.Done) Icons.Outlined.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
                label = if (task.status == AlphaTaskStatus.Done) "Mark task open" else "Mark task done",
                tint = if (task.status == AlphaTaskStatus.Done) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.primary,
                onClick = onToggle,
            )

            Row(
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(task.title, style = MaterialTheme.typography.titleMedium)
                    task.notes
                        ?.takeIf { it.startsWith("review-sync::").not() }
                        ?.takeIf { it.startsWith(ALPHA_ROSS_SUGGESTED_TASK_NOTE_PREFIX).not() }
                        ?.let { note ->
                            Text(note, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                        }
                    task.dueDate?.let { dueDate ->
                        Text("Due ${alphaDateLabel(dueDate)}", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                    }
                }

                if (task.status == AlphaTaskStatus.Open && onSnooze != null) {
                    AlphaCompactRowActionButton(
                        icon = Icons.Outlined.Schedule,
                        label = "Snooze task by one day",
                        onClick = onSnooze,
                    )
                }
            }
        }
    }
}

@Composable
private fun AlphaMatterDateRow(
    matterDate: AlphaMatterDate,
    onMarkDone: () -> Unit,
    onCancel: () -> Unit,
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.28f)),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(matterDate.title, style = MaterialTheme.typography.titleMedium)
                Text(alphaDateLabel(matterDate.date), color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                matterDate.notes?.takeIf { it.isNotBlank() }?.let { note ->
                    Text(note, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                }
            }
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = false,
                    onClick = {},
                    enabled = false,
                    label = { Text(matterDate.kind.title) },
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AlphaCompactRowActionButton(
                        icon = Icons.Outlined.Check,
                        label = "Mark date done",
                        tint = MaterialTheme.colorScheme.tertiary,
                        onClick = onMarkDone,
                    )
                    AlphaCompactRowActionButton(
                        icon = Icons.Outlined.Close,
                        label = "Cancel date",
                        tint = MaterialTheme.colorScheme.error,
                        onClick = onCancel,
                    )
                }
            }
        }
    }
}

@Composable
private fun AlphaReviewNudgeCard(
    item: AlphaReviewQueueItem,
    controller: AlphaRossController,
    onEditFallback: () -> Unit,
) {
    var isEditing by rememberSaveable(item.id) { mutableStateOf(false) }
    var draftValue by rememberSaveable(item.id) { mutableStateOf(item.detail) }
    val fieldId = item.fieldId
    val findingId = item.findingId

    fun accept() {
        when {
            fieldId != null -> controller.acceptExtractedField(item.caseId, item.documentId, fieldId)
            findingId != null -> controller.resolveExtractionFinding(item.caseId, item.documentId, findingId)
        }
        isEditing = false
    }

    fun dismiss() {
        when {
            fieldId != null -> controller.ignoreExtractedField(item.caseId, item.documentId, fieldId)
            findingId != null -> controller.resolveExtractionFinding(item.caseId, item.documentId, findingId)
        }
        isEditing = false
    }

    fun edit() {
        if (fieldId != null) {
            draftValue = item.detail
            isEditing = true
        } else {
            onEditFallback()
        }
    }

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.28f)),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(item.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(item.detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(item.caseTitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.secondary)
                }
                AlphaTagChip("Review")
            }
            item.sourceRef?.let { source ->
                FilterChip(
                    selected = false,
                    onClick = onEditFallback,
                    label = { Text(source.label, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                )
            }
            if (isEditing && fieldId != null) {
                OutlinedTextField(
                    value = draftValue,
                    onValueChange = { draftValue = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Edit value") },
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = {
                            controller.applyFieldCorrection(item.caseId, item.documentId, fieldId, draftValue)
                            isEditing = false
                        },
                        enabled = draftValue.isNotBlank(),
                    ) {
                        Text("Apply")
                    }
                    OutlinedButton(onClick = { isEditing = false }) { Text("Cancel") }
                }
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = ::accept) { Text("Accept") }
                    OutlinedButton(onClick = ::edit) { Text("Edit") }
                    TextButton(onClick = ::dismiss) { Text("Dismiss") }
                }
            }
        }
    }
}

@Composable
private fun AlphaMatterFolderGlyph(tint: AlphaMatterTint, size: Dp = 42.dp) {
    Box(
        modifier = Modifier
            .size(size)
            .clip(RoundedCornerShape(12.dp))
            .background(alphaMatterTintColor(tint).copy(alpha = 0.12f)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = Icons.Outlined.Folder,
            contentDescription = null,
            tint = alphaMatterTintColor(tint),
            modifier = Modifier.size(size * 0.58f),
        )
    }
}

@Composable
private fun AlphaCaseSummaryRow(
    case: AlphaCaseMatter,
    openTasks: Int,
    reviewCount: Int,
    onOpen: () -> Unit,
    onLongPress: (() -> Unit)? = null,
) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .combinedClickable(onClick = onOpen, onLongClick = onLongPress),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.Top,
            ) {
                AlphaMatterFolderGlyph(tint = case.folderTint)
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(case.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                    Text("${case.forum} • ${case.stage.displayTitle}", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                case.nextHearing?.let { nextDate ->
                    Text(alphaDateLabel(nextDate), style = MaterialTheme.typography.labelMedium, color = alphaMatterTintColor(case.folderTint))
                }
            }
            Text(
                "$openTasks open tasks • $reviewCount review items • ${case.documents.size} documents",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.labelMedium,
            )
            Text(
                case.summary,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall,
                maxLines = 2,
            )
            Text(case.localNotice, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun AlphaCaseCompactRow(
    case: AlphaCaseMatter,
    openTasks: Int,
    onOpen: () -> Unit,
    onLongPress: (() -> Unit)? = null,
) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .combinedClickable(onClick = onOpen, onLongClick = onLongPress),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AlphaMatterFolderGlyph(tint = case.folderTint, size = 34.dp)
            Spacer(modifier = Modifier.width(10.dp))
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(case.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, maxLines = 1)
                Text(
                    "${case.forum} • ${case.documents.size} files",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
            }
            Spacer(modifier = Modifier.width(10.dp))
            Text(
                case.nextHearing?.let { alphaDateLabel(it) } ?: "$openTasks open",
                style = MaterialTheme.typography.labelMedium,
                color = if (case.nextHearing == null) MaterialTheme.colorScheme.onSurfaceVariant else alphaMatterTintColor(case.folderTint),
            )
        }
    }
}

@Composable
private fun AlphaCaseFolderRow(
    case: AlphaCaseMatter,
    openTasks: Int,
    reviewCount: Int,
    onOpen: () -> Unit,
    onLongPress: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val tint = alphaMatterTintColor(case.folderTint)

    OutlinedCard(
        modifier = modifier
            .combinedClickable(onClick = onOpen, onLongClick = onLongPress),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, tint.copy(alpha = 0.08f)),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 11.dp, vertical = 11.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            AlphaFolderArtwork(
                tint = tint,
                asset = RossGlassAsset.FolderNeutral,
                badge = if (case.documents.isEmpty()) "New" else "${case.documents.size}",
            )

            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    case.title,
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                )
                Text(
                    case.nextHearing?.let { alphaDateLabel(it) }
                        ?: "$openTasks open task(s)",
                    style = MaterialTheme.typography.labelMedium,
                    color = tint,
                    maxLines = 1,
                )
                if (reviewCount > 0) {
                    Text(
                        "$reviewCount review item(s)",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

@Composable
private fun AlphaFolderArtwork(
    tint: Color,
    asset: RossGlassAsset,
    badge: String?,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(76.dp)
    ) {
        if (asset == RossGlassAsset.FolderNeutral) {
            Icon(
                imageVector = Icons.Outlined.Folder,
                contentDescription = null,
                tint = tint,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(start = 2.dp, top = 2.dp)
                    .size(64.dp),
            )
        } else {
            RossGlassIcon(
                asset = asset,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(start = 2.dp, top = 2.dp)
                    .size(64.dp),
            )
        }

        badge?.let {
            Text(
                it,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(start = 2.dp, bottom = 2.dp)
                    .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.92f), RoundedCornerShape(999.dp))
                    .border(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f), RoundedCornerShape(999.dp))
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = tint,
            )
        }
    }
}

@Composable
private fun AlphaDocumentLayoutMenu(
    layoutMode: AlphaDocumentLayoutMode,
    onSelect: (AlphaDocumentLayoutMode) -> Unit,
) {
    AlphaIconMenuButton(
        icon = if (layoutMode == AlphaDocumentLayoutMode.Grid) Icons.Outlined.GridView else Icons.AutoMirrored.Outlined.ViewList,
        label = "Change document view"
    ) { closeMenu ->
        AlphaDocumentLayoutMode.values().forEach { option ->
            DropdownMenuItem(
                text = { Text(option.label) },
                onClick = {
                    onSelect(option)
                    closeMenu()
                },
            )
        }
    }
}

@Composable
private fun AlphaDocumentFolderTile(
    document: AlphaCaseDocument,
    onOpen: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tint = alphaDocumentTint(document.kind)
    val asset = alphaDocumentAsset(document.kind)

    OutlinedCard(
        modifier = modifier.clickable(onClick = onOpen),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, tint.copy(alpha = 0.08f)),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 11.dp, vertical = 11.dp),
            verticalArrangement = Arrangement.spacedBy(9.dp),
        ) {
            AlphaFolderArtwork(
                tint = tint,
                asset = asset,
                badge = if (document.pageCount == 1) "1 page" else "${document.pageCount}",
            )

            Text(
                document.title,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
            )

            Text(
                document.lawyerStatusTitle(),
                style = MaterialTheme.typography.labelSmall,
                color = tint,
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun AlphaExpandableDocumentRow(
    caseTitle: String?,
    document: AlphaCaseDocument,
    expanded: Boolean,
    canMoveEarlier: Boolean,
    canMoveLater: Boolean,
    onToggle: () -> Unit,
    onOpen: () -> Unit,
    onMoveEarlier: () -> Unit,
    onMoveLater: () -> Unit,
) {
    val tint = alphaDocumentTint(document.kind)
    val asset = alphaDocumentAsset(document.kind)

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TextButton(onClick = onToggle, modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    RossGlassIcon(
                        asset = asset,
                        modifier = Modifier.size(30.dp),
                    )

                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(document.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                        caseTitle?.let {
                            Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Text(
                            "${document.kind.title} • ${alphaPageCountLabel(document.pageCount)} • ${document.lawyerStatusTitle()}",
                            style = MaterialTheme.typography.labelMedium,
                            color = tint,
                        )
                    }

                    Icon(
                        imageVector = if (expanded) Icons.Outlined.KeyboardArrowUp else Icons.Outlined.KeyboardArrowDown,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            if (expanded) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        "Imported ${alphaDateLabel(document.importedAt)}",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )

                    document.dominantSourceSnippet?.takeIf { it.isNotBlank() }?.let { snippet ->
                        Text(
                            snippet,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 3,
                        )
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = onOpen) {
                            Text("Open")
                        }
                        if (canMoveEarlier) {
                            TextButton(onClick = onMoveEarlier) {
                                Text("Move up")
                            }
                        }
                        if (canMoveLater) {
                            TextButton(onClick = onMoveLater) {
                                Text("Move down")
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AlphaSummaryRow(title: String, detail: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(title, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
        Text(detail, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun AlphaDocumentBrowser(
    documents: List<AlphaCaseDocument>,
    caseTitle: String?,
    layoutMode: AlphaDocumentLayoutMode,
    expandedDocumentIds: Set<String>,
    onExpandedDocumentIdsChange: (Set<String>) -> Unit,
    onOpen: (String) -> Unit,
    onMoveDocument: (String, Int) -> Unit,
) {
    when (layoutMode) {
        AlphaDocumentLayoutMode.Grid -> {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                documents.chunked(3).forEach { rowDocuments ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        rowDocuments.forEach { document ->
                            AlphaDocumentFolderTile(
                                document = document,
                                onOpen = { onOpen(document.id) },
                                modifier = Modifier.weight(1f),
                            )
                        }
                        repeat(3 - rowDocuments.size) {
                            Spacer(modifier = Modifier.weight(1f))
                        }
                    }
                }
            }
        }
        AlphaDocumentLayoutMode.List -> {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                documents.forEachIndexed { index, document ->
                    AlphaExpandableDocumentRow(
                        caseTitle = caseTitle,
                        document = document,
                        expanded = expandedDocumentIds.contains(document.id),
                        canMoveEarlier = index > 0,
                        canMoveLater = index < documents.lastIndex,
                        onToggle = {
                            onExpandedDocumentIdsChange(
                                expandedDocumentIds.toMutableSet().apply {
                                    if (contains(document.id)) remove(document.id) else add(document.id)
                                }
                            )
                        },
                        onOpen = { onOpen(document.id) },
                        onMoveEarlier = { onMoveDocument(document.id, -1) },
                        onMoveLater = { onMoveDocument(document.id, 1) },
                    )
                }
            }
        }
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
            Text(document.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
            caseTitle?.let {
                Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text(document.lawyerStatusTitle(), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.secondary)
        }
    }
}

@Composable
private fun AlphaAskConversationScreen(
    controller: AlphaRossController,
    fixedScopeCaseId: String?,
    showBack: Boolean,
    onBack: () -> Unit,
    onOpenSource: (AlphaSourceRef) -> Unit,
) {
    val activeScopeCaseId = fixedScopeCaseId ?: controller.askSelectedScopeCaseId
    val selectedDocuments = controller.selectedAskDocuments(activeScopeCaseId)
    val documentTitle = controller.askDocumentTitle(activeScopeCaseId)
    val conversation = controller.askConversation(activeScopeCaseId)
    val introDetail = when {
        documentTitle != null -> "Ask about $documentTitle, what it means, or what to do next."
        selectedDocuments.isNotEmpty() -> "Ask using only the files you selected here."
        activeScopeCaseId == null -> "Ask about today, shared files, or any matter on this device."
        else -> "Ask about this matter, its files, and what to do next."
    }
    AlphaShell(
        title = "Chat",
        showBack = showBack,
        onBack = onBack,
        bottomBar = {
            AlphaRootAskDock(controller = controller, fixedScopeCaseId = fixedScopeCaseId)
        },
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = alphaScreenPadding),
            contentPadding = PaddingValues(vertical = 18.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            if (conversation.isEmpty()) {
                item {
                    AlphaAskEmptyState(
                        detail = introDetail,
                        suggestions = alphaAskSuggestions(
                            scopeLabel = if (activeScopeCaseId == null) null else controller.scopeLabel(activeScopeCaseId),
                            documentTitle = documentTitle,
                        ),
                        onSelectSuggestion = { controller.setAskDraft(activeScopeCaseId, it) },
                    )
                }
            } else {
                item {
                    Text(
                        "Verify all answers before filing or sharing.",
                        modifier = Modifier.fillMaxWidth(),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.45f),
                        textAlign = TextAlign.Center,
                    )
                }
                items(conversation, key = { "${it.scopeCaseId}:${it.question}:${it.answerTitle}" }) { result ->
                    AlphaAskTurnCard(
                        result = result,
                        contextDocumentTitle = documentTitle,
                        onOpenSource = onOpenSource,
                        onReport = { controller.reportAiOutput(result.question, result.scopeCaseId) },
                    )
                }
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
        Text(alphaAskEmptyTitle(), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(
            detail,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            suggestions.forEach { suggestion ->
                OutlinedCard(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(alphaCardCornerRadius),
                    colors = CardDefaults.outlinedCardColors(
                        containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.86f),
                        contentColor = MaterialTheme.colorScheme.onSurface,
                    ),
                    border = androidx.compose.foundation.BorderStroke(1.dp, alphaChromeStrokeColor()),
                    onClick = { onSelectSuggestion(suggestion) },
                ) {
                    Text(
                        suggestion,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
        }
    }
}

@Composable
private fun AlphaAskTurnCard(
    result: AlphaAskResult,
    contextDocumentTitle: String?,
    onOpenSource: (AlphaSourceRef) -> Unit,
    onReport: () -> Unit,
) {
    var privacyExpanded by remember { mutableStateOf(false) }
    var sourcesExpanded by remember { mutableStateOf(false) }
    var showMenu by remember { mutableStateOf(false) }
    var showAnswerDetails by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val haptics = LocalHapticFeedback.current
    val hasAnswerDetails = result.answerDetails != null
    val answerSummaryModifier = if (hasAnswerDetails) {
        Modifier.combinedClickable(
            onClick = {},
            onLongClick = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                showAnswerDetails = true
            },
        )
    } else {
        Modifier
    }
    val deduplicatedStatusNote = result.statusNote?.takeIf {
        it.trim().lowercase() != result.answerTitle.trim().lowercase()
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            OutlinedCard(
                modifier = Modifier.widthIn(max = 320.dp),
                shape = RoundedCornerShape(alphaCardCornerRadius),
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
            shape = RoundedCornerShape(alphaCardCornerRadius),
            colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.82f)),
        ) {
            Column(modifier = Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(modifier = answerSummaryModifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            result.answerTitle,
                            modifier = Modifier.weight(1f),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            if (hasAnswerDetails) {
                                OutlinedCard(
                                    modifier = Modifier.size(32.dp),
                                    shape = RoundedCornerShape(999.dp),
                                    colors = CardDefaults.outlinedCardColors(
                                        containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.26f),
                                    ),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, alphaChromeStrokeColor()),
                                    onClick = { showAnswerDetails = true },
                                ) {
                                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                        Icon(
                                            Icons.Outlined.Info,
                                            contentDescription = "Answer details",
                                            modifier = Modifier.size(16.dp),
                                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        )
                                    }
                                }
                            }
                            Box {
                                Icon(
                                    Icons.Outlined.MoreVert,
                                    contentDescription = "Answer actions",
                                    modifier = Modifier
                                        .size(24.dp)
                                        .clickable { showMenu = true },
                                    tint = MaterialTheme.colorScheme.primary,
                                )
                                DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                                    result.answerDetails?.let {
                                        DropdownMenuItem(
                                            text = { Text("Answer details") },
                                            onClick = {
                                                showMenu = false
                                                showAnswerDetails = true
                                            },
                                            leadingIcon = { Icon(Icons.Outlined.Info, contentDescription = null) },
                                        )
                                    }
                                    DropdownMenuItem(
                                        text = { Text("Copy answer") },
                                        onClick = {
                                            (context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager)
                                                ?.setPrimaryClip(ClipData.newPlainText("Ross answer", alphaCopyAskResultText(result)))
                                            showMenu = false
                                        },
                                        leadingIcon = { Icon(Icons.Outlined.ContentCopy, contentDescription = null) },
                                    )
                                    DropdownMenuItem(
                                        text = { Text("Report answer") },
                                        onClick = { showMenu = false; onReport() },
                                        leadingIcon = { Icon(Icons.Outlined.Flag, contentDescription = null) },
                                    )
                                }
                            }
                        }
                    }
                    result.answerSections.forEach { section ->
                        AlphaFormattedAnswerText(section)
                    }
                    deduplicatedStatusNote?.let { note ->
                        Text(note, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.secondary)
                    }
                    if (result.selectedDocumentTitles.isNotEmpty() && contextDocumentTitle == null) {
                        Row(
                            modifier = Modifier.horizontalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            result.selectedDocumentTitles.forEach { title ->
                                OutlinedCard(
                                    shape = RoundedCornerShape(999.dp),
                                    colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)),
                                    border = androidx.compose.foundation.BorderStroke(0.dp, Color.Transparent),
                                ) {
                                    Text(
                                        title,
                                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.SemiBold,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                            }
                        }
                    }
                }
                if (result.caseFileSources.isNotEmpty()) {
                    OutlinedCard(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(alphaCardCornerRadius),
                        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.22f)),
                    ) {
                        Column(
                            modifier = Modifier.padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            AlphaSectionLabel("Sources", "From your files on this device.")
                            val shouldCollapseSources = result.caseFileSources.size > 2
                            if (shouldCollapseSources) {
                                TextButton(
                                    onClick = { sourcesExpanded = !sourcesExpanded },
                                    modifier = Modifier.fillMaxWidth(),
                                ) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        Text(if (sourcesExpanded) "Hide sources" else "Show ${result.caseFileSources.size} sources")
                                        Icon(
                                            imageVector = if (sourcesExpanded) Icons.Outlined.KeyboardArrowUp else Icons.Outlined.KeyboardArrowDown,
                                            contentDescription = null,
                                        )
                                    }
                                }
                            }
                            if (!shouldCollapseSources || sourcesExpanded) {
                                result.caseFileSources.forEach { source ->
                                    OutlinedCard(
                                        modifier = Modifier.fillMaxWidth(),
                                        shape = RoundedCornerShape(14.dp),
                                        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.72f)),
                                        onClick = { onOpenSource(source) },
                                    ) {
                                        Column(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                            Text(
                                                alphaSourceLabel(source, contextDocumentTitle),
                                                style = MaterialTheme.typography.labelLarge,
                                                fontWeight = FontWeight.SemiBold,
                                            )
                                            Text(source.detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                result.publicLawPreview?.let { preview ->
                    OutlinedCard(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(alphaCardCornerRadius),
                        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.22f)),
                    ) {
                        Column(
                            modifier = Modifier.padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            AlphaSectionLabel("What Ross searched", "Ross removed case details before searching.")
                            Text(preview.query, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                if (result.publicLawResults.isNotEmpty()) {
                    OutlinedCard(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(alphaCardCornerRadius),
                        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.22f)),
                    ) {
                        Column(
                            modifier = Modifier.padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            AlphaSectionLabel("From Legal Search", "Separate from your case files. Based on a cleaned search query.")
                            result.publicLawResults.forEach { publicResult ->
                                AlphaPublicLawResultCard(publicResult)
                            }
                        }
                    }
                }
                if (result.publicLawPreview != null || result.publicLawResults.isNotEmpty() || result.needsReviewWarning != null) {
                    AlphaPublicLawWarningsCard(
                        needsReviewWarning = result.needsReviewWarning,
                        includePublicLawWarnings = result.publicLawPreview != null || result.publicLawResults.isNotEmpty(),
                    )
                }

                // Compact privacy badge — expandable
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(999.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f))
                        .clickable { privacyExpanded = !privacyExpanded }
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Filled.Lock,
                        contentDescription = null,
                        modifier = Modifier.size(12.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                    )
                    Text(
                        alphaCompactPrivacyLabel(result),
                        modifier = Modifier.weight(1f),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                    )
                    Icon(
                        if (privacyExpanded) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                    )
                }
                AnimatedVisibility(visible = privacyExpanded) {
                    Text(
                        alphaPrivacyReceipt(result),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                    )
                }
            }
        }
    }

    if (showAnswerDetails && result.answerDetails != null) {
        AlphaAskAnswerDetailsSheet(
            result = result,
            onDismiss = { showAnswerDetails = false },
        )
    }
}

private fun alphaCopyAskResultText(result: AlphaAskResult): String =
    (listOf(result.answerTitle) + result.answerSections).joinToString(separator = "\n\n")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AlphaAskAnswerDetailsSheet(
    result: AlphaAskResult,
    onDismiss: () -> Unit,
) {
    val details = result.answerDetails ?: return
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surface,
        dragHandle = null,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text("Answer details", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Text(
                result.answerTitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            alphaAskAnswerDetailTokenLabel(details)?.let { tokenLabel ->
                AlphaSettingsValueRow("Tokens processed", tokenLabel)
            }
            alphaAskAnswerDetailSpeedLabel(details)?.let { speedLabel ->
                AlphaSettingsValueRow("Token speed", speedLabel)
            }
            alphaAskAnswerDetailRuntimeLabel(details)?.let { runtimeLabel ->
                AlphaSettingsValueRow("Runtime used", runtimeLabel)
            }
            alphaAskAnswerDetailPreferredRuntimeLabel(details)?.let { preferredRuntimeLabel ->
                AlphaSettingsValueRow("Preferred runtime", preferredRuntimeLabel)
            }
            details.runtimeFallbackReason?.let { fallbackReason ->
                AlphaSettingsValueRow("Fallback", fallbackReason)
            }
            alphaAskAnswerDetailPromptSizeLabel(details)?.let { promptSizeLabel ->
                AlphaSettingsValueRow("Prompt size", promptSizeLabel)
            }
            alphaAskAnswerDetailSourceCoverageLabel(details)?.let { sourceCoverageLabel ->
                AlphaSettingsValueRow("Source coverage", sourceCoverageLabel)
            }
        }
    }
}

private fun alphaAskAnswerDetailTokenLabel(details: AlphaAskAnswerDetails): String? {
    val processedTokens = details.estimatedProcessedTokens ?: return null
    return if (details.usesMeasuredTokenCounts) {
        processedTokens.toString()
    } else {
        "~$processedTokens"
    }
}

private fun alphaAskAnswerDetailSpeedLabel(details: AlphaAskAnswerDetails): String? {
    val tokensPerSecond = details.estimatedTokensPerSecond ?: return null
    val formatted = "${"%.1f".format(tokensPerSecond)} tok/s"
    return if (details.usesMeasuredTokenCounts) {
        formatted
    } else {
        "~$formatted"
    }
}

private fun alphaAskRuntimeModeLabel(runtimeMode: String?): String? =
    when (runtimeMode) {
        AlphaPackRuntimeMode.GemmaLocalRuntime.wireValue -> "Gemma GGUF"
        AlphaPackRuntimeMode.AppleFoundationModels.wireValue -> "Built-in CoreAI"
        AlphaPackRuntimeMode.MediapipeLlm.wireValue -> "MediaPipe"
        AlphaPackRuntimeMode.DeterministicDev.wireValue -> "Development runtime"
        AlphaPackRuntimeMode.Unavailable.wireValue, null -> null
        else -> runtimeMode
            .replace("_", " ")
            .split(" ")
            .joinToString(" ") { token -> token.replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString() } }
    }

private fun alphaAskAnswerDetailRuntimeLabel(details: AlphaAskAnswerDetails): String? =
    alphaAskRuntimeModeLabel(details.runtimeMode)

private fun alphaAskAnswerDetailPreferredRuntimeLabel(details: AlphaAskAnswerDetails): String? =
    alphaAskRuntimeModeLabel(details.preferredRuntimeMode)

private fun alphaAskAnswerDetailPromptSizeLabel(details: AlphaAskAnswerDetails): String? =
    details.promptChars
        ?.takeIf { it > 0 }
        ?.let { "${String.format(Locale.getDefault(), "%,d", it)} chars" }

private fun alphaAskAnswerDetailSourceCoverageLabel(details: AlphaAskAnswerDetails): String? {
    val usedSourceCount = details.usedSourceCount ?: return null
    val reviewedSourceCount = details.reviewedSourceCount?.takeIf { it > 0 } ?: return usedSourceCount.toString()
    return if (usedSourceCount < reviewedSourceCount) {
        "${String.format(Locale.getDefault(), "%,d", usedSourceCount)} / ${String.format(Locale.getDefault(), "%,d", reviewedSourceCount)}"
    } else {
        String.format(Locale.getDefault(), "%,d", usedSourceCount)
    }
}

private fun alphaCompactPrivacyLabel(result: AlphaAskResult): String {
    if (result.publicLawPreview != null && result.publicLawResults.isEmpty()) return "On-device · review pending"
    if (result.publicLawPreview != null || result.publicLawResults.isNotEmpty()) return "On-device + Legal Search"
    return "On-device only"
}

private fun alphaPrivacyReceipt(result: AlphaAskResult): String {
    if (result.publicLawPreview != null && result.publicLawResults.isEmpty()) {
        return "Your files stay on this device. A legal search query is awaiting your review — nothing has been sent yet."
    }
    if (result.publicLawPreview != null && result.publicLawResults.isNotEmpty() && result.caseFileSources.isNotEmpty()) {
        return "Ross used your local files and legal search results. Case details were removed before searching."
    }
    if (result.publicLawPreview != null || result.publicLawResults.isNotEmpty()) {
        return "Ross used Legal Search after you approved. Your case files stayed on this device."
    }
    return "Answered using only your files on this device. Nothing was sent online."
}

private val alphaAnswerBulletRegex = Regex("^[-•*]\\s+(.*)")
private val alphaAnswerNumberedRegex = Regex("^(\\d+\\.)\\s+(.*)")

@Composable
private fun AlphaFormattedAnswerText(text: String) {
    val lines = text.split("\n").filter { it.isNotBlank() }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        lines.forEach { line ->
            val trimmed = line.trim()
            val bulletMatch = alphaAnswerBulletRegex.matchEntire(trimmed)
            val numberedMatch = alphaAnswerNumberedRegex.matchEntire(trimmed)
            when {
                bulletMatch != null -> {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            "•",
                            modifier = Modifier.width(18.dp),
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.7f),
                            textAlign = TextAlign.End,
                        )
                        Text(
                            bulletMatch.groupValues[1],
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.88f),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
                numberedMatch != null -> {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            numberedMatch.groupValues[1],
                            modifier = Modifier.width(18.dp),
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.7f),
                            textAlign = TextAlign.End,
                        )
                        Text(
                            numberedMatch.groupValues[2],
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.88f),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
                else -> {
                    Text(
                        trimmed,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.88f),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }
        }
    }
}

@Composable
private fun AlphaSectionLabel(title: String, detail: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(title, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(detail, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun AlphaTagChip(title: String) {
    OutlinedCard(
        shape = RoundedCornerShape(999.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.08f)),
        border = androidx.compose.foundation.BorderStroke(0.dp, Color.Transparent),
    ) {
        Text(
            title,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.primary,
        )
    }
}

@Composable
private fun AlphaPublicLawResultCard(result: AlphaPublicLawResult) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.72f)),
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                AlphaTagChip("Legal Search result")
                Text(
                    result.sourceName,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(result.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            if (result.citation.isNotBlank()) {
                Text(result.citation, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
            }
            Text(result.snippet, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun AlphaPublicLawWarningsCard(needsReviewWarning: String?, includePublicLawWarnings: Boolean) {
    val warnings = buildList {
        if (includePublicLawWarnings) {
            add("Legal Search used a sanitized query.")
            add("Verify all citations before use.")
            add("Draft — please review.")
        }
        if (!needsReviewWarning.isNullOrBlank()) {
            add(needsReviewWarning)
        }
    }
    if (warnings.isEmpty()) return

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(alphaCardCornerRadius),
        colors = CardDefaults.outlinedCardColors(containerColor = AlphaAmberStatus.copy(alpha = 0.08f)),
        border = androidx.compose.foundation.BorderStroke(1.dp, AlphaAmberStatus.copy(alpha = 0.25f)),
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            AlphaSectionLabel("Warnings", "Keep legal search references and matter facts separate while reviewing.")
            warnings.forEach { AlphaBullet(it) }
        }
    }
}

private fun alphaAskSuggestions(scopeLabel: String?, documentTitle: String? = null): List<String> =
    if (alphaUsesHindiUi()) {
        if (!documentTitle.isNullOrBlank()) {
            listOf(
                "इस दस्तावेज़ का सार बताओ",
                "अदालत ने क्या निर्देश दिए?",
                "इस दस्तावेज़ से कार्य बनाओ",
                "क्या पुष्टि करनी है?",
            )
        } else if (scopeLabel.isNullOrBlank()) {
            listOf(
                "आज मुझे किस पर ध्यान देना है?",
                "कार्य जोड़ो",
                "अगली तारीख सहेजो",
                "केस नोट बनाओ",
            )
        } else {
            listOf(
                "इस मामले का सार बताओ",
                "हियरिंग नोट तैयार करो",
                "महत्वपूर्ण तारीखें बताओ",
                "कौन से कार्य बनाने चाहिए?",
            )
        }
    } else if (!documentTitle.isNullOrBlank()) {
        listOf(
            "Summarize this document",
            "What directions did the court give?",
            "Create tasks from this document",
            "What should I confirm?",
        )
    } else if (scopeLabel.isNullOrBlank()) {
        listOf(
            "What needs my attention today?",
            "Add task",
            "Save next hearing",
            "Generate case note",
        )
    } else {
        listOf(
            "Summarize this matter",
            "Prepare hearing note",
            "List important dates",
            "What tasks should I create?",
        )
    }

private fun alphaUsesHindiUi(): Boolean =
    Locale.getDefault().language.equals("hi", ignoreCase = true)

private fun alphaAskEmptyTitle(): String =
    if (alphaUsesHindiUi()) "Ross से आगे का काम पूछें" else "Ask Ross what's next"

private fun alphaFileSizeLabel(context: Context, bytes: Long): String =
    Formatter.formatShortFileSize(context, bytes.coerceAtLeast(0))

private fun alphaStorageSnapshot(controller: AlphaRossController): AlphaStorageSnapshot {
    val documents = controller.cases.flatMap { it.documents }
    val documentBytes = documents.fold(0L) { total, document ->
        total + (controller.absoluteFile(document.storedRelativePath).takeIf(File::exists)?.length() ?: 0L)
    }
    val exportBytes = controller.persisted.exports.fold(0L) { total, report ->
        total + (controller.absoluteFile(report.relativePath).takeIf(File::exists)?.length() ?: 0L)
    }
    val assistantBytes = controller.persisted.installedPacks.fold(0L) { total, pack ->
        total + (controller.absoluteFile(pack.installRelativePath).takeIf(File::exists)?.length() ?: 0L)
    }
    return AlphaStorageSnapshot(
        documentCount = documents.size,
        exportCount = controller.persisted.exports.size,
        documentBytes = documentBytes,
        exportBytes = exportBytes,
        assistantBytes = assistantBytes,
    )
}

@Composable
private fun alphaMatterTintColor(tint: AlphaMatterTint): Color =
    when (tint) {
        AlphaMatterTint.Indigo -> MaterialTheme.colorScheme.primary
        AlphaMatterTint.Amber -> AlphaAmberStatus
        AlphaMatterTint.Emerald -> MaterialTheme.colorScheme.tertiary
        AlphaMatterTint.Rose -> Color(0xFFC65C78)
        AlphaMatterTint.Slate -> MaterialTheme.colorScheme.onSurfaceVariant
    }

private fun alphaMatterTintLabel(tint: AlphaMatterTint): String =
    when (tint) {
        AlphaMatterTint.Indigo -> "Indigo"
        AlphaMatterTint.Amber -> "Amber"
        AlphaMatterTint.Emerald -> "Emerald"
        AlphaMatterTint.Rose -> "Rose"
        AlphaMatterTint.Slate -> "Slate"
    }

@Composable
private fun alphaDocumentTint(kind: AlphaDocumentKind): Color =
    when (kind) {
        AlphaDocumentKind.Pdf -> MaterialTheme.colorScheme.primary
        AlphaDocumentKind.Image -> AlphaAmberStatus
        AlphaDocumentKind.Text -> MaterialTheme.colorScheme.tertiary
        AlphaDocumentKind.Unknown -> MaterialTheme.colorScheme.onSurfaceVariant
    }

private fun alphaDocumentAsset(kind: AlphaDocumentKind): RossGlassAsset =
    when (kind) {
        AlphaDocumentKind.Pdf -> RossGlassAsset.FileNeutral
        AlphaDocumentKind.Image -> RossGlassAsset.FilesNeutral
        AlphaDocumentKind.Text -> RossGlassAsset.FileNeutral
        AlphaDocumentKind.Unknown -> RossGlassAsset.FileNeutral
    }

private fun alphaSourceLabel(source: AlphaSourceRef, contextDocumentTitle: String?): String {
    val label = source.label.trim()
    val context = contextDocumentTitle?.trim().orEmpty()
    if (context.isEmpty()) return label
    if (label == context) return "This file"

    listOf("$context ", "$context: ", "$context · ").forEach { prefix ->
        if (label.startsWith(prefix)) {
            val shortened = label.removePrefix(prefix).trim()
            return if (shortened.isEmpty()) "This file" else shortened
        }
    }

    return label
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
        OutlinedCard(
            shape = RoundedCornerShape(999.dp),
            colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.18f)),
            onClick = { expanded = true },
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(label, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
                Text("v", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
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

@Composable
private fun AlphaIconMenuButton(
    icon: ImageVector,
    label: String,
    content: @Composable (closeMenu: () -> Unit) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }

    Box {
        OutlinedCard(
            shape = RoundedCornerShape(999.dp),
            colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.18f)),
            onClick = { expanded = true },
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 9.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = label,
                    tint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(18.dp),
                )
                Icon(
                    imageVector = Icons.Outlined.KeyboardArrowDown,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(14.dp),
                )
            }
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            content { expanded = false }
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
    cases.flatMap { matter ->
        alphaScheduledMatterDates(matter)
            .filter { alphaIsToday(it.date) }
            .map { date -> "${date.title}: ${matter.title}" }
    }

private fun alphaUpcomingDateLines(cases: List<AlphaCaseMatter>): List<String> =
    cases.flatMap { matter ->
        alphaScheduledMatterDates(matter).mapNotNull { date ->
            alphaParsedInstant(date.date)?.let { instant ->
                Triple(matter.title, date.title, instant)
            }
        }
    }
        .sortedBy { it.third }
        .map { (title, label, instant) ->
            "$label: $title on ${alphaDateLabel(instant.toString())}"
        }

private fun alphaSortedCases(sortMode: AlphaCaseSortMode, cases: List<AlphaCaseMatter>, controller: AlphaRossController): List<AlphaCaseMatter> =
    when (sortMode) {
        AlphaCaseSortMode.RecentlyViewed -> cases.sortedByDescending { it.updatedAt }
        AlphaCaseSortMode.LastAdded -> cases
        AlphaCaseSortMode.EarliestActionNeeded -> cases.sortedWith(
            compareBy<AlphaCaseMatter> { alphaNextActionInstant(it, controller) == null }
                .thenBy { alphaNextActionInstant(it, controller) ?: java.time.Instant.MAX }
                .thenByDescending { it.updatedAt }
        )
    }

private fun alphaNextActionInstant(case: AlphaCaseMatter, controller: AlphaRossController): java.time.Instant? {
    val nextTask = controller.tasks(case.id)
        .firstOrNull { it.status == AlphaTaskStatus.Open && it.dueDate != null }
        ?.dueDate
        ?.let(::alphaParsedInstant)
    val nextMatterDate = alphaScheduledMatterDates(case)
        .mapNotNull { alphaParsedInstant(it.date) }
        .minOrNull()
    val nextHearing = alphaParsedInstant(case.nextHearing)
    return listOfNotNull(nextTask, nextMatterDate, nextHearing).minOrNull()
}

private fun alphaCaseAttentionSummary(case: AlphaCaseMatter): String =
    when {
        alphaScheduledMatterDates(case).isNotEmpty() -> {
            val nextDate = alphaScheduledMatterDates(case)
                .sortedBy { it.date }
                .first()
            "Ross sees the next focus as ${nextDate.title.lowercase()} on ${alphaDateLabel(nextDate.date)}."
        }
        case.nextHearing != null -> "Ross sees the next focus as getting this file ready for ${alphaDateLabel(case.nextHearing)}."
        case.draftTasks.isNotEmpty() -> "Ross sees the next focus as ${case.draftTasks.first().lowercase()}."
        else -> "Ross is ready to refresh the next-step note after another document or instruction is added."
    }

private fun alphaScheduledMatterDates(case: AlphaCaseMatter): List<AlphaMatterDate> {
    val scheduledDates = case.dates.filter { it.status == AlphaMatterDateStatus.Scheduled }
    if (scheduledDates.isNotEmpty()) {
        return scheduledDates
    }
    return case.nextHearing?.let { nextHearing ->
        listOf(
            AlphaMatterDate(
                caseId = case.id,
                title = "Next hearing",
                kind = AlphaMatterDateKind.Hearing,
                date = nextHearing,
            )
        )
    } ?: emptyList()
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

private fun alphaPrivateAiStatus(controller: AlphaRossController): Pair<String, String> {
    val activePack = controller.activePack()
    val activeJob = controller.persisted.modelJobs.firstOrNull()
    val runtimeHealth = controller.activeRuntimeHealth()
    val askRuntimeHealth = controller.askRuntimeHealth()
    val askRuntimePack = controller.askRuntimePack()

    return when {
        activeJob?.state == AlphaDownloadState.Downloading || activeJob?.state == AlphaDownloadState.Queued || activeJob?.state == AlphaDownloadState.Verifying ->
            "Setting up private assistant" to "Ross is setting up your private assistant on this device. You can keep working while setup finishes."
        activeJob?.state == AlphaDownloadState.PausedWaitingForWifi ->
            "Waiting for Wi-Fi" to "Ross will resume the private assistant setup when Wi-Fi is available."
        activeJob?.state == AlphaDownloadState.PausedUser ->
            "Private assistant needs attention" to "Setup is paused. You can continue working and resume whenever you are ready."
        activeJob?.state == AlphaDownloadState.PausedNoStorage ->
            "Private assistant needs attention" to "Free up space and try again."
        activeJob?.state == AlphaDownloadState.Failed || activeJob?.state == AlphaDownloadState.PausedError || activeJob?.state == AlphaDownloadState.Cancelled ->
            "Private assistant needs attention" to "Private assistant could not be set up. Open setup to retry."
        askRuntimeHealth?.available == true && askRuntimeHealth.fallbackActive == true ->
            "Private assistant is ready" to (
                askRuntimePack?.tier?.title?.let { tierTitle ->
                    "Ask Ross will use $tierTitle on this Android build when the active assistant cannot run locally."
                } ?: askRuntimeHealth.userFacingStatus
            )
        activePack != null && runtimeHealth?.fallbackActive == true ->
            "Private assistant unavailable" to "${activePack.tier.title} is installed, but Ross cannot use it right now."
        activePack != null && runtimeHealth?.available == true ->
            "Private assistant is ready" to "${activePack.tier.title} is ready for reading files, drafting, and Ask Ross actions on this device."
        activePack != null ->
            "Private assistant needs attention" to "${activePack.tier.title} is installed, but Ross needs to check it before turning it on."
        else ->
            "Private assistant is not set up." to "Ross can still organize matters, tasks, dates, and files on this device. Legal answers require model setup."
    }
}

private fun alphaActiveSetupJob(controller: AlphaRossController): AlphaModelDownloadJob? =
    controller.persisted.modelJobs.firstOrNull { job ->
        when (job.state) {
            AlphaDownloadState.NotStarted,
            AlphaDownloadState.Installed,
            AlphaDownloadState.Cancelled,
            AlphaDownloadState.Failed -> false
            AlphaDownloadState.Queued,
            AlphaDownloadState.Downloading,
            AlphaDownloadState.PausedWaitingForWifi,
            AlphaDownloadState.PausedUser,
            AlphaDownloadState.PausedNoStorage,
            AlphaDownloadState.PausedError,
            AlphaDownloadState.Verifying -> true
        }
    }

private fun alphaAssistantActivityDetail(state: AlphaDownloadState): String = when (state) {
    AlphaDownloadState.Queued,
    AlphaDownloadState.Downloading -> "Ross is downloading the assistant in the background. You can keep using the app."
    AlphaDownloadState.Verifying -> "Ross finished the download and is checking the files before turning it on."
    AlphaDownloadState.PausedWaitingForWifi -> "Ross is waiting for Wi-Fi before continuing the assistant setup."
    AlphaDownloadState.PausedUser -> "Setup is paused. You can continue working and resume whenever you are ready."
    AlphaDownloadState.PausedNoStorage -> "Ross needs more free space before the assistant can finish setting up."
    AlphaDownloadState.PausedError,
    AlphaDownloadState.Failed -> "Ross hit a setup problem. Open device setup to resume or choose another assistant level."
    AlphaDownloadState.NotStarted,
    AlphaDownloadState.Installed,
    AlphaDownloadState.Cancelled -> "No setup is running right now."
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

private fun alphaJobProgressLabel(job: AlphaModelDownloadJob): String? {
    if (job.totalBytes <= 0) return null
    val percent = ((job.bytesDownloaded.toDouble() / job.totalBytes.toDouble()) * 100).toInt()
    return "$percent% downloaded"
}

private fun alphaJobProgressFraction(job: AlphaModelDownloadJob): Float? {
    if (job.totalBytes <= 0) return null
    return (job.bytesDownloaded.toDouble() / job.totalBytes.toDouble()).toFloat()
}

private data class AlphaTechnicalModelArtifact(
    val displayName: String,
    val repository: String,
    val fileName: String,
    val quantization: String,
    val sha256: String,
)

private fun alphaTechnicalModelArtifact(tier: AlphaCapabilityTier): AlphaTechnicalModelArtifact = when (tier) {
    AlphaCapabilityTier.QuickStart -> AlphaTechnicalModelArtifact(
        displayName = "Gemma 3 270M IT Q8 MediaPipe Task",
        repository = "litert-community/gemma-3-270m-it",
        fileName = "gemma3-270m-it-q8.task",
        quantization = "Q8",
        sha256 = "0f7147f1c22eaf758b819bbf7841793e4c90096c9352cde7fbe5c631f2265ef5",
    )
    AlphaCapabilityTier.CaseAssociate -> AlphaTechnicalModelArtifact(
        displayName = "Gemma 3 1B IT Q4 MediaPipe Task",
        repository = "litert-community/Gemma3-1B-IT",
        fileName = "Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task",
        quantization = "Q4",
        sha256 = "ddfaf1210d8b4d1b812b5fadb6652999e852c8be6dd9abe353b9213a25262c10",
    )
    AlphaCapabilityTier.SeniorDraftingSupport -> AlphaTechnicalModelArtifact(
        displayName = "Gemma 3 1B IT Q4 Block128 MediaPipe Task",
        repository = "litert-community/Gemma3-1B-IT",
        fileName = "Gemma3-1B-IT_multi-prefill-seq_q4_block128_ekv4096.task",
        quantization = "Q4_BLOCK128",
        sha256 = "036e15114d1868fc7be7ccc552fc8da2fe31d64af02b48847ff99f0185d37891",
    )
}

private fun alphaExtractionProgressLabel(run: AlphaExtractionRun): String = when (run.progressState) {
    AlphaExtractionProgressState.AcquiringText -> "Reading file"
    AlphaExtractionProgressState.DetectingLanguage -> "Checking language"
    AlphaExtractionProgressState.ExtractingFields -> "Finding details"
    AlphaExtractionProgressState.VerifyingFields -> "Checking sources"
    AlphaExtractionProgressState.PreparingReview -> "Preparing review"
    AlphaExtractionProgressState.Complete -> "Complete"
    AlphaExtractionProgressState.NeedsReview -> "Please confirm"
    AlphaExtractionProgressState.Failed -> "Needs attention"
}

private fun alphaExtractionProgressDetail(run: AlphaExtractionRun): String {
    val pages = if (run.totalPages > 0) {
        " Page ${run.pagesProcessed.coerceAtMost(run.totalPages)} of ${run.totalPages}."
    } else {
        ""
    }
    return when (run.progressState) {
        AlphaExtractionProgressState.AcquiringText -> "Ross is reading the file on this device.$pages"
        AlphaExtractionProgressState.DetectingLanguage -> "Ross is checking language and script before extraction.$pages"
        AlphaExtractionProgressState.ExtractingFields -> "Ross is finding parties, dates, directions, and other details from your files.$pages"
        AlphaExtractionProgressState.VerifyingFields -> "Ross is checking each detail against the source text.$pages"
        AlphaExtractionProgressState.PreparingReview -> "Ross is preparing the review queue and source anchors.$pages"
        AlphaExtractionProgressState.Complete -> "Ross finished reading."
        AlphaExtractionProgressState.NeedsReview -> "Ross found items that need advocate review."
        AlphaExtractionProgressState.Failed -> run.errorMessage ?: "Ross could not finish review for this file."
    }
}

private fun alphaExtractionProgressFraction(run: AlphaExtractionRun): Float {
    if (run.totalPages > 0 && run.pagesProcessed > 0) {
        val pageProgress = run.pagesProcessed.toFloat() / run.totalPages.toFloat()
        return pageProgress.coerceIn(0.12f, 0.92f)
    }
    return when (run.progressState) {
        AlphaExtractionProgressState.AcquiringText -> 0.14f
        AlphaExtractionProgressState.DetectingLanguage -> 0.32f
        AlphaExtractionProgressState.ExtractingFields -> 0.52f
        AlphaExtractionProgressState.VerifyingFields -> 0.72f
        AlphaExtractionProgressState.PreparingReview -> 0.88f
        AlphaExtractionProgressState.Complete -> 1f
        AlphaExtractionProgressState.NeedsReview -> 1f
        AlphaExtractionProgressState.Failed -> 1f
    }
}

private fun Boolean.thenCompleted(): String = if (this) "Completed" else "Needs attention"
