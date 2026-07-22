import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Compact − / typed qty / + control, clamped to [0, max].
class QtyStepper extends StatefulWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 999999,
    this.enabled = true,
    this.onExceedMax,
  });

  final int value;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final VoidCallback? onExceedMax;

  @override
  State<QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends State<QtyStepper> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant QtyStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _commit(_controller.text);
    }
  }

  int _clamp(int value) {
    if (value < 0) return 0;
    if (value > widget.max) return widget.max;
    return value;
  }

  void _commit(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) {
      _controller.text = '${widget.value}';
      return;
    }

    if (parsed > widget.max) {
      widget.onExceedMax?.call();
    }

    final next = _clamp(parsed);
    _controller.text = '$next';
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }

  void _set(int next) {
    final clamped = _clamp(next);
    if (next > widget.max) {
      widget.onExceedMax?.call();
    }
    _controller.text = '$clamped';
    if (clamped != widget.value) {
      widget.onChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDec = widget.enabled && widget.value > 0;
    final canInc = widget.enabled && widget.value < widget.max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: canDec ? () => _set(widget.value - 1) : null,
          icon: const Icon(Icons.remove),
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(
          width: 48,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled && widget.max > 0,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              border: OutlineInputBorder(),
            ),
            onSubmitted: _commit,
            onChanged: (raw) {
              if (raw.isEmpty) return;
              final parsed = int.tryParse(raw);
              if (parsed == null) return;
              if (parsed > widget.max) {
                widget.onExceedMax?.call();
                final clamped = widget.max;
                _controller.value = TextEditingValue(
                  text: '$clamped',
                  selection: TextSelection.collapsed(
                    offset: '$clamped'.length,
                  ),
                );
                if (clamped != widget.value) {
                  widget.onChanged(clamped);
                }
              } else if (parsed != widget.value) {
                widget.onChanged(parsed);
              }
            },
          ),
        ),
        IconButton(
          onPressed: canInc ? () => _set(widget.value + 1) : null,
          icon: const Icon(Icons.add),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
