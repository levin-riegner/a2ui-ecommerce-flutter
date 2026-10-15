import 'package:flutter/material.dart';

import 'occasion_artwork.dart';

/// Three staggered columns of original, locally drawn occasion artwork.
class FinalizedOccasionCollage extends StatelessWidget {
  const FinalizedOccasionCollage({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final width = constraints.hasBoundedWidth ? constraints.maxWidth : 392.0;
      final height = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : width * 669 / 392;
      final columnWidth = (width - 8) / 2.4;
      const columns = [
        [1, 2, 3],
        [4, 5, 6, 7],
        [8, 9, 10],
      ];
      return SizedBox(
        width: width,
        height: height,
        child: ClipRect(
          child: Stack(
            children: [
              for (var column = 0; column < columns.length; column++)
                Positioned(
                  left: column * (columnWidth + 4),
                  top: 0,
                  bottom: 0,
                  width: columnWidth,
                  child: OverflowBox(
                    maxHeight: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (
                          var row = 0;
                          row < columns[column].length;
                          row++
                        ) ...[
                          if (row > 0) const SizedBox(height: 4),
                          OccasionArtwork(
                            seed: columns[column][row],
                            width: columnWidth,
                            height: columnWidth * 4 / 3,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
