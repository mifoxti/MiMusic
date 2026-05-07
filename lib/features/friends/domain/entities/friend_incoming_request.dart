class FriendIncomingRequest {
  const FriendIncomingRequest({
    required this.fromUserId,
    required this.nickname,
    this.createdAt,
  });

  final int fromUserId;
  final String nickname;
  final String? createdAt;
}
