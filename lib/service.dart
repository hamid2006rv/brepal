import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class BLT_Service
{
  late List<double> data_list;
  BLT_Service()
  {
    data_list = [];
  }

  listen () async
  {
    await Permission.bluetoothScan.request();
    try {
      BluetoothConnection connection = await BluetoothConnection.toAddress('00:22:06:01:10:4E');
      print('Connected to the device');

      connection.input!.listen((Uint8List data) {
        // print('Data incoming: ${ascii.decode(data)}');
        data_list.add(double.parse(ascii.decode(data)));

      }).onDone(() {
        print('Disconnected by remote request');
      });
    }
    catch (exception) {
      print('Cannot connect, exception occured');
    }

  }
}