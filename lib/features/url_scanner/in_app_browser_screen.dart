import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/link_guard_service.dart';

class InAppBrowserScreen extends StatefulWidget {
  final String url;
  const InAppBrowserScreen({super.key, required this.url});

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _isLoading = true;
  String _pageTitle = '';
  String _currentUrl = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _initWebView();
  }

  void _initWebView() {
    final parsedUri = Uri.tryParse(widget.url);
    final target =
        (parsedUri != null &&
            (parsedUri.scheme == 'http' || parsedUri.scheme == 'https'))
        ? widget.url
        : 'https://${widget.url}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF06090F))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _currentUrl = url;
                _isLoading = true;
                _hasError = false;
              });
              _updateNavControls();
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              final title = await _controller.getTitle();
              setState(() {
                _currentUrl = url;
                _isLoading = false;
                _pageTitle = title ?? '';
              });
              _updateNavControls();
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == true) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = error.description;
                  _isLoading = false;
                });
              }
            }
          },
        ),
      );

    _controller.loadRequest(Uri.parse(target));
  }

  Future<void> _updateNavControls() async {
    try {
      final canBack = await _controller.canGoBack();
      final canFwd = await _controller.canGoForward();
      if (mounted) {
        setState(() {
          _canGoBack = canBack;
          _canGoForward = canFwd;
        });
      }
    } catch (_) {}
  }

  String _getHost() {
    try {
      final uri = Uri.parse(_currentUrl.isNotEmpty ? _currentUrl : widget.url);
      return uri.host.isNotEmpty ? uri.host : _currentUrl;
    } catch (_) {
      return _currentUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF06090F) : const Color(0xFFF8FAFC);
    final barBg = isDark ? const Color(0xFF0D1322) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final host = _getHost();

    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _canGoBack) {
          await _controller.goBack();
          _updateNavControls();
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: barBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: textMain, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFF00E676),
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      host,
                      style: TextStyle(
                        color: textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _pageTitle.isNotEmpty
                          ? _pageTitle
                          : 'SafeSignal Sandbox Isolated',
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: textMain, size: 22),
              tooltip: 'Reload',
              onPressed: () {
                HapticFeedback.lightImpact();
                _controller.reload();
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.open_in_browser_rounded,
                color: Color(0xFF38BDF8),
                size: 22,
              ),
              tooltip: 'Open in Chrome / Browser',
              onPressed: () {
                HapticFeedback.lightImpact();
                LinkGuardService.openUrlInSystemBrowser(_currentUrl);
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: textMain, size: 22),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              onSelected: (val) {
                if (val == 'share') {
                  SharePlus.instance.share(ShareParams(text: _currentUrl));
                } else if (val == 'copy') {
                  Clipboard.setData(ClipboardData(text: _currentUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied to clipboard'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (val == 'external') {
                  LinkGuardService.openUrlInSystemBrowser(_currentUrl);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_rounded, size: 18, color: textMain),
                      const SizedBox(width: 10),
                      Text(
                        'Share Link',
                        style: TextStyle(color: textMain, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18, color: textMain),
                      const SizedBox(width: 10),
                      Text(
                        'Copy URL',
                        style: TextStyle(color: textMain, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'external',
                  child: const Row(
                    children: [
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: Color(0xFF38BDF8),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Open in Chrome ↗',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2.5),
            child: _isLoading
                ? LinearProgressIndicator(
                    value: _loadingProgress > 0
                        ? _loadingProgress / 100.0
                        : null,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00E676),
                    ),
                    minHeight: 2.5,
                  )
                : const SizedBox(height: 2.5),
          ),
        ),
        body: SafeArea(
          child: _hasError
              ? _buildErrorView(isDark)
              : WebViewWidget(controller: _controller),
        ),
        bottomNavigationBar: Container(
          height: 48,
          decoration: BoxDecoration(
            color: barBg,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_rounded,
                  size: 18,
                  color: _canGoBack
                      ? textMain
                      : textMain.withValues(alpha: 0.3),
                ),
                onPressed: _canGoBack ? () => _controller.goBack() : null,
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: _canGoForward
                      ? textMain
                      : textMain.withValues(alpha: 0.3),
                ),
                onPressed: _canGoForward ? () => _controller.goForward() : null,
              ),
              IconButton(
                icon: Icon(Icons.refresh_rounded, size: 20, color: textMain),
                onPressed: () => _controller.reload(),
              ),
              IconButton(
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: Color(0xFF38BDF8),
                ),
                onPressed: () =>
                    LinkGuardService.openUrlInSystemBrowser(_currentUrl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFEF4444),
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Page Could Not Be Loaded',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'Unable to connect to remote host in isolated sandbox.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _isLoading = true;
                    });
                    _controller.reload();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    LinkGuardService.openUrlInSystemBrowser(_currentUrl);
                  },
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('Open in Chrome'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
