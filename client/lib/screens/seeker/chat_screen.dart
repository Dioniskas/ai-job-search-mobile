import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

const _blue = Color(0xFF2563EB);
const _slate = Color(0xFF64748B);

// ── Conversations list ─────────────────────────────────────────────────────────

class SeekerChatScreen extends StatefulWidget {
  const SeekerChatScreen({super.key});

  @override
  State<SeekerChatScreen> createState() => _SeekerChatScreenState();
}

class _SeekerChatScreenState extends State<SeekerChatScreen> {
  List<dynamic> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = context.read<AuthProvider>();
      final list =
          await auth.withAuth((t) => ApiService.getChatConversations(t));
      if (!mounted) return;
      setState(() {
        _conversations = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщения',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {},
          ),
        ],
        elevation: 0,
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _slate)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Повторить')),
        ]),
      );
    }
    if (_conversations.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: _slate),
          SizedBox(height: 12),
          Text('Нет сообщений',
              style: TextStyle(fontSize: 17, color: _slate)),
          SizedBox(height: 6),
          Text('Откликнитесь на вакансию, чтобы начать чат',
              style: TextStyle(color: _slate),
              textAlign: TextAlign.center),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _conversations.length,
        separatorBuilder: (context, idx) =>
            const Divider(height: 1, indent: 72),
        itemBuilder: (context, i) => _ConversationTile(
          conversation: _conversations[i],
          onTap: () {
            final conv = _conversations[i] as Map<String, dynamic>;
            final vacancy =
                conv['vacancy'] as Map<String, dynamic>? ?? {};
            final employer =
                conv['employer'] as Map<String, dynamic>? ?? {};
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatConversationScreen(
                  vacancyId: vacancy['id'] as String? ?? '',
                  employerId: employer['id'] as String? ?? '',
                  vacancyTitle: vacancy['title'] as String? ?? 'Вакансия',
                  companyName:
                      employer['companyName'] as String? ?? '',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile(
      {required this.conversation, required this.onTap});

  final dynamic conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final conv = conversation as Map<String, dynamic>;
    final vacancy = conv['vacancy'] as Map<String, dynamic>? ?? {};
    final employer = conv['employer'] as Map<String, dynamic>? ?? {};
    final logoUrl = employer['logoUrl'] as String?;
    final companyName = employer['companyName'] as String? ?? '';
    final vacancyTitle = vacancy['title'] as String? ?? 'Вакансия';
    final lastMsg = conv['lastMessage'] as String? ?? '';
    final lastAt = conv['lastMessageAt'] as String?;

    String timeLabel = '';
    if (lastAt != null) {
      final dt = DateTime.tryParse(lastAt);
      if (dt != null) {
        final now = DateTime.now();
        if (now.difference(dt).inDays == 0) {
          timeLabel =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else {
          timeLabel =
              '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
        }
      }
    }

    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundImage:
            logoUrl != null ? NetworkImage(logoUrl) : null,
        backgroundColor: const Color(0xFFDBEAFE),
        child: logoUrl == null
            ? Text(
                companyName.isNotEmpty
                    ? companyName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: _blue, fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Text(vacancyTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(companyName,
              style: const TextStyle(color: _slate, fontSize: 13)),
          if (lastMsg.isNotEmpty)
            Text(lastMsg,
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: timeLabel.isNotEmpty
          ? Text(timeLabel,
              style:
                  const TextStyle(color: _slate, fontSize: 12))
          : null,
      isThreeLine: lastMsg.isNotEmpty,
    );
  }
}

// ── Conversation screen ────────────────────────────────────────────────────────

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({
    super.key,
    required this.vacancyId,
    required this.employerId,
    required this.vacancyTitle,
    required this.companyName,
  });

  final String vacancyId;
  final String employerId;
  final String vacancyTitle;
  final String companyName;

  @override
  State<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<dynamic> _messages = [];
  bool _loading = true;
  String? _currentUserId;
  io.Socket? _socket;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    _currentUserId = auth.user?['id'] as String?;
    await _loadMessages();
    _connectSocket(auth.token ?? '');
  }

  Future<void> _loadMessages() async {
    try {
      final auth = context.read<AuthProvider>();
      final list = await auth.withAuth((t) =>
          ApiService.getChatMessages(t, widget.vacancyId, widget.employerId));
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _connectSocket(String token) {
    _socket = io.io(
      '${ApiService.baseUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
    _socket!.on('receiveMessage', (data) {
      if (!mounted) return;
      final msg = data as Map<String, dynamic>;
      if (msg['vacancyId'] == widget.vacancyId) {
        setState(() => _messages = [..._messages, msg]);
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _msgCtrl.clear();
    setState(() => _sending = true);
    try {
      final auth = context.read<AuthProvider>();
      final msg = await auth.withAuth((t) => ApiService.sendChatMessage(
          t, widget.vacancyId, widget.employerId, text));
      if (!mounted) return;
      _socket?.emit('sendMessage', {
        'vacancyId': widget.vacancyId,
        'employerId': widget.employerId,
        'text': text,
      });
      setState(() {
        _messages = [..._messages, msg];
        _sending = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.vacancyTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (widget.companyName.isNotEmpty)
              Text(widget.companyName,
                  style:
                      const TextStyle(color: _slate, fontSize: 12)),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(isDark)),
          _buildInput(isDark),
        ],
      ),
    );
  }

  Widget _buildMessages(bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_messages.isEmpty) {
      return const Center(
        child: Text('Начните переписку',
            style: TextStyle(color: _slate)),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i] as Map<String, dynamic>;
        final senderId = msg['senderId'] as String?;
        final isMe = senderId == _currentUserId;
        return _MessageBubble(
            text: msg['text'] as String? ?? '',
            createdAt: msg['createdAt'] as String?,
            isMe: isMe,
            isDark: isDark);
      },
    );
  }

  Widget _buildInput(bool isDark) {
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final border = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA);

    return Container(
      color: bg,
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Сообщение...',
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: _blue),
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          _sending
              ? const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  onPressed: _send,
                  style: IconButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 20),
                ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.isDark,
    this.createdAt,
  });

  final String text;
  final bool isMe;
  final bool isDark;
  final String? createdAt;

  @override
  Widget build(BuildContext context) {
    String time = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt!);
      if (dt != null) {
        time =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    final bubbleColor = isMe
        ? _blue
        : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7));
    final textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft:
                isMe ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight:
                isMe ? const Radius.circular(4) : const Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: TextStyle(color: textColor, fontSize: 15)),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(time,
                  style: TextStyle(
                      color: isMe
                          ? Colors.white60
                          : _slate,
                      fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}
