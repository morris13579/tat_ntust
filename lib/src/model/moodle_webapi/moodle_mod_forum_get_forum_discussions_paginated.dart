/// discussions : [{"id":242038,"name":"論文研討注意事項","groupid":-1,"timemodified":1631163160,"usermodified":51406,"timestart":0,"timeend":0,"discussion":153487,"parent":0,"userid":51406,"created":1631163160,"modified":1631163160,"mailed":1,"subject":"論文研討注意事項","message":"<p>各位同學好，附件是本學期論文研討的相關規定<br /></p>","messageformat":1,"messagetrust":0,"attachment":"1","attachments":[{"filename":"110_1論文研討的規定.pptx","mimetype":"application/vnd.openxmlformats-officedocument.presentationml.presentation","fileurl":"https://moodle.ntust.edu.tw/webservice/pluginfile.php/826780/mod_forum/attachment/242038/110_1%E8%AB%96%E6%96%87%E7%A0%94%E8%A8%8E%E7%9A%84%E8%A6%8F%E5%AE%9A.pptx"}],"totalscore":0,"mailnow":0,"userfullname":"M10902113@ 陳彥丞","usermodifiedfullname":"M10902113@ 陳彥丞","userpictureurl":"https://moodle.ntust.edu.tw/theme/image.php/essential/core/1631171023/u/f1","usermodifiedpictureurl":"https://moodle.ntust.edu.tw/theme/image.php/essential/core/1631171023/u/f1","numreplies":"0","numunread":0,"pinned":false}]
/// warnings : []

class MoodleModForumGetForumDiscussionsPaginated {
  List<Discussions> _discussions;

  List<Discussions> get discussions => _discussions;

  MoodleModForumGetForumDiscussionsPaginated({List<Discussions> discussions}) {
    _discussions = discussions;
  }

