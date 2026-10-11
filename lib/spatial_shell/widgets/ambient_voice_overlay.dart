// lib/spatial_shell/widgets/ambient_voice_overlay.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart'; // 👈 تم التصحيح
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AmbientVoiceOverlay extends StatelessWidget {
  const AmbientVoiceOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<AmbientVoiceCubit, AmbientVoiceState>(
      builder: (context, state) {
        if (!state.isOpen) return const SizedBox.shrink();

        final cubit = context.read<AmbientVoiceCubit>();
        final isError = state.status == AmbientVoiceStatus.error;

        final accentColor = isError
            ? colors.error
            : (state.isProcessing ? colors.secondary : colors.primary);

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          left: 16,
          right: 16,
          bottom: 24,
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              liveRegion: true,
              label: '${_getStatusLabel(state)}. ${_getContentText(state)}',
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: accentColor,
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.18),
                      blurRadius: 28,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _buildPulsingRadar(context, state),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getStatusLabel(state),
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getContentText(state),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            state.isListening
                                ? Icons.stop_circle_rounded
                                : Icons.close_rounded,
                            color: colors.onSurfaceVariant,
                            size: 26,
                          ),
                          tooltip:
                              state.isListening ? 'Done Speaking' : 'Dismiss',
                          onPressed: () {
                            if (state.isListening) {
                              cubit.stopAndExecute();
                            } else {
                              cubit.closeSession();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPulsingRadar(BuildContext context, AmbientVoiceState state) {
    final colors = context.colors;
    final normalizedLevel = (state.soundLevel.abs() / 10).clamp(0.2, 1.0);
    final isError = state.status == AmbientVoiceStatus.error;

    final accentColor = isError
        ? colors.error
        : (state.isProcessing ? colors.secondary : colors.primary);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(
          alpha: state.isListening ? (normalizedLevel * 0.4) : 0.15,
        ),
        border: Border.all(
          color: accentColor,
          width: 2,
        ),
      ),
      child: Center(
        child: Icon(
          isError
              ? Icons.error_outline_rounded
              : (state.isListening
                  ? Icons.mic_rounded
                  : (state.isProcessing
                      ? Icons.hourglass_top_rounded
                      : Icons.volume_up_rounded)),
          color: accentColor,
          size: 22,
        ),
      ),
    );
  }

  String _getStatusLabel(AmbientVoiceState state) {
    switch (state.status) {
      case AmbientVoiceStatus.listening:
        return 'BEACON AI • LISTENING...';
      case AmbientVoiceStatus.processing:
        return 'THINKING...';
      case AmbientVoiceStatus.speaking:
        return state.intent != null
            ? 'EXECUTED • ${state.intent}'
            : 'BEACON RESPONSE';
      case AmbientVoiceStatus.error:
        return state.errorMessage != null
            ? 'ERROR • ${state.errorMessage!.toUpperCase()}'
            : 'ERROR';
      case AmbientVoiceStatus.idle:
        return '';
    }
  }

  String _getContentText(AmbientVoiceState state) {
    if (state.isListening) {
      return state.liveTranscript.isEmpty
          ? 'Listening to your voice...'
          : '"${state.liveTranscript}"';
    }
    if (state.isProcessing) {
      return state.liveTranscript.isEmpty
          ? 'Processing request...'
          : '"${state.liveTranscript}"';
    }
    if (state.isSpeaking) {
      return state.spokenResponse;
    }
    if (state.status == AmbientVoiceStatus.error) {
      return state.spokenResponse.isNotEmpty
          ? state.spokenResponse
          : (state.errorMessage ?? 'Could not process audio request.');
    }
    return '';
  }
}