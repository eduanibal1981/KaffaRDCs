import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/l10n/l10n_extensions.dart';
import '../../core/offline/sync_service.dart';
import '../../core/widgets/common.dart';
import '../../data/models/center.dart';
import '../../data/repositories/center_repository.dart';
import 'center_registry_controller.dart';

Future<void> showCenterEditor(BuildContext context, RenalCenter? center) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => CenterEditorSheet(center: center));

class CenterEditorSheet extends ConsumerStatefulWidget {
  const CenterEditorSheet({super.key, this.center});
  final RenalCenter? center;
  @override
  ConsumerState<CenterEditorSheet> createState() => _CenterEditorSheetState();
}

class _CenterEditorSheetState extends ConsumerState<CenterEditorSheet> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  late String _id = widget.center?.id ?? const Uuid().v4();
  late int _version = widget.center?.rowVersion ?? 0;
  bool _busy = false;
  bool _loading = true;
  bool _conflict = false;
  String? _error;
  String? _codeError;
  Map<String, dynamic>? _serverCopy;
  static const _names = [
    'code',
    'name_en',
    'name_ar',
    'wilayat_en',
    'wilayat_ar',
    'governorate_en',
    'governorate_ar',
    'contact_email',
    'contact_phone',
    'registered_patients',
    'dialysis_beds'
  ];
  @override
  void initState() {
    super.initState();
    final c = widget.center;
    final initial = <String, dynamic>{
      ...?c?.toUpdateMap(),
      'code': c?.code,
      'governorate_en': c?.governorateEn,
      'governorate_ar': c?.governorateAr
    };
    for (final key in _names) {
      _fields[key] =
          TextEditingController(text: initial[key]?.toString() ?? '');
    }
    _restore();
  }

  Future<void> _restore() async {
    final repo = ref.read(centerRepositoryProvider);
    if (widget.center == null) {
      final pending = await repo.newDraft();
      if (pending?['id'] is String) _id = pending!['id'];
    }
    final draft = await repo.draft(_id);
    if (!mounted) return;
    if (draft != null) {
      for (final key in _names) {
        _fields[key]!.text = draft[key]?.toString() ?? '';
      }
    }
    setState(() => _loading = false);
  }

  Map<String, dynamic> _payload() => {
        for (final key in _names)
          key: ['registered_patients', 'dialysis_beds'].contains(key)
              ? int.tryParse(_fields[key]!.text.trim())
              : (_fields[key]!.text.trim().isEmpty
                  ? null
                  : _fields[key]!.text.trim())
      };
  void _persist() {
    ref.read(centerRepositoryProvider).saveDraft(_id, _payload());
    if (widget.center == null) {
      ref.read(centerRepositoryProvider).saveNewDraft(_id, _payload());
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _codeError = null;
    });
    try {
      final confirmed = await ref.read(centerRepositoryProvider).save(
          _id, _version, _payload(), ref.read(syncServiceProvider.notifier));
      if (widget.center == null) {
        await ref.read(centerRepositoryProvider).clearNewDraft();
      }
      ref.invalidate(centerRegistryProvider);
      ref.invalidate(centersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(confirmed
              ? context.l10n.actionSave
              : context.l10n.syncSavedOnDevice)));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final text = e.toString();
      setState(() {
        _conflict = text.contains('KAFAA_CONFLICT');
        if (text.contains('duplicate') || text.contains('23505')) {
          _codeError = context.l10n.centerCodeInUse;
        } else {
          _error =
              _conflict ? context.l10n.syncConflict : describeError(context, e);
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    try {
      final current = await ref.read(centerRepositoryProvider).byId(_id);
      if (!mounted || current == null) return;
      setState(() {
        _serverCopy = {
          ...current.toUpdateMap(),
          'code': current.code,
          'governorate_en': current.governorateEn,
          'governorate_ar': current.governorateAr
        };
        _version = current.rowVersion;
        _conflict = false;
        _error =
            '${current.code} · ${context.pick(current.nameEn, current.nameAr)} · ${current.registeredPatients ?? '—'} / ${current.dialysisBeds ?? '—'}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = describeError(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [
      l.centerCode,
      l.centerNameEn,
      l.centerNameAr,
      '${l.centerWilayat} (English)',
      '${l.centerWilayat} (العربية)',
      '${l.centerGovernorate} (English)',
      '${l.centerGovernorate} (العربية)',
      l.centerEmail,
      l.centerPhone,
      l.centrePatients,
      l.centreBeds
    ];
    return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _loading
            ? const SizedBox(height: 120, child: LoadingView())
            : Form(
                key: _form,
                child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(widget.center == null ? l.centerAdd : l.centerEdit,
                          style: Theme.of(context).textTheme.titleLarge),
                      for (var i = 0; i < _names.length; i++)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextFormField(
                                controller: _fields[_names[i]],
                                enabled: !_busy,
                                decoration: InputDecoration(
                                    labelText: labels[i],
                                    errorText: i == 0 ? _codeError : null),
                                textDirection: _names[i].endsWith('_ar')
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                hintLocales: [
                                  Locale(
                                      _names[i].endsWith('_ar') ? 'ar' : 'en')
                                ],
                                keyboardType: i >= 9
                                    ? TextInputType.number
                                    : i == 7
                                        ? TextInputType.emailAddress
                                        : TextInputType.text,
                                onChanged: (_) {
                                  if (i == 0 && _codeError != null) {
                                    setState(() => _codeError = null);
                                  }
                                  _persist();
                                },
                                validator: (value) {
                                  if (i < 3 && (value ?? '').trim().isEmpty) {
                                    return l.validationRequired;
                                  }
                                  if (i >= 9 &&
                                      (value ?? '').isNotEmpty &&
                                      (int.tryParse(value!) == null ||
                                          int.parse(value) < 0)) {
                                    return l.validationNonnegative;
                                  }
                                  return null;
                                })),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(_error!)),
                      if (_serverCopy != null)
                        KafaaCard(
                            title: l.reviewVersion,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var i = 0; i < _names.length; i++)
                                    if ((_serverCopy![_names[i]]?.toString() ??
                                            '') !=
                                        _fields[_names[i]]!.text.trim())
                                      Text(
                                          '${labels[i]}: ${_serverCopy![_names[i]] ?? '—'} → ${_fields[_names[i]]!.text}'),
                                ])),
                      if (_conflict)
                        OutlinedButton(
                            onPressed: _busy ? null : _reload,
                            child: Text(l.actionRefresh)),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _busy || _conflict ? null : _save,
                          child: Text(l.actionSave)),
                      TextButton(
                          onPressed:
                              _busy ? null : () => Navigator.pop(context),
                          child: Text(l.actionCancel)),
                    ])));
  }
}
