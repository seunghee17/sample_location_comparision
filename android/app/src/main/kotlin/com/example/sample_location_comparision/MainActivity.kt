package com.example.sample_location_comparision

import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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

    //분리가 필요하다면 메소드로 분리하기
//    private fun getLastLocation() {
//        val fusedLocationProviderClient = LocationServices.getFusedLocationProviderClient(context)
//        if (ActivityCompat.checkSelfPermission(
//                this,
//                Manifest.permission.ACCESS_FINE_LOCATION
//            ) != PackageManager.PERMISSION_GRANTED && ActivityCompat.checkSelfPermission(
//                this,
//                Manifest.permission.ACCESS_COARSE_LOCATION
//            ) != PackageManager.PERMISSION_GRANTED
//        ) {
//            return
//        }
//        fusedLocationProviderClient.lastLocation
//            .addOnSuccessListener { location: Location? ->
//                if(location != null) {
//                    latitude = location.latitude.toString()
//                    longitude = location.longitude.toString()
//                }
//            }
//    }
}
