package com.peonping.peonping_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PeonForgeWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            val level = widgetData.getInt("level", 1)
            val xpProgress = widgetData.getInt("xp_progress", 0)
            val tasks = widgetData.getInt("tasks_today", 0)
            val steps = widgetData.getInt("steps_today", 0)
            val happiness = widgetData.getInt("happiness", 50)
            val faction = widgetData.getString("faction", "human") ?: "human"

            views.setTextViewText(R.id.widget_level, "Niveau $level")
            views.setProgressBar(R.id.widget_xp_bar, 100, xpProgress, false)
            views.setTextViewText(R.id.widget_tasks, "$tasks taches")
            views.setTextViewText(R.id.widget_steps, "$steps pas")
            views.setTextViewText(R.id.widget_happiness, "\u2764 $happiness%")

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
