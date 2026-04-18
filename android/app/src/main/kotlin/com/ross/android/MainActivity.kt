package com.ross.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.Surface
import com.ross.android.app.RossApplication
import com.ross.android.feature.RossApp
import com.ross.android.theme.RossTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val container = (application as RossApplication).appContainer
        setContent {
            RossTheme {
                Surface {
                    RossApp(container = container)
                }
            }
        }
    }
}
