import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Fonction servant à récupérer le fichier Json
Future<List<CountryCode>> fetchCountryCode(http.Client client) async {
  final response = await client
      .get(Uri.parse('./../indicatifsInternationaux.json'),
      headers: {"Content-Type": "application/json"});

  if(response.statusCode == 200){
    // On exécute la fonction parseCountryCode dans un Isolate séparé
    return compute(parseCountryCode, utf8.decode(response.bodyBytes));
  }else{
    throw Exception('Impossible de charger le fichier JSON.');
  }
}

// Fonction servant à convertir la réponse obtenue en parsant le Json en une liste.
List<CountryCode> parseCountryCode(String responseBody) {
  final parsed = jsonDecode(responseBody).cast<Map<String, dynamic>>();

  return parsed.map<CountryCode>((json) => CountryCode.fromJson(json)).toList();
}

// Fonction servant à récupérer le pays lié à l'indicatif du numéro de téléphone
List<CountryCode> getCountry(String phoneNumber, List<CountryCode> countryCode){
  int i = 7;
  List<CountryCode> temp = [];

  do{
    temp = countryCode.where((e) => e.indicatif.toString() == phoneNumber.substring(0,i)).toList();
    i--;
  }while(temp.isEmpty && i>=2);

  if(temp.isEmpty){
    temp.add(CountryCode(indicatif: 0, pays: "Inexistant"));
  }

  return temp;
}

// Fonction servant à récupérer le pays lié à l'indicatif de la carte SIM
List<CountryCode> getCountryFromSIM(String SIMNumber, List<CountryCode> countryCode){
  List<CountryCode> temp = [];

  if(SIMNumber.startsWith("7")){
    temp.add(CountryCode(indicatif: 7, pays: "Russie/Kasakhstan"));
  }else if(SIMNumber.startsWith("39")){
    temp.add(CountryCode(indicatif: 39, pays: "Italie"));
  }else if(SIMNumber.startsWith("1")){
    temp.add(CountryCode(indicatif: 1, pays: "Amérique du Nord"));
  }else if(SIMNumber.startsWith("47")){
    temp.add(CountryCode(indicatif: 47, pays: "Norvège"));
  }else{
    temp = getCountry(SIMNumber, countryCode);
  }

  return temp;
}

// Fonction servant à connaître la couleur à afficher en fonction du résultat
Color getColor(List<CountryCode> list){
  if(list[0].pays == "Inexistant"){
    return Colors.red;
  }else return Colors.green;
}

// Classe définissant un code pays, comprenant un indicatif et un pays
class CountryCode {
  final int indicatif;
  final String pays;

  CountryCode({required this.indicatif, required this.pays});

  factory CountryCode.fromJson(Map<String, dynamic> json) {
    return CountryCode(
      indicatif: json['Indicatif'] as int,
      pays: json['Pays'] as String,
    );
  }
}

// Fonction principale du programme
void main() => runApp(MyApp());

// Classe de départ pour afficher l'application
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appTitle = "Pays d'un numéro de téléphone ou d'une carte SIM";

    return MaterialApp(
      title: appTitle,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: appTitle),
    );
  }
}

// Classe Stateful pour gérer la récupération et le parsing du fichier Json
class MyHomePage extends StatefulWidget{
  final String title;

  MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

// Classe d'état pour gérer la récupération et le parsing du fichier Json
class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: FutureBuilder<List<CountryCode>>(
        future: fetchCountryCode(http.Client()),
        builder: (context, AsyncSnapshot snapshot) {
          if(snapshot.hasError){
            print(snapshot.error);
            return Container();
          }else if(snapshot.hasData){
            return CountryCodeList(countryCode: snapshot.data);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

// Classe Stateful pour afficher l'application une fois le parsing du fichier Json réussi
class CountryCodeList extends StatefulWidget{
  final List<CountryCode> countryCode;

  CountryCodeList({Key? key, required this.countryCode}) : super(key: key);

  @override
  _CountryCodeListState createState() => _CountryCodeListState(countryCode: countryCode);
}

// Classe d'état pour afficher l'application une fois le parsing du fichier Json réussi
class _CountryCodeListState extends State<CountryCodeList> {
  final List<CountryCode> countryCode;

  _CountryCodeListState({Key? key, required this.countryCode}) : super();

  /// On définit les contrôleurs de texte et de formulaire
  final phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// On définit les expressions régulières
  static Pattern patternPhoneNumber = r"\(?[0-9]{1,3}\)? ?-?[0-9]{1,3} ?-?[0-9]{3,5} ?-?[0-9]{4}( ?-?[0-9]{3})?";
  static RegExp regexPhoneNumber = new RegExp(patternPhoneNumber.toString());
  static Pattern patternICCID = r"^89[1-9][0-9]{16,19}$";
  static RegExp regexICCID = new RegExp(patternICCID.toString());

  bool showResult = false; /// Booléen pour afficher le résultat ou non
  String phoneNumber = ""; /// Numéro de téléphone entré
  String country = ""; /// Résultat à afficher
  List<CountryCode> result = [];

  /// Variables d'affichage de l'application
  int? _radioValue = 0;
  String _displayStartText = "";
  String _displayInputText = "";
  String _displayErrorText = "";

  /// On initialise l'état de l'application
  void initState(){
    _handleRadioValueChange(_radioValue);
    super.initState();
  }

  /// Lorsqu'on clique sur le bouton effacer
    void _erase(){
      setState((){
        showResult = false;
        phoneController.text = "";
      });
    }

    /// Lorsqu'on clique sur le bouton valider
    void _validate(){
      if(_formKey.currentState!.validate()){
        setState(() {
          phoneNumber = phoneController.text;
          if(_radioValue == 1){
            result = getCountryFromSIM(phoneNumber.substring(2), countryCode); /// On supprime, lorsqu'il s'agit d'une carte SIM, les 2 premiers caractères
          }else {
            result = getCountry(phoneNumber, countryCode);
          }
          showResult = true;
        });
      }else{
        setState((){
          showResult = false;
        });
      }
    }

  /// Lorsqu'un bouton radio est modifié
  void _handleRadioValueChange(int? value){
    setState((){
      _radioValue = value;
      showResult = false;

      switch(_radioValue){
        case 0:
          _displayStartText = "Entrez un numéro de téléphone";
          _displayInputText = "Numéro de téléphone";
          _displayErrorText = "Entrez un numéro de téléphone au format valide";
          break;
        case 1:
          _displayStartText = "Entrez un numéro de carte SIM";
          _displayInputText = "Numéro de carte SIM";
          _displayErrorText = "Entrez un numéro de carte SIM au format valide";
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
            Radio(
              value: 0,
              groupValue: _radioValue,
              activeColor: Colors.blue,
              onChanged: (int? value) {
                _handleRadioValueChange(value);
              }
          ),
          Text("Numéro de téléphone"),
          Radio(
            value: 1,
            groupValue: _radioValue,
            activeColor: Colors.blue,
            onChanged: (int? value) {
              _handleRadioValueChange(value);
            }
          ),
          Text("Numéro de carte SIM"),
          ]),
          Text(_displayStartText),
          Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                ),
                TextFormField(
                  keyboardType: TextInputType.number,
                  controller: phoneController,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                      labelText: _displayInputText
                  ),
                  validator: (value){
                    if(value != null) {
                      if (value.isEmpty) {
                        return _displayStartText;
                      } else if (_radioValue == 0 &&
                          !regexPhoneNumber.hasMatch(value)) {
                        return _displayErrorText;
                      } else
                      if (_radioValue == 1 && !regexICCID.hasMatch(value)) {
                        return _displayErrorText;
                      }
                      return null;
                    }
                  },
                ),
                SizedBox(height: 5), /// On ajoute un espacement en hauteur
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: (){
                        _validate();
                      },
                      child: Text("Valider"),
                    ),
                    SizedBox(width: 5), /// On ajoute un espacement entre les 2 boutons
                    ElevatedButton(
                      onPressed: (){
                        _erase();
                      },
                      child: Text("Effacer"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          showResult ? DataTable( /// Si un résultat doit être affiché
            columns: <DataColumn>[
              DataColumn(
                label: Text(
                    _displayInputText
                ),
              ),
              DataColumn(
                label: Text(
                    "Pays"
                ),
              ),
            ],
            rows: <DataRow>[
              DataRow(
                cells: <DataCell>[
                  DataCell(Text(phoneNumber, style: TextStyle(color: getColor(result)))),
                  DataCell(Text(result[0].pays, style: TextStyle(color: getColor(result)))),
                ],
              ),
            ],
          ) : SizedBox(), /// Si aucun résultat ne doit être affiché
        ],
      ),// This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
