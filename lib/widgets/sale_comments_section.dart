import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../services/api_service.dart';

class SaleCommentsSection extends StatefulWidget {
  const SaleCommentsSection({
    super.key,
    required this.apiService,
    required this.saleId,
  });

  final ApiService apiService;
  final int saleId;

  @override
  State<SaleCommentsSection> createState() => _SaleCommentsSectionState();
}

class _SaleCommentsSectionState extends State<SaleCommentsSection> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _saving = false;
  final _draft = TextEditingController();
  int? _replyToId;
  String? _replyToName;
  int? _editingId;
  final _editDraft = TextEditingController();
  int _visibleCount = 10;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll =
        Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _draft.dispose();
    _editDraft.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final data = await widget.apiService.fetchSaleComments(widget.saleId);
      if (!mounted) return;
      setState(() {
        _comments = data;
        if (!silent) _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) setState(() => _loading = false);
    }
  }

  Future<void> _post() async {
    final body = _draft.text.trim();
    if (body.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final next = await widget.apiService.createSaleComment(
        widget.saleId,
        body: body,
        parentId: _replyToId,
      );
      if (!mounted) return;
      setState(() {
        _comments = next;
        _draft.clear();
        _replyToId = null;
        _replyToName = null;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _saveEdit(int id) async {
    final body = _editDraft.text.trim();
    if (body.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final next = await widget.apiService.updateSaleComment(id, body: body);
      if (!mounted) return;
      setState(() {
        _comments = next;
        _editingId = null;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
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
        title: Text(t('comments.deleteConfirm')),
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
    setState(() => _saving = true);
    try {
      final next = await widget.apiService.deleteSaleComment(id);
      if (!mounted) return;
      setState(() {
        _comments = next;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _showCommentActions(
    Map<String, dynamic> comment,
    String body,
  ) async {
    final canEdit = comment['canEdit'] == true;
    final canDelete = comment['canDelete'] == true;
    if (!canEdit && !canDelete) return;
    final t = LocaleScope.of(context).t;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
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
    final id = comment['id'] as int;
    if (action == 'edit') {
      setState(() {
        _editingId = id;
        _editDraft.text = body;
      });
    } else if (action == 'delete') {
      await _delete(id);
    }
  }

  Widget _avatar(String name, String? imageUrl, {double size = 40}) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl.trim(),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initial(name, size),
        ),
      );
    }
    return _initial(name, size);
  }

  Widget _initial(String name, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFFDE68A),
        shape: BoxShape.circle,
      ),
      child: Text(
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF92400E),
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  Widget _commentTile(Map<String, dynamic> comment, {bool reply = false}) {
    final t = LocaleScope.of(context).t;
    final id = comment['id'] as int;
    final name = comment['userName'] as String? ?? '';
    final body = comment['body'] as String? ?? '';
    final imageUrl = comment['userImageUrl'] as String?;
    final canEdit = comment['canEdit'] == true;
    final canDelete = comment['canDelete'] == true;
    final replies = ((comment['replies'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final editing = _editingId == id;

    return Padding(
      padding: EdgeInsets.only(left: reply ? 40 : 0, top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(name, imageUrl, size: reply ? 32 : 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: (canEdit || canDelete) && !editing
                      ? () => _showCommentActions(comment, body)
                      : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: editing
                        ? Column(
                            children: [
                              TextField(
                                controller: _editDraft,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => _saveEdit(id),
                                    child: Text(t('common.saveChanges')),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _editingId = null),
                                    child: Text(t('common.cancel')),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(body),
                            ],
                          ),
                  ),
                ),
                if (!editing)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Wrap(
                      spacing: 12,
                      children: [
                        if (!reply)
                          GestureDetector(
                            onTap: () => setState(() {
                              _replyToId = id;
                              _replyToName = name;
                            }),
                            child: Text(
                              t('comments.reply'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ...replies.map((r) => _commentTile(r, reply: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = LocaleScope.of(context).t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        Text(
          t('comments.title'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1917),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              t('comments.empty'),
              style: const TextStyle(color: Color(0xFF78716C)),
            ),
          )
        else
          ..._comments.take(_visibleCount).map(_commentTile),
        if (!_loading && _visibleCount < _comments.length)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton(
              onPressed: () => setState(() => _visibleCount += 10),
              child: Text(
                t(
                  'comments.loadMore',
                  {
                    'count': (_comments.length - _visibleCount).clamp(0, 10),
                  },
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (_replyToName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t('comments.replyingTo', {'name': _replyToName!}),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _replyToId = null;
                    _replyToName = null;
                  }),
                  child: Text(t('common.cancel')),
                ),
              ],
            ),
          ),
        TextField(
          controller: _draft,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: t('comments.placeholder'),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _saving ? null : _post,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
            ),
            child: Text(t('comments.post')),
          ),
        ),
      ],
    );
  }
}
