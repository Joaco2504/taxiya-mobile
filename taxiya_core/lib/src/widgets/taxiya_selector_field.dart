import 'package:flutter/material.dart';

import '../theme/taxiya_theme.dart';

/// Opción individual para [TaxiyaSelectorField].
@immutable
class TaxiyaSelectorOption<T> {
  const TaxiyaSelectorOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
}

/// Selector modal estilizado con bordes definidos (1.5 px), sombra sutil,
/// superficie contrastada y transición suave mediante `showModalBottomSheet`.
class TaxiyaSelectorField<T> extends StatelessWidget {
  const TaxiyaSelectorField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hintText,
    this.sheetTitle,
    this.prefixIcon,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<TaxiyaSelectorOption<T>> options;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? sheetTitle;
  final IconData? prefixIcon;
  final FormFieldValidator<T>? validator;
  final bool enabled;

  TaxiyaSelectorOption<T>? _findSelected(T? val) {
    if (val == null) return null;
    for (final opt in options) {
      if (opt.value == val) return opt;
    }
    return null;
  }

  Future<void> _openSheet(
    BuildContext context,
    FormFieldState<T> field,
  ) async {
    FocusScope.of(context).unfocus();
    final semantic = context.taxiyaColors;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = field.value;

    final chosen = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.72;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Material(
              color: scheme.surface,
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: semantic.border, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxSheetHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: semantic.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              sheetTitle ?? label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Cerrar',
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: semantic.border),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(10),
                        itemCount: options.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (BuildContext _, int index) {
                          final opt = options[index];
                          final isSelected = opt.value == current;
                          return Material(
                            color: isSelected
                                ? scheme.primary.withValues(alpha: 0.14)
                                : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected
                                    ? scheme.primary
                                    : semantic.border.withValues(alpha: 0.65),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(ctx).pop(opt.value),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                child: Row(
                                  children: [
                                    if (opt.leading != null) ...[
                                      opt.leading!,
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            opt.label,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isSelected
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                          if (opt.subtitle != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              opt.subtitle!,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: semantic.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: scheme.primary,
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (chosen != null) {
      field.didChange(chosen);
      onChanged?.call(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.taxiyaColors;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (FormFieldState<T> field) {
        final effectiveValue = value ?? field.value;
        final selected = _findSelected(effectiveValue);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: field.hasError ? semantic.error : semantic.border,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: enabled && options.isNotEmpty
                      ? () => _openSheet(context, field)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        if (prefixIcon != null) ...[
                          Icon(
                            prefixIcon,
                            color: semantic.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: field.hasError
                                      ? semantic.error
                                      : semantic.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selected?.label ?? hintText ?? 'Seleccionar',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: selected != null
                                      ? scheme.onSurface
                                      : semantic.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: semantic.textSecondary,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (field.hasError && field.errorText != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  field.errorText!,
                  style: TextStyle(
                    fontSize: 12,
                    color: semantic.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
