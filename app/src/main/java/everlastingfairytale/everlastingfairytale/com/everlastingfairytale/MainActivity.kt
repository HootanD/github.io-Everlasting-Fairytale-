package everlastingfairytale.everlastingfairytale.com.everlastingfairytale

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.widget.TextView
import everlastingfairytale.everlastingfairytale.com.everlastingfairytale.databinding.ActivityMainBinding
import android.content.Intent
import android.net.Uri

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // Example of a call to a native method
        binding.sampleText.text = stringFromJNI()
        // ATTENTION: This was auto-generated to handle app links.
        val appLinkIntent: Intent = intent
        val appLinkAction: String? = appLinkIntent.action
        val appLinkData: Uri? = appLinkIntent.data
    }

    /**
     * A native method that is implemented by the 'everlastingfairytale' native library,
     * which is packaged with this application.
     */
    external fun stringFromJNI(): String

    companion object {
        // Used to load the 'everlastingfairytale' library on application startup.
        init {
            System.loadLibrary("everlastingfairytale")
        }
    }
}