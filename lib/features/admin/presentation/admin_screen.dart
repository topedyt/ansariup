import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../library/library_providers.dart'; // Access to supabaseClientProvider

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- QUESTION MANAGEMENT STATE ---
  int? _selectedSubjectId;
  int? _selectedChapterId;
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _chapters = [];
  List<Map<String, dynamic>> _existingQuestions = [];

  bool _isLoadingDropdowns = false;
  bool _isLoadingQuestions = false;

  // Form Controllers
  final _questionController = TextEditingController();
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _optionCController = TextEditingController();
  final _optionDController = TextEditingController();
  final _explanationController = TextEditingController();
  final _pyqController = TextEditingController();

  String _correctOption = 'A';
  bool _isPaid = false;
  bool _isSubmitting = false;
  bool _isImporting = false; // State for bulk import

  // EDIT MODE STATE
  int? _editingQuestionId;

  // --- REPORTED QUESTIONS STATE ---
  List<Map<String, dynamic>> _reportedQuestions = [];
  bool _isLoadingReports = false;

  // --- DAILY WISDOM STATE ---
  final _quoteController = TextEditingController();
  bool _isPostingQuote = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchSubjects();
    _fetchLatestQuote();
    _fetchReportedQuestions();
  }

  // ====================================================
  //  TAB 1: QUESTION MANAGER LOGIC
  // ====================================================

  Future<void> _fetchSubjects() async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final data =
          await supabase.from('subjects').select('id, title').order('title');
      if (mounted) {
        setState(() {
          _subjects = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showSnackBar("Error fetching subjects: $e", isError: true);
    }
  }

  Future<void> _fetchChapters(int subjectId) async {
    setState(() {
      _isLoadingDropdowns = true;
      _chapters = [];
      _selectedChapterId = null;
      _existingQuestions = [];
    });

    final supabase = ref.read(supabaseClientProvider);
    try {
      final data = await supabase
          .from('chapters')
          .select('id, title')
          .eq('subject_id', subjectId)
          .order('title');

      if (mounted) {
        setState(() {
          _chapters = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showSnackBar("Error fetching chapters: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingDropdowns = false);
    }
  }

  Future<void> _fetchQuestionsForChapter(int chapterId) async {
    setState(() => _isLoadingQuestions = true);
    final supabase = ref.read(supabaseClientProvider);
    try {
      final data = await supabase
          .from('questions')
          .select()
          .eq('chapter_id', chapterId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _existingQuestions = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showSnackBar("Error loading questions: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingQuestions = false);
    }
  }

  // --- CRUD OPERATIONS ---

  Future<void> _upsertQuestion() async {
    if (_selectedChapterId == null && _editingQuestionId == null) {
      _showSnackBar("Select a chapter first.", isError: true);
      return;
    }
    if (_questionController.text.isEmpty) {
      _showSnackBar("Question text is empty.", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    final supabase = ref.read(supabaseClientProvider);

    try {
      final pyqYear = _pyqController.text.trim().isEmpty
          ? null
          : _pyqController.text.trim();

      final data = {
        'question_text': _questionController.text.trim(),
        'option_a': _optionAController.text.trim(),
        'option_b': _optionBController.text.trim(),
        'option_c': _optionCController.text.trim(),
        'option_d': _optionDController.text.trim(),
        'correct_option': _correctOption,
        'explanation': _explanationController.text.trim(),
        'is_paid': _isPaid,
        'pyq_year': pyqYear,
      };

      if (_selectedChapterId != null) {
        data['chapter_id'] = _selectedChapterId;
      }

      if (_editingQuestionId == null) {
        if (_selectedChapterId == null)
          throw "Chapter ID missing for new question";
        data['chapter_id'] = _selectedChapterId;
        await supabase.from('questions').insert(data);
        _showSnackBar("Question Added Successfully!");
      } else {
        await supabase
            .from('questions')
            .update(data)
            .eq('id', _editingQuestionId!);
        _showSnackBar("Question Updated!");
      }

      _clearForm();
      if (_selectedChapterId != null) {
        _fetchQuestionsForChapter(_selectedChapterId!);
      }
      _fetchReportedQuestions();
    } catch (e) {
      _showSnackBar("Operation failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteQuestion(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Question?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase.from('questions').delete().eq('id', id);
      _showSnackBar("Question Deleted.");
      if (_selectedChapterId != null) {
        _fetchQuestionsForChapter(_selectedChapterId!);
      }
      _fetchReportedQuestions();
    } catch (e) {
      _showSnackBar("Delete failed: $e", isError: true);
    }
  }

  // --- BULK IMPORT LOGIC ---

  void _showBulkImportDialog(String type) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Bulk Import $type"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type == 'Chapters'
                    ? "Format: One title per line.\nExample:\nChapter 1\nChapter 2"
                    : "Format (CSV): question, A, B, C, D, correct(A/B/C/D), explanation, paid(true/false), pyq\n\nExample:\nWhat is 2+2?, 1, 2, 4, 5, C, Math rule, false, 2022",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: "Paste CSV/Text content here...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (textController.text.trim().isNotEmpty) {
                if (type == 'Chapters') {
                  _processBulkChapters(textController.text);
                } else {
                  _processBulkQuestions(textController.text);
                }
              }
            },
            child: const Text("Import"),
          ),
        ],
      ),
    );
  }

  // Custom CSV Parser to handle quotes and commas
  List<List<String>> _parseCsv(String input) {
    final List<List<String>> result = [];
    final lines = input.split(RegExp(r'\r\n|\r|\n'));

    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      
      List<String> row = [];
      StringBuffer buffer = StringBuffer();
      bool inQuotes = false;
      
      for (int i = 0; i < line.length; i++) {
        String char = line[i];
        if (char == '"') {
          inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
          row.add(buffer.toString().trim());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
      row.add(buffer.toString().trim());
      result.add(row);
    }
    return result;
  }

  Future<void> _processBulkChapters(String text) async {
    if (_selectedSubjectId == null) return;
    setState(() => _isImporting = true);
    final supabase = ref.read(supabaseClientProvider);

    try {
      final lines = text.split('\n');
      final List<Map<String, dynamic>> records = [];
      
      for (var line in lines) {
        if (line.trim().isNotEmpty) {
          records.add({
            'subject_id': _selectedSubjectId,
            'title': line.trim(),
          });
        }
      }

      if (records.isNotEmpty) {
        await supabase.from('chapters').insert(records);
        _showSnackBar("Imported ${records.length} chapters!");
        _fetchChapters(_selectedSubjectId!);
      }
    } catch (e) {
      _showSnackBar("Import failed: $e", isError: true);
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _processBulkQuestions(String csvText) async {
    if (_selectedChapterId == null) return;
    setState(() => _isImporting = true);
    final supabase = ref.read(supabaseClientProvider);

    try {
      final rows = _parseCsv(csvText);
      final List<Map<String, dynamic>> records = [];

      for (var row in rows) {
        // Basic validation: need at least Question + 4 options + correct
        if (row.length < 6) continue; 

        records.add({
          'chapter_id': _selectedChapterId,
          'question_text': row[0],
          'option_a': row[1],
          'option_b': row[2],
          'option_c': row[3],
          'option_d': row[4],
          'correct_option': row[5].toUpperCase(),
          'explanation': (row.length > 6) ? row[6] : '',
          'is_paid': (row.length > 7) ? (row[7].toLowerCase() == 'true') : false,
          'pyq_year': (row.length > 8 && row[8].isNotEmpty) ? row[8] : null,
        });
      }

      if (records.isNotEmpty) {
        await supabase.from('questions').insert(records);
        _showSnackBar("Imported ${records.length} questions!");
        _fetchQuestionsForChapter(_selectedChapterId!);
      } else {
        _showSnackBar("No valid rows found to import.", isError: true);
      }
    } catch (e) {
      _showSnackBar("Import failed: $e", isError: true);
    } finally {
      setState(() => _isImporting = false);
    }
  }

  // --- HELPERS ---

  void _loadQuestionForEditing(Map<String, dynamic> q) {
    setState(() {
      _editingQuestionId = q['id'];
      _selectedChapterId = q['chapter_id'];
      _questionController.text = q['question_text'];
      _optionAController.text = q['option_a'];
      _optionBController.text = q['option_b'];
      _optionCController.text = q['option_c'];
      _optionDController.text = q['option_d'];
      _explanationController.text = q['explanation'] ?? '';
      _pyqController.text = q['pyq_year'] ?? '';
      _correctOption = q['correct_option'];
      _isPaid = q['is_paid'] ?? false;
    });
    _tabController.animateTo(0);
  }

  void _clearForm() {
    setState(() {
      _editingQuestionId = null;
      _questionController.clear();
      _optionAController.clear();
      _optionBController.clear();
      _optionCController.clear();
      _optionDController.clear();
      _explanationController.clear();
      _pyqController.clear();
      _correctOption = 'A';
      _isPaid = false;
    });
  }

  // ====================================================
  //  TAB 2: REPORTED QUESTIONS LOGIC
  // ====================================================

  Future<void> _fetchReportedQuestions() async {
    setState(() => _isLoadingReports = true);
    final supabase = ref.read(supabaseClientProvider);
    try {
      final data = await supabase
          .from('question_reports')
          .select('*, questions(*)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reportedQuestions = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("Error fetching reports: $e");
    } finally {
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _dismissReport(int reportId) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase.from('question_reports').delete().eq('id', reportId);
      _showSnackBar("Report dismissed");
      _fetchReportedQuestions();
    } catch (e) {
      _showSnackBar("Error dismissing report: $e", isError: true);
    }
  }

  // ====================================================
  //  TAB 3: DAILY WISDOM LOGIC
  // ====================================================

  Future<void> _fetchLatestQuote() async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final data = await supabase
          .from('daily_updates')
          .select('fact_text')
          .limit(1)
          .maybeSingle();

      if (data != null) {
        _quoteController.text = data['fact_text'] ?? '';
      }
    } catch (e) {
      debugPrint("No quote found or error: $e");
    }
  }

  Future<void> _updateQuote() async {
    if (_quoteController.text.isEmpty) return;
    setState(() => _isPostingQuote = true);

    final supabase = ref.read(supabaseClientProvider);
    try {
      final existingData = await supabase
          .from('daily_updates')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (existingData != null) {
        await supabase.from('daily_updates').update({
          'fact_text': _quoteController.text.trim(),
        }).eq('id', existingData['id']);
        _showSnackBar("Daily Wisdom Updated!");
      } else {
        await supabase.from('daily_updates').insert({
          'fact_text': _quoteController.text.trim(),
        });
        _showSnackBar("Daily Wisdom Created!");
      }
    } catch (e) {
      _showSnackBar("Failed to update: $e", isError: true);
    } finally {
      setState(() => _isPostingQuote = false);
    }
  }

  // ====================================================
  //  UI BUILD
  // ====================================================

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : Colors.green),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.quiz), text: "Manage"),
            Tab(icon: Icon(Icons.warning_amber_rounded), text: "Reports"),
            Tab(icon: Icon(Icons.lightbulb), text: "Wisdom"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuestionManager(),
          _buildReportedQuestionsManager(),
          _buildDailyWisdomManager(),
        ],
      ),
    );
  }

  Widget _buildQuestionManager() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- 1. SELECTION AREA ---
          DropdownButtonFormField<int>(
            decoration: _inputDecoration("Select Subject"),
            value: _selectedSubjectId,
            items: _subjects
                .map((s) => DropdownMenuItem(
                    value: s['id'] as int, child: Text(s['title'])))
                .toList(),
            onChanged: (val) {
              setState(() => _selectedSubjectId = val);
              if (val != null) _fetchChapters(val);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            decoration: _inputDecoration("Select Chapter"),
            value: _selectedChapterId,
            hint: _isLoadingDropdowns
                ? const Text("Loading...")
                : const Text("Select Chapter"),
            items: _chapters
                .map((c) => DropdownMenuItem(
                    value: c['id'] as int, child: Text(c['title'])))
                .toList(),
            onChanged: (val) {
              setState(() => _selectedChapterId = val);
              if (val != null) _fetchQuestionsForChapter(val);
            },
          ),
          
          // --- NEW: BULK IMPORT BUTTONS ---
          const SizedBox(height: 15),
          if (_isImporting) 
            const Center(child: CircularProgressIndicator())
          else 
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedSubjectId == null ? null : () => _showBulkImportDialog('Chapters'),
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Import Chapters (Text)"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedChapterId == null ? null : () => _showBulkImportDialog('Questions'),
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Import Questions (Text)"),
                  ),
                ),
              ],
            ),

          const Divider(height: 30, thickness: 2),

          // --- 2. FORM AREA ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  _editingQuestionId == null
                      ? "ADD NEW QUESTION"
                      : "EDITING ID: $_editingQuestionId",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _editingQuestionId == null
                          ? Colors.green
                          : Colors.orange)),
              if (_editingQuestionId != null)
                TextButton.icon(
                    onPressed: _clearForm,
                    icon: const Icon(Icons.clear),
                    label: const Text("Cancel Edit"))
            ],
          ),
          // ... (Rest of Form Fields remain the same)
          const SizedBox(height: 10),
          TextField(
              controller: _questionController,
              maxLines: 3,
              decoration: _inputDecoration("Question Text")),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _optionAController,
                    decoration: _inputDecoration("Option A"))),
            const SizedBox(width: 5),
            Expanded(
                child: TextField(
                    controller: _optionBController,
                    decoration: _inputDecoration("Option B"))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _optionCController,
                    decoration: _inputDecoration("Option C"))),
            const SizedBox(width: 5),
            Expanded(
                child: TextField(
                    controller: _optionDController,
                    decoration: _inputDecoration("Option D"))),
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Correct Option"),
                  value: _correctOption,
                  items: ['A', 'B', 'C', 'D']
                      .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                      .toList(),
                  onChanged: (val) => setState(() => _correctOption = val!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Text("Paid?"),
                      const Spacer(),
                      Switch(
                          value: _isPaid,
                          onChanged: (v) => setState(() => _isPaid = v)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _explanationController,
              maxLines: 2,
              decoration: _inputDecoration("Explanation")),
          const SizedBox(height: 10),
          TextField(
              controller: _pyqController,
              decoration: _inputDecoration("PYQ Year (Optional)")),
          const SizedBox(height: 20),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _editingQuestionId == null
                      ? Colors.blueGrey[900]
                      : Colors.orange[800],
                  foregroundColor: Colors.white),
              onPressed: _isSubmitting ? null : _upsertQuestion,
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_editingQuestionId == null
                      ? "ADD QUESTION"
                      : "UPDATE QUESTION"),
            ),
          ),

          const Divider(height: 40, thickness: 2),

          // --- 3. EXISTING QUESTIONS LIST ---
          const Text("EXISTING QUESTIONS IN CHAPTER",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          if (_isLoadingQuestions)
            const Center(child: CircularProgressIndicator())
          else if (_existingQuestions.isEmpty)
            const Center(child: Text("No questions added yet."))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _existingQuestions.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (ctx, index) {
                final q = _existingQuestions[index];
                final isBeingEdited = q['id'] == _editingQuestionId;
                return Container(
                  color: isBeingEdited ? Colors.orange.withOpacity(0.1) : null,
                  child: ListTile(
                    title: Text(q['question_text'],
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text("Ans: ${q['correct_option']} | ID: ${q['id']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _loadQuestionForEditing(q),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteQuestion(q['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // --- REPORTED QUESTIONS TAB ---
  Widget _buildReportedQuestionsManager() {
    if (_isLoadingReports) return const Center(child: CircularProgressIndicator());
    
    if (_reportedQuestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
            const SizedBox(height: 10),
            const Text("No reported questions found!"),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _fetchReportedQuestions, child: const Text("Refresh"))
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _reportedQuestions.length,
      itemBuilder: (ctx, index) {
        final report = _reportedQuestions[index];
        final questionData = report['questions']; // Linked table data
        
        if (questionData == null) {
          return Card(
            color: Colors.red[50],
            child: ListTile(
              title: const Text("Question Deleted"),
              subtitle: const Text("This reported question no longer exists."),
              trailing: IconButton(
                icon: const Icon(Icons.delete_forever),
                onPressed: () => _dismissReport(report['id']),
              ),
            ),
          );
        }

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Report ID: ${report['id']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    Chip(label: Text(report['issue_text'] ?? 'No reason provided'), backgroundColor: Colors.orange[100]),
                  ],
                ),
                const Divider(),
                Text("Q: ${questionData['question_text']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 5),
                Text("Correct: ${questionData['correct_option']} | Explanation: ${questionData['explanation'] ?? 'None'}"),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.check, color: Colors.green),
                      label: const Text("Dismiss Report"),
                      onPressed: () => _dismissReport(report['id']),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text("Edit Question"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                      onPressed: () {
                        _loadQuestionForEditing(questionData);
                        _showSnackBar("Switched to Manage tab for editing");
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyWisdomManager() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.format_quote, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text("Update Home Screen Quote",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _quoteController,
              maxLines: 4,
              decoration:
                  _inputDecoration("Enter new wisdom/quote here..."),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.black),
                onPressed: _isPostingQuote ? null : _updateQuote,
                child: _isPostingQuote
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("PUBLISH TO HOME SCREEN"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}