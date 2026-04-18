package com.ross.android.app

import android.app.Application

class RossApplication : Application() {
    val appContainer: AppContainer by lazy { AppContainer(this) }
}