  MoodleModForumGetForumDiscussionsPaginated.fromJson(dynamic json) {
    if (json['discussions'] != null) {
      _discussions = [];
      json['discussions'].forEach((v) {
        _discussions.add(Discussions.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    if (_discussions != null) {
      map['discussions'] = _discussions.map((v) => v.toJson()).toList();
    }
    return map;
  }
}

/// id : 242038
/// name : "論文研討注意事項"
/// groupid : -1
/// timemodified : 1631163160
/// usermodified : 51406
/// timestart : 0
/// timeend : 0
/// discussion : 153487
/// parent : 0
/// userid : 51406
/// created : 1631163160
/// modified : 1631163160
/// mailed : 1
/// subject : "論文研討注意事項"
/// message : "<p>各位同學好，附件是本學期論文研討的相關規定<br /></p>"
/// messageformat : 1
/// messagetrust : 0
/// attachment : "1"
/// attachments : [{"filename":"110_1論文研討的規定.pptx","mimetype":"application/vnd.openxmlformats-officedocument.presentationml.presentation","fileurl":"https://moodle.ntust.edu.tw/webservice/pluginfile.php/826780/mod_forum/attachment/242038/110_1%E8%AB%96%E6%96%87%E7%A0%94%E8%A8%8E%E7%9A%84%E8%A6%8F%E5%AE%9A.pptx"}]
/// totalscore : 0
/// mailnow : 0
/// userfullname : "M10902113@ 陳彥丞"
/// usermodifiedfullname : "M10902113@ 陳彥丞"
/// userpictureurl : "https://moodle.ntust.edu.tw/theme/image.php/essential/core/1631171023/u/f1"
/// usermodifiedpictureurl : "https://moodle.ntust.edu.tw/theme/image.php/essential/core/1631171023/u/f1"
/// numreplies : "0"
/// numunread : 0
/// pinned : false

class Discussions {
  int _id;
  String _name;
  int _groupid;
  int _timemodified;
  int _usermodified;
  int _timestart;
  int _timeend;
  int _discussion;
  int _parent;
  int _userid;
  int _created;
  int _modified;
  int _mailed;
  String _subject;
  String _message;
  int _messageformat;
  int _messagetrust;
  String _attachment;
  List<Attachments> _attachments;
  int _totalscore;
  int _mailnow;
  String _userfullname;
  String _usermodifiedfullname;
  String _userpictureurl;
  String _usermodifiedpictureurl;
  String _numreplies;
  int _numunread;
  bool _pinned;

  int get id => _id;

  String get name => _name;

  int get groupid => _groupid;

  int get timemodified => _timemodified;

  int get usermodified => _usermodified;

  int get timestart => _timestart;

  int get timeend => _timeend;

  int get discussion => _discussion;

  int get parent => _parent;

  int get userid => _userid;

  int get created => _created;

  int get modified => _modified;

  int get mailed => _mailed;

  String get subject => _subject;

  String get message => _message;

  int get messageformat => _messageformat;

  int get messagetrust => _messagetrust;

  String get attachment => _attachment;

  List<Attachments> get attachments => _attachments;

  int get totalscore => _totalscore;

  int get mailnow => _mailnow;

  String get userfullname => _userfullname;

  String get usermodifiedfullname => _usermodifiedfullname;

  String get userpictureurl => _userpictureurl;

  String get usermodifiedpictureurl => _usermodifiedpictureurl;

  String get numreplies => _numreplies;

  int get numunread => _numunread;

  bool get pinned => _pinned;

  Discussions(
      {int id,
      String name,
      int groupid,
      int timemodified,
      int usermodified,
      int timestart,
      int timeend,
      int discussion,
      int parent,
      int userid,
      int created,
      int modified,
      int mailed,
      String subject,
      String message,
      int messageformat,
      int messagetrust,
      String attachment,
      List<Attachments> attachments,
      int totalscore,
      int mailnow,
      String userfullname,
      String usermodifiedfullname,
      String userpictureurl,
      String usermodifiedpictureurl,
      String numreplies,
      int numunread,
      bool pinned}) {
    _id = id;
    _name = name;
    _groupid = groupid;
    _timemodified = timemodified;
    _usermodified = usermodified;
    _timestart = timestart;
    _timeend = timeend;
    _discussion = discussion;
    _parent = parent;
    _userid = userid;
    _created = created;
    _modified = modified;
    _mailed = mailed;
    _subject = subject;
    _message = message;
    _messageformat = messageformat;
    _messagetrust = messagetrust;
    _attachment = attachment;
    _attachments = attachments;
    _totalscore = totalscore;
    _mailnow = mailnow;
    _userfullname = userfullname;
    _usermodifiedfullname = usermodifiedfullname;
    _userpictureurl = userpictureurl;
    _usermodifiedpictureurl = usermodifiedpictureurl;
    _numreplies = numreplies;
    _numunread = numunread;
    _pinned = pinned;
  }

  Discussions.fromJson(dynamic json) {
    _id = json['id'];
    _name = json['name'];
    _groupid = json['groupid'];
    _timemodified = json['timemodified'];
    _usermodified = json['usermodified'];
    _timestart = json['timestart'];
    _timeend = json['timeend'];
    _discussion = json['discussion'];
    _parent = json['parent'];
    _userid = json['userid'];
    _created = json['created'];
    _modified = json['modified'];
    _mailed = json['mailed'];
    _subject = json['subject'];
    _message = json['message'];
    _messageformat = json['messageformat'];
    _messagetrust = json['messagetrust'];
    _attachment = json['attachment'];
    if (json['attachments'] != null) {
      _attachments = [];
      json['attachments'].forEach((v) {
        _attachments.add(Attachments.fromJson(v));
      });
    }
    _totalscore = json['totalscore'];
    _mailnow = json['mailnow'];
    _userfullname = json['userfullname'];
    _usermodifiedfullname = json['usermodifiedfullname'];
    _userpictureurl = json['userpictureurl'];
    _usermodifiedpictureurl = json['usermodifiedpictureurl'];
    _numreplies = json['numreplies'];
    _numunread = json['numunread'];
    _pinned = json['pinned'];
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map['id'] = _id;
    map['name'] = _name;
    map['groupid'] = _groupid;
    map['timemodified'] = _timemodified;
    map['usermodified'] = _usermodified;
    map['timestart'] = _timestart;
    map['timeend'] = _timeend;
    map['discussion'] = _discussion;
    map['parent'] = _parent;
    map['userid'] = _userid;
    map['created'] = _created;
    map['modified'] = _modified;
    map['mailed'] = _mailed;
    map['subject'] = _subject;
    map['message'] = _message;
    map['messageformat'] = _messageformat;
    map['messagetrust'] = _messagetrust;
    map['attachment'] = _attachment;
    if (_attachments != null) {
      map['attachments'] = _attachments.map((v) => v.toJson()).toList();
    }
    map['totalscore'] = _totalscore;
    map['mailnow'] = _mailnow;
    map['userfullname'] = _userfullname;
    map['usermodifiedfullname'] = _usermodifiedfullname;
    map['userpictureurl'] = _userpictureurl;
    map['usermodifiedpictureurl'] = _usermodifiedpictureurl;
    map['numreplies'] = _numreplies;
    map['numunread'] = _numunread;
    map['pinned'] = _pinned;
    return map;
  }
}

/// filename : "110_1論文研討的規定.pptx"
/// mimetype : "application/vnd.openxmlformats-officedocument.presentationml.presentation"
/// fileurl : "https://moodle.ntust.edu.tw/webservice/pluginfile.php/826780/mod_forum/attachment/242038/110_1%E8%AB%96%E6%96%87%E7%A0%94%E8%A8%8E%E7%9A%84%E8%A6%8F%E5%AE%9A.pptx"

class Attachments {
  String _filename;
  String _mimetype;
  String _fileurl;

  String get filename => _filename;

  String get mimetype => _mimetype;

  String get fileurl => _fileurl;

  Attachments({String filename, String mimetype, String fileurl}) {
    _filename = filename;
    _mimetype = mimetype;
    _fileurl = fileurl;
  }

  Attachments.fromJson(dynamic json) {
    _filename = json['filename'];
    _mimetype = json['mimetype'];
    _fileurl = json['fileurl'];
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map['filename'] = _filename;
    map['mimetype'] = _mimetype;
    map['fileurl'] = _fileurl;
    return map;
  }
}
