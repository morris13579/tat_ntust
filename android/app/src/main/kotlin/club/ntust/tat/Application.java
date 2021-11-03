package club.ntust.tat;

import io.flutter.app.FlutterApplication;
import io.flutter.plugin.common.PluginRegistry;

public class Application extends FlutterApplication implements PluginRegistry.PluginRegistrantCallback {
    @Override
    public void onCreate() {
        super.onCreate();
    }

    @Override
    public void registerWith(PluginRegistry registry) {
    }
}