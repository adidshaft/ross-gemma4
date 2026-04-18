package com.privatedigitalclerk.android.app

import android.app.Application

class PrivateDigitalClerkApplication : Application() {
    val appContainer: AppContainer by lazy { AppContainer(this) }
}
