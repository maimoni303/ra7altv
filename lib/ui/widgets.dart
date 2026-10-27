import 'package:flutter/material.dart';

import '../theme.dart';

/// RA7AlTV mark: royal-blue tile, white play triangle, turquoise signal arc.
class Ra7alLogo extends StatelessWidget {
  final double size;
  const Ra7alLogo({super.key, this.size = 38});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(size * 0.29)),
      child: CustomPaint(painter: _LogoPainter(Ra7al.dark.accent)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color arc;
  _LogoPainter(this.arc);
  @override
  void paint(Canvas canvas, Size s) {
    final u = s.width / 24;
    final tri = Path()
      ..moveTo(10 * u, 7.5 * u)
      ..lineTo(10 * u, 16.5 * u)
      ..lineTo(17 * u, 12 * u)
      ..close();
    canvas.drawPath(tri, Paint()..color = Colors.white);
    final p = Paint()
      ..color = arc
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * u
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(11.5 * u, 12 * u), radius: 5 * u), 2.4, 1.48, false, p);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.arc != arc;
}

class BrandTitle extends StatelessWidget {
  final double size;
  const BrandTitle({super.key, this.size = 22});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Ra7alLogo(size: size * 1.7),
        const SizedBox(width: 10),
        Text('RA7AlTV', style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: context.c.text)),
      ]);
}

/// Network image with a calm placeholder and safe failure.
class NetImage extends StatelessWidget {
  final String url;
  final double? width, height;
  final BoxFit fit;
  final double radius;
  final IconData icon;
  const NetImage(this.url,
      {super.key, this.width, this.height, this.fit = BoxFit.cover, this.radius = 10, this.icon = Icons.tv_rounded});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ph = Container(
      width: width,
      height: height,
      color: c.placeholder,
      alignment: Alignment.center,
      child: Icon(icon, color: c.faint, size: 22),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? ph
          : Image.network(
              url,
              width: width,
              height: height,
              fit: fit,
              cacheWidth: width != null && width!.isFinite ? (width! * 2).round() : 400,
              errorBuilder: (_, __, ___) => ph,
              loadingBuilder: (_, child, p) => p == null ? child : ph,
            ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: context.c.faint),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.c.muted, fontSize: 15)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  const PrimaryButton({super.key, required this.label, this.icon, this.onPressed, this.busy = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      child: busy
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onAccent))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Text(label),
            ]),
    );
  }
}

class SoftButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  const SoftButton({super.key, required this.label, this.icon, this.onPressed});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: c.active,
        foregroundColor: c.text,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Chip-style category selector (horizontal).
class CategoryChips extends StatelessWidget {
  final List<MapEntry<String, String>> items; // id -> name
  final String selected;
  final ValueChanged<String> onSelect;
  const CategoryChips({super.key, required this.items, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final e = items[i];
          final on = e.key == selected;
          return ChoiceChip(
            label: Text(e.value),
            selected: on,
            showCheckmark: false,
            onSelected: (_) => onSelect(e.key),
            backgroundColor: Colors.transparent,
            selectedColor: c.text,
            labelStyle: TextStyle(color: on ? c.bg : c.muted, fontWeight: on ? FontWeight.w600 : FontWeight.w500),
            side: BorderSide(color: on ? c.text : c.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }
}

String fmtTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String fmtDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '$m:${s.toString().padLeft(2, '0')}';
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
}
