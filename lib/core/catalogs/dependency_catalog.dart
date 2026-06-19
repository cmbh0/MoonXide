import '../models/dependency_preset.dart';

class DependencyCatalog {
  static const flutter = [
    DependencyPreset(name: 'WebView 官方组件', description: '在应用内加载网页、网页 UI、混合开发页面。', packageName: 'webview_flutter'),
    DependencyPreset(name: '增强 WebView', description: '更完整的 WebView 能力，适合复杂 WebUI。', packageName: 'flutter_inappwebview'),
    DependencyPreset(name: 'HTTP 请求', description: '简单网络请求、REST API 调用。', packageName: 'http'),
    DependencyPreset(name: 'Dio 网络库', description: '拦截器、上传下载、取消请求、复杂接口。', packageName: 'dio'),
    DependencyPreset(name: 'Provider 状态管理', description: '轻量状态管理，适合中小型应用。', packageName: 'provider'),
    DependencyPreset(name: 'Riverpod 状态管理', description: '更强状态管理，适合复杂项目。', packageName: 'flutter_riverpod'),
    DependencyPreset(name: 'GetX 快速开发', description: '路由、状态、依赖注入一体化。', packageName: 'get'),
    DependencyPreset(name: '本地键值存储', description: '保存设置、Token、用户偏好。', packageName: 'shared_preferences'),
    DependencyPreset(name: 'SQLite 数据库', description: '结构化本地数据库。', packageName: 'sqflite'),
    DependencyPreset(name: 'Hive 数据库', description: '高性能本地 NoSQL 存储。', packageName: 'hive'),
    DependencyPreset(name: '文件选择器', description: '选择文件、导入 keystore、导入资源。', packageName: 'file_picker'),
    DependencyPreset(name: '路径工具', description: '获取下载目录、缓存目录、文档目录。', packageName: 'path_provider'),
    DependencyPreset(name: '权限申请', description: '运行时申请相机、存储、定位、通知等权限。', packageName: 'permission_handler'),
    DependencyPreset(name: '图片选择', description: '从相册或相机选择图片。', packageName: 'image_picker'),
    DependencyPreset(name: '分享', description: '分享 APK、链接、文本。', packageName: 'share_plus'),
    DependencyPreset(name: '应用信息', description: '读取版本号、包名、构建号。', packageName: 'package_info_plus'),
    DependencyPreset(name: 'URL 打开', description: '打开浏览器、GitHub、外部链接。', packageName: 'url_launcher'),
    DependencyPreset(name: 'Markdown 渲染', description: '渲染 README、Release 说明、日志摘要。', packageName: 'flutter_markdown'),
    DependencyPreset(name: '压缩包处理', description: '解压 Actions 日志 zip、打包项目。', packageName: 'archive'),
  ];
}