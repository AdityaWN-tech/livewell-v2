package net.conciergeconnectedcare.livewell

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
}
