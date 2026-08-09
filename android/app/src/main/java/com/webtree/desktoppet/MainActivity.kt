package com.webtree.desktoppet

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {

    private lateinit var tvOverlayStatus: TextView
    private lateinit var tvUsageStatus: TextView
    private lateinit var btnStart: Button
    private lateinit var btnStop: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        tvOverlayStatus = findViewById(R.id.tvOverlayStatus)
        tvUsageStatus = findViewById(R.id.tvUsageStatus)
        btnStart = findViewById(R.id.btnStart)
        btnStop = findViewById(R.id.btnStop)

        val cardOverlay = findViewById<CardView>(R.id.cardOverlay)
        val cardUsage = findViewById<CardView>(R.id.cardUsage)

        cardOverlay.setOnClickListener {
            if (!Settings.canDrawOverlays(this)) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
            }
        }

        cardUsage.setOnClickListener {
            if (!hasUsageStatsPermission()) {
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                startActivity(intent)
            }
        }

        btnStart.setOnClickListener {
            if (hasAllPermissions()) {
                val intent = Intent(this, FloatingPetService::class.java)
                ContextCompat.startForegroundService(this, intent)
            }
        }

        btnStop.setOnClickListener {
            val intent = Intent(this, FloatingPetService::class.java)
            stopService(intent)
        }

        setupActionButtons()
    }

    private fun setupActionButtons() {
        val actionMap = mapOf(
            R.id.btnActIdle to "idle",
            R.id.btnActWalk to "walk",
            R.id.btnActSleep to "sleep",
            R.id.btnActReact to "react",
            R.id.btnActDrink to "drink",
            R.id.btnActPlay to "play",
            R.id.btnActLaugh to "laugh",
            R.id.btnActRoll to "roll",
            R.id.btnActLove to "love",
            R.id.btnActAnger to "anger"
        )

        for ((btnId, stateName) in actionMap) {
            findViewById<Button>(btnId)?.setOnClickListener {
                FloatingPetService.instance?.triggerState(stateName)
            }
        }

        findViewById<Button>(R.id.btnSim20)?.setOnClickListener {
            FloatingPetService.instance?.simulateScroll(1200)
        }
        findViewById<Button>(R.id.btnSim40)?.setOnClickListener {
            FloatingPetService.instance?.simulateScroll(2400)
        }
        findViewById<Button>(R.id.btnSim60)?.setOnClickListener {
            FloatingPetService.instance?.simulateScroll(3600)
        }
    }

    override fun onResume() {
        super.onResume()
        updatePermissionUI()
    }

    private fun updatePermissionUI() {
        val overlayGranted = Settings.canDrawOverlays(this)
        if (overlayGranted) {
            tvOverlayStatus.text = getString(R.string.status_granted)
            tvOverlayStatus.setTextColor(ContextCompat.getColor(this, R.color.color_green))
        } else {
            tvOverlayStatus.text = getString(R.string.status_missing)
            tvOverlayStatus.setTextColor(ContextCompat.getColor(this, R.color.color_red))
        }

        val usageGranted = hasUsageStatsPermission()
        if (usageGranted) {
            tvUsageStatus.text = getString(R.string.status_granted)
            tvUsageStatus.setTextColor(ContextCompat.getColor(this, R.color.color_green))
        } else {
            tvUsageStatus.text = getString(R.string.status_missing)
            tvUsageStatus.setTextColor(ContextCompat.getColor(this, R.color.color_red))
        }

        btnStart.isEnabled = overlayGranted
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasAllPermissions(): Boolean {
        return Settings.canDrawOverlays(this) && hasUsageStatsPermission()
    }
}
