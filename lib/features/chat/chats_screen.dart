import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../sessions/models/service_session.dart';
import 'chat_screen.dart';
import 'repositories/firebase_chat_repository.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  String _timeLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }

    return '${local.day}/${local.month}';
  }

  String _otherName(ServiceSession session) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == session.requesterId
        ? session.providerName
        : session.requesterName;
  }

  bool _hasUnread(ServiceSession session) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || session.lastMessage.isEmpty) return false;
    if (session.lastMessageSenderId == uid) return false;
    return !session.lastMessageReadBy.contains(uid);
  }

  @override
  Widget build(BuildContext context) {
    final repository = FirebaseChatRepository();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<ServiceSession>>(
        stream: repository.watchMyTextChats(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load chats.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data!;

          if (sessions.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 120),
                Icon(Icons.chat_bubble_outline_rounded, size: 54),
                SizedBox(height: 14),
                Text(
                  'No chats yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Accepted text service requests will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            );
          }

          sessions.sort((a, b) {
            final aTime = a.lastMessageAt ??
                a.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.lastMessageAt ??
                b.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          return ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 76,
            ),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final name = _otherName(session);
              final preview = session.lastMessage.trim().isEmpty
                  ? 'Text service ready'
                  : session.lastMessage;
              final hasUnread = _hasUnread(session);

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    name.isEmpty ? 'S' : name[0].toUpperCase(),
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight:
                        hasUnread ? FontWeight.w900 : FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasUnread
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                    fontWeight:
                        hasUnread ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _timeLabel(session.lastMessageAt ?? session.createdAt),
                      style: TextStyle(
                        color: hasUnread
                            ? colors.primary
                            : const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight:
                            hasUnread ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(session: session),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
