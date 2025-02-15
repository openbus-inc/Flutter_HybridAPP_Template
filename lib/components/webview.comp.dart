// Docs: https://inappwebview.dev/docs/intro/

import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class WebViewComp extends StatefulWidget {
  /// 웹뷰 컴포넌트
  /// - [initialUrl] : 초기 URL [required]
  /// - [onLoadWidget] : 로딩시 보여줄 위젯
  /// - [userAgent] : 웹뷰의 UserAgent
  /// - [applicationNameForUserAgent] : 웹뷰의 UserAgent 마지막에 추가할 앱 이름
  /// - [jsInterface] : 웹뷰의 자바스크립트 인터페이스
  const WebViewComp({
    super.key,
    required this.initialUrl,
    this.onLoadWidget,
    this.userAgent,
    this.applicationNameForUserAgent,
    this.jsInterface,
  });

  final String initialUrl;
  final Widget? onLoadWidget;
  final String? userAgent;
  final String? applicationNameForUserAgent;
  final Function(InAppWebViewController)? jsInterface;

  @override
  State<WebViewComp> createState() => _WebViewCompState();
}

class _WebViewCompState extends State<WebViewComp> {
  final GlobalKey webViewKey = GlobalKey();
  late final InAppWebViewController webViewController;
  late PullToRefreshController pullToRefreshController;

  // 로딩상태
  final RxBool _isLoading = false.obs;

  // 웹뷰용 로그
  void _log(String value) {
    log(value, name: '📟');
  }

  // 뒤로가기 이벤트의 웹뷰 라우팅 처리
  Future<bool> _goBack(BuildContext context) async {
    if (await webViewController.canGoBack()) {
      webViewController.goBack();
      return Future.value(false);
    } else {
      return Future.value(true);
    }
  }

  @override
  void initState() {
    super.initState();

    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Colors.primaries.first,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController.reload();
        } else if (Platform.isIOS) {
          webViewController.loadUrl(
            urlRequest: URLRequest(
              url: await webViewController.getUrl(),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) => _goBack(context),
      child: Stack(
        children: [
          // 웹뷰
          InAppWebView(
            key: webViewKey,
            initialUrlRequest: URLRequest(
              url: WebUri.uri(Uri.parse(widget.initialUrl)),
            ),
            pullToRefreshController: pullToRefreshController,
            onWebViewCreated: (InAppWebViewController controller) {
              _isLoading.value = true;
              webViewController = controller;

              if (widget.jsInterface != null) {
                widget.jsInterface!(webViewController);
              }
            },
            // 버튼 클릭 잔상 제거
            preventGestureDelay: true,
            // 로딩 종료
            onLoadStop: (controller, url) {
              _log('onLoadStop : $url');
              pullToRefreshController.endRefreshing();
              _isLoading.value = false;
            },
            // 로딩 에러 발생시
            onReceivedError: (controller, request, error) {
              _log('onLoadError : ${request.url}, ${error.description}');
              pullToRefreshController.endRefreshing();
            },
            // 콘솔 로그
            onConsoleMessage: (controller, consoleMessage) {
              _log('onConsoleMessage : ${consoleMessage.message}');
            },
            // 페이지 변경 이벤트 감지
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              var uri = navigationAction.request.url!;

              /// 웹뷰 내에서 페이지 이동을 처리
              if (!["http", "https", "file", "chrome", "data", "javascript", "about"]
                  .contains(uri.scheme)) {
                if (await canLaunchUrl(uri)) {
                  // Launch the App
                  await launchUrl(uri);

                  // 웹뷰 내의 페이지 이동을 취소
                  return NavigationActionPolicy.CANCEL;
                }
              }

              return NavigationActionPolicy.ALLOW;
            },
            onPermissionRequest: (controller, permissionRequest) async {
              return PermissionResponse(
                resources: permissionRequest.resources,
                action: PermissionResponseAction.GRANT,
              );
            },
            initialSettings: InAppWebViewSettings(
              javaScriptCanOpenWindowsAutomatically: true,
              javaScriptEnabled: true,
              useOnDownloadStart: true,
              useOnLoadResource: true,
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              supportZoom: false,
              verticalScrollBarEnabled: true,
              userAgent: widget.userAgent ?? "",
              useHybridComposition: true,
              allowContentAccess: true,
              builtInZoomControls: true,
              thirdPartyCookiesEnabled: true,
              allowFileAccess: true,
              supportMultipleWindows: true,
              allowsInlineMediaPlayback: true,
              allowsBackForwardNavigationGestures: true,
              applicationNameForUserAgent: widget.applicationNameForUserAgent ?? "",
            ),
          ),
          // 로딩
          Obx(() {
            if (_isLoading.isTrue) {
              if (widget.onLoadWidget != null) {
                return widget.onLoadWidget!;
              }
            }

            return Container();
          }),
        ],
      ),
    );
  }
}
