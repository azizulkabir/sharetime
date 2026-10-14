import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  bool _remoteDescriptionSet = false;
  bool _disposed = false;
  bool _videoEnabled = false;

  static const _iceServers = <Map<String, dynamic>>[
    <String, dynamic>{'urls': 'stun:stun.l.google.com:19302'},
  ];

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

    final signalRef = _firestore
        .collection('serviceSessions')
        .doc(session.id)
        .collection('webrtc')
        .doc('signaling');

    _peerConnection = await createPeerConnection(
      <String, dynamic>{'iceServers': _iceServers},
      <String, dynamic>{},
    );

    _peerConnection!.onConnectionState = onConnectionState;

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams.first);
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia(
      <String, dynamic>{
        'audio': true,
        'video': video
            ? <String, dynamic>{
                'facingMode': 'user',
                'width': <String, dynamic>{'ideal': 720},
                'height': <String, dynamic>{'ideal': 1280},
                'frameRate': <String, dynamic>{'ideal': 24},
              }
            : false,
      },
    );

    onLocalStream?.call(_localStream!);

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

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
      if (peer == null || !_remoteDescriptionSet) return;

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;

        try {
          await peer.addCandidate(
            RTCIceCandidate(
              data['candidate'] as String?,
              data['sdpMid'] as String?,
              (data['sdpMLineIndex'] as num?)?.toInt(),
            ),
          );
        } catch (_) {
          // Candidate can arrive slightly before the remote description is ready.
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

    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
      await stream.dispose();
    }

    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _peerConnection = null;
    _localStream = null;
  }
}
