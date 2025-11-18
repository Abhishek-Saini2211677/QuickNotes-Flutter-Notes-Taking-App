import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const QuickNotesApp());
}

class QuickNotesApp extends StatelessWidget {
  const QuickNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotesModel()..loadNotes(),
      child: MaterialApp(
        title: 'QuickNotes',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
        ),
        home: const NotesHomePage(),
      ),
    );
  }
}

class Note {
  String id;
  String title;
  String content;
  int colorValue;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.colorValue,
    required this.updatedAt,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      colorValue: map['colorValue'] ?? 0xFFFFFFFF,
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'colorValue': colorValue,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class NotesModel extends ChangeNotifier {
  static const _kNotesKey = 'quicknotes_notes';
  List<Note> notes = [];
  String _query = '';

  List<Note> get filtered {
    if (_query.isEmpty) return notes;
    final q = _query.toLowerCase();
    return notes.where((n) => n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q)).toList();
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  Future<void> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNotesKey);
    if (raw != null) {
      final List parsed = jsonDecode(raw);
      notes = parsed.map((e) => Note.fromMap(Map<String, dynamic>.from(e))).toList();
    } else {
      notes = [];
    }
    notifyListeners();
  }

  Future<void> saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(notes.map((n) => n.toMap()).toList());
    await prefs.setString(_kNotesKey, raw);
  }

  Future<void> addOrUpdate(Note note) async {
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index == -1) {
      notes.insert(0, note);
    } else {
      notes[index] = note;
    }
    await saveNotes();
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    notes.removeWhere((n) => n.id == id);
    await saveNotes();
    notifyListeners();
  }
}

class NotesHomePage extends StatelessWidget {
  const NotesHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<NotesModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickNotes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: model.setQuery,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ),
      body: model.filtered.isEmpty
          ? const Center(child: Text('No notes yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: model.filtered.length,
              itemBuilder: (context, i) {
                final note = model.filtered[i];
                return Dismissible(
                  key: Key(note.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => model.deleteNote(note.id),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ListTile(
                    tileColor: Color(note.colorValue),
                    title: Text(note.title),
                    subtitle: Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => NoteEditor(note: note)),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final newNote = Note(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: '',
            content: '',
            colorValue: Colors.white.value,
            updatedAt: DateTime.now(),
          );
          Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditor(note: newNote)));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class NoteEditor extends StatefulWidget {
  final Note note;
  const NoteEditor({required this.note, super.key});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  int _color = Colors.white.value;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);
    _contentCtrl = TextEditingController(text: widget.note.content);
    _color = widget.note.colorValue;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.read<NotesModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              final updated = Note(
                id: widget.note.id,
                title: _titleCtrl.text.trim().isEmpty ? 'Untitled' : _titleCtrl.text.trim(),
                content: _contentCtrl.text,
                colorValue: _color,
                updatedAt: DateTime.now(),
              );
              await model.addOrUpdate(updated);
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Container(
        color: Color(_color),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _contentCtrl,
                decoration: const InputDecoration(hintText: 'Write your note...'),
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Color:'),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 8,
                  children: [Colors.white, Colors.yellow.shade100, Colors.green.shade50, Colors.blue.shade50]
                      .map((c) => GestureDetector(
                            onTap: () => setState(() => _color = c.value),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: c,
                                border: Border.all(color: Colors.grey),
                                shape: BoxShape.rectangle,
                              ),
                              child: _color == c.value ? const Icon(Icons.check) : null,
                            ),
                          ))
                      .toList(),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
