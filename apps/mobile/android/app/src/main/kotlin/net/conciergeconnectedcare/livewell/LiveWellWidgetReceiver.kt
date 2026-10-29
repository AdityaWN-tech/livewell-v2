package net.conciergeconnectedcare.livewell

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The Android home-screen widget (FR-TCH-03, D-61): the same snapshot the
 * iPhone widget reads (`lw_snapshot`, written by the app through
 * home_widget). Small shows the coach's line and one button; wider adds the
 * streak and a second button. **Done works without opening the app**: it
 * stores today's date (`lw_done_date`, the same key as iOS) and shows the
 * "done" entry at once; the app saves it to habit_logs the next time it
 * runs, for that day (D-60). With "hide details" on, only the generic line
 * shows. No health values are ever in the snapshot.
 */
class LiveWellWidgetReceiver : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    for (id in appWidgetIds) {
      val options = appWidgetManager.getAppWidgetOptions(id)
      appWidgetManager.updateAppWidget(id, render(context, widgetData, options))
    }
  }

  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle,
  ) {
    appWidgetManager.updateAppWidget(
        appWidgetId, render(context, HomeWidgetPlugin.getData(context), newOptions))
  }

  companion object {
    const val SNAPSHOT_KEY = "lw_snapshot"
    const val DONE_KEY = "lw_done_date"
    private val TODO_SLOTS = setOf("morning_checkin", "step", "step_window", "gentle")

    fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun dayOf(iso: String): String = iso.take(10)

    /** Redraws every Live Well widget. */
    fun refreshAll(context: Context) {
      val manager = AppWidgetManager.getInstance(context)
      val ids = manager.getAppWidgetIds(ComponentName(context, LiveWellWidgetReceiver::class.java))
      if (ids.isEmpty()) return
      val data = HomeWidgetPlugin.getData(context)
      for (id in ids) {
        manager.updateAppWidget(id, render(context, data, manager.getAppWidgetOptions(id)))
      }
    }

    /** The entry to show now: the last one that has started (the first is shown early). */
    private fun current(snapshot: JSONObject, doneHere: Boolean): JSONObject? {
      val entries = snapshot.optJSONArray("entries") ?: return null
      if (entries.length() == 0) return null
      val now = System.currentTimeMillis()
      val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
      var shown = entries.getJSONObject(0)
      for (i in 1 until entries.length()) {
        val e = entries.getJSONObject(i)
        val at = try {
          iso.parse(e.optString("at").take(19))?.time
        } catch (_: Exception) {
          null
        } ?: continue
        if (at <= now) shown = e
      }
      val after = snapshot.optJSONObject("after_done")
      if (doneHere && after != null && shown.optString("slot") in TODO_SLOTS &&
          dayOf(shown.optString("at")) <= today()) {
        return after
      }
      return shown
    }

    fun render(context: Context, data: SharedPreferences, options: Bundle?): RemoteViews {
      val views = RemoteViews(context.packageName, R.layout.live_well_widget)
      val snapshot = data.getString(SNAPSHOT_KEY, null)?.let {
        try {
          JSONObject(it)
        } catch (_: Exception) {
          null
        }
      }
      val doneHere = data.getString(DONE_KEY, null) == today()
      val entry = snapshot?.let { current(it, doneHere) }
      val wide = (options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0) >= 250

      if (snapshot == null || entry == null) {
        views.setTextViewText(R.id.widget_headline, context.getString(R.string.widget_open_app))
        views.setViewVisibility(R.id.widget_subline, View.GONE)
        views.setViewVisibility(R.id.widget_streak, View.GONE)
        views.setViewVisibility(R.id.widget_secondary, View.GONE)
        views.setTextViewText(R.id.widget_primary, context.getString(R.string.widget_open))
        views.setOnClickPendingIntent(R.id.widget_primary, open(context, "livewell://home"))
        views.setOnClickPendingIntent(R.id.widget_root, open(context, "livewell://home"))
        return views
      }

      val hide = snapshot.optBoolean("hide_details", false)
      views.setTextViewText(
          R.id.widget_headline,
          if (hide) entry.optString("lock_headline") else entry.optString("headline"))
      val subline = if (hide || entry.isNull("subline")) "" else entry.optString("subline")
      views.setTextViewText(R.id.widget_subline, subline)
      views.setViewVisibility(R.id.widget_subline, if (subline.isEmpty()) View.GONE else View.VISIBLE)

      val streak = if (snapshot.isNull("streak_days")) 0 else snapshot.optInt("streak_days")
      if (wide && streak > 0) {
        views.setTextViewText(
            R.id.widget_streak,
            context.resources.getQuantityString(R.plurals.widget_streak, streak, streak))
        views.setViewVisibility(R.id.widget_streak, View.VISIBLE)
      } else {
        views.setViewVisibility(R.id.widget_streak, View.GONE)
      }

      bind(context, views, R.id.widget_primary, entry.optJSONObject("primary_action"))
      val secondary = if (wide) entry.optJSONObject("secondary_action") else null
      if (secondary == null) {
        views.setViewVisibility(R.id.widget_secondary, View.GONE)
      } else {
        views.setViewVisibility(R.id.widget_secondary, View.VISIBLE)
        bind(context, views, R.id.widget_secondary, secondary)
      }
      views.setOnClickPendingIntent(R.id.widget_root, open(context, "livewell://home"))
      return views
    }

    private fun bind(context: Context, views: RemoteViews, id: Int, action: JSONObject?) {
      if (action == null) {
        views.setViewVisibility(id, View.GONE)
        return
      }
      views.setViewVisibility(id, View.VISIBLE)
      views.setTextViewText(id, action.optString("label"))
      val intent = if (action.optString("id") == "done") {
        // Logged here, without opening the app.
        val done = Intent(context, LiveWellDoneReceiver::class.java)
        PendingIntent.getBroadcast(
            context, 1, done, PendingIntent.FLAG_UPDATE_CURRENT or immutable())
      } else {
        open(context, action.optString("link"))
      }
      views.setOnClickPendingIntent(id, intent)
    }

    private fun open(context: Context, link: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(link))

    private fun immutable(): Int =
        if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0
  }
}

/** Done tapped on the widget: remember today's date, redraw (idempotent). */
class LiveWellDoneReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    HomeWidgetPlugin.getData(context)
        .edit()
        .putString(LiveWellWidgetReceiver.DONE_KEY, LiveWellWidgetReceiver.today())
        .apply()
    LiveWellWidgetReceiver.refreshAll(context)
  }
}
