import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../library/library_providers.dart'; // Access to supabaseClientProvider

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> with SingleTickerProviderStateMixin {
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

  // EDIT MODE STATE
  int? _editingQuestionId;

  // --- DAILY WISDOM STATE ---
  final _quoteController = TextEditingController();
  bool _isPostingQuote = false; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSubjects();
    _fetchLatestQuote();
  }

  // ====================================================
  //  TAB 1: QUESTION MANAGER LOGIC
  // ====================================================

  Future<void> _fetchSubjects() async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final data = await supabase.from('subjects').select('id, title').order('title');
      setState(() {
        _subjects = List<Map<String, dynamic>>.from(data);
      });
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
      
      setState(() {
        _chapters = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      _showSnackBar("Error fetching chapters: $e", isError: true);
    } finally {
      setState(() => _isLoadingDropdowns = false);
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
      
      setState(() {
        _existingQuestions = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      _showSnackBar("Error loading questions: $e", isError: true);
    } finally {
      setState(() => _isLoadingQuestions = false);
    }
  }

  // --- CRUD OPERATIONS ---

  Future<void> _upsertQuestion() async {
    if (_selectedChapterId == null) {
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
      final pyqYear = _pyqController.text.trim().isEmpty ? null : _pyqController.text.trim();
      
      final data = {
        'chapter_id': _selectedChapterId,
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

      if (_editingQuestionId == null) {
        await supabase.from('questions').insert(data);
        _showSnackBar("Question Added Successfully!");
      } else {
        await supabase.from('questions').update(data).eq('id', _editingQuestionId!);
        _showSnackBar("Question Updated!");
      }

      _clearForm();
      if (_selectedChapterId != null) {
        _fetchQuestionsForChapter(_selectedChapterId!);
      }

    } catch (e) {
      _showSnackBar("Operation failed: $e", isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteQuestion(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Question?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
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
    } catch (e) {
      _showSnackBar("Delete failed: $e", isError: true);
    }
  }

  void _loadQuestionForEditing(Map<String, dynamic> q) {
    setState(() {
      _editingQuestionId = q['id'];
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
  //  TAB 2: DAILY WISDOM LOGIC (SINGLE ROW FIX)
  // ====================================================
  
  Future<void> _fetchLatestQuote() async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final data = await supabase.from('daily_updates')
          .select('fact_text') 
          .limit(1)
          .maybeSingle(); // Get the single row if it exists
          
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
      // 1. Check if ANY row exists
      final existingData = await supabase.from('daily_updates').select('id').limit(1).maybeSingle();

      if (existingData != null) {
        // 2. UPDATE existing row
        await supabase.from('daily_updates').update({
          'fact_text': _quoteController.text.trim(),
        }).eq('id', existingData['id']);
        _showSnackBar("Daily Wisdom Updated!");
      } else {
        // 3. INSERT new row (only happens if table is empty)
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
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Colors.green),
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
            Tab(icon: Icon(Icons.quiz), text: "Manage Questions"),
            Tab(icon: Icon(Icons.lightbulb), text: "Daily Wisdom"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuestionManager(),
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
            initialValue: _selectedSubjectId,
            items: _subjects.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text(s['title']))).toList(),
            onChanged: (val) {
              setState(() => _selectedSubjectId = val);
              if (val != null) _fetchChapters(val);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            decoration: _inputDecoration("Select Chapter"),
            initialValue: _selectedChapterId,
            hint: _isLoadingDropdowns ? const Text("Loading...") : const Text("Select Chapter"),
            items: _chapters.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['title']))).toList(),
            onChanged: (val) {
              setState(() => _selectedChapterId = val);
              if (val != null) _fetchQuestionsForChapter(val);
            },
          ),
          const Divider(height: 30, thickness: 2),

          // --- 2. FORM AREA ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_editingQuestionId == null ? "ADD NEW QUESTION" : "EDITING ID: $_editingQuestionId", 
                style: TextStyle(fontWeight: FontWeight.bold, color: _editingQuestionId == null ? Colors.green : Colors.orange)),
              if (_editingQuestionId != null)
                TextButton.icon(
                  onPressed: _clearForm, 
                  icon: const Icon(Icons.clear), 
                  label: const Text("Cancel Edit")
                )
            ],
          ),
          const SizedBox(height: 10),
          TextField(controller: _questionController, maxLines: 3, decoration: _inputDecoration("Question Text")),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _optionAController, decoration: _inputDecoration("Option A"))),
            const SizedBox(width: 5),
            Expanded(child: TextField(controller: _optionBController, decoration: _inputDecoration("Option B"))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _optionCController, decoration: _inputDecoration("Option C"))),
            const SizedBox(width: 5),
            Expanded(child: TextField(controller: _optionDController, decoration: _inputDecoration("Option D"))),
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Correct Option"),
                  initialValue: _correctOption,
                  items: ['A', 'B', 'C', 'D'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                  onChanged: (val) => setState(() => _correctOption = val!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Text("Paid?"),
                      const Spacer(),
                      Switch(value: _isPaid, onChanged: (v) => setState(() => _isPaid = v)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(controller: _explanationController, maxLines: 2, decoration: _inputDecoration("Explanation")),
          const SizedBox(height: 10),
          TextField(controller: _pyqController, decoration: _inputDecoration("PYQ Year (Optional)")),
          const SizedBox(height: 20),
          
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _editingQuestionId == null ? Colors.blueGrey[900] : Colors.orange[800], foregroundColor: Colors.white),
              onPressed: _isSubmitting ? null : _upsertQuestion,
              child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(_editingQuestionId == null ? "ADD QUESTION" : "UPDATE QUESTION"),
            ),
          ),
          
          const Divider(height: 40, thickness: 2),

          // --- 3. EXISTING QUESTIONS LIST ---
          const Text("EXISTING QUESTIONS IN CHAPTER", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
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
              separatorBuilder: (_,__) => const Divider(),
              itemBuilder: (ctx, index) {
                final q = _existingQuestions[index];
                final isBeingEdited = q['id'] == _editingQuestionId;
                return Container(
                  color: isBeingEdited ? Colors.orange.withValues(alpha: 0.1) : null,
                  child: ListTile(
                    title: Text(q['question_text'], maxLines: 2, overflow: TextOverflow.ellipsis),
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

  Widget _buildDailyWisdomManager() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.format_quote, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text("Update Home Screen Quote", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _quoteController,
              maxLines: 4,
              decoration: _inputDecoration("Enter new wisdom/quote here..."),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], foregroundColor: Colors.black),
                onPressed: _isPostingQuote ? null : _updateQuote,
                child: _isPostingQuote ? const CircularProgressIndicator(color: Colors.white) : const Text("PUBLISH TO HOME SCREEN"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}