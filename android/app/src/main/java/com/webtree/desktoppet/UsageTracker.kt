package com.webtree.desktoppet

import android.app.usage.UsageStatsManager
import android.content.Context
import java.util.Locale

object UsageTracker {
    fun getForegroundApp(context: Context): String? {
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return null
        val time = System.currentTimeMillis()
        // Query stats from the last 60 seconds
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            time - 60 * 1000,
            time
        )
        
        if (!stats.isNullOrEmpty()) {
            var recentStats = stats[0]
            for (stat in stats) {
                if (stat.lastTimeUsed > recentStats.lastTimeUsed) {
                    recentStats = stat
                }
            }
            // Only return if it's currently active (last used in the last 5 seconds)
            if (time - recentStats.lastTimeUsed < 5000) {
                return recentStats.packageName
            }
        }
        return null
    }

    fun getAppName(packageName: String): String {
        val lower = packageName.lowercase(Locale.ROOT)
        return when {
            lower.contains("instagram") -> "Instagram"
            lower.contains("youtube") -> "YouTube"
            lower.contains("facebook") -> "Facebook"
            lower.contains("twitter") || lower.contains("x.android") -> "Twitter/X"
            lower.contains("tiktok") -> "TikTok"
            lower.contains("reddit") -> "Reddit"
            lower.contains("whatsapp") -> "WhatsApp"
            lower.contains("chrome") || lower.contains("browser") || lower.contains("firefox") -> "Browser"
            lower.contains("com.webtree.desktoppet") -> "Luna"
            else -> {
                val parts = packageName.split(".")
                if (parts.isNotEmpty()) {
                    parts.last().replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.ROOT) else it.toString() }
                } else {
                    packageName
                }
            }
        }
    }
}
