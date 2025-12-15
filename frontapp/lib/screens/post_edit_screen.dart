import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import '../services/api_service.dart';

class PostEditScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostEditScreen({super.key, required this.post});

  @override
  State<PostEditScreen> createState() => _PostEditScreenState();
}

class _PostEditScreenState extends State<PostEditScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _newImage;
  String? _existingImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController.text = widget.post['content'] ?? '';
    _existingImageUrl = widget.post['imageUrl'];
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _newImage = pickedFile;
        _existingImageUrl = null; // Clear existing image when new one is picked
      });
    }
  }

  Future<void> _savePost() async {
    if (_isSaving) return;

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내용을 입력해주세요.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? imageUrl = _existingImageUrl;

      // Upload new image if selected
      if (_newImage != null) {
        final mimeType = lookupMimeType(_newImage!.path) ?? 'image/jpeg';
        final presignedData = await _apiService.getUploadPresignedUrl(
          'posts',
          mimeType,
        );

        await _apiService.uploadFileToS3(
          presignedData['url'] as String,
          _newImage!,
          mimeType,
        );

        imageUrl = presignedData['key'] as String?;
      }

      var categoryId = widget.post['categoryId'];
      if (categoryId == null && widget.post['category'] != null) {
        categoryId = widget.post['category']['id'];
      }

      if (categoryId == null) {
        throw Exception('게시글의 카테고리 정보를 찾을 수 없습니다.');
      }

      // Ensure categoryId is int
      if (categoryId is String) {
        categoryId = int.tryParse(categoryId);
      }

      if (categoryId == null) {
        throw Exception('카테고리 ID가 올바르지 않습니다.');
      }

      await _apiService.updatePost(
        widget.post['id'],
        content,
        categoryId,
        imageUrl: imageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('게시글이 수정되었습니다.')));
        Navigator.pop(context, {'content': content, 'imageUrl': imageUrl});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
        print('Post update error: $e'); // 디버깅용 로그
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get category name (read-only)
    final categoryName = widget.post['categoryName'] ?? '카테고리';

    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글 수정'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePost,
            child:
                _isSaving
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('저장', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category (read-only)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.category, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(categoryName, style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(width: 8),
                  Icon(Icons.lock, size: 14, color: Colors.grey[600]),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '카테고리는 수정할 수 없습니다',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Content
            TextField(
              controller: _contentController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: '내용을 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 16),

            // Image Section
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: _buildImagePreview(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '이미지를 탭하여 변경',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_newImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(_newImage!.path),
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    } else if (_existingImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/$_existingImageUrl',
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        ),
      );
    } else {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[600]),
        const SizedBox(height: 8),
        Text('이미지 추가', style: TextStyle(color: Colors.grey[500])),
      ],
    );
  }
}
