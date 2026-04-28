import 'package:flutter/material.dart';

import '../core/models/policy_model.dart' as policy;
import '../core/theme.dart';

class DynamicFormFieldWidget extends StatelessWidget {
  final policy.FormField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final bool readOnly;

  const DynamicFormFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(),
          const SizedBox(height: 6),
          _buildControl(context),
        ],
      ),
    );
  }

  Widget _label() {
    return RichText(
      text: TextSpan(
        text: field.label.isEmpty ? field.key : field.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        children: [
          if (field.required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.danger),
            ),
        ],
      ),
    );
  }

  Widget _buildControl(BuildContext context) {
    switch (field.fieldType) {
      case 'booleano':
        return _BoolField(
          value: value == true,
          readOnly: readOnly,
          onChanged: onChanged,
        );
      case 'numero':
        return _TextLikeField(
          initialValue: value?.toString() ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          readOnly: readOnly,
          onChanged: (v) => onChanged(num.tryParse(v) ?? v),
        );
      case 'fecha':
        return _DateField(
          value: value?.toString(),
          readOnly: readOnly,
          onChanged: onChanged,
        );
      case 'lista':
      case 'select':
        return _SelectField(
          options: field.options,
          value: value?.toString(),
          readOnly: readOnly,
          onChanged: onChanged,
        );
      case 'archivo':
      case 'imagen':
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.muted, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Adjunta este recurso desde la sección de Evidencias.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      case 'texto':
      default:
        return _TextLikeField(
          initialValue: value?.toString() ?? '',
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: 4,
          readOnly: readOnly,
          onChanged: onChanged,
        );
    }
  }
}

class _TextLikeField extends StatefulWidget {
  final String initialValue;
  final TextInputType keyboardType;
  final int minLines;
  final int maxLines;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  const _TextLikeField({
    required this.initialValue,
    required this.keyboardType,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.readOnly = false,
  });

  @override
  State<_TextLikeField> createState() => _TextLikeFieldState();
}

class _TextLikeFieldState extends State<_TextLikeField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      readOnly: widget.readOnly,
      keyboardType: widget.keyboardType,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      onChanged: widget.onChanged,
    );
  }
}

class _BoolField extends StatelessWidget {
  final bool value;
  final bool readOnly;
  final ValueChanged<bool> onChanged;

  const _BoolField({
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value ? 'Sí' : 'No',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: readOnly ? null : onChanged,
          ),
        ],
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  final List<String> options;
  final String? value;
  final bool readOnly;
  final ValueChanged<String?> onChanged;

  const _SelectField({
    required this.options,
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return _TextLikeField(
        initialValue: value ?? '',
        keyboardType: TextInputType.text,
        readOnly: readOnly,
        onChanged: onChanged,
      );
    }
    final current = options.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: current,
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      items: options
          .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
          .toList(),
      onChanged: readOnly ? null : onChanged,
    );
  }
}

class _DateField extends StatefulWidget {
  final String? value;
  final bool readOnly;
  final ValueChanged<String?> onChanged;

  const _DateField({
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_ctrl.text) ?? now;
    final res = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (res != null) {
      final iso = res.toIso8601String().split('T').first;
      _ctrl.text = iso;
      widget.onChanged(iso);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      readOnly: true,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        suffixIcon: IconButton(
          icon: const Icon(Icons.event, color: AppColors.muted),
          onPressed: widget.readOnly ? null : _pick,
        ),
      ),
      onTap: widget.readOnly ? null : _pick,
    );
  }
}
