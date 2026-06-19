import '../models/app_permission_item.dart';

class PermissionCatalog {
  static const android = [
    AppPermissionItem(name: 'android.permission.INTERNET', description: '网络访问：请求接口、加载网页、WebView 必备。', dangerous: false),
    AppPermissionItem(name: 'android.permission.ACCESS_NETWORK_STATE', description: '网络状态：判断 Wi-Fi/移动网络连接。', dangerous: false),
    AppPermissionItem(name: 'android.permission.CAMERA', description: '相机：拍照、扫码、录制。', dangerous: true),
    AppPermissionItem(name: 'android.permission.RECORD_AUDIO', description: '麦克风：录音、语音输入、音视频通话。', dangerous: true),
    AppPermissionItem(name: 'android.permission.ACCESS_FINE_LOCATION', description: '精准定位：地图、导航、附近服务。', dangerous: true),
    AppPermissionItem(name: 'android.permission.ACCESS_COARSE_LOCATION', description: '粗略定位：城市级定位、天气、区域服务。', dangerous: true),
    AppPermissionItem(name: 'android.permission.POST_NOTIFICATIONS', description: '通知权限：Android 13+ 推送通知。', dangerous: true),
    AppPermissionItem(name: 'android.permission.READ_MEDIA_IMAGES', description: '读取图片：Android 13+ 相册图片读取。', dangerous: true),
    AppPermissionItem(name: 'android.permission.READ_MEDIA_VIDEO', description: '读取视频：Android 13+ 相册视频读取。', dangerous: true),
    AppPermissionItem(name: 'android.permission.READ_MEDIA_AUDIO', description: '读取音频：Android 13+ 音频文件读取。', dangerous: true),
    AppPermissionItem(name: 'android.permission.READ_EXTERNAL_STORAGE', description: '读取存储：Android 12 及以下文件读取。', dangerous: true),
    AppPermissionItem(name: 'android.permission.WRITE_EXTERNAL_STORAGE', description: '写入存储：Android 10 及以下文件写入。', dangerous: true),
    AppPermissionItem(name: 'android.permission.MANAGE_EXTERNAL_STORAGE', description: '所有文件管理：文件管理器类应用使用，审核敏感。', dangerous: true),
    AppPermissionItem(name: 'android.permission.BLUETOOTH', description: '蓝牙基础权限：旧版本蓝牙操作。', dangerous: false),
    AppPermissionItem(name: 'android.permission.BLUETOOTH_CONNECT', description: '蓝牙连接：Android 12+ 连接蓝牙设备。', dangerous: true),
    AppPermissionItem(name: 'android.permission.BLUETOOTH_SCAN', description: '蓝牙扫描：Android 12+ 扫描附近设备。', dangerous: true),
    AppPermissionItem(name: 'android.permission.NFC', description: 'NFC：读取/写入 NFC 标签。', dangerous: false),
    AppPermissionItem(name: 'android.permission.VIBRATE', description: '振动：触觉反馈、提醒。', dangerous: false),
    AppPermissionItem(name: 'android.permission.WAKE_LOCK', description: '保持唤醒：下载、播放、后台任务。', dangerous: false),
    AppPermissionItem(name: 'android.permission.FOREGROUND_SERVICE', description: '前台服务：持续定位、下载、播放器等。', dangerous: false),
    AppPermissionItem(name: 'android.permission.REQUEST_INSTALL_PACKAGES', description: '安装 APK：下载构建产物后拉起安装。', dangerous: true),
    AppPermissionItem(name: 'android.permission.QUERY_ALL_PACKAGES', description: '查询全部应用：应用管理场景使用，审核敏感。', dangerous: true),
  ];
}