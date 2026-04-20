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

  final TagViewModel tagViewModel = TagViewModel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ST25DV Mailbox"),
      ),
      body: ListView(
        children: [
          Center(
            child: ListenableBuilder(
              listenable: tagViewModel,
              builder: (context, child) {
                return switch (tagViewModel.message) {
                  (null) => Center(child: CircularProgressIndicator()),
                  (String message) => SingleChildScrollView(child: Center(child: Text(message))),
                };
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => tagViewModel.startNfc(),
        icon: const Icon(Icons.refresh),
        label: const Text('Rescan'),
      ),
    );
  }
}

class TagViewModel extends ChangeNotifier {
  String? _message;
  String? get message => _message;
  St25dv? st25dv;

  TagViewModel() {
    startNfc();
  }

  bool inRange() {
    return st25dv != null;
  }

  Future<void> openDoor() async {
    if (!inRange()) return;

    final identity = Identity();
    final start = DateTime.now();
    try {
      final token = List<int>.generate(145, (int i) => i);
      SignedMessage signed = await identity.sign(token);
      Uint8List msg = Uint8List.fromList(signed.toList());
      _message = _message! + "\n### >>> sending token ###";
      notifyListeners();
      await st25dv!.mailbox_put(msg);
      await Future.delayed(Duration(milliseconds: 20));
      final ans = await st25dv!.mailbox_get();
      _message = _message! + "\n### <<< received challenge ###";
      signed = SignedMessage.fromList(ans);
      if (await signed.isValid()) {
        final seed = signed.message;
        _message = _message! + "\n### SEED: ${listToHexString(Uint8List.fromList(seed))} ###";
        notifyListeners();
        signed = await identity.sign(seed);
        msg = Uint8List.fromList(signed.toList());
        _message = _message! + "\n### >>> answering challenge ###";
        notifyListeners();
        await st25dv!.mailbox_put(msg);
      } else {
        _message = _message! + "\n### ERROR: expecting seed, got unsigned message ###";
        notifyListeners();
      }
      _message = _message! + "\nOK";
    } on Exception catch (error) {
      _message = _message! + "\nERROR: ${error}";
    }
    final stop = DateTime.now();
    final elapsed = stop.difference(start).inMilliseconds;
    _message = _message! + "\n### handshake completed in ${elapsed} ms";
    notifyListeners();
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
          final NfcVAndroid? t = NfcVAndroid.from(tag);
          if (t != null) {
            st25dv = St25dv(tag: t!);
            _message = "### found tag: ${listToHexString(t.tag.id)} ###";
            notifyListeners();
            try {
              await st25dv!.mailbox_clear();
            } on Exception catch(error) {
              // ignore
            }
            openDoor();
          }
        },
      );
    }
  }
}
