import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class MessageLoading extends StatelessWidget {
  const MessageLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    return Align(
      alignment: Alignment.centerLeft, // Aligned like a chatbot response
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildShimmerLine(
              width: 200,
              base: baseColor,
              highlight: highlightColor,
            ),
            const SizedBox(height: 8),
            _buildShimmerLine(
              width: 140,
              base: baseColor,
              highlight: highlightColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLine({
    required double width,
    required Color base,
    required Color highlight,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 12,
        width: width,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
