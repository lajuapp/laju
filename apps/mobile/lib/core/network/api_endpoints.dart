class ApiEndpoints {
  ApiEndpoints._();

  // Health
  static const String health = '/health';

  // Auth
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String verify2Fa = '/auth/verify-2fa';
  static const String logout = '/auth/logout';

  // Users
  static const String currentUser = '/users/me';
  static const String users = '/users';
  static String userById(String id) => '/users/$id';
  static const String userReport = '/users/report';
  static String userTrustScore(String id) => '/users/$id/trust-score';
  static const String userReportsAll = '/users/reports/all';
  static String reviewUserReport(String id) => '/users/reports/$id/review';

  // Conversations
  static const String conversations = '/conversations';
  static String conversationById(String id) => '/conversations/$id';
  static String conversationMembers(String id) => '/conversations/$id/members';
  static String conversationMemberRole(String id, String userId) => '/conversations/$id/members/$userId';
  static String conversationLeave(String id) => '/conversations/$id/leave';
  static String conversationMessages(String id) => '/conversations/$id/messages';

  // Messages
  static String messageById(String id) => '/messages/$id';
  static String messageRead(String id) => '/messages/$id/read';
  static String messageDelivery(String id) => '/messages/$id/delivery';

  // Calls
  static const String calls = '/calls';
  static String callAccept(String id) => '/calls/$id/accept';
  static String callReject(String id) => '/calls/$id/reject';
  static String callEnd(String id) => '/calls/$id/end';
  static String callSignal(String id) => '/calls/$id/signal';

  // Attachments
  static String attachmentUpload(String messageId) => '/attachments/$messageId';
  static String attachmentDownload(String blobId) => '/attachments/$blobId';

  // Devices & Identity
  static const String devices = '/devices';
  static const String deviceChallenge = '/devices/challenge';
  static const String deviceVerify = '/devices/verify';
  static const String devicePushToken = '/devices/push-token';
  static const String deviceTestPush = '/devices/test-push';
  static String deviceRevoke(String id) => '/devices/$id/revoke';
  static const String identityRegister = '/identity/register';
  static const String identityRestore = '/identity/restore';
  static const String identityMe = '/identity/me';

  // Migration
  static const String migrationStart = '/migration/start';
  static String migrationJoin(String id) => '/migration/$id/join';
  static String migrationVerify(String id) => '/migration/$id/verify';
  static String migrationCommit(String id) => '/migration/$id/commit';
  static String migrationCancel(String id) => '/migration/$id/cancel';
  static String migrationStatus(String id) => '/migration/$id/status';

  // Status (Stories)
  static const String status = '/status';
  static const String statusMe = '/status/me';
  static const String statusContacts = '/status/contacts';
  static String statusView(String id) => '/status/$id/view';
  static String statusById(String id) => '/status/$id';

  // Message Reactions
  static String messageReactions(String messageId) => '/messages/$messageId/reactions';
  static String messageReactionDelete(String messageId, String emoji) =>
      '/messages/$messageId/reactions/$emoji';
}


