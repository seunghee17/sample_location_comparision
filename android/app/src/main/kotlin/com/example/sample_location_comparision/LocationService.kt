package com.example.sample_location_comparision

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationServices
import android.os.Looper
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.DetectedActivity

//class LocationForegroundService : Service() {
//
//    private val channelId = "loc_channel"
//    private val notifId = 1001
//
//    private lateinit var fused: FusedLocationProviderClient
//    private lateinit var actClient: ActivityRecognitionClient
//
//    // 현재 요청(정지/저전력 vs 이동/고정밀) 상태
//    private var highAccuracy = false
//
//    // 마지막 위치 캐시 (앱 진입 시 즉시 push)
//    private var lastLat: Double? = null
//    private var lastLng: Double? = null
//    private var lastAcc: Float? = null
//    private var lastTs: Long? = null
//
//    @RequiresApi(Build.VERSION_CODES.O)
//    override fun onCreate() {
//        super.onCreate()
//        fused = LocationServices.getFusedLocationProviderClient(this)
//        actClient = ActivityRecognition.getClient(this)
//        createNotificationChannel()
//        startForeground(notifId, buildNotification("위치 공유 활성화"))
//
//        // 1) 모션 감지 시작 (이동/정지에 따라 위치 품질/주기 조절)
//        startActivityTransitions()
//
//        // 2) 기본(저전력) 위치 업데이트 시작
//        requestBalancedLocation()
//    }
//
//    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
//        // 앱 진입 시 Flutter로 “캐시된 최근 위치” 즉시 push
//        pushCachedLocationToFlutter()
//        return START_STICKY
//    }
//
//    override fun onDestroy() {
//        stopLocation()
//        stopActivityTransitions()
//        super.onDestroy()
//    }
//
//    override fun onBind(intent: Intent?): IBinder? = null
//
//    @RequiresApi(Build.VERSION_CODES.O)
//    private fun createNotificationChannel() {
//        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//        val ch = NotificationChannel(channelId, "Location", NotificationManager.IMPORTANCE_LOW)
//        nm.createNotificationChannel(ch)
//    }
//
//    private fun buildNotification(text: String): Notification {
//        return NotificationCompat.Builder(this, channelId)
//            .setContentTitle("FSV 위치 서비스")
//            .setContentText(text)
//            .setOngoing(true)
//            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
//            .build()
//    }
//
//    // --- 모션: 이동 시작/정지 이벤트에 따라 위치 요청을 바꾼다 ---
////    private val actReceiver = object : com.google.android.gms.location.ActivityTransitionCallback() {
////        override fun onActivityTransitionResult(activityTransitionResult: ActivityTransitionResult) {
////            for (event in activityTransitionResult.transitionEvents) {
////                when (event.activityType) {
////                    DetectedActivity.IN_VEHICLE,
////                    DetectedActivity.ON_BICYCLE,
////                    DetectedActivity.RUNNING,
////                    DetectedActivity.ON_FOOT,
////                    DetectedActivity.WALKING -> {
////                        // 이동 시작 → 고정밀/짧은 간격
////                        requestHighAccuracyLocation()
////                    }
////                    DetectedActivity.STILL -> {
////                        // 정지 상태 → 저전력/긴 간격
////                        requestBalancedLocation()
////                    }
////                }
////            }
////        }
////    }
//
//    private fun startActivityTransitions() {
//        val transitions = listOf(
//            ActivityTransition.Builder()
//                .setActivityType(DetectedActivity.STILL)
//                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
//                .build(),
//            ActivityTransition.Builder()
//                .setActivityType(DetectedActivity.STILL)
//                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
//                .build(),
//            ActivityTransition.Builder()
//                .setActivityType(DetectedActivity.ON_FOOT)
//                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
//                .build(),
//            ActivityTransition.Builder()
//                .setActivityType(DetectedActivity.ON_FOOT)
//                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
//                .build(),
//            ActivityTransition.Builder()
//                .setActivityType(DetectedActivity.IN_VEHICLE)
//                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
//                .build(),
//            ActivityTransition.Builder()
//                .setActivityType(DetectedActivity.IN_VEHICLE)
//                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
//                .build(),
//            ActivityTransition.Builder()
//                .setActivityType(DetectedActivity.RUNNING)
//                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
//                .build(),
//            ActivityTransition.Builder()
//                .setActivityType(DetectedActivity.RUNNING)
//                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
//                .build()
//        )
//
//        val req = ActivityTransitionRequest(transitions)
//        actClient.requestActivityTransitionUpdates(req, getPendingIntentForTransitions())
//    }
//
//    private fun stopActivityTransitions() {
//        actClient.removeActivityTransitionUpdates(getPendingIntentForTransitions())
//    }
//
//    private fun getPendingIntentForTransitions(): PendingIntent {
//        val intent = Intent(this, ActivityTransitionReceiver::class.java)
//        return PendingIntent.getBroadcast(
//            this, 0, intent,
//            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
//        )
//    }
//
//    // --- 위치 요청 (저전력 / 고정밀) ---
//    private fun requestBalancedLocation() {
//        if (highAccuracy) {
//            fused.removeLocationUpdates(locationCallback)
//            highAccuracy = false
//        }
//        val req = LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 5 * 60 * 1000L) // 5분
//            .setMinUpdateIntervalMillis(60 * 1000L)  // 최소 1분
//            .setMinUpdateDistanceMeters(50f)         // 50m 이상 이동 시
//            .build()
//        fused.requestLocationUpdates(req, locationCallback, Looper.getMainLooper())
//        startForeground(notifId, buildNotification("정지/저속: 저전력 측정 중"))
//    }
//
//    private fun requestHighAccuracyLocation() {
//        if (!highAccuracy) {
//            fused.removeLocationUpdates(locationCallback)
//            highAccuracy = true
//        }
//        val req = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5_000L) // 5초
//            .setMinUpdateIntervalMillis(2_000L)
//            .setMinUpdateDistanceMeters(5f)
//            .build()
//        fused.requestLocationUpdates(req, locationCallback, Looper.getMainLooper())
//        startForeground(notifId, buildNotification("이동 감지: 고정밀 측정 중"))
//    }
//
//    private fun stopLocation() {
//        fused.removeLocationUpdates(locationCallback)
//    }
//
//    private val locationCallback = object : LocationCallback() {
//        override fun onLocationResult(result: LocationResult) {
//            val loc = result.lastLocation ?: return
//            lastLat = loc.latitude
//            lastLng = loc.longitude
//            lastAcc = loc.accuracy
//            lastTs  = loc.time
//            // 필요시 여기서도 Flutter로 push 가능 (실시간 동기화)
//            pushCachedLocationToFlutter()
//        }
//    }
//
//    private fun pushCachedLocationToFlutter() {
//        val lat = lastLat ?: return
//        val lng = lastLng ?: return
//        val acc = lastAcc ?: 0f
//        val ts  = lastTs  ?: System.currentTimeMillis()
//        val map = mapOf(
//            "latitude" to lat,
//            "longitude" to lng,
//            "accuracy" to acc,
//            "timestamp" to ts
//        )
//        App.methodChannel?.invokeMethod("pushLocation", map)
//    }
//}
