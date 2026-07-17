import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/locale_scope.dart';
import '../services/api_service.dart';
import '../utils/safe_insets.dart';
import 'bakery_loading_spinner.dart';
import 'call_options_sheet.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.apiService,
    required this.deliveryGuyId,
    required this.title,
    this.imageUrl,
    this.phone,
  });

  final ApiService apiService;
  final int deliveryGuyId;
  final String title;
  final String? imageUrl;
  final String? phone;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _uploading = false;
  String? _pendingImage;
  int? _editingId;
  final _editDraft = TextEditingController();
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll =
        Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _draft.dispose();
    _editDraft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final data = await widget.apiService.fetchChatMessages(
        widget.deliveryGuyId,
      );
      if (!mounted) return;
      setState(() {
        _messages = data;
        _loading = false;
      });
      if (!silent) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (!silent) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await widget.apiService.uploadImage(
        bytes: bytes,
        filename: file.name,
      );
      if (!mounted) return;
      setState(() {
        _pendingImage = url;
        _uploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _send() async {
    final body = _draft.text.trim();
    if ((body.isEmpty && _pendingImage == null) || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.apiService.sendChatMessage(
        widget.deliveryGuyId,
        body: body,
        imageUrl: _pendingImage,
      );
      if (!mounted) return;
      setState(() {
        _draft.clear();
        _pendingImage = null;
        _sending = false;
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _saveEdit(int id) async {
    final body = _editDraft.text.trim();
    if (body.isEmpty) return;
    try {
      final updated = await widget.apiService.updateChatMessage(
        id,
        body: body,
      );
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map((m) => m['id'] == id ? {...m, ...updated} : m)
            .toList();
        _editingId = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _delete(int id) async {
    final t = LocaleScope.of(context).t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('chat.deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('common.delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final updated = await widget.apiService.deleteChatMessage(id);
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _messages = _messages
              .map((m) => m['id'] == id ? {...m, ...updated} : m)
              .toList();
        });
      } else {
        await _load(silent: true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _showMessageActions(Map<String, dynamic> message) async {
    final canEdit = message['canEdit'] == true;
    final canDelete = message['canDelete'] == true;
    final body = message['body'] as String? ?? '';
    if (!canEdit && !canDelete) return;
    final t = LocaleScope.of(context).t;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit && body.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(t('common.edit')),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFDC2626),
                ),
                title: Text(
                  t('common.delete'),
                  style: const TextStyle(color: Color(0xFFDC2626)),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    final id = message['id'] as int;
    if (action == 'edit') {
      setState(() {
        _editingId = id;
        _editDraft.text = body;
      });
    } else if (action == 'delete') {
      await _delete(id);
    }
  }

  Widget _avatar(String name, String? imageUrl) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl.trim(),
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initial(name),
        ),
      );
    }
    return _initial(name);
  }

  Widget _initial(String name) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFFDE68A),
        shape: BoxShape.circle,
      ),
      child: Text(
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF92400E),
        ),
      ),
    );
  }

  String _timeAgo(String? iso) {
    final t = LocaleScope.of(context).t;
    if (iso == null) return '';
    final date = DateTime.tryParse(iso);
    if (date == null) return '';
    final difference = DateTime.now().toUtc().difference(date.toUtc());
    if (difference.inMinutes < 1) return t('chat.justNow');
    if (difference.inHours < 1) {
      return t('chat.minutesAgo', {'count': difference.inMinutes});
    }
    if (difference.inDays < 1) {
      return t('chat.hoursAgo', {'count': difference.inHours});
    }
    if (difference.inDays < 7) {
      return t('chat.daysAgo', {'count': difference.inDays});
    }
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB45309),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            _avatar(widget.title, widget.imageUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.title, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (widget.phone != null && widget.phone!.trim().isNotEmpty)
            IconButton(
              tooltip: t('calls.call'),
              onPressed: () => showCallOptionsSheet(
                context,
                name: widget.title,
                phone: widget.phone,
              ),
              icon: const Icon(Icons.phone_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const BakeryLoadingCenter()
                : _messages.isEmpty
                    ? Center(child: Text(t('chat.emptyThread')))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final mine = msg['mine'] == true;
                          final deleted = msg['isDeleted'] == true;
                          final name = msg['senderName'] as String? ?? '';
                          final imageUrl = msg['senderImageUrl'] as String?;
                          final body = msg['body'] as String? ?? '';
                          final photo = msg['imageUrl'] as String?;
                          final createdAt = msg['createdAt'] as String?;
                          final editing = _editingId == msg['id'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: mine
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!mine) ...[
                                  _avatar(name, imageUrl),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: GestureDetector(
                                    onLongPress: mine && !deleted && !editing
                                        ? () => _showMessageActions(msg)
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: deleted
                                            ? const Color(0xFFF5F5F4)
                                            : mine
                                                ? const Color(0xFFB45309)
                                                : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft:
                                              Radius.circular(mine ? 16 : 4),
                                          bottomRight:
                                              Radius.circular(mine ? 4 : 16),
                                        ),
                                        border: mine && !deleted
                                            ? null
                                            : Border.all(
                                                color: const Color(0xFFE7E5E4),
                                              ),
                                      ),
                                      child: editing
                                          ? Column(
                                              children: [
                                                TextField(
                                                  controller: _editDraft,
                                                  maxLines: 3,
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                  ),
                                                  decoration:
                                                      const InputDecoration(
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                    border:
                                                        OutlineInputBorder(),
                                                    isDense: true,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          _saveEdit(
                                                        msg['id'] as int,
                                                      ),
                                                      child: Text(
                                                        t('common.saveChanges'),
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => setState(
                                                        () => _editingId = null,
                                                      ),
                                                      child: Text(
                                                          t('common.cancel')),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (!mine && !deleted)
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF78716C),
                                                    ),
                                                  ),
                                                if (deleted)
                                                  Text(
                                                    t('chat.messageDeleted'),
                                                    style: TextStyle(
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      color: mine
                                                          ? Colors.white70
                                                          : const Color(
                                                              0xFF78716C,
                                                            ),
                                                    ),
                                                  )
                                                else ...[
                                                  if (photo != null &&
                                                      photo.trim().isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                        bottom: 6,
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          10,
                                                        ),
                                                        child: Image.network(
                                                          photo.trim(),
                                                          height: 180,
                                                          width:
                                                              double.infinity,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                  if (body.isNotEmpty)
                                                    Text(
                                                      body,
                                                      style: TextStyle(
                                                        color: mine
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF1C1917,
                                                              ),
                                                      ),
                                                    ),
                                                ],
                                                if (createdAt != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      top: 4,
                                                    ),
                                                    child: Text(
                                                      _timeAgo(createdAt),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: mine && !deleted
                                                            ? Colors.white70
                                                            : const Color(
                                                                0xFFA8A29E,
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                8 + systemBottomInset(context),
              ),
              child: Column(
                children: [
                  if (_pendingImage != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _pendingImage!,
                              height: 72,
                              width: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: -4,
                            top: -4,
                            child: IconButton(
                              onPressed: () =>
                                  setState(() => _pendingImage = null),
                              icon: const Icon(Icons.cancel, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _uploading || _sending ? null : _pickImage,
                        icon: _uploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_outlined),
                        color: const Color(0xFFB45309),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _draft,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: t('chat.placeholder'),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending || _uploading ? null : _send,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFB45309),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.send),
                      ),
                    ],
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

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    super.key,
    required this.apiService,
    this.isDelivery = false,
    this.myUserId,
  });

  final ApiService apiService;
  final bool isDelivery;
  final int? myUserId;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll =
        Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String _preview(Map<String, dynamic> item, String Function(String) t) {
    final type = item['lastMessageType'] as String?;
    final last = item['lastMessage'] as String?;
    if (type == 'deleted') return t('chat.messageDeleted');
    if (type == 'image' && (last == null || last.isEmpty)) {
      return t('chat.photo');
    }
    if (type == 'image' && last != null) return '📷 $last';
    return last ?? t('chat.startChat');
  }

  Future<void> _load({bool silent = false}) async {
    try {
      if (widget.isDelivery && widget.myUserId != null) {
        final data = await widget.apiService.fetchConversations();
        final list = ((data['conversations'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (!mounted) return;
        setState(() {
          _items = list.isNotEmpty
              ? list
              : [
                  {
                    'deliveryGuyId': widget.myUserId,
                    'deliveryGuyName': 'Admin',
                    'deliveryGuyImageUrl': null,
                    'deliveryGuyPhone': null,
                    'lastMessage': null,
                    'unreadCount': 0,
                  },
                ];
          _loading = false;
        });
        return;
      }

      final results = await Future.wait([
        widget.apiService.fetchConversations(),
        widget.apiService.fetchDeliveryPartners(),
      ]);
      final data = results[0] as Map<String, dynamic>;
      final guys = results[1] as List;
      final list = ((data['conversations'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final byId = <int, Map<String, dynamic>>{
        for (final item in list) item['deliveryGuyId'] as int: item,
      };
      for (final guy in guys) {
        final partner = guy as dynamic;
        final id = partner.id as int;
        if (!byId.containsKey(id) && partner.isActive == true) {
          byId[id] = {
            'deliveryGuyId': id,
            'deliveryGuyName': partner.name,
            'deliveryGuyImageUrl': partner.imageUrl,
            'deliveryGuyPhone': partner.phone,
            'lastMessage': null,
            'unreadCount': 0,
          };
        }
      }
      final merged = byId.values.toList()
        ..sort((a, b) {
          final at = a['lastMessageAt'] as String?;
          final bt = b['lastMessageAt'] as String?;
          if (at == null && bt == null) {
            return (a['deliveryGuyName'] as String)
                .compareTo(b['deliveryGuyName'] as String);
          }
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
      if (!mounted) return;
      setState(() {
        _items = merged;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          apiService: widget.apiService,
          deliveryGuyId: item['deliveryGuyId'] as int,
          title: item['deliveryGuyName'] as String? ?? 'Chat',
          imageUrl: item['deliveryGuyImageUrl'] as String?,
          phone: item['deliveryGuyPhone'] as String?,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;
    if (_loading) return const BakeryLoadingCenter();
    if (_items.isEmpty) {
      return Center(child: Text(t('chat.noPartners')));
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 24 + systemBottomInset(context)),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        final name = item['deliveryGuyName'] as String? ?? '';
        final unread = (item['unreadCount'] as num?)?.toInt() ?? 0;
        final imageUrl = item['deliveryGuyImageUrl'] as String?;
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFDE68A)),
          ),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFFDE68A),
            backgroundImage: imageUrl != null && imageUrl.trim().isNotEmpty
                ? NetworkImage(imageUrl.trim())
                : null,
            child: imageUrl == null || imageUrl.trim().isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            _preview(item, t),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: unread > 0
              ? CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFFB45309),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                )
              : const Icon(Icons.chevron_right),
          onTap: () => _open(item),
        );
      },
    );
  }
}
