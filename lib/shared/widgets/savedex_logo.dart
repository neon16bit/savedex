import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

class SavedexLogo extends StatelessWidget {
  final double size;
  final bool filled;
  final Color? color;

  const SavedexLogo({
    super.key,
    this.size = 24,
    this.filled = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    return SvgPicture.asset(
      filled
          ? 'assets/icons/savedex_icon_filled.svg'
          : 'assets/icons/savedex_icon.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
    );
  }
}
