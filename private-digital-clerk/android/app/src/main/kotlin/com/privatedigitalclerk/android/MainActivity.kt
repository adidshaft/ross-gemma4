package com.privatedigitalclerk.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.Surface
import com.privatedigitalclerk.android.app.PrivateDigitalClerkApplication
import com.privatedigitalclerk.android.feature.PrivateDigitalClerkApp
import com.privatedigitalclerk.android.theme.PrivateDigitalClerkTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val container = (application as PrivateDigitalClerkApplication).appContainer
        setContent {
            PrivateDigitalClerkTheme {
                Surface {
                    PrivateDigitalClerkApp(container = container)
                }
            }
        }
    }
}
