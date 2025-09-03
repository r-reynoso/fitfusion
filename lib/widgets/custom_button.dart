import 'package:flutter/material.dart';

enum ButtonType { primary, secondary }

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final ButtonType type;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double height;

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.type = ButtonType.primary,
    this.padding,
    this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;
    Color disabledBackgroundColor;
    Color disabledForegroundColor;

    switch (type) {
      case ButtonType.primary:
        backgroundColor = Theme.of(context).colorScheme.primary;
        foregroundColor = Theme.of(context).colorScheme.onPrimary;
        disabledBackgroundColor = Theme.of(context).colorScheme.primary.withOpacity(0.5);
        disabledForegroundColor = Theme.of(context).colorScheme.onPrimary.withOpacity(0.5);
        break;
      case ButtonType.secondary:
        backgroundColor = Theme.of(context).colorScheme.secondary;
        foregroundColor = Theme.of(context).colorScheme.onSecondary;
        disabledBackgroundColor = Theme.of(context).colorScheme.secondary.withOpacity(0.5);
        disabledForegroundColor = Theme.of(context).colorScheme.onSecondary.withOpacity(0.5);
        break;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width ?? 0,
        maxWidth: width ?? double.infinity,
        minHeight: height,
        maxHeight: height,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            disabledBackgroundColor: disabledBackgroundColor,
            disabledForegroundColor: disabledForegroundColor,
            elevation: 0,
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: Size(0, height),
            maximumSize: Size(double.infinity, height),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                )
              : child,
        ),
      ),
    );
  }
}