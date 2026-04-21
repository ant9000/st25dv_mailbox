import 'dart:typed_data';

import 'package:nfc_manager/src/nfc_manager_android/tags/nfc_v.dart';

import 'utils.dart';

class St25dv {
  St25dv({required this.tag, this.debug = false});

  bool debug;

  final NfcVAndroid tag;

  Future<Uint8List> _send(List<int> data) async {
    final request = Uint8List.fromList(data);
    if (debug) {
      print("sending request ${listToHexString(request)}");
    }
    final start = DateTime.now();
    final response = await tag.transceive(request);
    final stop = DateTime.now();
    final elapsed = stop.difference(start).inMilliseconds;
    if (debug == true) {
      print("got response: ${listToHexString(response)} in ${elapsed} ms");
    }
    if (response[0] & 0x01 != 0) throw Exception("error code ${response[1]}");
    return response;
  }

  Future<void> mailbox_put(Uint8List msg) async {
    await _send([0x20, 0xAA, 0x02, ...tag.tag.id, msg.length - 1, ...msg]);
  }

  Future<Uint8List> mailbox_get() async {
    Uint8List response;
    // poll until there is a response...
    int retries = 10;
    while(retries-- > 0) {
      await Future.delayed(Duration(milliseconds: 10));
      // read MB_CTRL_Dyn
      try {
        response = await _send([0x20, 0xAD, 0x02, ...tag.tag.id, 0x0D]);
        if (response[1] & 0x42 == 0x42) break;
      } on Exception catch(error) {
        // ignore
      }
    }
    if (retries <= 0) throw Exception("timed out");
    // read message
    response = await _send([0x20, 0xAC, 0x02, ...tag.tag.id, 0x00, 0x00]);
    return Uint8List.sublistView(response, 1, response.length-1);
  }

  Future<void> mailbox_clear() async {
    Uint8List? response;
    // read MB_CTRL_Dyn
    try {
      response = await _send([0x20, 0xAD, 0x02, ...tag.tag.id, 0x0D]);
    } on Exception catch(error) {
      // ignore
      return;
    }
    if (response![1] & 0x40 == 0) return;
    // read message length
    response = await _send([0x20, 0xAB, 0x02, ...tag.tag.id]);
    final len = response[1];
    if (len == 0) return;
    // read message
    await _send([0x20, 0xAC, 0x02, ...tag.tag.id, 0x00, len]);
  }

}
