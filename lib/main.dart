import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'oscilloscope.dart';

/// Demo of using the oscilloscope package
///
/// In this demo 2 displays are generated showing the outputs for Sine & Cosine
/// The scope displays will show the data sets  which will fill the yAxis and then the screen display will 'scroll'
import 'package:flutter/material.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Oscilloscope Display Example",
      home: Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  @override
  _ShellState createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late FlutterTts flutterTts;
  String? language;
  String? engine;
  double volume = 1;
  double pitch = 7.0;
  double rate = 0.3;

  initTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("en-US");

    await flutterTts.setSpeechRate(rate);

    await flutterTts.setVolume(volume);

    await flutterTts.setPitch(pitch);

    await flutterTts.isLanguageAvailable("en-US");
  }

  String _old_speek = "";

  Future _speak(String text) async {
    var result = await flutterTts.speak(text);
  }

  Future _stop() async {
    var result = await flutterTts.stop();
  }

  List<double> data = [];
  List<double> traceSine = [];
  List<double> traceCosine = [];

  Timer? _timer;
  int i = 0;
  int k = 0;

  double _currentP = 0;
  double _maxP = 0;
  double _minP = 0;

  int _timer_delay = 500;
  bool _play = false;

  int t_i = 3 * 1000;
  int t_r = 2 * 1000;
  int t_e = 3 * 1000;
  int m_i = 100;
  int m_e = 100;

  final TextEditingController t_i_cntl = TextEditingController(text: '3');
  final TextEditingController t_r_cntl = TextEditingController(text: '2');
  final TextEditingController t_e_cntl = TextEditingController(text: '3');
  final TextEditingController m_i_cntl = TextEditingController(text: '100');
  final TextEditingController m_e_cntl = TextEditingController(text: '100');

  final _form_key = GlobalKey<FormState>();

  late Oscilloscope scopeOne;
  late Oscilloscope scopeTwo;

  restOscilloscope() {
    setState(() {
      i = 0;
      k = 0;
      traceSine = [];
      traceCosine = [];
    });
  }

  bool isNumeric(String s) {
    if (s == null) {
      return false;
    }
    return double.tryParse(s) != null;
  }

  // double generate_ideal_signal(int step) {
  //   step = step % (t_i + t_e + 2 * t_r);
  //   if (step < t_i)
  //     return -(m_i / t_i) * step;
  //   else if (t_i <= step && step < t_i + t_r)
  //     return 0;
  //   else if (t_i + t_r <= step && step < t_i + t_r + t_e)
  //     return (m_e / t_e) * (step - t_i - t_r);
  //   else
  //     return 0;
  // }



  double generate_ideal_signal(int step) {
    step = step % (t_i + t_e + 2 * t_r);
    if (step < t_i)
      return (m_i / t_i) * step - m_i;
    else if (t_i <= step && step < t_i + t_r)
      return 0;
    else if (t_i + t_r <= step && step < t_i + t_r + t_e)
      return -(m_e / t_e) * (step - t_i - t_r) + m_e;
    else
      return 0;
  }

  int last_t = 0;
  double last_s = 0;
  String _text = '';
  Color _color = Colors.white;
  String _img_path = 'assets/images/rest.png';

  bool _conn_status = false;
  late BluetoothConnection connection;
  listen_ble() async
  {
      if(_conn_status) {
        try {
          connection.input!.listen((Uint8List d) {
            double v = double.parse(
                ascii.decode(d).replaceAll(RegExp(r'[^0-9.\-]'), ''));
            print('Data incoming : $v');
            data.add(v);
          }).onDone(() {
            print('Disconnected by remote request');
            });
        }
        catch (exception) {
          print('Cannot connect, exception occured');
          setState(() {
            _conn_status = false;
          });
        }
      }
  }
  /// method to generate a Test  Wave Pattern Sets
  /// this gives us a value between +1  & -1 for sine & cosine
  _generateTrace(Timer t) {
    // generate our  values
    // var sv = sin((radians * pi));
    double sv = 0 ;
    if(data.length>0){
      // sv = data[0];
      // data.removeAt(0);
      sv = data.last;
    }
    k += 1;
    setState(() {
      _currentP = sv;
    });
    if (_maxP < _currentP)
      setState(() {
        _maxP = _currentP;
      });
    if (_minP > _currentP)
      setState(() {
        _minP = _currentP;
      });
    // var cv = cos((radians * pi));
    // var cv = 130 * sin((radians * pi));
    var cv = generate_ideal_signal(k * _timer_delay);

    try {
      double gradinet = (cv - last_s) / ((k * _timer_delay) - last_t);
      print(gradinet);
      if (gradinet < 0 && gradinet > -0.1) {
        setState(() {
          _text = 'Out';
          _color = Colors.lightGreen;
          _img_path = 'assets/images/exhale.png';
        });
        if (_old_speek != 'out') {
          _old_speek = 'out';
          _speak("Out");
        }
      } else if (gradinet > 0 && gradinet < 0.1) {
        setState(() {
          _text = 'In';
          _color = Colors.lightBlueAccent;
          _img_path = 'assets/images/inhale.png';
        });
        if (_old_speek != 'in') {
          _old_speek = 'in';
          _speak("in");
        }
      } else {
        setState(() {
          _text = 'Rest';
          _color = Colors.white;
          _img_path = 'assets/images/rest.png';
        });
        if (_old_speek != 'rest') {
          _old_speek = 'rest';
          _speak("rest");
        }
      }
      print(gradinet);
    } on Exception catch (_) {
      print('never reached');
    }

    last_t = k * _timer_delay;
    last_s = cv;
    // Add to the growing dataset
    setState(() {
      traceSine.add(sv);
      traceCosine.add(cv);
    });
  }

  @override
  initState() {
    super.initState();
    restOscilloscope();
    initTts();
 }

  @override
  void dispose() {
    _timer!.cancel();
    super.dispose();
    flutterTts.stop();
  }

  @override
  Widget build(BuildContext context) {
    // Create A Scope Display for Sine
    scopeOne = Oscilloscope(
      showYAxis: true,
      yAxisColor: Colors.orange,
      margin: EdgeInsets.all(20.0),
      strokeWidth: 3.0,
      backgroundColor: Colors.black,
      traceColor: Colors.green,
      yAxisMax: 150,
      yAxisMin: -150,
      dataSet: traceSine,
    );

    // Create A Scope Display for Cosine
    scopeTwo = Oscilloscope(
      showYAxis: true,
      margin: EdgeInsets.all(20.0),
      strokeWidth: 3.0,
      backgroundColor: Colors.black,
      traceColor: Colors.yellow,
      yAxisMax: 150.0,
      yAxisMin: -150.0,
      dataSet: traceCosine,
    );

    // Generate the Scaffold
    return Scaffold(
      appBar: AppBar(
        title: Text(_conn_status?"Brepal (Connected)":"Brepal(Disconnected)"),
        actions: [
          IconButton(
              onPressed: _conn_status? () async {
                if (!_play) {
                  await _speak("are you ready.");
                  _timer = Timer.periodic(
                      Duration(milliseconds: _timer_delay), _generateTrace);
                } else {
                  await _speak("Practice stopped");
                  _timer!.cancel();
                }
                setState(() {
                  _play = !_play;
                });
              }:null,
              icon: _play ? Icon(Icons.pause) : Icon(Icons.play_arrow)),
          IconButton(onPressed: showModal, icon: Icon(Icons.settings)),
          IconButton(onPressed: () async{
            if(_conn_status==false)
              {
                await Permission.bluetoothScan.request();
                try {
                  connection =
                  await BluetoothConnection.toAddress('00:22:06:01:10:4E');
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannoted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),backgroundColor: Colors.green,));
                  setState(() {
                    _conn_status = true;
                  });
                  listen_ble();
                }
                 catch (exception) {
                  print('Cannot connect, exception occured');
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot connect, exception occured',style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),backgroundColor: Colors.red,));
                  setState(() {
                    _conn_status = false;
                  });
                }
              }
            else{
              setState(() {
                _play = false;
              });
            }
          }, icon: _conn_status?Icon(Icons.bluetooth): Icon(Icons.bluetooth_disabled))
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
              flex: 1,
              child: Stack(children: [
                scopeOne,
                Positioned(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real Signal (Pressure)',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(
                        height: 2,
                      ),
                      Text(
                        'Current: $_currentP',
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(
                        height: 2,
                      ),
                      Text(
                        'Max: $_maxP',
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(
                        height: 2,
                      ),
                      Text(
                        'Min: $_minP',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  left: 10,
                  top: 10,
                )
              ])),
          Expanded(
            flex: 1,
            child: Stack(children: [
              scopeTwo,
              Positioned(
                left: 10,
                top: 10,
                child: Text(
                  'Pattern Signal',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              (_text != '')
                  ? Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 50,
                        height: 20,
                        child: Center(
                          child: Text(
                            _text,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        decoration: BoxDecoration(
                            color: _color,
                            borderRadius: BorderRadius.circular(5)),
                      ))
                  : Text(''),
              Positioned(
                  bottom: 10,
                  right: 30,
                  child: CircleAvatar(
                    radius: 25,
                    foregroundImage: AssetImage(_img_path),
                  ))
            ]),
          ),
        ],
      ),
    );
  }

  showModal() {
    return showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Form(
              key: _form_key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: Icon(Icons.timer),
                    title: Text('Inhale Duration (Seconds)'),
                    trailing: SizedBox(
                        width: 50,
                        child: TextFormField(
                          controller: t_i_cntl,
                          onTap: () => t_i_cntl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: t_i_cntl.value.text.length),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                  borderRadius: BorderRadius.circular(10))),
                          validator: (val) {
                            if (val!.trim().length == 0 ||
                                isNumeric(val) == false) return 'Error';
                            return null;
                          },
                          onSaved: (val) => t_i = int.parse(val!) * 1000,
                        )),
                  ),
                  ListTile(
                    leading: Icon(Icons.timer),
                    title: Text('Exhale Duration (Seconds)'),
                    trailing: SizedBox(
                        width: 50,
                        child: TextFormField(
                          controller: t_e_cntl,
                          keyboardType: TextInputType.number,
                          onTap: () => t_e_cntl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: t_e_cntl.value.text.length),
                          decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                  borderRadius: BorderRadius.circular(10))),
                          validator: (val) {
                            if (val!.trim().length == 0 ||
                                isNumeric(val) == false) return 'Error';
                            return null;
                          },
                          onSaved: (val) => t_e = int.parse(val!) * 1000,
                        )),
                  ),
                  ListTile(
                    leading: Icon(Icons.timer),
                    title: Text('Rest Duration (Seconds)'),
                    trailing: SizedBox(
                        width: 50,
                        child: TextFormField(
                          controller: t_r_cntl,
                          keyboardType: TextInputType.number,
                          onTap: () => t_r_cntl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: t_r_cntl.value.text.length),
                          decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                  borderRadius: BorderRadius.circular(10))),
                          validator: (val) {
                            if (val!.trim().length == 0 ||
                                isNumeric(val) == false) return 'Error';
                            return null;
                          },
                          onSaved: (val) => t_r = int.parse(val!) * 1000,
                        )),
                  ),
                  ListTile(
                    leading: Icon(Icons.vertical_align_top),
                    title: Text('Max Inahle Pressure:'),
                    trailing: SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: m_i_cntl,
                          keyboardType: TextInputType.number,
                          onTap: () => m_i_cntl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: m_i_cntl.value.text.length),
                          decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                  borderRadius: BorderRadius.circular(10))),
                          validator: (val) {
                            if (val!.trim().length == 0 ||
                                isNumeric(val) == false) return 'Error';
                            return null;
                          },
                          onSaved: (val) => m_i = int.parse(val!),
                        )),
                  ),
                  ListTile(
                    leading: Icon(Icons.vertical_align_bottom),
                    title: Text('Max Exhale Pressure:'),
                    trailing: SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: m_e_cntl,
                          keyboardType: TextInputType.number,
                          onTap: () => m_e_cntl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: m_e_cntl.value.text.length),
                          decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.blue),
                                  borderRadius: BorderRadius.circular(10))),
                          validator: (val) {
                            if (val!.trim().length == 0 ||
                                isNumeric(val) == false) return 'Error';
                            return null;
                          },
                          onSaved: (val) => m_e = int.parse(val!),
                        )),
                  ),
                  ElevatedButton(
                      onPressed: () {
                        if (_form_key.currentState!.validate()) {
                          _form_key.currentState!.save();
                          _timer!.cancel();
                          restOscilloscope();

                          _timer = Timer.periodic(
                              Duration(milliseconds: _timer_delay),
                              _generateTrace);
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text('Reset'))
                ],
              ),
            ),
          );
        });
  }
}
