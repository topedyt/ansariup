import 'package:flutter/material.dart';

class ClayContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  final double? width;
  final Color? color;
  final Color? parentColor;
  final double borderRadius;
  final double spread;
  final bool emboss; // TRUE = Input Field (Flat), FALSE = Card (Pop)
  final VoidCallback? onTap;

  const ClayContainer({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.color,
    this.parentColor,
    this.borderRadius = 20,
    this.spread = 6,
    this.emboss = false, 
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 1. COLORS
    Color bgColor;
    if (color != null) {
      bgColor = color!;
    } else {
      // Default colors if none provided
      if (emboss) {
        // Input: Slightly darker than background
        bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9); 
      } else {
        // Card: White or Dark Grey
        bgColor = isDark ? const Color(0xFF334155) : Colors.white;
      }
    }

    // 2. SHADOWS (Clean Drop Shadow, No Inner Glow)
    List<BoxShadow> shadows = [];
    if (!emboss) {
      shadows = [
        BoxShadow(
          // Soft, colored shadow based on theme mode
          color: isDark 
              ? Colors.black.withOpacity(0.4) 
              : const Color(0xFF64748B).withOpacity(0.15),
          offset: const Offset(0, 8), // Shadow drops down
          blurRadius: 16,             // Soft edge
          spreadRadius: -4,           // Tighter look
        ),
      ];
    }

    // 3. BORDER (Subtle outline for definition)
    BoxBorder border;
    if (emboss) {
      // Input: Solid border
      border = Border.all(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
        width: 1.5,
      );
    } else {
      // Card: Hairline border
      border = Border.all(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        width: 1,
      );
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: shadows,
            border: border,
          ),
          // Remove the complex padding logic that was breaking your layout
          child: child,
        ),
      ),
    );
  }
}
