package net.conciergeconnectedcare.livewell

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
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
 *
 * Every link it opens carries `size` (small, or medium when wider) and the
 * entry's `slot`, and its own Done keeps them, for the app's
 * `widget_interaction` analytics (T-AVT-08g-e). Fixed names only.
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
    const val DONE_SIZE_KEY = "lw_done_size"
    const val DONE_SLOT_KEY = "lw_done_slot"
    const val EXTRA_SIZE = "size"
    const val EXTRA_SLOT = "slot"
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
      val size = if (wide) "medium" else "small"

      if (snapshot == null || entry == null) {
        views.setTextViewText(R.id.widget_headline, context.getString(R.string.widget_open_app))
        views.setViewVisibility(R.id.widget_subline, View.GONE)
        views.setViewVisibility(R.id.widget_streak, View.GONE)
        views.setViewVisibility(R.id.widget_secondary, View.GONE)
        views.setTextViewText(R.id.widget_primary, context.getString(R.string.widget_open))
        val home = open(context, "livewell://home", size, null)
        views.setOnClickPendingIntent(R.id.widget_primary, home)
        views.setOnClickPendingIntent(R.id.widget_root, home)
        views.setViewVisibility(R.id.widget_goal, View.GONE)
        bindTabs(context, views, size)
        return views
      }

      // Missing setting = hidden: the private choice is the default (D-68).
      val hide = snapshot.optBoolean("hide_details", true)
      views.setTextViewText(
          R.id.widget_headline,
          accentLastWord(if (hide) entry.optString("lock_headline") else entry.optString("headline")))
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

      val slot = entry.optString("slot")
      bind(context, views, R.id.widget_primary, entry.optJSONObject("primary_action"), size, slot)
      val secondary = if (wide) entry.optJSONObject("secondary_action") else null
      if (secondary == null) {
        views.setViewVisibility(R.id.widget_secondary, View.GONE)
      } else {
        views.setViewVisibility(R.id.widget_secondary, View.VISIBLE)
        bind(context, views, R.id.widget_secondary, secondary, size, slot)
      }
      views.setOnClickPendingIntent(R.id.widget_root, open(context, "livewell://home", size, slot))
      bindGoal(context, views, snapshot, doneHere, size, slot)
      bindTabs(context, views, size)
      // Too short for the goal card and tabs (e.g. 2x2): hide them, never cut them.
      val tall = (options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) ?: 0) >= 250
      if (!tall) {
        views.setViewVisibility(R.id.widget_goal, View.GONE)
        views.setViewVisibility(R.id.widget_tabs, View.GONE)
      } else {
        views.setViewVisibility(R.id.widget_tabs, View.VISIBLE)
      }
      return views
    }

    private const val ACCENT = 0xFF7ED957.toInt()

    /** The headline with its last word in the accent green (D-110). */
    private fun accentLastWord(text: String): CharSequence {
      val trimmed = text.trimEnd()
      val start = trimmed.lastIndexOf(' ') + 1
      if (trimmed.isEmpty() || start >= trimmed.length) return text
      return SpannableString(trimmed).apply {
        setSpan(ForegroundColorSpan(ACCENT), start, trimmed.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    }

    /**
     * Today's Goal: the day's moments done out of planned (check-in, step,
     * reflection; the app's `routine` map), as a ring and "3 of 5 completed".
     * Counts only, nothing personal (AGENTS.md).
     */
    private fun bindGoal(
        context: Context,
        views: RemoteViews,
        snapshot: JSONObject,
        doneHere: Boolean,
        size: String,
        slot: String,
    ) {
      val routine = snapshot.optJSONObject("routine")
      val keys = routine?.keys()?.asSequence()?.toList() ?: emptyList()
      if (keys.isEmpty()) {
        views.setViewVisibility(R.id.widget_goal, View.GONE)
        return
      }
      val done = keys.count { k ->
        routine!!.optString(k) == "done" || (k == "step" && doneHere)
      }
      val total = keys.size
      views.setViewVisibility(R.id.widget_goal, View.VISIBLE)
      views.setTextViewText(
          R.id.widget_goal_count, context.getString(R.string.widget_goal_count, done, total))
      views.setImageViewBitmap(R.id.widget_goal_ring, ring(context, done, total))
      views.setOnClickPendingIntent(R.id.widget_goal, open(context, "livewell://home", size, slot))
    }

    /** A progress ring with the percentage in the middle. */
    private fun ring(context: Context, done: Int, total: Int): Bitmap {
      val px = (44 * context.resources.displayMetrics.density).toInt().coerceAtLeast(44)
      val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
      val c = Canvas(bmp)
      val stroke = px * 0.11f
      val box = RectF(stroke / 2, stroke / 2, px - stroke / 2, px - stroke / 2)
      val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = stroke
        strokeCap = Paint.Cap.ROUND
      }
      paint.color = 0x33FFFFFF
      c.drawArc(box, 0f, 360f, false, paint)
      val pct = if (total == 0) 0 else (done * 100 / total)
      if (pct > 0) {
        paint.color = ACCENT
        c.drawArc(box, -90f, 360f * pct / 100f, false, paint)
      }
      val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
        textSize = px * 0.28f
        isFakeBoldText = true
      }
      c.drawText("$pct%", px / 2f, px / 2f - (text.descent() + text.ascent()) / 2, text)
      return bmp
    }

    /** The four tab buttons (D-110): each opens its tab in the app. */
    private fun bindTabs(context: Context, views: RemoteViews, size: String) {
      views.setOnClickPendingIntent(R.id.widget_tab_plan, open(context, "livewell://plan", size, null))
      views.setOnClickPendingIntent(R.id.widget_tab_track, open(context, "livewell://track", size, null))
      views.setOnClickPendingIntent(R.id.widget_tab_learn, open(context, "livewell://learn", size, null))
      views.setOnClickPendingIntent(R.id.widget_tab_care, open(context, "livewell://care", size, null))
    }

    private fun bind(
        context: Context,
        views: RemoteViews,
        id: Int,
        action: JSONObject?,
        size: String,
        slot: String,
    ) {
      if (action == null) {
        views.setViewVisibility(id, View.GONE)
        return
      }
      views.setViewVisibility(id, View.VISIBLE)
      views.setTextViewText(id, action.optString("label"))
      val intent = if (action.optString("id") == "done") {
        // Logged here, without opening the app.
        val done = Intent(context, LiveWellDoneReceiver::class.java)
            .putExtra(EXTRA_SIZE, size)
            .putExtra(EXTRA_SLOT, slot)
        // One request code per size, so each size keeps its own extras.
        PendingIntent.getBroadcast(
            context, if (size == "medium") 2 else 1, done,
            PendingIntent.FLAG_UPDATE_CURRENT or immutable())
      } else {
        open(context, action.optString("link"), size, slot)
      }
      views.setOnClickPendingIntent(id, intent)
    }

    private fun open(context: Context, link: String, size: String, slot: String?): PendingIntent {
      val uri = Uri.parse(link).buildUpon().appendQueryParameter(EXTRA_SIZE, size)
      if (!slot.isNullOrEmpty()) uri.appendQueryParameter(EXTRA_SLOT, slot)
      return HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri.build())
    }

    private fun immutable(): Int =
        if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0
  }
}

/**
 * Done tapped on the widget: remember today's date, and the size and slot it
 * was tapped in (for analytics), redraw (idempotent).
 */
class LiveWellDoneReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    HomeWidgetPlugin.getData(context)
        .edit()
        .putString(LiveWellWidgetReceiver.DONE_KEY, LiveWellWidgetReceiver.today())
        .putString(
            LiveWellWidgetReceiver.DONE_SIZE_KEY,
            intent.getStringExtra(LiveWellWidgetReceiver.EXTRA_SIZE))
        .putString(
            LiveWellWidgetReceiver.DONE_SLOT_KEY,
            intent.getStringExtra(LiveWellWidgetReceiver.EXTRA_SLOT))
        .apply()
    LiveWellWidgetReceiver.refreshAll(context)
  }
}
