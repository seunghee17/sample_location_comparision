package com.example.sample_location_comparision

import android.Manifest
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionClient
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.DetectedActivity
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

enum class ChannelNaem(val value: String) {
    App("app/Location_comparision")
}

class MainActivity: FlutterActivity() {
    private lateinit var appMethodChannel: MethodChannel
    private var latitude: String = ""
    private var longitude: String = ""

    private lateinit var activityRecognitionClient: ActivityRecognitionClient
    private lateinit var pendingIntent: PendingIntent

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activityRecognitionClient = ActivityRecognition.getClient(this)
        val intent = Intent(this, MotionConfigurationReceiver::class.java)
        pendingIntent = PendingIntent.getBroadcast(
            this,0,intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 알림을 받으려는 전환을 나타내는 객체의 목록
        val transitions = mutableListOf<ActivityTransition>()
        transitions += ActivityTransition.Builder()
            .setActivityType(DetectedActivity.IN_VEHICLE)
            .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
            .build()

        transitions += ActivityTransition.Builder()
            .setActivityType(DetectedActivity.IN_VEHICLE)
            .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
            .build()

        transitions += ActivityTransition.Builder()
            .setActivityType(DetectedActivity.WALKING)
            .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
            .build()

        transitions += ActivityTransition.Builder()
            .setActivityType(DetectedActivity.STILL)
            .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
            .build()

        // 활동 및 전환의 유형 지정
        val request = ActivityTransitionRequest(transitions)
        if(ActivityCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), 100)
            return
        }
        activityRecognitionClient.requestActivityTransitionUpdates(request, pendingIntent)
            .addOnSuccessListener { Log.d("TTAG", "등록 성공") }
            .addOnFailureListener { Log.d("TTAG", "등록 실패") }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appMethodChannel = MethodChannel(flutterEngine.dartExecutor, ChannelNaem.App.value)
        appMethodChannel.setMethodCallHandler { call, result ->
            if(call.method == "measureLocation") {
                val fusedLocationProviderClient = LocationServices.getFusedLocationProviderClient(context)
                if (ActivityCompat.checkSelfPermission(
                        this,
                        Manifest.permission.ACCESS_FINE_LOCATION
                    ) != PackageManager.PERMISSION_GRANTED && ActivityCompat.checkSelfPermission(
                        this,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    ) != PackageManager.PERMISSION_GRANTED
                )
                    fusedLocationProviderClient.lastLocation
                        .addOnSuccessListener { location: Location? ->
                            if(location != null) {
                                latitude = location.latitude.toString()
                                longitude = location.longitude.toString()
                                result.success("위도 ${latitude} 경도 ${longitude}")
                            }
                        }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.ACTIVITY_RECOGNITION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            // TODO: Consider calling
            //    ActivityCompat#requestPermissions
            // here to request the missing permissions, and then overriding
            //   public void onRequestPermissionsResult(int requestCode, String[] permissions,
            //                                          int[] grantResults)
            // to handle the case where the user grants the permission. See the documentation
            // for ActivityCompat#requestPermissions for more details.
            return
        }
        activityRecognitionClient.removeActivityTransitionUpdates(pendingIntent)
    }

}
