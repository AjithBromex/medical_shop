import 'dart:ui';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Core Glassmorphism container with backdrop blur, translucent fill,
/// subtle specular border highlight, and soft diffused shadows.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final Clip clipBehavior;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 0.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.padding,
    this.margin,
    this.gradient,
    this.color,
    this.border,
    this.boxShadow,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (gradient == null ? Colors.white : null),
        gradient: gradient,
        borderRadius: borderRadius,
        border: border ??
            Border.all(
              color: AppColors.border,
              width: 1.2,
            ),
        boxShadow: boxShadow ??
            const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
      ),
      child: child,
    );

    if (blur > 0) {
      content = ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}

/// A card widget with home page solid white 18px rounded styling.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double borderRadius;
  final Color? color;
  final Gradient? gradient;
  final BoxBorder? border;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.blur = 0.0,
    this.borderRadius = 18.0,
    this.color,
    this.gradient,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = GlassContainer(
      blur: blur,
      borderRadius: BorderRadius.circular(borderRadius),
      padding: padding,
      margin: margin,
      color: color,
      gradient: gradient,
      border: border,
      child: child,
    );

    if (onTap != null) {
      body = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: body,
      );
    }

    return body;
  }
}

/// Ambient glowing backdrop with smooth radial color spheres
/// to provide rich visual diffusion behind frosted glass panels.
class AmbientBackdrop extends StatelessWidget {
  final Widget child;
  final bool animate;

  const AmbientBackdrop({
    super.key,
    required this.child,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base light space canvas
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEDF2F7), // Cool Slate 100
                  Color(0xFFE2E8F0), // Cool Slate 200
                  Color(0xFFE5EBF2), // Slate Soft Blue
                ],
              ),
            ),
          ),
        ),

        // Ambient glowing orb 1: Cyan / Teal top-left
        Positioned(
          top: -120,
          left: -100,
          width: 500,
          height: 500,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.total.withValues(alpha: 0.12),
                  AppColors.total.withValues(alpha: 0.03),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // Ambient glowing orb 2: Indigo / Violet top-right
        Positioned(
          top: 100,
          right: -150,
          width: 550,
          height: 550,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.remaining.withValues(alpha: 0.10),
                  AppColors.remaining.withValues(alpha: 0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Ambient glowing orb 3: Emerald bottom-left
        Positioned(
          bottom: -100,
          left: 150,
          width: 480,
          height: 480,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.cash.withValues(alpha: 0.10),
                  AppColors.cash.withValues(alpha: 0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Foreground content sitting on top of the glowing mesh
        Positioned.fill(child: child),
      ],
    );
  }
}

/// A glowing glass pill button
class GlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final bool isPrimary;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.accentColor,
    this.padding,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? (isPrimary ? AppColors.total : AppColors.textPrimary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: isPrimary ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary ? color : AppColors.border,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
              ],
              DefaultTextStyle(
                style: TextStyle(
                  color: isPrimary ? color : const Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
