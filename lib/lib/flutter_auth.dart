import 'dart:async';
import 'dart:io';

import 'package:flutter_oauth/lib/auth_code_information.dart';
import 'package:flutter_oauth/lib/model/config.dart';
import 'package:flutter_oauth/lib/oauth.dart';
import 'package:url_launcher/url_launcher.dart';

class FlutterOAuth extends OAuth {
  final StreamController<String> onCodeListener = new StreamController();

  var isBrowserOpen = false;
  var server;
  var onCodeStream;

  Stream<String> get onCode =>
      onCodeStream ??= onCodeListener.stream.asBroadcastStream();

  FlutterOAuth(Config configuration) :
        super(configuration, new AuthorizationRequest(configuration));

  Future<String> requestCode() async {
    if (shouldRequestCode() && !isBrowserOpen) {
      isBrowserOpen = true;

      server = await createServer();
      listenForServerResponse(server);

      final String urlParams = constructUrlParams();

      closeWebView();
      launch("${requestDetails.url}?$urlParams",
          forceWebView: configuration.forceWebiew, forceSafariVC: configuration.forceSafariVC, enableJavaScript: configuration.enableJavaScript);

      code = await onCode.first;
      close();
    }
    return code;
  }

  void close() {
    if (isBrowserOpen) {
      server.close(force: true);
      closeWebView();
    }
    isBrowserOpen = false;
  }

  Future<HttpServer> createServer() async {
    final server = await HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, 8080,
        shared: true);
    return server;
  }

  listenForServerResponse(HttpServer server) {
    server.listen((HttpRequest request) async {
      final uri = request.uri;
      request.response
        ..statusCode = 200
        ..headers.set("Content-Type", ContentType.HTML.mimeType);

      final code = uri.queryParameters["code"];
      final error = uri.queryParameters["error"];

      if( (configuration.redirectedHtml != null) && (configuration.forceWebiew != true) ) {
        request.response.write(configuration.redirectedHtml);
      }

      await request.response.close();

      if (code != null && error == null) {
        onCodeListener.add(code);
      } else if (error != null) {
        onCodeListener.add(null);
        onCodeListener.addError(error);
      }
    });
  }

}
