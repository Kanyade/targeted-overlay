import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Signature for building overlay widgets.
typedef OverlayBuilder = Widget Function(void Function() remove);

/// Defines the point on the target widget where the overlay will be attached.
/// For example, AttachPoint.topRight will attach the overlay to the top-right corner of the target widget.
///
/// Note that by default, Flutter's coordinate system has its origin at the top-left corner of the screen,
/// with the x-axis extending to the right and the y-axis extending downwards.
///
/// This means the overlay will be positioned next to the specified attach point on the target widget,
/// not centered over it.
enum AttachPoint {
  topLeft(0, 0),
  topCenter(0, 0.5),
  topRight(0, 1),
  centerLeft(0.5, 0),
  center(0.5, 0.5),
  centerRight(0.5, 1),
  bottomLeft(1, 0),
  bottomCenter(1, 0.5),
  bottomRight(1, 1);

  const AttachPoint(this.offsetHeightModifier, this.offsetWidthModifier);

  final double offsetHeightModifier;
  final double offsetWidthModifier;
}

/// Defines whether the overlay should be mirrored along vertical and/or horizontal axis
/// based on the attach point.
@immutable
class AxisMirrors {
  const AxisMirrors({
    this.vertical = false,
    this.horizontal = false,
  });

  final bool vertical;
  final bool horizontal;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AxisMirrors && other.vertical == vertical && other.horizontal == horizontal;
  }

  @override
  int get hashCode => Object.hash(vertical, horizontal);
}

/// Mixin that provides functionality to manage overlays attached to target widgets.
/// The mixin allows inserting, hiding, and clearing overlays based on target widgets identified by [GlobalKey]s.
/// It also provides methods to register target widgets and update their positions.
mixin TargetedOverlayMixin on Diagnosticable {
  static final HashMap<GlobalKey, _OverlayData> _overlays = HashMap();
  static final HashMap<GlobalKey, _OverlayController> _overlayControllers = HashMap();

  /// Inserts an overlay widget attached to the target widget identified by [key].
  /// The overlay is built using the provided [builder] function.
  /// The [attachPoint] specifies where on the target widget the overlay should be attached.
  /// The [axisMirrors] parameter allows mirroring the overlay along vertical and/or horizontal axes.
  /// The [offset] parameter allows fine-tuning the overlay position relative to the attach point.
  void insertOverlay({
    required BuildContext context,
    required GlobalKey key,
    required OverlayBuilder builder,
    required AttachPoint attachPoint,
    AxisMirrors axisMirrors = const AxisMirrors(),
    Offset offset = Offset.zero,
    Duration fadeDuration = const Duration(milliseconds: 300),
  }) {
    if (_overlays.containsKey(key)) {
      final targetData = _overlays[key]!;
      final opacity = ValueNotifier(1.0);
      final screenSize = MediaQuery.sizeOf(context);
      final overlay = OverlayEntry(
        builder: (context) => Positioned(
          bottom: axisMirrors.vertical
              ? null
              : screenSize.height -
                    (targetData.offset.dy + offset.dy + targetData.height * attachPoint.offsetHeightModifier),
          right: axisMirrors.horizontal
              ? null
              : screenSize.width -
                    (targetData.offset.dx + offset.dx + targetData.width * attachPoint.offsetWidthModifier),
          top: axisMirrors.vertical
              ? targetData.offset.dy + offset.dy + targetData.height * attachPoint.offsetHeightModifier
              : null,
          left: axisMirrors.horizontal
              ? targetData.offset.dx + offset.dx + targetData.width * attachPoint.offsetWidthModifier
              : null,
          child: ValueListenableBuilder(
            valueListenable: opacity,
            builder: (context, value, child) => AnimatedOpacity(
              duration: fadeDuration,
              opacity: value,
              child: child,
            ),
            child: builder(() {
              _overlayControllers[key]?.close();
              _overlayControllers.remove(key);
            }),
          ),
        ),
      );

      if (_overlayControllers.containsKey(key)) {
        _overlayControllers[key]?.close();
        _overlayControllers.remove(key);
      }

      Overlay.of(context).insert(overlay);

      _overlayControllers[key] = _OverlayController(
        close: () async {
          opacity.value = 0.0;
          await Future.delayed(fadeDuration);

          overlay.remove();
        },
      );
    }
  }

  /// Clears overlays associated with the specified target widgets identified by [keys].
  /// This removes the overlays from the screen and cleans up associated resources.
  /// You need to register the targets again if you want to use them after clearing.
  void clearOverlays({required BuildContext context, required Iterable<GlobalKey> keys}) {
    for (final key in keys) {
      _overlays.remove(key);
      _overlayControllers[key]?.close();
      _overlayControllers.remove(key);
    }
  }

  /// Hides overlays associated with the specified target widgets identified by [keys].
  /// This removes the overlays from the screen but retains the target registrations.
  /// You can show overlays again without re-registering the targets.
  void hideOverlays({required BuildContext context, required Iterable<GlobalKey> keys}) {
    for (final key in keys) {
      _overlayControllers[key]?.close();
      _overlayControllers.remove(key);
    }
  }

  /// Same as [insertOverlay] but schedules the insertion to occur
  /// after the current frame has been rendered.
  ///
  /// This is useful when you want to ensure that the overlay is inserted
  /// after all layout calculations are complete, such as during the initial build phase.
  ///
  /// E.g. showing a tooltip right after navigating to a new screen which registers the targets in its initState.
  void insertPostFrameOverlay({
    required BuildContext context,
    required GlobalKey key,
    required OverlayBuilder builder,
    required AttachPoint attachPoint,
    AxisMirrors axisMirrors = const AxisMirrors(),
    Offset offset = Offset.zero,
    Duration fadeDuration = const Duration(milliseconds: 300),
  }) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      insertOverlay(
        context: context,
        key: key,
        builder: builder,
        attachPoint: attachPoint,
        axisMirrors: axisMirrors,
        offset: offset,
        fadeDuration: fadeDuration,
      );
    });
  }

  /// Registers multiple target widgets for overlay management.
  /// This method schedules the registration to occur after the current frame has been rendered.
  ///
  /// Useful for registering targets during the initial build phase or right after navigation.
  void scheduleRegisterTargets(Iterable<GlobalKey> keys) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      registerTargets(keys);
    });
  }

  /// Updates the positions and sizes of all registered target widgets.
  /// This should be called when the layout of the target widgets may have changed,
  /// such as after a screen rotation or when the widgets are moved.
  void updateTargets({required BuildContext context}) {
    _overlays.updateAll((key, data) {
      final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return data;
      final Size size = renderBox.size;
      final Offset offset = renderBox.localToGlobal(Offset.zero);

      return _OverlayData(offset: offset, width: size.width, height: size.height);
    });
  }

  /// Registers target widgets for overlay management.
  ///
  /// This method does not schedule the registration, so it should be called
  /// when the target widget is already laid out and its size and position can be determined.
  void registerTargets(Iterable<GlobalKey> keys) {
    for (var key in keys) {
      try {
        final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) continue;
        final Size size = renderBox.size;
        final Offset offset = renderBox.localToGlobal(Offset.zero);

        _overlays[key] = _OverlayData(offset: offset, width: size.width, height: size.height);
      } catch (_) {}
    }
  }
}

@immutable
class _OverlayData {
  const _OverlayData({
    required this.offset,
    required this.width,
    required this.height,
  });

  final Offset offset;
  final double width;
  final double height;
}

@immutable
class _OverlayController {
  const _OverlayController({required this.close});

  final void Function() close;
}
