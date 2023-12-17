import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:todolist_firebase/model/item_list.dart';
import 'package:flutter/material.dart';
import 'package:todolist_firebase/model/todo.dart';
import 'package:todolist_firebase/view/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  
  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Logger _logger = Logger('_HomePageState');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool isComplete = false;

  Future<void> _signOut() async {
    await _auth.signOut();
    runApp( const MaterialApp(
      home: LoginPage(),
    ));
  }

  Future<QuerySnapshot>? searchResultsFuture;

  Future<void> searchResult(String textEntered) async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection("Todos")
        .where("title", isGreaterThanOrEqualTo: textEntered)
        .where("title", isLessThan: textEntered)
        .get();

    setState(() {
      searchResultsFuture = Future.value(querySnapshot);
    });
  }

  void cleartext() {
    _titleController.clear();
    _descriptionController.clear();
  }

  @override
  void initState() {
    super.initState();
    getTodo();
  }

  List<Todo> _listTodo = [];

  Future<void> getTodo() async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        QuerySnapshot<Map<String, dynamic>> querySnapshot = await _firestore
            .collection('Todos')
            .where('uid', isEqualTo: user.uid)
            .get();

        List<Todo> listTodo = querySnapshot.docs.map((document) {
          final data = document.data();
          final String title = data['title'];
          final String description = data['description'];
          final bool isComplete = data['isComplete'];
          final String uid = user.uid;

          return Todo(
            description: description,
            title: title,
            isComplete: isComplete,
            uid: uid,
          );
        }).toList();

        // Lakukan logika atau perbarui keadaan widget berdasarkan data yang diambil.
        setState(() {
          // Simpan listTodo ke dalam variabel di state
          _listTodo = listTodo;
        });

        for (var todo in _listTodo) {
          _logger.info('Todo title: ${todo.title}');
        }
      }
    } catch (error) {
      _logger.info('Gagal mendapatkan data tugas: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    CollectionReference todoCollection = _firestore.collection('Todos');
    final User? user = _auth.currentUser;

    Future<void> addTodo() {
      return todoCollection.add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'isComplete': isComplete,
        'uid': _auth.currentUser!.uid,
        // ignore: invalid_return_type_for_catch_error
      }).catchError((error) => _logger.info('Failed to add todo: $error'));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Todo List'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Apakah anda yakin ingin logout?'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Tidak'),
                    ),
                    TextButton(
                      onPressed: () {
                        _signOut();
                      },
                      child: const Text('Ya'),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            child: TextField(
              decoration: const InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder()),
              onChanged: (textEntered) {
                searchResult(textEntered);

                setState(() {
                  _searchController.text = textEntered;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _searchController.text.isEmpty
                    ? _firestore
                        .collection('Todos')
                        .where('uid', isEqualTo: user!.uid)
                        .snapshots()
                    : searchResultsFuture != null
                        ? searchResultsFuture!
                            .asStream()
                            .cast<QuerySnapshot<Map<String, dynamic>>>()
                        : const Stream.empty(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  List<Todo> listTodo = snapshot.data!.docs.map((document) {
                    final data = document.data();
                    final String title = data['title'];
                    final String description = data['description'];
                    final bool isComplete = data['isComplete'];
                    final String uid = user!.uid;

                    return Todo(
                        description: description,
                        title: title,
                        isComplete: isComplete,
                        uid: uid);
                  }).toList();
                  return ListView.builder(
                      shrinkWrap: true,
                      itemCount: listTodo.length,
                      itemBuilder: (context, index) {
                        return ItemList(
                          todo: listTodo[index],
                          transaksiDocId: snapshot.data!.docs[index].id,
                        );
                      });
                }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Tambah Todo'),
              content: SizedBox(
                width: 200,
                height: 100,
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(hintText: 'Judul todo'),
                    ),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(hintText: 'Deskripsi todo'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Batalkan'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: const Text('Tambah'),
                  onPressed: () {
                    addTodo();
                    cleartext();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}