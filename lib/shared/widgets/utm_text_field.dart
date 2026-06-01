import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class UtmTextField extends StatelessWidget {
  const UtmTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.isRequired = true,
    this.icon,
    this.autofillHints,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final bool isRequired;
  final IconData? icon;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return TextFormField(
      controller: controller,
      style: TextStyle(color: colors.textPrimary),
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      validator:
          validator ??
          (value) {
            if (!isRequired) {
              return null;
            }

            if (value == null || value.trim().isEmpty) {
              return '$label is required';
            }

            return null;
          },
    );
  }
}
