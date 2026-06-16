import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';

class AudioMessageBubble extends StatefulWidget {
  const AudioMessageBubble({
    required this.path,
    required this.isUser,
    super.key,
  });

  final String path;
  final bool isUser;

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final player = PlayerController();

  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await player.preparePlayer(
      path: widget.path,
      shouldExtractWaveform: true,
      noOfSamples: 80,
    );

    duration = Duration(milliseconds: player.maxDuration);

    setState(() {});
  }

  Future<void> _togglePlay() async {
    if (isPlaying) {
      await player.pausePlayer();
    } else {
      await player.startPlayer();
    }

    setState(() {
      isPlaying = !isPlaying;
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;

    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isUser ? Colors.white : Colors.blue;

    return SizedBox(
      width: 250,
      child: Row(
        children: [
          InkWell(
            onTap: _togglePlay,
            borderRadius: BorderRadius.circular(50),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(.15),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: color,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: AudioFileWaveforms(
              size: const Size(double.infinity, 42),
              playerController: player,
              waveformType: WaveformType.fitWidth,
              playerWaveStyle: PlayerWaveStyle(
                fixedWaveColor: color.withOpacity(.35),
                liveWaveColor: color,
                spacing: 4,
                waveThickness: 2,
                seekLineColor: Colors.transparent,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Text(
            _format(duration),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
