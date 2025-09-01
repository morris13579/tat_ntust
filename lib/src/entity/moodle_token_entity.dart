class MoodleTokenEntity {
  String signature;
  String token;
  String privateToken;

  MoodleTokenEntity(this.signature, this.token, this.privateToken);

  factory MoodleTokenEntity.fromJson(Map<String, dynamic> json) {
    return MoodleTokenEntity(
        json["signature"],
        json["token"],
        json["private_token"]
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "signature": signature,
      "token": token,
      "private_token": privateToken
    };
  }
}