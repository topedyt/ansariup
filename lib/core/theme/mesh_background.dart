import 'package:flutter/material.dart';
import 'app_theme.dart';

class MeshBackground extends StatelessWidget {
  final AppTheme theme;
  final Widget child;

  const MeshBackground({
    super.key, 
    required this.theme, 
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    final color1 = theme.bgGradient.first;
    // Use the middle color if available, else blend first/last
    final cloudColor1 = theme.bgGradient.length > 1 ? theme.bgGradient[1] : Color.lerp(color1, theme.bgGradient.last, 0.5)!;
    final cloudColor2 = theme.bgGradient.last;

    return Stack(
      children: [
        // 1. Solid Base Layer
        Container(color: color1),

        // 2. Cloud 1 (Top Left - Drifting down)
        Positioned(
          top: -200,
          left: -100,
          right: 0,
          child: Container(
            height: 600,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5, // Stretched radius for softer edge
                colors: [
                  cloudColor1.withOpacity(0.4), // Soft, similar color
                  Colors.transparent
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
        ),

        // 3. Cloud 2 (Bottom Right - Drifting up)
        Positioned(
          bottom: -300,
          right: -200,
          left: 100,
          child: Container(
            height: 800,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomRight,
                radius: 1.8, // Highly stretched
                colors: [
                  cloudColor2.withOpacity(0.5), // Deeper similar color
                  Colors.transparent
                ],
                 stops: const [0.0, 0.8],
              ),
            ),
          ),
        ),
        
        // 4. Cloud 3 (Center Accent - Very subtle)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.3,
          left: -200,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  theme.accentColor.withOpacity(0.08), // Very faint accent color
                  Colors.transparent
                ],
              ),
            ),
          ),
        ),

        // 5. The Content
        child,
      ],
    );
  }
}