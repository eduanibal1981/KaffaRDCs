import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extensions.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/theme/kafaa_colors.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/common.dart';
import '../../data/models/operations.dart';
import '../../data/models/primitives.dart';
import '../../data/repositories/operations_repository.dart';

/// Anonymous patient survey, reached by QR code or run in kiosk mode.
///
/// No name, no ID, no clinical detail. The only identifier is a salted
/// device hash used to stop one tablet answering fifty times, and it
/// cannot be linked back to a person.
class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key, required this.centerId, this.kiosk = false});

  final String centerId;
  final bool kiosk;

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

enum _Stage { language, consent, questions, thanks, duplicate }

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  _Stage _stage = _Stage.language;
  String _locale = 'ar';
  int _index = 0;
  final Map<String, num> _values = {};
  final Map<String, String> _texts = {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(surveyFormProvider);

    // The survey renders in the patient's chosen language regardless of
    // the device or the staff member's app setting.
    return Directionality(
      textDirection: _locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Localizations.override(
        context: context,
        locale: Locale(_locale),
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: SafeArea(
              child: AsyncView(
                value: form,
                onRetry: () => ref.invalidate(surveyFormProvider),
                builder: (f) => _buildStage(context, f),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(BuildContext context, SurveyForm form) {
    return switch (_stage) {
      _Stage.language => _LanguageStage(
          onPick: (code) => setState(() {
            _locale = code;
            _stage = form.requiresConsent ? _Stage.consent : _Stage.questions;
          }),
        ),
      _Stage.consent => _ConsentStage(
          form: form,
          locale: _locale,
          onAgree: () => setState(() => _stage = _Stage.questions),
          onDecline: () => setState(() => _stage = _Stage.language),
        ),
      _Stage.questions => _QuestionStage(
          form: form,
          locale: _locale,
          index: _index,
          value: _values[form.questions[_index].code],
          text: _texts[form.questions[_index].code],
          busy: _busy,
          onValue: (v) =>
              setState(() => _values[form.questions[_index].code] = v),
          onText: (t) =>
              setState(() => _texts[form.questions[_index].code] = t),
          onBack: _index == 0 ? null : () => setState(() => _index--),
          onNext: () => _next(form),
        ),
      _Stage.thanks => _ThanksStage(
          form: form,
          locale: _locale,
          kiosk: widget.kiosk,
          onRestart: _restart,
        ),
      _Stage.duplicate => _DuplicateStage(
          locale: _locale,
          kiosk: widget.kiosk,
          onRestart: _restart,
        ),
    };
  }

  void _restart() => setState(() {
        _values.clear();
        _texts.clear();
        _index = 0;
        _stage = _Stage.language;
      });

  Future<void> _next(SurveyForm form) async {
    if (_index < form.questions.length - 1) {
      setState(() => _index++);
      return;
    }
    await _submit(form);
  }

  Future<void> _submit(SurveyForm form) async {
    setState(() => _busy = true);
    try {
      final answers = [
        for (final q in form.questions)
          if (_values.containsKey(q.code) || _texts.containsKey(q.code))
            {
              'question_code': q.code,
              if (_values.containsKey(q.code)) 'value': _values[q.code],
              if ((_texts[q.code] ?? '').isNotEmpty) 'text': _texts[q.code],
            },
      ];

      final result = await ref.read(surveyRepositoryProvider).submit(
            formCode: form.code,
            centerId: widget.centerId,
            locale: _locale,
            answers: answers,
            deviceHash: await _deviceHash(),
            source: widget.kiosk ? 'kiosk' : 'qr',
            kioskId: widget.kiosk ? 'kiosk' : null,
          );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = result.isDuplicate ? _Stage.duplicate : _Stage.thanks;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(context, e))),
      );
    }
  }

  /// A salted, one-way fingerprint. In kiosk mode a fresh salt is used per
  /// submission, because a shared tablet is meant to take many answers.
  Future<String> _deviceHash() async {
    if (widget.kiosk) {
      final nonce = '${DateTime.now().microsecondsSinceEpoch}'
          '${Random.secure().nextInt(1 << 32)}';
      return sha256.convert(utf8.encode(nonce)).toString();
    }

    final prefs = ref.read(appPreferencesProvider);
    var salt = prefs.kioskCenterId;
    if (salt == null || salt.isEmpty) {
      salt = '${DateTime.now().microsecondsSinceEpoch}'
          '${Random.secure().nextInt(1 << 32)}';
      await prefs.setKioskCenterId(salt);
    }
    return sha256
        .convert(utf8.encode('$salt|${widget.centerId}'))
        .toString();
  }
}

// ---------------------------------------------------------------------------

class _LanguageStage extends StatelessWidget {
  const _LanguageStage({required this.onPick});
  final void Function(String code) onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite,
                size: 56, color: KafaaColors.teal),
            const SizedBox(height: 24),
            Text(
              'اختر لغتك\nChoose your language',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 260,
              child: FilledButton(
                onPressed: () => onPick('ar'),
                child: const Text('العربية', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 260,
              child: OutlinedButton(
                onPressed: () => onPick('en'),
                child: const Text('English', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentStage extends StatelessWidget {
  const _ConsentStage({
    required this.form,
    required this.locale,
    required this.onAgree,
    required this.onDecline,
  });

  final SurveyForm form;
  final String locale;
  final VoidCallback onAgree;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.privacy_tip_outlined,
              size: 44, color: KafaaColors.brandBlue),
          const SizedBox(height: 20),
          Text(
            l10n.surveyConsentTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            pickForLocale(locale, form.consentTextEn, form.consentTextAr),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            pickForLocale(locale, form.introEn, form.introAr),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 36),
          FilledButton(
            onPressed: onAgree,
            child: Text(l10n.surveyConsentAgree),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onDecline, child: Text(l10n.actionBack)),
        ],
      ),
    );
  }
}

class _QuestionStage extends StatelessWidget {
  const _QuestionStage({
    required this.form,
    required this.locale,
    required this.index,
    required this.value,
    required this.text,
    required this.busy,
    required this.onValue,
    required this.onText,
    required this.onBack,
    required this.onNext,
  });

  final SurveyForm form;
  final String locale;
  final int index;
  final num? value;
  final String? text;
  final bool busy;
  final ValueChanged<num> onValue;
  final ValueChanged<String> onText;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = form.questions[index];
    final isLast = index == form.questions.length - 1;
    final answered = value != null || !q.isRequired;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (index + 1) / form.questions.length,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.surveyQuestionOf(index + 1, form.questions.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Text(
                  pickForLocale(locale, q.textEn, q.textAr),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (q.helpEn != null || q.helpAr != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    pickForLocale(locale, q.helpEn, q.helpAr),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 36),
                _AnswerInput(
                  question: q,
                  value: value,
                  text: text,
                  onValue: onValue,
                  onText: onText,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                if (onBack != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onBack,
                      child: Text(l10n.actionBack),
                    ),
                  ),
                if (onBack != null) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: busy || !answered ? null : onNext,
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isLast ? l10n.actionSubmit : l10n.actionNext),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnswerInput extends StatelessWidget {
  const _AnswerInput({
    required this.question,
    required this.value,
    required this.text,
    required this.onValue,
    required this.onText,
  });

  final SurveyQuestion question;
  final num? value;
  final String? text;
  final ValueChanged<num> onValue;
  final ValueChanged<String> onText;

  @override
  Widget build(BuildContext context) {
    switch (question.inputType) {
      case SurveyInputType.emoji5:
        return _EmojiScale(value: value?.toInt(), onChanged: onValue);

      case SurveyInputType.stars5:
        return _StarScale(value: value?.toInt(), onChanged: onValue);

      case SurveyInputType.yesNo:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final option in [(1, Icons.thumb_up), (0, Icons.thumb_down)])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: IconButton.filledTonal(
                  iconSize: 40,
                  onPressed: () => onValue(option.$1),
                  isSelected: value == option.$1,
                  icon: Icon(option.$2),
                ),
              ),
          ],
        );

      case SurveyInputType.nps10:
      case SurveyInputType.slider10:
        return Column(
          children: [
            Text(
              value == null ? '—' : '${value!.toInt()}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: KafaaColors.teal,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Slider(
              value: (value ?? 5).toDouble(),
              min: 0,
              max: question.maxValue,
              divisions: question.maxValue.toInt(),
              label: '${(value ?? 5).toInt()}',
              onChanged: (v) => onValue(v.round()),
            ),
          ],
        );

      case SurveyInputType.freeText:
        return TextField(
          maxLines: 5,
          minLines: 3,
          maxLength: 500,
          onChanged: onText,
          controller: TextEditingController(text: text)
            ..selection = TextSelection.collapsed(offset: (text ?? '').length),
          decoration: InputDecoration(
            hintText: context.l10n.surveyOptionalComment,
          ),
        );

      case SurveyInputType.singleChoice:
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 1; i <= question.maxValue.toInt(); i++)
              ChoiceChip(
                selected: value == i,
                label: Text('$i'),
                onSelected: (_) => onValue(i),
              ),
          ],
        );
    }
  }
}

