import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

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

class Identity {
  static final Identity _instance = Identity._internal();
  factory Identity() { return _instance; }
  Identity._internal();

  final ed25519 = Ed25519();

  Future<SimpleKeyPair> get _keyPair async {
    final appDir = await getApplicationDocumentsDirectory();
    final keyFile = await File('${appDir.path}/key.bin');
    SimpleKeyPair kp;
    try {
      final contents = await keyFile.readAsBytes();
      if (contents.length != 64) throw Exception("Invalid file ${keyFile}");
      final key = contents.sublist(0,32).toList(growable: false);
      final pub = contents.sublist(32).toList(growable: false);
      kp = SimpleKeyPairData(key, publicKey: SimplePublicKey(pub, type: KeyPairType.ed25519), type: KeyPairType.ed25519);
    } catch (e) {
      kp = await ed25519.newKeyPair();
      final key = await kp.extractPrivateKeyBytes();
      final publicKey = await kp.extractPublicKey();
      await keyFile.writeAsBytes(key + publicKey.bytes);
    }
    return kp;
  }

  Future<List<int>> get publicKey async {
    final kp = await _keyPair;
    final pub = await kp.extractPublicKey();
    print("PubKey: ${listToHexString(Uint8List.fromList(pub.bytes))}");
    return pub.bytes;
  }

  Future<SignedMessage> sign(List<int> data) async {
    final kp = await _keyPair;
    final pub = await kp.extractPublicKey();
    final sig = await ed25519.sign(data, keyPair: kp);
    return SignedMessage(publicKey: pub.bytes, message: data, signature: sig.bytes);
  }

  Future<bool> verify(SignedMessage signedMessage) async {
    return signedMessage.isValid();
  }
}

class SignedMessage {
  SignedMessage({
    required this.publicKey,
    required this.message,
    required this.signature,
  });

  final List<int> signature;
  final List<int> publicKey;
  final List<int> message;

  Future<bool> isValid() async {
    final ed25519 = Ed25519();
    final sig = Signature(signature, publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519));
    return ed25519.verify(message, signature: sig);
  }

  static SignedMessage fromList(List<int> data) {
    final len = data.length;
    if (len <= 96) throw Exception("Signed message is too short");
    final pub = data.sublist(0, 32);
    final msg = data.sublist(32, len-64);
    final sig = data.sublist(len-64);
    return SignedMessage(publicKey: pub, message: msg, signature: sig);
  }

  List<int> toList() {
    return this.publicKey + this.message + this.signature;
  }
}
