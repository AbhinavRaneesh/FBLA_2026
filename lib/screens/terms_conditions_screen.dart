import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

/// Displays the in-app Terms & Conditions content during account creation.
class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
      ),
      body: const SafeArea(
        child: _TermsHtmlView(),
      ),
    );
  }
}

class _TermsHtmlView extends StatefulWidget {
  const _TermsHtmlView();

  @override
  State<_TermsHtmlView> createState() => _TermsHtmlViewState();
}

class _TermsHtmlViewState extends State<_TermsHtmlView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loading = false);
            }
          },
        ),
      );
    _loadTermsHtml();
  }

  Future<void> _loadTermsHtml() async {
    final html = await rootBundle.loadString('assets/legal/terms_conditions.html');
    await _controller.loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
