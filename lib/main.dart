import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/src/nfc_manager_android/tags/nfc_v.dart';

import 'st25dv.dart';
import 'utils.dart';

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
            viewModel.startNfc();
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Restart'),
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

  Future<void> startNfc() async {
    _message = null;
    notifyListeners();
    await NfcManager.instance.stopSession();
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
          if (t != null) {
            final st25dv = St25dv(tag: t!, debug: true);

            try {
              _message = "### found tag: ${listToHexString(t.tag.id)} ###";
              notifyListeners();
              try {
                await st25dv.mailbox_clear();
              } on Exception catch(error) {
                // ignore
              }
              final msg = Uint8List.fromList(List<int>.generate(64, (int i) => i));
              _message = _message! + "\n### >>> ${listToHexString(msg)} ###";
              notifyListeners();
              await st25dv.mailbox_put(msg);
              final ans = await st25dv.mailbox_get();
              _message = _message! + "\n### <<< ${listToHexString(ans)} ###";
              notifyListeners();
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
