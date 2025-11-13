import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/age_detection_service.dart';
import '../services/sensory_regulation_service.dart';

/// Wrapper widget that adapts UI for elderly users
class ElderlyUIWrapper extends StatefulWidget {
  final Widget child;
  final bool enableVoiceGuidance;
  final double fontScaleFactor;
  final bool simplifiedMode;
  final bool forceElderlyMode;

  const ElderlyUIWrapper({
    super.key,
    required this.child,
    this.enableVoiceGuidance = true,
    this.fontScaleFactor = 1.5,
    this.simplifiedMode = true,
    this.forceElderlyMode = false,
  });

  @override
  State<ElderlyUIWrapper> createState() => _ElderlyUIWrapperState();
}

class _ElderlyUIWrapperState extends State<ElderlyUIWrapper> {
  late FlutterTts _flutterTts;
  bool _ttsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.4); // Slower for elderly
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _ttsInitialized = true;
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  Future<void> _speak(String text) async {
    if (!widget.enableVoiceGuidance || !_ttsInitialized) return;
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error speaking: $e');
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ageDetection = Provider.of<AgeDetectionService>(context);
    final sensoryService = Provider.of<SensoryRegulationService>(context);
    final isElderlyMode = widget.forceElderlyMode || ageDetection.isElderlyMode;

    if (!isElderlyMode) {
      return widget.child;
    }

    // Apply sensory profile adjustments
    final adjustedFontScale = widget.fontScaleFactor * sensoryService.paddingMultiplier;
    final shouldUseVoice = widget.enableVoiceGuidance && sensoryService.shouldUseHaptics;

    return ElderlyThemeWrapper(
      fontScaleFactor: adjustedFontScale,
      simplifiedMode: widget.simplifiedMode,
      onSpeak: _speak,
      enableVoiceGuidance: shouldUseVoice,
      sensoryService: sensoryService,
      child: widget.child,
    );
  }
}

/// Internal theme wrapper that applies elderly-friendly styling
class ElderlyThemeWrapper extends InheritedWidget {
  final double fontScaleFactor;
  final bool simplifiedMode;
  final Function(String) onSpeak;
  final bool enableVoiceGuidance;
  final SensoryRegulationService sensoryService;

  const ElderlyThemeWrapper({
    super.key,
    required this.fontScaleFactor,
    required this.simplifiedMode,
    required this.onSpeak,
    required this.enableVoiceGuidance,
    required this.sensoryService,
    required super.child,
  });

  static ElderlyThemeWrapper? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ElderlyThemeWrapper>();
  }

  @override
  bool updateShouldNotify(ElderlyThemeWrapper oldWidget) {
    return fontScaleFactor != oldWidget.fontScaleFactor ||
        simplifiedMode != oldWidget.simplifiedMode ||
        enableVoiceGuidance != oldWidget.enableVoiceGuidance;
  }
}

/// Enhanced button with elderly-friendly features
class ElderlyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? label;
  final ButtonStyle? style;
  final bool enableVoiceGuidance;

  const ElderlyButton({
    super.key,
    required this.child,
    this.onPressed,
    this.label,
    this.style,
    this.enableVoiceGuidance = true,
  });

  @override
  State<ElderlyButton> createState() => _ElderlyButtonState();
}

class _ElderlyButtonState extends State<ElderlyButton> {
  bool _isLongPressing = false;
  Timer? _longPressTimer;

