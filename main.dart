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
  List<CountryCode> temp;

  do{
    temp = countryCode.where((e) => e.indicatif.toString() == phoneNumber.substring(0,i)).toList();
    i--;
  }while(temp.isEmpty && i>=2);

  if(temp.isEmpty){
    temp.add(CountryCode(pays: "Inexistant"));
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

  CountryCode({this.indicatif, this.pays});

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
    final appTitle = "Pays d'un numéro de téléphone";

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

  MyHomePage({Key key, this.title}) : super(key: key);

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
        builder: (context, snapshot) {
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

  CountryCodeList({Key key, this.countryCode}) : super(key: key);

  @override
  _CountryCodeListState createState() => _CountryCodeListState(countryCode: countryCode);
}

// Classe d'état pour afficher l'application une fois le parsing du fichier Json réussi
class _CountryCodeListState extends State<CountryCodeList> {
  final List<CountryCode> countryCode;

  _CountryCodeListState({Key key, this.countryCode}) : super();

  /// On définit les contrôleurs de texte et de formulaire
  final phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// On définit les expressions régulières
  static Pattern patternPhoneNumber = r"\(?[0-9]{1,3}\)? ?-?[0-9]{1,3} ?-?[0-9]{3,5} ?-?[0-9]{4}( ?-?[0-9]{3})?";
  static RegExp regexPhoneNumber = new RegExp(patternPhoneNumber);

  bool showResult = false; /// Booléen pour afficher le résultat ou non
  String phoneNumber = ""; /// Numéro de téléphone entré
  String country = ""; /// Résultat à afficher
  List<CountryCode> result;

  void initState(){
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text("Entrez un numéro de téléphone"),
          Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                TextFormField(
                  keyboardType: TextInputType.number,
                  controller: phoneController,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: "Numéro de téléphone"
                  ),
                  validator: (value){
                    if(value.isEmpty){
                      return "Entrez un numéro de téléphone";
                    }else if(!regexPhoneNumber.hasMatch(value)){
                      return "Entrez un numéro de téléphone au format valide";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 5), /// On ajoute un espacement en hauteur
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: (){
                        if(_formKey.currentState.validate()){
                          setState(() {
                            phoneNumber = phoneController.text;
                            result = getCountry(phoneNumber, countryCode);
                            showResult = true;
                          });
                        }
                      },
                      child: Text("Valider"),
                    ),
                    SizedBox(width: 5), /// On ajoute un espacement entre les 2 boutons
                    ElevatedButton(
                      onPressed: (){
                        setState(() {
                          showResult = false;
                          phoneController.text = "";
                        });
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
                    "Numéro de téléphone"
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