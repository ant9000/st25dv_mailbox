import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/src/nfc_manager_android/tags/nfc_v.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TagWidget(),
    );
  }
}

class TagWidget extends StatelessWidget {
  TagWidget({super.key});

  final TagViewModel viewModel = TagViewModel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ST25DV Mailbox"),
      ),
      body: Center(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, child) {
            return switch (viewModel.message) {
              (null) => Center(child: CircularProgressIndicator()),
              (String message) => Center(child: Text(message)),
            };
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
            viewModel.clear();
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );
  }
}

class TagViewModel extends ChangeNotifier {
  String? _message;
  String? get message => _message;

  TagViewModel() {
    startNfc();
  }

  void clear() {
    _message = null;
    notifyListeners();
  }

  String listToHexString(Uint8List list) {
    var hex = "";
    for (int i = 0; i < list.length; i++) {
      var x = list[i].toRadixString(16);
      if(x.length == 1) x = "0$x";
      hex += x;
      if (i < list.length - 1) hex += ':';
    }
    return hex;
  }

  Future<void> startNfc() async {
    // Check the availability of NFC on the current device.
    NfcAvailability availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      _message = 'NFC may not be supported or may be temporarily disabled.';
      notifyListeners();
    } else {
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          NfcVAndroid? t = NfcVAndroid.from(tag);
          Uint8List request, response;
          if (t != null) {
            Future<Uint8List> send(List<int> data) async {
              final request = Uint8List.fromList(data);
              _message = _message! + "\nsending request ${listToHexString(request)}";
              notifyListeners();
              final start = DateTime.now();
              final response = await t.transceive(request);
              final stop = DateTime.now();
              final elapsed = stop.difference(start).inMilliseconds;
              _message = _message! + "\ngot response: ${listToHexString(response)} in ${elapsed} ms";
              notifyListeners();
              if (response[0] & 0x01 != 0) throw Exception("error code ${response[1]}");
              return response;
            }

            try {
              _message = "found tag: ${listToHexString(t.tag.id)}";
              notifyListeners();
              // read message length
              response = await send([0x20, 0xAB, 0x02, ...t.tag.id]);
              // read message
              response = await send([0x20, 0xAC, 0x02, ...t.tag.id, 0x00, response[1]]);
              // write message
              final List<int> msg = List<int>.generate(240, (int i) => 240 - i);
              response = await send([0x20, 0xAA, 0x02, ...t.tag.id, msg.length - 1, ...msg]);
              _message = _message! + "\nOK";
            } on Exception catch (error) {
              _message = _message! + "\nERROR: ${error}";
            }
            notifyListeners();
          }
        },
      );
    }
  }
}
