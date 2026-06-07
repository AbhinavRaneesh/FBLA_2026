import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app Instagram experience for the official FBLA National profile.
class InstagramFeedScreen extends StatelessWidget {
  static const String profileUrl = 'https://www.instagram.com/fbla_national/';

  const InstagramFeedScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const InstagramFeedScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      appBar: AppBar(
        title: const Text('FBLA Instagram'),
        backgroundColor: const Color(0xFF1D4E89),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const SafeArea(
        child: InstagramWebView(profileUrl: profileUrl),
      ),
    );
  }
}

/// Reusable Instagram WebView for embedded previews and full-screen views.
class InstagramWebView extends StatefulWidget {
  final String profileUrl;
  final double? height;

  const InstagramWebView({
    super.key,
    required this.profileUrl,
    this.height,
  });

  @override
  State<InstagramWebView> createState() => _InstagramWebViewState();
}

class _InstagramWebViewState extends State<InstagramWebView> {
  static const List<String> _allowedHandles = ['fbla_national', 'fbla'];

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F0F0F))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_isAllowedInstagramUrl(request.url)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) {
            _removeInstagramSignupOverlay();
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.profileUrl));
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _controller.loadRequest(Uri.parse(widget.profileUrl));
  }

  Future<void> _openInBrowser() async {
    final launched = await launchUrl(
      Uri.parse(widget.profileUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open Instagram in browser right now.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeInstagramSignupOverlay() async {
    try {
      // Instagram injects a "See full profile in the app" / login modal a
      // moment after the page settles, so a one-shot removal misses it.
      // Run cleanup immediately and then on a short interval to keep the
      // profile grid browsable in-app.
      await _controller.runJavaScript('''
        (function() {
          function cleanup() {
            // Centered login / "open in app" modals.
            document.querySelectorAll('div[role="dialog"]').forEach(function(el) {
              el.remove();
            });
            // Fixed full-screen backdrops that block scrolling/taps.
            document.querySelectorAll('div[role="presentation"]').forEach(function(el) {
              var s = window.getComputedStyle(el);
              if (s && s.position === 'fixed') { el.remove(); }
            });
            // Sticky bottom "Log in" / "Sign up" bar.
            document.querySelectorAll('div[aria-label="Sign up"]').forEach(function(el) {
              el.remove();
            });
            // Restore scrolling Instagram disables behind the modal.
            document.documentElement.style.overflow = 'auto';
            document.body.style.overflow = 'auto';
            document.body.style.position = 'static';
          }

          cleanup();
          var runs = 0;
          var timer = setInterval(function() {
            cleanup();
            if (++runs > 40) clearInterval(timer);
          }, 500);
        })();
      ''');
    } catch (_) {
      // Ignore JavaScript failures if Instagram changes its DOM.
    }
  }

  bool _isAllowedInstagramUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    if (!host.contains('instagram.com')) {
      return false;
    }

    final segments =
        uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) {
      return true;
    }

    final first = segments.first.toLowerCase();
    if (_allowedHandles.contains(first)) {
      return true;
    }

    if (first == 'p' || first == 'reel' || first == 'tv') {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return SizedBox(
        height: widget.height,
        child: Container(
          color: const Color(0xFF0F0F0F),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded,
                  color: Colors.grey.shade400, size: 34),
              const SizedBox(height: 12),
              Text(
                'Instagram could not be loaded right now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: _openInBrowser,
                    child: const Text('Open in Browser'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final webView = Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Container(
            color: const Color(0x99000000),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),
      ],
    );

    if (widget.height != null) {
      return SizedBox(height: widget.height, child: webView);
    }

    return webView;
  }
}
