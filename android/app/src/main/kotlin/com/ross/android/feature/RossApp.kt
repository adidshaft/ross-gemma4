package com.ross.android.feature

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.ross.android.app.AppContainer

@Composable
fun RossApp(container: AppContainer) {
    val presenter = remember(container) { AppPresenter(container) }
    val uiState = presenter.uiState

    if (uiState.onboardingRequired) {
        OnboardingScreen(
            state = uiState.onboarding,
            onSelectOffer = presenter::selectOffer,
            onContinue = presenter::completeOnboarding,
        )
    } else {
        WorkbenchScreen(
            state = uiState.workbench,
            onSectionSelected = presenter::openSection,
            onCaseSelected = presenter::selectCase,
            onCaptureHeadlineChanged = presenter::updateCaptureHeadline,
            onCaptureBodyChanged = presenter::updateCaptureBody,
            onSaveCapture = presenter::saveCapture,
            onLawQueryChanged = presenter::updateLawQuery,
            onRunLawPreview = presenter::runLawPreview,
            onUpdateSettings = presenter::updateSettings,
        )
    }
}
