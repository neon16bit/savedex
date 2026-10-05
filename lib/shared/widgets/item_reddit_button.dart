import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:savedex/features/detail/widgets/detail_utils.dart';

class RedditIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const RedditIcon({super.key, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SvgPicture.asset(
      'assets/icons/reddit.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        BlendMode.srcIn,
      ),
    );
  }
}

class ItemRedditButton extends StatelessWidget {
  final String permalink;
  final double size;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const ItemRedditButton({
    super.key,
    required this.permalink,
    this.size = 18,
    this.padding = const EdgeInsets.all(5),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Open in Reddit',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () => openRedditUrl(context, permalink),
          child: Padding(
            padding: padding,
            child: RedditIcon(size: size, color: color),
          ),
        ),
      ),
    );
  }
}
