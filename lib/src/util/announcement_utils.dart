class AnnouncementUtils{

  static late FirebaseRemoteConfig _remoteConfig;

  static Future<void> init() async {
    _remoteConfig = FirebaseRemoteConfig.instance;
    _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(hours: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    /*
    _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: Duration.zero,
        minimumFetchInterval: Duration.zero,
      ),
    );
     */
  }


}