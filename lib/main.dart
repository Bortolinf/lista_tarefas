import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';

void main() {
  runApp(MaterialApp(
    home: Home(),
  ));
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _toDoController = TextEditingController();
  List _toDoList = [];
  Map<String, dynamic> _lastRemoved;
  int _lastRemovedPos;

  @override //  aqui estamos reescrevendo o metodo initState p/dizer o que fazer qdo entrar na bagaça
  void initState() {
    super.initState();
    // a funcao _readData é do tipo Future, por isso foi incluido o then
    // que ira receber uma string qdo terminar, depois executar a função
    // que atribui o resultado p/dentro da lista _toDoList e isto dentro de
    // um setState, que é para fazer a reexibição da tela.
    _readData().then((dados) {
      setState(() {
        _toDoList = json.decode(dados);
      });
    });
  }

  void _addToDo() {
    setState(() {
      if (_toDoController.text != '') {
        Map<String, dynamic> newToDo = Map();
        newToDo["title"] = _toDoController.text;
        _toDoController.text = "";
        newToDo["ok"] = false;
        _toDoList.add(newToDo);
        _saveData();
        // esconde o teclado
        FocusScope.of(context).requestFocus(new FocusNode());
        
      } else  // texto em branco da um vibrada de avertencia
      {
        if (Vibration.hasVibrator() != null){
          Vibration.vibrate(duration: 200);
        }
      }
    });
  }

  // funcao para fazer a ordenacao das tarefas
  // primeiro as não concluidas e depois as concluidas
  // o método sort faz isso - retorno -1 joga item p/cima e retorno 1 joga p/baixo
  Future<Null> _refresh() async {
    // faz uma espera de 1 segundo
    await Future.delayed(Duration(seconds: 1));
    setState(() {
      _toDoList.sort((a, b) {
        if (a["ok"] && !b["ok"])
          return 1;
        else if (!a["ok"] && b["ok"])
          return -1;
        else
          return 0;
      });
      _saveData();
    });

    return null;
  }


  // solicita a confirmação p/excluir TODAS tarefas
  Future<void> _confirmarDeleteAll() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
         // title: Text('Confirmar'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Quer mesmo excluir Tudo?')
              ],)
             ,),
             actions: <Widget>[
               FlatButton(
                 child: Text('Sim'),
                 onPressed: (){
                   Navigator.of(context).pop();
                   _deleteAll();
                 },
               ),
               FlatButton(
                 child: Text('Não'),
                 onPressed: (){
                   Navigator.of(context).pop();
                 },
               ),
             ],
        );
      }
    );
  }





  //  função para excluir TODAS tarefas
  void _deleteAll() {
    setState(() {
         _toDoList.clear();
    _saveData();  
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Lista de Tarefas"),
          backgroundColor: Colors.blueAccent,
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.delete_forever),
              onPressed: (){
               //  _deleteAll();
               _confirmarDeleteAll();
              }
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Container(
              padding: EdgeInsets.fromLTRB(17.0, 1.0, 7.0, 1.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    // faz o campo de texto utilizar a largura máxima
                    child: TextField(
                      controller: _toDoController,
                      decoration: InputDecoration(
                          labelText: "Nova Tarefa",
                          labelStyle: TextStyle(color: Colors.blueAccent)),
                    ),
                  ),
                  RaisedButton(
                    color: Colors.blueAccent,
                    child: Text("Incluir"),
                    textColor: Colors.white,
                    onPressed: _addToDo,
                  )
                ],
              ),
            ),
            Expanded(
                child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                padding: EdgeInsets.only(top: 10.0),
                itemCount: _toDoList.length,
                itemBuilder: montarItem,
              ),
            ))
          ],
        ));
  }

// funcao que monta o item do listview
// dismissible - componente que permite arrastar
  Widget montarItem(context, index) {
    return Dismissible(
      key: Key(DateTime.now().millisecondsSinceEpoch.toString()),
      background: Container(
        color: Colors.red,
        child: Align(
          alignment: Alignment(-0.9, 0.0),
          child: Icon(Icons.delete, color: Colors.white),
        ),
      ),
      direction: DismissDirection.startToEnd,
      child: CheckboxListTile(
        title: Text(_toDoList[index]["title"]),
        value: _toDoList[index]["ok"],
        secondary: CircleAvatar(
          child: Icon(_toDoList[index]["ok"]
              ? // aqui foi usado um if na forma abreviada
              Icons.check
              : Icons.error),
        ),
        onChanged: (c) {
          setState(() {
            _toDoList[index]["ok"] = c;
            _saveData();
          });
        },
      ),
      //  evento de quando deslizar p/o lado para excluir a tarefa
      onDismissed: (direction) {
        setState(() {
          _lastRemoved = Map.from(_toDoList[index]);
          _lastRemovedPos = index;
          _toDoList.removeAt(index);
          _saveData();
          // mostrar snack bar para desfazer a exclusao
          final snack = SnackBar(
            content: Text("Tarefa \"${_lastRemoved["title"]}\" removida!"),
            action: SnackBarAction(
              label: "Desfazer",
              onPressed: () {
                setState(() {
                  _toDoList.insert(_lastRemovedPos, _lastRemoved);
                  _saveData();
                });
              },
            ),
            duration: Duration(seconds: 5),
          );

          // faz a exibicao da SnackBar
          Scaffold.of(context).removeCurrentSnackBar();
          Scaffold.of(context).showSnackBar(snack);
        });
      },
    );
  }

// funcao para retornar o nome do arquivo que vai conter os dados salvos.
  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File("${directory.path}/dadosB.json");
  }

// funcao para salvar os dados
  Future<File> _saveData() async {
    String data = json.encode(_toDoList);
    final file = await _getFile();
    return file.writeAsString(data);
  }

// função para retornar os dados salvos
  Future<String> _readData() async {
    try {
      final file = await _getFile();
      return file.readAsString();
    } catch (e) {
      return null;
    }
  }
} //fim da porra toda
