package com.example.sample_location_comparision

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionResult
import com.google.android.gms.location.DetectedActivity

class MotionConfigurationReceiver: BroadcastReceiver() {
    //companion object {
    //        val transitionRecognitionLiveData = MutableLiveData<String>()
    //    }
    @RequiresApi(Build.VERSION_CODES.N)
    override fun onReceive(context: Context?, intent: Intent?) {
        if(intent == null) return
        val result = ActivityTransitionResult.extractResult(intent) ?: return
        result.transitionEvents.forEach { event ->
            when(event.activityType) {
                DetectedActivity.WALKING -> Log.d("TTAG", "걷는중")
                DetectedActivity.STILL -> Log.d("TTAG", "그대로")
                else -> Log.d("TTAG", "나머지")
            }
            val transition = if(event.transitionType == ActivityTransition.ACTIVITY_TRANSITION_ENTER) "시작"
            else "종료"
        }


    }
}