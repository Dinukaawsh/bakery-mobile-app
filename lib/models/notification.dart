class AppNotification {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String body;
  final String? href;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.href,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      userId: json['userId'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      href: json['href'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class NotificationsPageResult {
  final List<AppNotification> notifications;
  final int page;
  final int limit;
  final int total;
  final int unreadCount;

  const NotificationsPageResult({
    required this.notifications,
    required this.page,
    required this.limit,
    required this.total,
    required this.unreadCount,
  });

  factory NotificationsPageResult.fromJson(Map<String, dynamic> json) {
    return NotificationsPageResult(
      notifications: ((json['notifications'] as List?) ?? [])
          .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}
