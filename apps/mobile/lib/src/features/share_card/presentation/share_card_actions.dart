import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/share_card.dart';
import 'share_card_cubit.dart';

class ShareCardActions extends StatelessWidget {
  const ShareCardActions({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ShareCardCubit, ShareCardState>(
    builder: (context, state) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final format in ShareCardFormat.values)
              Builder(
                builder: (button) => OutlinedButton.icon(
                  onPressed: state.busy
                      ? null
                      : () {
                          final box = button.findRenderObject() as RenderBox?;
                          if (box == null || !box.hasSize) return;
                          context.read<ShareCardCubit>().share(
                            format,
                            box.localToGlobal(Offset.zero) & box.size,
                          );
                        },
                  icon: Icon(
                    format == ShareCardFormat.story
                        ? Icons.ios_share
                        : Icons.crop_square,
                  ),
                  label: Text(
                    format == ShareCardFormat.story
                        ? 'Share to Instagram Story'
                        : 'Square post image',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Choose Instagram in the share sheet if available. You decide where to send the image.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (state.busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(
              semanticsLabel: 'Preparing share image',
            ),
          ),
        if (state.error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (state.notice != null)
          Semantics(liveRegion: true, child: Text(state.notice!)),
      ],
    ),
  );
}
