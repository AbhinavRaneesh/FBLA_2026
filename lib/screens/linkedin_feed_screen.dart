import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app LinkedIn experience for the official FBLA company page.
class LinkedInFeedScreen extends StatelessWidget {
  static const String companyUrl =
      'https://www.linkedin.com/company/fbla-pbl/';

  const LinkedInFeedScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const LinkedInFeedScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : Colors.white,
      appBar: AppBar(
        title: const Text('FBLA on LinkedIn'),
        backgroundColor: const Color(0xFF0A66C2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const SafeArea(
        child: LinkedInWebView(profileUrl: companyUrl),
      ),
    );
  }
}

class LinkedInWebView extends StatefulWidget {
  final String profileUrl;

  const LinkedInWebView({
    super.key,
    required this.profileUrl,
  });

  @override
  State<LinkedInWebView> createState() => _LinkedInWebViewState();
}

class _LinkedInWebViewState extends State<LinkedInWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3F2EF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_isAllowedLinkedInUrl(request.url)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.profileUrl));
  }

  bool _isAllowedLinkedInUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('linkedin.com') ||
        host.contains('licdn.com') ||
        url.startsWith('about:blank');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF0A66C2),
            ),
          ),
      ],
    );
  }
}