class _EmojiScale extends StatelessWidget {
  const _EmojiScale({required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <({int score, IconData icon, Color color, String label})>[
      (score: 1, icon: Icons.sentiment_very_dissatisfied, color: KafaaColors.danger, label: l10n.surveyEmojiVeryBad),
      (score: 2, icon: Icons.sentiment_dissatisfied, color: const Color(0xFFEA580C), label: l10n.surveyEmojiBad),
      (score: 3, icon: Icons.sentiment_neutral, color: KafaaColors.warning, label: l10n.surveyEmojiOk),
      (score: 4, icon: Icons.sentiment_satisfied_alt, color: KafaaColors.teal, label: l10n.surveyEmojiGood),
      (score: 5, icon: Icons.sentiment_very_satisfied, color: KafaaColors.success, label: l10n.surveyEmojiVeryGood),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (final o in options)
          Semantics(
            selected: value == o.score,
            button: true,
            label: o.label,
            child: InkWell(
              onTap: () => onChanged(o.score),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 66,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: value == o.score
                      ? o.color.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: value == o.score
                        ? o.color
                        : Theme.of(context).dividerColor,
                    width: value == o.score ? 2.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(o.icon,
                        size: value == o.score ? 40 : 34, color: o.color),
                    const SizedBox(height: 6),
                    Text(
                      o.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StarScale extends StatelessWidget {
  const _StarScale({required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            iconSize: 44,
            onPressed: () => onChanged(i),
            icon: Icon(
              (value ?? 0) >= i ? Icons.star : Icons.star_border,
              color: KafaaColors.gold,
            ),
          ),
      ],
    );
  }
}

class _ThanksStage extends StatelessWidget {
  const _ThanksStage({
    required this.form,
    required this.locale,
    required this.kiosk,
    required this.onRestart,
  });

  final SurveyForm form;
  final String locale;
  final bool kiosk;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CelebrationOverlay(
      pieceCount: 30,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  size: 76, color: KafaaColors.success),
              const SizedBox(height: 24),
              Text(
                l10n.surveyThanks,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                pickForLocale(locale, form.thanksEn, form.thanksAr).isEmpty
                    ? l10n.surveyThanksBody
                    : pickForLocale(locale, form.thanksEn, form.thanksAr),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 40),
              if (kiosk)
                FilledButton(
                  onPressed: onRestart,
                  child: Text(l10n.surveyStart),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuplicateStage extends StatelessWidget {
  const _DuplicateStage({
    required this.locale,
    required this.kiosk,
    required this.onRestart,
  });

  final String locale;
  final bool kiosk;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.done_all, size: 66, color: KafaaColors.teal),
            const SizedBox(height: 20),
            Text(
              l10n.surveyAlreadySubmitted,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 30),
            if (kiosk)
              FilledButton(
                onPressed: onRestart,
                child: Text(l10n.surveyStart),
              ),
          ],
        ),
      ),
    );
  }
}
