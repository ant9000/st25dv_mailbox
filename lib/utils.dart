import 'dart:typed_data';

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
