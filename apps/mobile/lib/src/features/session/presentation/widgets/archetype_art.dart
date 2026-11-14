import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Decoration for an already-saved launch archetype, never a new match.
class ArchetypeArt extends StatelessWidget {
  const ArchetypeArt({required this.name, super.key});
  final String name;
  static const _assets = {
    'anthemist': 'assets/archetypes/anthemist.jpg',
    'atmospherist': 'assets/archetypes/atmospherist.jpg',
    'hedonist': 'assets/archetypes/hedonist.jpg',
    'romantic': 'assets/archetypes/romantic.jpg',
    'transformer': 'assets/archetypes/transformer.jpg',
    'witness': 'assets/archetypes/witness.jpg',
  };

  @override
  Widget build(BuildContext context) {
    final key = name.trim().toLowerCase().replaceFirst(RegExp(r'^the\s+'), '');
    final asset = _assets[key];
    if (asset == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image.asset(
              asset,
              width: 384,
              fit: BoxFit.contain,
              semanticLabel: 'Ink illustration for $name',
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
