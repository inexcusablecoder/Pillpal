import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// On web, [Widget.animate] + fade effects have been observed to leave the UI
/// fully transparent (blank white screen) on some browsers/runtimes. This
/// wrapper snaps the animation controller to completion so effects render at
/// their end state immediately.
extension PillpalWebSafeAnimate on Widget {
  Animate webSkipAnimate({
    Key? key,
    List<Effect>? effects,
    bool? autoPlay,
    Duration? delay,
    AnimationController? controller,
    Adapter? adapter,
    double? target,
    double? value,
  }) {
    if (kIsWeb) {
      return Animate(
        key: key,
        value: 1.0,
        autoPlay: false,
        delay: Duration.zero,
        effects: effects,
        controller: controller,
        adapter: adapter,
        target: target,
        child: this,
      );
    }
    return animate(
      key: key,
      effects: effects,
      autoPlay: autoPlay,
      delay: delay,
      controller: controller,
      adapter: adapter,
      target: target,
      value: value,
    );
  }
}
