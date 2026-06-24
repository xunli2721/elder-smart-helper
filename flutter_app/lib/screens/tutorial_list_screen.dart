import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/font_size_provider.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../models/tutorial.dart';
import 'tutorial_detail_screen.dart';

class TutorialListScreen extends StatefulWidget {
  const TutorialListScreen({super.key});

  @override
  State<TutorialListScreen> createState() => _TutorialListScreenState();
}

class _TutorialListScreenState extends State<TutorialListScreen> {
  List<Tutorial> _tutorials = [];
  bool _loading = true;
  String? _selectedCategory;

  static const Map<String, String> _categories = {
    '': '全部',
    'basic': '基础操作',
    'communication': '通讯社交',
    'payment': '支付',
    'entertainment': '娱乐',
    'utility': '工具',
  };

  @override
  void initState() {
    super.initState();
    _loadTutorials();
  }

  Future<void> _loadTutorials() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.getTutorials(category: _selectedCategory);
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _tutorials = (result['data'] as List).map((t) => Tutorial.fromJson(t)).toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<FontSizeProvider>().scaled;
    return Scaffold(
      appBar: AppBar(title: const Text('教程中心'), automaticallyImplyLeading: false),
      body: Column(
        children: [
          // 分类筛选
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _categories.entries.map((entry) {
                final isSelected = (_selectedCategory ?? '') == entry.key;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(entry.value, style: TextStyle(fontSize: s(16))),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = entry.key.isEmpty ? null : entry.key);
                      _loadTutorials();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // 教程列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tutorials.isEmpty
                    ? Center(child: Text('暂无教程', style: TextStyle(fontSize: s(18), color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tutorials.length,
                        itemBuilder: (context, index) => _tutorialItem(_tutorials[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tutorialItem(Tutorial tutorial) {
    final s = context.watch<FontSizeProvider>().scaled;
    Color difficultyColor;
    String difficultyText;
    switch (tutorial.difficultyLevel) {
      case 'beginner':
        difficultyColor = Colors.green;
        difficultyText = '入门';
        break;
      case 'intermediate':
        difficultyColor = Colors.orange;
        difficultyText = '进阶';
        break;
      default:
        difficultyColor = Colors.red;
        difficultyText = '高级';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.menu_book, size: 32, color: AppColors.primary),
        ),
        title: Row(
          children: [
            Expanded(child: Text(tutorial.title, style: TextStyle(fontSize: s(20), fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: difficultyColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(difficultyText, style: TextStyle(fontSize: s(14), color: difficultyColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(tutorial.description, style: TextStyle(fontSize: s(16)), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 20),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TutorialDetailScreen(tutorial: tutorial)));
        },
      ),
    );
  }
}