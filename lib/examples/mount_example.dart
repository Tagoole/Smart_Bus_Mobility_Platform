import 'package:flutter/material.dart';
import 'dart:async';

/// Example demonstrating the mount concept and common mount errors
///
/// This file shows:
/// 1. What "mounted" means
/// 2. Common mount errors and how to fix them
/// 3. Best practices for handling async operations

class MountExampleScreen extends StatefulWidget {
  const MountExampleScreen({super.key});

  @override
  State<MountExampleScreen> createState() => _MountExampleScreenState();
}

class _MountExampleScreenState extends State<MountExampleScreen> {
  String _status = 'Initial';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mount Example'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Status: $_status',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const LinearProgressIndicator()
                    else
                      const Text('Ready'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Examples section
            const Text(
              'Mount Examples:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            // ❌ WRONG - No mount check
            ElevatedButton(
              onPressed: _wrongAsyncOperation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('❌ Wrong: No Mount Check'),
            ),

            const SizedBox(height: 8),

            // ✅ CORRECT - With mount check
            ElevatedButton(
              onPressed: _correctAsyncOperation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('✅ Correct: With Mount Check'),
            ),

            const SizedBox(height: 8),

            // 🔄 DEMO - Simulate widget disposal
            ElevatedButton(
              onPressed: _simulateDisposal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('🔄 Simulate Widget Disposal'),
            ),

            const SizedBox(height: 20),

            // Explanation
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What is "mounted"?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• "mounted" is a boolean property that indicates whether a widget is currently part of the widget tree\n'
                      '• It becomes false when the widget is disposed (removed from the tree)\n'
                      '• Always check mounted before calling setState() in async operations\n'
                      '• This prevents "setState() called after dispose()" errors',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ❌ WRONG EXAMPLE - No mount check
  /// This can cause "setState() called after dispose()" error
  void _wrongAsyncOperation() async {
    setState(() {
      _status = 'Starting async operation...';
      _isLoading = true;
    });

    // Simulate async operation
    await Future.delayed(const Duration(seconds: 2));

    // ❌ DANGEROUS: No mount check
    setState(() {
      _status = 'Async operation completed!';
      _isLoading = false;
    });
  }

  /// ✅ CORRECT EXAMPLE - With mount check
  /// This prevents mount errors
  void _correctAsyncOperation() async {
    setState(() {
      _status = 'Starting async operation...';
      _isLoading = true;
    });

    // Simulate async operation
    await Future.delayed(const Duration(seconds: 2));

    // ✅ SAFE: Check if widget is still mounted
    if (mounted) {
      setState(() {
        _status = 'Async operation completed!';
        _isLoading = false;
      });
    } else {
      // Widget was disposed during async operation
      print('Widget was disposed, skipping setState()');
    }
  }

  /// 🔄 DEMO - Simulate widget disposal during async operation
  void _simulateDisposal() async {
    setState(() {
      _status = 'Starting operation that will be interrupted...';
      _isLoading = true;
    });

    // Simulate async operation
    await Future.delayed(const Duration(seconds: 1));

    // Simulate widget disposal (in real app, this happens when navigating away)
    if (mounted) {
      setState(() {
        _status = 'Operation interrupted by disposal';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // This is called when the widget is removed from the widget tree
    print('Widget disposed - mounted will now be false');
    super.dispose();
  }
}

/// Additional Mount Error Examples
/// 
/// Here are some common patterns that can cause mount errors:

/// ❌ WRONG - No mount check in async callback
/// This can cause "setState() called after dispose()" error
/// 
/// Future.delayed(Duration(seconds: 1)).then((_) {
///   setState(() {
///     // Update UI - DANGEROUS!
///   });
/// });

/// ✅ CORRECT - With mount check in async callback
/// 
/// Future.delayed(Duration(seconds: 1)).then((_) {
///   if (mounted) {
///     setState(() {
///       // Update UI - SAFE!
///     });
///   }
/// });

/// ❌ WRONG - No mount check in Stream subscription
/// 
/// Stream.periodic(Duration(seconds: 1)).listen((_) {
///   setState(() {
///     // Update UI - DANGEROUS!
///   });
/// });

/// ✅ CORRECT - With mount check in Stream subscription
/// 
/// Stream.periodic(Duration(seconds: 1)).listen((_) {
///   if (mounted) {
///     setState(() {
///       // Update UI - SAFE!
///     });
///   }
/// });

/// ❌ WRONG - No mount check in Timer
/// 
/// Timer(Duration(seconds: 1), () {
///   setState(() {
///     // Update UI - DANGEROUS!
///   });
/// });

/// ✅ CORRECT - With mount check in Timer
/// 
/// Timer(Duration(seconds: 1), () {
///   if (mounted) {
///     setState(() {
///       // Update UI - SAFE!
///     });
///   }
/// });



