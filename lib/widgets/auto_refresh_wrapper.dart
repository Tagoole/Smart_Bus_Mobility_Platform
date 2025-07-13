import 'dart:async';
import 'package:flutter/material.dart';

class AutoRefreshWrapper extends StatefulWidget {
  final Widget child;
  final Duration refreshInterval;
  final VoidCallback onRefresh;
  final bool enabled;

  const AutoRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshInterval = const Duration(minutes: 2),
    this.enabled = true,
  });

  @override
  State<AutoRefreshWrapper> createState() => _AutoRefreshWrapperState();
}

class _AutoRefreshWrapperState extends State<AutoRefreshWrapper> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _startAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(widget.refreshInterval, (timer) {
      if (mounted) {
        widget.onRefresh();
      }
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void didUpdateWidget(AutoRefreshWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _startAutoRefresh();
      } else {
        _stopAutoRefresh();
      }
    }
    if (widget.refreshInterval != oldWidget.refreshInterval && widget.enabled) {
      _startAutoRefresh();
    }
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// Mixin for easy auto refresh functionality
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  Timer? _autoRefreshTimer;

  void startAutoRefresh(VoidCallback onRefresh, {Duration interval = const Duration(minutes: 2)}) {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(interval, (timer) {
      if (mounted) {
        onRefresh();
      }
    });
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
} 