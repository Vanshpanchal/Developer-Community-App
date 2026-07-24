library page_transition;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'enum.dart';

/// This package allows you amazing transition for your routes

/// Builder function type for creating the transition page
typedef TransitionPageBuilder = Widget Function(BuildContext context,
    Animation<double> animation, Animation<double> secondaryAnimation);

/// Builder function type for creating child widget
typedef ChildBuilder = Widget Function(BuildContext context);

/// Page transition class extends PageRouteBuilder
class PageTransition<T> extends PageRouteBuilder<T> {
  /// Child widget for the next page
  final Widget? child;

  /// Builder function for creating child widget with context
  final ChildBuilder? childBuilder;

  // ignore: public_member_api_docs
  final PageTransitionsBuilder matchingBuilder;

  /// Child for your next page
  final Widget? childCurrent;

  /// Transition types
  ///  fade,rightToLeft,leftToRight, upToDown,downToUp,scale,rotate,size,rightToLeftWithFade,leftToRightWithFade
  final PageTransitionType type;

  /// Transition types
  final PageTransitionType? reverseType;

  /// Curves for transitions
  final Curve curve;

  /// Alignment for transitions
  final Alignment? alignment;

  /// Duration for your transition default is 300 ms
  final Duration duration;

  /// Duration for your pop transition default is 300 ms
  final Duration? reverseDuration;

  /// Context for inherit theme
  final BuildContext? ctx;

  /// Optional inherit theme
  final bool inheritTheme;

  /// Optional fullscreen dialog mode
  final bool fullscreenDialog;

  final bool opaque;

  // ignore: public_member_api_docs
  final bool isIos;

  // ignore: public_member_api_docs
  final bool? maintainStateData;

  /// Page transition constructor. We can pass the next page either as a child widget
  /// or as a builder function.
  ///
  /// Example using child:
  /// ```dart
  /// PageTransition(
  ///   type: PageTransitionType.rightToLeft,
  ///   child: DetailPage(),
  /// )
  /// ```
  ///
  /// Example using builder:
  /// ```dart
  /// PageTransition(
  ///   type: PageTransitionType.rightToLeft,
  ///   builder: (context) => DetailPage(),
  /// )
  /// ```
  PageTransition({
    Key? key,
    this.child,
    this.childBuilder,
    required this.type,
    this.childCurrent,
    this.ctx,
    this.inheritTheme = false,
    this.curve = Curves.linear,
    this.alignment,
    this.duration = const Duration(milliseconds: 200),
    this.reverseDuration = const Duration(milliseconds: 200),
    this.fullscreenDialog = false,
    this.opaque = false,
    this.isIos = false,
    this.matchingBuilder = const CupertinoPageTransitionsBuilder(),
    this.maintainStateData,
    this.reverseType,
    RouteSettings? settings,
  })  : assert(child != null || childBuilder != null,
            'Either child or childBuilder must be provided'),
        assert(!(child != null && childBuilder != null),
            'Cannot provide both child and childBuilder'),
        assert(inheritTheme ? ctx != null : true,
            "'ctx' cannot be null when 'inheritTheme' is true, set ctx: context"),
        super(
          pageBuilder: (context, animation, secondaryAnimation) {
            return childBuilder?.call(context) ?? child!;
          },
          settings: settings,
          maintainState: maintainStateData ?? true,
          opaque: opaque,
          fullscreenDialog: fullscreenDialog,
        );

  @override
  Duration get transitionDuration => duration;

  @override
  // ignore: public_member_api_docs
  Duration get reverseTransitionDuration => reverseDuration ?? duration;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curvedAnimation = CurvedAnimation(parent: animation, curve: curve);
    final curvedSecondaryAnimation =
        CurvedAnimation(parent: secondaryAnimation, curve: curve);
    switch (type) {
      case PageTransitionType.theme:
        return Theme.of(context).pageTransitionsTheme.buildTransitions(
              this,
              context,
              curvedAnimation,
              curvedSecondaryAnimation,
              child,
            );
      case PageTransitionType.fade:
        return FadeTransition(opacity: curvedAnimation, child: child);
      case PageTransitionType.rightToLeft:
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .animate(curvedAnimation),
          child: child,
        );
      case PageTransitionType.leftToRight:
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero)
                  .animate(curvedAnimation),
          child: child,
        );
      case PageTransitionType.topToBottom:
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0.0, -1.0), end: Offset.zero)
                  .animate(curvedAnimation),
          child: child,
        );
      case PageTransitionType.bottomToTop:
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero)
                  .animate(curvedAnimation),
          child: child,
        );
      case PageTransitionType.scale:
        return ScaleTransition(scale: curvedAnimation, child: child);
      case PageTransitionType.rotate:
        return RotationTransition(turns: curvedAnimation, child: child);
      case PageTransitionType.size:
        return Align(
          alignment: alignment ?? Alignment.center,
          child: SizeTransition(
            sizeFactor: curvedAnimation,
            axisAlignment: 0.0,
            child: child,
          ),
        );
      case PageTransitionType.rightToLeftWithFade:
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .animate(curvedAnimation),
          child: FadeTransition(opacity: curvedAnimation, child: child),
        );
      case PageTransitionType.leftToRightWithFade:
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero)
                  .animate(curvedAnimation),
          child: FadeTransition(opacity: curvedAnimation, child: child),
        );
      case PageTransitionType.leftToRightJoined:
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero)
                  .animate(curvedAnimation),
          child: child,
        );
      case PageTransitionType.rightToLeftJoined:
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .animate(curvedAnimation),
          child: child,
        );
      case PageTransitionType.topToBottomJoined:
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0.0, -1.0), end: Offset.zero)
                  .animate(curvedAnimation),
          child: child,
        );
      case PageTransitionType.bottomToTopJoined:
        return SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero)
                  .animate(curvedAnimation),
          child: child,
        );
      case PageTransitionType.leftToRightPop:
        return SlideTransition(
          position:
              Tween<Offset>(begin: Offset.zero, end: const Offset(-1.0, 0.0))
                  .animate(curvedAnimation),
          child: child,
        );
      case PageTransitionType.rightToLeftPop:
        return SlideTransition(
          position:
              Tween<Offset>(begin: Offset.zero, end: const Offset(1.0, 0.0))
                  .animate(curvedAnimation),
          child: child,
        );
      case PageTransitionType.topToBottomPop:
        return SlideTransition(
          position:
              Tween<Offset>(begin: Offset.zero, end: const Offset(0.0, -1.0))
                  .animate(curvedAnimation),
          child: child,
        );
      case PageTransitionType.bottomToTopPop:
        return SlideTransition(
          position:
              Tween<Offset>(begin: Offset.zero, end: const Offset(0.0, 1.0))
                  .animate(curvedAnimation),
          child: child,
        );
      case PageTransitionType.sharedAxisHorizontal:
        return FadeTransition(opacity: curvedAnimation, child: child);
      case PageTransitionType.sharedAxisVertical:
        return FadeTransition(opacity: curvedAnimation, child: child);
      case PageTransitionType.sharedAxisScale:
        return ScaleTransition(scale: curvedAnimation, child: child);
    }
  }
}
