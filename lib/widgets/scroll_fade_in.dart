import 'package:flutter/material.dart';

/// A widget that fades in and slides up when it scrolls into the viewport.
/// Robust implementation that handles hot reloads and different scroll contexts.
class ScrollFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double slideOffset;
  final Curve curve;
  final Duration delay;

  const ScrollFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.slideOffset = 24.0,
    this.curve = Curves.easeOutCubic,
    this.delay = Duration.zero,
  });

  @override
  State<ScrollFadeIn> createState() => _ScrollFadeInState();
}

class _ScrollFadeInState extends State<ScrollFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _opacity;
  Animation<Offset>? _slide;
  bool _triggered = false;
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _initAnimations();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _attachScrollListener();
        _checkAndAnimate();
      }
    });
  }

  void _initAnimations() {
    // We use this to ensure animations are initialized even if hot reload 
    // bypasses initState for newly added late fields.
    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    _slide = Tween<Offset>(
      // Convert physical pixel offset to relative fraction for SlideTransition
      // Using a heuristic divisor or just a fixed small fraction like 0.1
      begin: Offset(0, widget.slideOffset / 300.0), 
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  void _attachScrollListener() {
    try {
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null) {
        _scrollPosition = scrollable.position;
        _scrollPosition?.addListener(_onScroll);
      }
    } catch (e) {
      debugPrint('ScrollFadeIn: Could not attach scroll listener: $e');
    }
  }

  void _onScroll() {
    if (!_triggered) _checkAndAnimate();
  }

  void _checkAndAnimate() {
    if (!mounted || _triggered) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final pos = box.localToGlobal(Offset.zero);
    final screenH = MediaQuery.of(context).size.height;

    // Trigger if top of widget is within bottom 10% of screen or already above it
    if (pos.dy < screenH + 20) {
      _triggered = true;
      _scrollPosition?.removeListener(_onScroll);
      
      if (widget.delay > Duration.zero) {
        Future.delayed(widget.delay, () {
          if (mounted) _controller.forward();
        });
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure animations are initialized (handles hot reload edge cases)
    if (_opacity == null || _slide == null) {
      _initAnimations();
    }

    return FadeTransition(
      opacity: _opacity!,
      child: SlideTransition(
        position: _slide!,
        child: widget.child,
      ),
    );
  }
}