  void _handleLongPressStart(LongPressStartDetails details) {
    setState(() => _isLongPressing = true);
    
    final elderlyTheme = ElderlyThemeWrapper.of(context);
    if (elderlyTheme != null && elderlyTheme.enableVoiceGuidance && widget.label != null) {
      _longPressTimer = Timer(const Duration(milliseconds: 800), () {
        elderlyTheme.onSpeak(widget.label!);
      });
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    setState(() => _isLongPressing = false);
    _longPressTimer?.cancel();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elderlyTheme = ElderlyThemeWrapper.of(context);
    final isElderlyMode = elderlyTheme != null;

    if (!isElderlyMode) {
      return ElevatedButton(
        onPressed: widget.onPressed,
        style: widget.style,
        child: widget.child,
      );
    }

    // Elderly mode: Larger buttons with better contrast
    final defaultStyle = ElevatedButton.styleFrom(
      minimumSize: const Size(64, 64), // Minimum 64x64 dp
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: TextStyle(
        fontSize: 18 * elderlyTheme.fontScaleFactor,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.black.withOpacity(0.2),
          width: 2,
        ),
      ),
    );

    return GestureDetector(
      onLongPressStart: widget.enableVoiceGuidance ? _handleLongPressStart : null,
      onLongPressEnd: widget.enableVoiceGuidance ? _handleLongPressEnd : null,
      child: Container(
        margin: const EdgeInsets.all(8), // Extra spacing between buttons
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isLongPressing
              ? (Matrix4.identity()..scale(1.05))
              : Matrix4.identity(),
          child: ElevatedButton(
            onPressed: widget.onPressed,
            style: widget.style?.merge(defaultStyle) ?? defaultStyle,
            child: DefaultTextStyle(
              style: TextStyle(
                fontSize: 18 * elderlyTheme.fontScaleFactor,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Enhanced text with elderly-friendly scaling
class ElderlyText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ElderlyText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final elderlyTheme = ElderlyThemeWrapper.of(context);

    if (elderlyTheme == null) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Apply font scaling
    final scaledStyle = (style ?? const TextStyle()).copyWith(
      fontSize: (style?.fontSize ?? 14) * elderlyTheme.fontScaleFactor,
      fontWeight: FontWeight.w500, // Slightly bolder for readability
      height: 1.5, // Increased line spacing
    );

    return Text(
      text,
      style: scaledStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Enhanced ListTile with elderly-friendly features
class ElderlyListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? label;

  const ElderlyListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final elderlyTheme = ElderlyThemeWrapper.of(context);

    if (elderlyTheme == null) {
      return ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
      );
    }

    // Elderly mode: Larger tap targets and spacing
    return InkWell(
      onTap: onTap,
      onLongPress: elderlyTheme.enableVoiceGuidance && label != null
          ? () => elderlyTheme.onSpeak(label!)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme(
                data: IconThemeData(
                  size: 32 * elderlyTheme.fontScaleFactor,
                  color: Theme.of(context).primaryColor,
                ),
                child: leading!,
              ),
              const SizedBox(width: 20),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 18 * elderlyTheme.fontScaleFactor,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      child: title!,
                    ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 14 * elderlyTheme.fontScaleFactor,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 16),
              IconTheme(
                data: IconThemeData(
                  size: 28 * elderlyTheme.fontScaleFactor,
                ),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Enhanced IconButton with elderly-friendly features
class ElderlyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double? size;
  final Color? color;

  const ElderlyIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final elderlyTheme = ElderlyThemeWrapper.of(context);

    if (elderlyTheme == null) {
      return IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: size,
        color: color,
      );
    }

    // Elderly mode: Larger icons with better tap targets
    final iconSize = (size ?? 24) * elderlyTheme.fontScaleFactor;

    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        onLongPress: elderlyTheme.enableVoiceGuidance && tooltip != null
            ? () => elderlyTheme.onSpeak(tooltip!)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: color ?? Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
}

/// Enhanced AppBar with elderly-friendly features
class ElderlyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const ElderlyAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    final elderlyTheme = ElderlyThemeWrapper.of(context);

    if (elderlyTheme == null) {
      return AppBar(
        title: title,
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
      );
    }

    // Elderly mode: Larger title and icons
    return AppBar(
      title: title != null
          ? DefaultTextStyle(
              style: TextStyle(
                fontSize: 22 * elderlyTheme.fontScaleFactor,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              child: title!,
            )
          : null,
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: 72 * elderlyTheme.fontScaleFactor,
      elevation: 4,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

/// Simplified navigation bar for elderly mode
class ElderlyNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<ElderlyNavItem> items;

  const ElderlyNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final elderlyTheme = ElderlyThemeWrapper.of(context);

    if (elderlyTheme == null) {
      // Standard navigation bar
      return NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        destinations: items
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  label: item.label,
                ))
            .toList(),
      );
    }

    // Elderly mode: Larger icons, clearer labels, reduced items
    final displayItems = elderlyTheme.simplifiedMode && items.length > 4
        ? items.sublist(0, 4) // Show only 4 priority items
        : items;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: displayItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == currentIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  onLongPress: elderlyTheme.enableVoiceGuidance
                      ? () => elderlyTheme.onSpeak(item.label)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 32 * elderlyTheme.fontScaleFactor,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12 * elderlyTheme.fontScaleFactor,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Navigation item model
class ElderlyNavItem {
  final IconData icon;
  final String label;

  const ElderlyNavItem({
    required this.icon,
    required this.label,
  });
}

