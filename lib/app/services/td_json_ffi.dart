import 'dart:ffi';

import 'package:ffi/ffi.dart';

abstract interface class TdJsonClient {
  int tdCreate();
  void tdSend(int clientId, String request);
  String? tdReceive(num timeout);
}

class TdJsonFfi implements TdJsonClient {
  TdJsonFfi(String libraryPath) : this._(DynamicLibrary.open(libraryPath));

  TdJsonFfi._(DynamicLibrary library)
    : _create = library.lookupFunction<Int32 Function(), int Function()>(
        'td_create_client_id',
      ),
      _send = library
          .lookupFunction<
            Void Function(Int32, Pointer<Utf8>),
            void Function(int, Pointer<Utf8>)
          >('td_send'),
      _receive = library
          .lookupFunction<
            Pointer<Utf8> Function(Double),
            Pointer<Utf8> Function(double)
          >('td_receive'),
      _execute = library
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Utf8>),
            Pointer<Utf8> Function(Pointer<Utf8>)
          >('td_execute');

  final int Function() _create;
  final void Function(int, Pointer<Utf8>) _send;
  final Pointer<Utf8> Function(double) _receive;
  final Pointer<Utf8> Function(Pointer<Utf8>) _execute;

  @override
  int tdCreate() => _create();

  @override
  void tdSend(int clientId, String request) {
    final input = request.toNativeUtf8();
    try {
      _send(clientId, input);
    } finally {
      malloc.free(input);
    }
  }

  @override
  String? tdReceive(num timeout) => _copy(_receive(timeout.toDouble()));

  String? execute(String request) {
    final input = request.toNativeUtf8();
    try {
      return _copy(_execute(input));
    } finally {
      malloc.free(input);
    }
  }

  // TDLib 拥有返回值；必须在下一次 receive/execute 前复制。
  static String? _copy(Pointer<Utf8> value) =>
      value == nullptr ? null : value.toDartString();
}
