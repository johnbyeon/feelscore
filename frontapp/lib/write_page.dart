import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'services/api_service.dart';
import 'services/category_service.dart';
import 'package:provider/provider.dart';
import 'providers/refresh_provider.dart';

class WritePage extends StatefulWidget {
  final VoidCallback? onPostSuccess;

  const WritePage({super.key, this.onPostSuccess});

  @override
  State<WritePage> createState() => _WritePageState();
}

class _WritePageState extends State<WritePage> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _thoughtController = TextEditingController();
  final ApiService _apiService = ApiService();
  final CategoryService _categoryService = CategoryService();

  XFile? _selectedImage;
  bool _isUploading = false;

  // Category Autocomplete
  List<Map<String, dynamic>> _categorySuggestions = [];
  bool _showSuggestions = false;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _categoryService.checkAndFetchCategories(); // Check for updates on init
    _categoryController.addListener(_onCategoryChanged);
  }

  void _onCategoryChanged() {
    final text = _categoryController.text;
    // #이 있든 없든 검색어 추출
    final query = text.startsWith('#') ? text.substring(1) : text;

    if (query.isNotEmpty) {
      _searchCategories(query);
    } else {
      setState(() {
        _showSuggestions = false;
        _categorySuggestions = [];
      });
    }
  }

  Future<void> _searchCategories(String query) async {
    final results = await _categoryService.searchCategories(query);
    setState(() {
      _categorySuggestions = results;
      _showSuggestions = results.isNotEmpty;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _thoughtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Theme.of(context).colorScheme.surface, // Removed to use global scaffoldBackgroundColor
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '게시글 작성하기',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        leading: null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Section
                    Text(
                      "카테고리",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).inputDecorationTheme.fillColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _categoryController,
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: InputDecoration(
                              hintText: '카테고리를 검색하세요.ex(#사회, 또는 사회)',
                              prefixIcon: Icon(
                                Icons.tag_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                          if (_showSuggestions)
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _categorySuggestions.length,
                                itemBuilder: (context, index) {
                                  final category = _categorySuggestions[index];
                                  return ListTile(
                                    title: Text(category['name']),
                                    onTap: () {
                                      // 선택 시 리스너가 트리거되어 다시 검색되는 것을 방지
                                      _categoryController.removeListener(
                                        _onCategoryChanged,
                                      );
                                      _categoryController.text =
                                          '#${category['name']}';
                                      _categoryController.addListener(
                                        _onCategoryChanged,
                                      );

                                      setState(() {
                                        _selectedCategoryId = category['id'];
                                        _showSuggestions = false;
                                        _categorySuggestions = [];
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Image Section
                    Text("사진", style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: _selectedImage != null ? null : 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child:
                            _selectedImage != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child:
                                      kIsWeb
                                          ? Image.network(
                                            _selectedImage!.path,
                                            fit: BoxFit.fitWidth,
                                          )
                                          : Image.file(
                                            File(_selectedImage!.path),
                                            fit: BoxFit.fitWidth,
                                          ),
                                )
                                : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_rounded,
                                      size: 48,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Add a photo",
                                      style: TextStyle(
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Thought Section
                    Text(
                      "게시글 내용",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).inputDecorationTheme.fillColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _thoughtController,
                        maxLines: 12,
                        minLines: 8,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: const InputDecoration(
                          hintText: "게시글을 내용을 여기에 작성해 보세요.",
                          alignLabelWithHint: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom Action Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed:
                      _isUploading
                          ? null
                          : () async {
                            if (_categoryController.text.isEmpty ||
                                _thoughtController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill in all fields'),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              _isUploading = true;
                            });

                            try {
                              String? objectKey;
                              if (_selectedImage != null) {
                                final mimeType =
                                    lookupMimeType(_selectedImage!.path) ??
                                    'image/jpeg';
                                final fileName =
                                    _selectedImage!.path.split('/').last;

                                // 1. Get Presigned URL
                                final presignedInfo = await _apiService
                                    .getUploadPresignedUrl(fileName, mimeType);
                                final presignedUrl =
                                    presignedInfo['presignedUrl']!;
                                objectKey = presignedInfo['objectKey'];

                                // 2. Upload to S3
                                await _apiService.uploadFileToS3(
                                  presignedUrl,
                                  _selectedImage!,
                                  mimeType,
                                );
                              }

                              // Call createPost API
                              if (_selectedCategoryId == null) {
                                // If user typed manually without selecting from list, try to find ID or handle error
                                // For now, require selection from list or assume backend handles name lookup (not implemented)
                                // Simple fallback: search again to find exact match
                                final results = await _categoryService
                                    .searchCategories(
                                      _categoryController.text.substring(1),
                                    );
                                if (results.isNotEmpty &&
                                    results.first['name'] ==
                                        _categoryController.text.substring(1)) {
                                  _selectedCategoryId = results.first['id'];
                                } else {
                                  throw Exception(
                                    'Please select a valid category from the list',
                                  );
                                }
                              }

                              // The print statements below are commented out, removing them as per instruction.
                              // print('Category: ${_categoryController.text}');
                              // print('Thought: ${_thoughtController.text}');
                              if (objectKey != null) {
                                // print('Image Key: $objectKey');
                              }

                              await _apiService.createPost(
                                _thoughtController.text,
                                _selectedCategoryId!,
                                imageUrl: objectKey,
                              );

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Thought shared successfully!'),
                                ),
                              );

                              // Reset fields
                              _thoughtController.clear();
                              _categoryController.clear();
                              setState(() {
                                _selectedImage = null;
                                _selectedCategoryId = null;
                              });

                              // Trigger history refresh
                              context
                                  .read<RefreshProvider>()
                                  .triggerRefreshHistory();

                              // Navigate to Home
                              widget.onPostSuccess?.call();
                            } catch (e) {
                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isUploading = false;
                                });
                              }
                            }
                          },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  icon:
                      _isUploading
                          ? Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2.0),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                          : const Icon(Icons.send_rounded),
                  label: Text(
                    _isUploading ? "공유중..." : "게시글 공유하기",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
