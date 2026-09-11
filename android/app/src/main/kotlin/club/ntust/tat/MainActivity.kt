package club.ntust.tat;

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
import androidx.annotation.NonNull
import androidx.core.view.WindowCompat
import com.anggrayudi.storage.file.DocumentFileCompat
import com.anggrayudi.storage.file.absolutePath
import io.flutter.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import kotlin.system.exitProcess

class MainActivity : FlutterFragmentActivity() {
    private val methodChannelWidgetName = "club.ntust.tat.widget"
    private val methodChannelSaveName = "club.ntust.tat.save"
    private val DIRECTORY_CHOOSE_REQ_CODE = 42
    var pendingPickResult: MethodChannel.Result? = null
    private val logTag = "FlutterActivity"
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelWidgetName).setMethodCallHandler { call, result ->
            when (call.method) {
                "update_weight" -> {
                    Log.i(logTag, "update_weight")
                    try {
                        val intend = Intent("android.appwidget.action.APPWIDGET_UPDATE") //顯示意圖
                        this.sendBroadcast(intend)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                        Log.e(logTag, e.toString())
                    }
                }
                "restart_app" -> {
                    // doRestart 成功時最後會呼叫 exitProcess(0)，程式不會回到這一行；
                    // 也就是說「doRestart 有回來」本身就代表重啟失敗。
                    // 一定要回覆，否則 Dart 端的 Future 會永遠 pending，
                    // 使用者只會看到「按了沒反應」，連錯誤都收不到。
                    doRestart(this)
                    result.success(false)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelSaveName).setMethodCallHandler { call, result ->
            when (call.method) {
                "choice_folder" -> {
                    Log.i(logTag, "choice_folder")
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    startActivityForResult(intent, DIRECTORY_CHOOSE_REQ_CODE);
                    pendingPickResult = result
                }
                "get_path" -> {
                    // 一定要用 firstOrNull（或 filter），千萬不要換回 takeWhile：
                    // takeWhile 碰到第一個不符合條件的元素就整串停住，所以只要清單第 0 筆是
                    // 「只有讀取權限」的殘留授權，後面真正 read+write 的授權就被一起丟掉，
                    // 症狀是使用者明明選過資料夾卻抓不到路徑。
                    // 而 onActivityResult 只釋放「read+write 且 uri 不同」的授權，
                    // 唯讀的殘留授權不會被清掉，所以這個狀態會一直留著。
                    //
                    // 用 firstOrNull 而不是 filter{}.first() 還順便擋掉舊版的另一個問題：
                    // 舊版在 list 為空時呼叫了 result.success(null) 卻沒有 return，
                    // 會繼續執行 list.first() 丟 NoSuchElementException，
                    // 而且 result 被回覆兩次（MethodChannel 只允許回覆一次）。
                    val granted = contentResolver.persistedUriPermissions
                            .firstOrNull { it.isReadPermission && it.isWritePermission }
                    if (granted == null) {
                        result.success(null)
                    } else {
                        val file = DocumentFileCompat.fromUri(this, granted.uri)
                        Log.i(logTag, file?.absolutePath.toString())
                        result.success(file?.absolutePath.toString())
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(
            requestCode: Int, resultCode: Int,
            data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            DIRECTORY_CHOOSE_REQ_CODE ->
                if (resultCode == Activity.RESULT_OK) {
                    data?.data?.also { uri ->
                        Log.d("flutter.store_path", uri.toString())
                        val contentResolver = applicationContext.contentResolver
                        val takeFlags: Int = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        contentResolver.takePersistableUriPermission(uri, takeFlags)
                        for (i in contentResolver.persistedUriPermissions) {
                            if (i.isReadPermission && i.isWritePermission && i.uri != uri) {
                                contentResolver.releasePersistableUriPermission(i.uri, takeFlags)
                            }
                        }
                        pendingPickResult?.success(true)
                        pendingPickResult = null
                    }
                } else {
                    pendingPickResult?.success(false)
                    pendingPickResult = null
                }
        }
    }


    private fun doRestart(c: Context?) {
        try {
            //check if the context is given
            if (c != null) {
                //fetch the packageManager so we can get the default launch activity
                // (you can replace this intent with any other activity if you want
                val pm: PackageManager = c.packageManager
                //check if we got the PackageManager
                //create the intent with the default start activity for your application
                val mStartActivity: Intent? = pm.getLaunchIntentForPackage(
                        c.packageName
                )
                if (mStartActivity != null) {
                    mStartActivity.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    //create a pending intent so the application is restarted after System.exit(0) was called.
                    // We use an AlarmManager to call this intent in 100ms
                    val mPendingIntentId = 223344
                    // FLAG_IMMUTABLE 是必要的，不要拿掉：Android 12（API 31）起，
                    // 建立 PendingIntent 若沒有指明 FLAG_IMMUTABLE / FLAG_MUTABLE 會直接丟
                    // IllegalArgumentException，而 targetSdkVersion 已經是 36。
                    // 這個例外會被下面的 catch 吞掉，所以症狀只是「App 就是不重啟、也沒有錯誤」。
                    // 這個 PendingIntent 只負責重新叫起 launcher activity，不需要別人填 extras，
                    // 用 IMMUTABLE 即可，和 CourseWidgetProvider 的作法一致。
                    // minSdkVersion 是 24（> FLAG_IMMUTABLE 的 API 23），不需要再做版本判斷。
                    val mPendingIntent: PendingIntent = PendingIntent
                            .getActivity(c, mPendingIntentId, mStartActivity,
                                    PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val mgr: AlarmManager = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    mgr.set(AlarmManager.RTC, System.currentTimeMillis() + 100, mPendingIntent)
                    //kill the application
                    exitProcess(0)
                } else {
                    Log.e(logTag, "Was not able to restart application, mStartActivity null")
                }
            } else {
                Log.e(logTag, "Was not able to restart application, Context null")
            }
        } catch (ex: java.lang.Exception) {
            Log.e(logTag, "Was not able to restart application")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.setFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
    }

    override fun onPostResume() {
        super.onPostResume()
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

}
