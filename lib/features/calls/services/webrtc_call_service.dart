import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../sessions/models/service_session.dart';

class WebRtcCallService {
  WebRtcCallService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _signalSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _candidateSub;
  Timer? _statsTimer;

  bool _remoteDescriptionSet = false;
  bool _disposed = false;
  bool _videoEnabled = false;
  final List<RTCIceCandidate> _pendingRemoteCandidates = <RTCIceCandidate>[];

  static const _turnApiUrl =
      'https://0q04aw6q8b.execute-api.ap-southeast-2.amazonaws.com/default/sharetime-turn-credentials';

  Future<List<Map<String, dynamic>>> _loadIceServers(
    User user,
    String sessionId,
  ) async {
    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Firebase ID token is unavailable.');
    }

    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(_turnApiUrl));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(<String, dynamic>{
        'clientId': '${user.uid}-$sessionId',
      }));

      final response = await request.close();
      final body = await utf8.decodeStream(response);

      debugPrint(
        'ShareTime TURN API status=${response.statusCode} body=$body',
      );

      if (response.statusCode != HttpStatus.ok) {
        throw StateError(
          'TURN API failed (${response.statusCode}): $body',
        );
      }

      final decodedValue = jsonDecode(body);
      if (decodedValue is! Map) {
        throw const FormatException('TURN API returned invalid JSON.');
      }

      final decoded = Map<String, dynamic>.from(decodedValue);
      final rawServers = decoded['iceServers'];

      if (rawServers is! List) {
        throw const FormatException(
          'TURN API response does not contain iceServers.',
        );
      }

      final servers = rawServers
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map((item) {
            final urls = item['urls'];
            return <String, dynamic>{
              'urls': urls is List
                  ? urls.map((value) => value.toString()).toList()
                  : urls?.toString(),
              if (item['username'] != null)
                'username': item['username'].toString(),
              if (item['credential'] != null)
                'credential': item['credential'].toString(),
            };
          })
          .where((item) => item['urls'] != null)
          .toList();

      if (servers.isEmpty) {
        throw const FormatException('TURN API returned no ICE servers.');
      }

      final hasTurn = servers.any((server) {
        final urls = server['urls'];
        final values = urls is List ? urls : <dynamic>[urls];
        return values.any(
          (value) => value.toString().startsWith('turn:') ||
              value.toString().startsWith('turns:'),
        );
      });

      if (!hasTurn) {
        throw const FormatException('AWS TURN servers were not returned.');
      }

      debugPrint('ShareTime AWS TURN loaded: ${servers.length} ICE entries');
      return servers;
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _peerConfiguration(
    List<Map<String, dynamic>> iceServers,
  ) {
    return <String, dynamic>{
      'iceServers': iceServers,
      'iceTransportPolicy': 'all',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'iceCandidatePoolSize': 4,
    };
  }

  Future<void> startAudioCall({
    required ServiceSession session,
    required void Function(RTCPeerConnectionState state) onConnectionState,
  }) {
    return _startCall(
      session: session,
      video: false,
      onConnectionState: onConnectionState,
    );
  }

  Future<void> startVideoCall({
    required ServiceSession session,
    required void Function(RTCPeerConnectionState state) onConnectionState,
    required void Function(MediaStream stream) onLocalStream,
    required void Function(MediaStream stream) onRemoteStream,
  }) {
    return _startCall(
      session: session,
      video: true,
      onConnectionState: onConnectionState,
      onLocalStream: onLocalStream,
      onRemoteStream: onRemoteStream,
    );
  }

  Future<void> _startCall({
    required ServiceSession session,
    required bool video,
    required void Function(RTCPeerConnectionState state) onConnectionState,
    void Function(MediaStream stream)? onLocalStream,
    void Function(MediaStream stream)? onRemoteStream,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    final isRequester = user.uid == session.requesterId;
    if (!isRequester && user.uid != session.providerId) {
      throw StateError('User is not part of this call.');
    }

    _videoEnabled = video;

    if (Platform.isAndroid) {
      await Helper.setAndroidAudioConfiguration(
        AndroidAudioConfiguration.communication,
      );
    }

    final iceServers = await _loadIceServers(user, session.id);

    final signalRef = _firestore
        .collection('serviceSessions')
        .doc(session.id)
        .collection('webrtc')
        .doc('signaling');

    _peerConnection = await createPeerConnection(
      _peerConfiguration(iceServers),
      <String, dynamic>{},
    );

    _peerConnection!.onConnectionState = onConnectionState;

    _peerConnection!.onTrack = (event) async {
      if (event.track.kind == 'audio') {
        event.track.enabled = true;
        await Helper.setVolume(1.0, event.track);

        debugPrint('ShareTime remote audio track enabled');
      }

      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams.first);
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia(
      <String, dynamic>{
        'audio': <String, dynamic>{
          'echoCancellation': true,
          'googEchoCancellation': true,
          'noiseSuppression': true,
          'googNoiseSuppression': true,
          'autoGainControl': true,
          'channelCount': 1,
        },
        'video': video
            ? <String, dynamic>{
                'facingMode': 'user',
                'width': <String, dynamic>{'ideal': 640},
                'height': <String, dynamic>{'ideal': 480},
                'frameRate': <String, dynamic>{'ideal': 15},
              }
            : false,
      },
    );

    onLocalStream?.call(_localStream!);

    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = true;
    }

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    _startStatsLogging();

    final ownCandidates = signalRef.collection(
      isRequester ? 'requesterCandidates' : 'providerCandidates',
    );
    final remoteCandidates = signalRef.collection(
      isRequester ? 'providerCandidates' : 'requesterCandidates',
    );

    _peerConnection!.onIceCandidate = (candidate) async {
      if (_disposed || candidate.candidate == null) return;

      await ownCandidates.add(<String, dynamic>{
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'createdAt': FieldValue.serverTimestamp(),
      });
    };

    _candidateSub = remoteCandidates.snapshots().listen((snapshot) async {
      final peer = _peerConnection;
      if (peer == null) return;

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;

        final candidate = RTCIceCandidate(
          data['candidate'] as String?,
          data['sdpMid'] as String?,
          (data['sdpMLineIndex'] as num?)?.toInt(),
        );

        if (!_remoteDescriptionSet) {
          _pendingRemoteCandidates.add(candidate);
          continue;
        }

        try {
          await peer.addCandidate(candidate);
        } catch (_) {
          // Ignore a duplicate/late candidate; existing candidates are replayed
          // once the remote description is ready.
        }
      }
    });

    if (isRequester) {
      await _startAsRequester(signalRef);
    } else {
      await _startAsProvider(signalRef);
    }
  }

  Future<void> _startAsRequester(
    DocumentReference<Map<String, dynamic>> signalRef,
  ) async {
    final peer = _peerConnection!;
    final offer = await peer.createOffer(<String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _videoEnabled,
    });
    await peer.setLocalDescription(offer);

    await signalRef.set(<String, dynamic>{
      'offer': <String, dynamic>{
        'type': offer.type,
        'sdp': offer.sdp,
      },
      'answer': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _signalSub = signalRef.snapshots().listen((snapshot) async {
      if (_disposed || _remoteDescriptionSet) return;
      final data = snapshot.data();
      final answer = data?['answer'];
      if (answer is! Map) return;

      final type = answer['type']?.toString();
      final sdp = answer['sdp']?.toString();
      if (type == null || sdp == null || sdp.isEmpty) return;

      await peer.setRemoteDescription(RTCSessionDescription(sdp, type));
      _remoteDescriptionSet = true;
      await _flushPendingRemoteCandidates();
      await _addExistingRemoteCandidates(signalRef, 'providerCandidates');
    });
  }

  Future<void> _startAsProvider(
    DocumentReference<Map<String, dynamic>> signalRef,
  ) async {
    final peer = _peerConnection!;

    _signalSub = signalRef.snapshots().listen((snapshot) async {
      if (_disposed || _remoteDescriptionSet) return;
      final data = snapshot.data();
      final offer = data?['offer'];
      if (offer is! Map) return;

      final type = offer['type']?.toString();
      final sdp = offer['sdp']?.toString();
      if (type == null || sdp == null || sdp.isEmpty) return;

      await peer.setRemoteDescription(RTCSessionDescription(sdp, type));
      _remoteDescriptionSet = true;
      await _flushPendingRemoteCandidates();

      final answer = await peer.createAnswer(<String, dynamic>{
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': _videoEnabled,
      });
      await peer.setLocalDescription(answer);

      await signalRef.set(<String, dynamic>{
        'answer': <String, dynamic>{
          'type': answer.type,
          'sdp': answer.sdp,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _addExistingRemoteCandidates(signalRef, 'requesterCandidates');
    });
  }

  Future<void> _flushPendingRemoteCandidates() async {
    final peer = _peerConnection;
    if (peer == null || !_remoteDescriptionSet) return;

    final pending = List<RTCIceCandidate>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();

    for (final candidate in pending) {
      try {
        await peer.addCandidate(candidate);
      } catch (_) {
        // Ignore duplicate/late candidates.
      }
    }
  }

  Future<void> _addExistingRemoteCandidates(
    DocumentReference<Map<String, dynamic>> signalRef,
    String collectionName,
  ) async {
    final peer = _peerConnection;
    if (peer == null) return;

    final snapshot = await signalRef.collection(collectionName).get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      try {
        await peer.addCandidate(
          RTCIceCandidate(
            data['candidate'] as String?,
            data['sdpMid'] as String?,
            (data['sdpMLineIndex'] as num?)?.toInt(),
          ),
        );
      } catch (_) {
        // Ignore duplicate or late ICE candidates.
      }
    }
  }

  void _startStatsLogging() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final peer = _peerConnection;
      if (peer == null || _disposed) return;

      try {
        final reports = await peer.getStats();
        for (final report in reports) {
          final values = report.values;
          final type = report.type;

          if (type == 'outbound-rtp' && values['kind'] == 'audio') {
            debugPrint(
              'ShareTime AUDIO OUT packetsSent=${values['packetsSent']} '
              'bytesSent=${values['bytesSent']} '
              'audioLevel=${values['audioLevel']} '
              'totalAudioEnergy=${values['totalAudioEnergy']}',
            );
          }

          if (type == 'inbound-rtp' && values['kind'] == 'audio') {
            debugPrint(
              'ShareTime AUDIO IN packetsReceived=${values['packetsReceived']} '
              'bytesReceived=${values['bytesReceived']} '
              'audioLevel=${values['audioLevel']} '
              'totalAudioEnergy=${values['totalAudioEnergy']}',
            );
          }
        }
      } catch (error) {
        debugPrint('ShareTime audio stats error: $error');
      }
    });
  }

  Future<void> setMuted(bool muted) async {
    final stream = _localStream;
    if (stream == null) return;

    for (final track in stream.getAudioTracks()) {
      track.enabled = !muted;
    }
  }

  Future<void> setCameraEnabled(bool enabled) async {
    final stream = _localStream;
    if (stream == null) return;

    for (final track in stream.getVideoTracks()) {
      track.enabled = enabled;
    }
  }

  Future<void> switchCamera() async {
    final stream = _localStream;
    if (stream == null || stream.getVideoTracks().isEmpty) return;
    await Helper.switchCamera(stream.getVideoTracks().first);
  }

  Future<void> setSpeakerphone(bool enabled) async {
    await Helper.setSpeakerphoneOn(enabled);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _signalSub?.cancel();
    await _candidateSub?.cancel();
    _statsTimer?.cancel();
    _statsTimer = null;

    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
      await stream.dispose();
    }

    await _peerConnection?.close();
    await _peerConnection?.dispose();

    if (Platform.isAndroid) {
      await Helper.clearAndroidCommunicationDevice();
    }

    _peerConnection = null;
    _localStream = null;
  }
}
