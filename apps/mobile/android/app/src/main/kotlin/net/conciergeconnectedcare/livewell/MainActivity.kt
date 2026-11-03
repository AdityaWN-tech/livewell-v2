package net.conciergeconnectedcare.livewell

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

// A FlutterFragmentActivity: Health Connect's permission screen needs one
// (Step 4f, D-59).
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 12+ fades its system splash out by default, which dims the logo
        // and hides the start of our Flutter logo reveal. The Flutter splash's
        // first frame looks identical to the system splash, so remove it
        // instantly instead (S-7, D-13).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { view -> view.remove() }
        }
    }

    // Opened by Health Connect to show why the app reads health data: go
    // straight to the Privacy Policy.
    override fun getInitialRoute(): String? = when (intent?.action) {
        "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE",
        "android.intent.action.VIEW_PERMISSION_USAGE" -> "/onboarding/legal/privacy"
        else -> super.getInitialRoute()
    }
}
