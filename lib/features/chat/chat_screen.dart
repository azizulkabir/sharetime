import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../sessions/models/service_session.dart';
import 'models/chat_message.dart';
import 'repositories/firebase_chat_repository.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.session,
  });

  final ServiceSession session;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repository = FirebaseChatRepository();
  final _controller = TextEditingController();
  Timer? _typingTimer;
  bool _isSending = false;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  String get _otherUserId {
    return _currentUid == widget.session.requesterId
        ? widget.session.providerId
        : widget.session.requesterId;
  }

  String get _otherName {
    return _currentUid == widget.session.requesterId
        ? widget.session.providerName
        : widget.session.requesterName;
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _repository.setTyping(
      sessionId: widget.session.id,
      isTyping: false,
    );
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _typingTimer?.cancel();

    if (value.trim().isEmpty) {
      _repository.setTyping(
        sessionId: widget.session.id,
        isTyping: false,
      );
      return;
    }

    _repository.setTyping(
      sessionId: widget.session.id,
      isTyping: true,
    );

    _typingTimer = Timer(const Duration(milliseconds: 1400), () {
      _repository.setTyping(
        sessionId: widget.session.id,
        isTyping: false,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      await _repository.sendMessage(
        sessionId: widget.session.id,
        text: text,
      );
      _controller.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message could not be sent.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _markReadIfNeeded(List<ChatMessage> messages) {
    final uid = _currentUid;
    if (uid == null) return;

    final hasUnreadIncoming = messages.any(
      (message) => message.senderId != uid && !message.isRead,
    );
    if (!hasUnreadIncoming) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _repository.markIncomingMessagesDeliveredAndRead(
        sessionId: widget.session.id,
        messages: messages,
      );
    });
  }

  String _timeLabel(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _deliveryIcon(ChatMessage message) {
    if (message.isRead) {
      return const Icon(
        Icons.done_all_rounded,
        size: 15,
        color: Color(0xFF2563EB),
      );
    }
    if (message.isDelivered) {
      return const Icon(
        Icons.done_all_rounded,
        size: 15,
        color: Color(0xFF64748B),
      );
    }
    return const Icon(
      Icons.done_rounded,
      size: 15,
      color: Color(0xFF64748B),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _currentUid;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primaryContainer,
              child: Text(
                _otherName.isEmpty ? 'S' : _otherName[0].toUpperCase(),
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<bool>(
                stream: _repository.watchOtherTyping(
                  sessionId: widget.session.id,
                  otherUserId: _otherUserId,
                ),
                builder: (context, snapshot) {
                  final isTyping = snapshot.data == true;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _otherName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        isTyping ? 'typing...' : 'Text service',
                        style: TextStyle(
                          color: isTyping
                              ? colors.primary
                              : const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight:
                              isTyping ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Audio call',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Audio calling will be added in the WebRTC step.'),
                ),
              );
            },
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Video calling will be added in the WebRTC step.'),
                ),
              );
            },
            icon: const Icon(Icons.videocam_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _repository.watchMessages(widget.session.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load messages.'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                _markReadIfNeeded(messages);

                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No messages yet. Start the conversation.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == currentUid;

                    return Align(
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.76,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                        decoration: BoxDecoration(
                          color: isMine
                              ? colors.primaryContainer
                              : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMine ? 16 : 4),
                            bottomRight: Radius.circular(isMine ? 4 : 16),
                          ),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                message.text,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _timeLabel(message.sentAt),
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 10,
                                  ),
                                ),
                                if (isMine) ...[
                                  const SizedBox(width: 3),
                                  _deliveryIcon(message),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: _onTextChanged,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
