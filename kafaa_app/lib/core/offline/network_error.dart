import 'dart:io';

import 'package:http/http.dart' as http;

bool isNetworkError(Object error) =>
    error is SocketException || error is http.ClientException;
