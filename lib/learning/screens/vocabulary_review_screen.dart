import 'package:flutter/material.dart';

import '../services/vocabulary_store.dart';

class VocabularyReviewScreen extends StatefulWidget {
  const VocabularyReviewScreen({super.key});

  @override
  State<VocabularyReviewScreen> createState() => _VocabularyReviewScreenState();
}

class _VocabularyReviewScreenState extends State<VocabularyReviewScreen> {
  List<VocabularyItem> _due = const [];
  bool _loading = true;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final due = await VocabularyStore.due();
    if (!mounted) return;
    setState(() {
      _due = due;
      _loading = false;
      _revealed = false;
    });
  }

  Future<void> _grade(VocabularyGrade grade) async {
    if (_due.isEmpty) return;
    await VocabularyStore.review(_due.first.key, grade);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Review')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _due.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 64, color: Colors.greenAccent),
                        SizedBox(height: 14),
                        Text('You are done for now', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        SizedBox(height: 6),
                        Text('Tap words while watching to build your personal vocabulary.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${_due.length} due today', style: const TextStyle(color: Colors.white54)),
                      ),
                      const Spacer(),
                      Text(_due.first.word, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Text(_due.first.context, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 16)),
                      const SizedBox(height: 22),
                      if (_revealed)
                        Text(_due.first.meaning, textAlign: TextAlign.center, style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 26, fontWeight: FontWeight.w700))
                      else
                        FilledButton.icon(onPressed: () => setState(() => _revealed = true), icon: const Icon(Icons.visibility_rounded), label: const Text('Reveal meaning')),
                      const Spacer(),
                      if (_revealed)
                        Row(
                          children: [
                            Expanded(child: _gradeButton('Again', VocabularyGrade.again, Colors.redAccent)),
                            const SizedBox(width: 6),
                            Expanded(child: _gradeButton('Hard', VocabularyGrade.hard, Colors.orangeAccent)),
                            const SizedBox(width: 6),
                            Expanded(child: _gradeButton('Good', VocabularyGrade.good, Colors.lightBlueAccent)),
                            const SizedBox(width: 6),
                            Expanded(child: _gradeButton('Easy', VocabularyGrade.easy, Colors.greenAccent)),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _gradeButton(String label, VocabularyGrade grade, Color color) => OutlinedButton(
        style: OutlinedButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4)),
        onPressed: () => _grade(grade),
        child: Text(label),
      );
}
