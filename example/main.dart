import 'package:flutter/material.dart';
import 'package:targeted_overlay/targeted_overlay.dart';

void main() {
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: const Test()));
}

class Test extends StatefulWidget {
  const Test({super.key});

  @override
  State<Test> createState() => _TestState();
}

class _TestState extends State<Test> with TargetedOverlayMixin {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    scheduleRegisterTargets([_key]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Targeted Overlay Example')),
      body: Center(
        child: GestureDetector(
          onTap: () {
            insertOverlay(
              context: context,
              key: _key,
              attachPoint: AttachPoint.topRight,
              offset: const Offset(-15, -12),
              builder: (remove) {
                return TapRegion(
                  onTapOutside: (_) => hideOverlays(context: context, keys: [_key]),
                  onTapInside: (_) => hideOverlays(context: context, keys: [_key]),
                  child: Material(
                    textStyle: const TextStyle(color: Colors.black),
                    type: MaterialType.transparency,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      width: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black),
                      ),
                      child: Text('Overlay', textAlign: TextAlign.center),
                    ),
                  ),
                );
              },
            );
          },
          child: Container(
            key: _key,
            width: 120,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(16)),
            child: const Text('Show Overlay'),
          ),
        ),
      ),
    );
  }
}
