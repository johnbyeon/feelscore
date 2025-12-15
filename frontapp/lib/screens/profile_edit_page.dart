import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final ApiService _apiService = ApiService();

  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FocusNode _nicknameFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isLoadingImage = false;
  bool _isNicknameEditable = false;
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  String? _nicknameError;
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.nickname != null) {
      _nicknameController.text = userProvider.nickname!;
    }
    // Fetch latest user info (including email)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      userProvider.fetchMe();
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_isLoading) return;

    setState(() {
      _nicknameError = null;
      _currentPasswordError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;
    });

    final nickname = _nicknameController.text.trim();
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    bool hasError = false;

    if (nickname.isEmpty) {
      setState(() => _nicknameError = '닉네임을 입력해주세요');
      hasError = true;
    }

    if (newPassword.isNotEmpty) {
      if (currentPassword.isEmpty) {
        setState(() => _currentPasswordError = '현재 비밀번호를 입력해주세요');
        hasError = true;
      }
      if (newPassword != confirmPassword) {
        setState(() => _confirmPasswordError = '새 비밀번호가 일치하지 않습니다');
        hasError = true;
      }
      if (newPassword.length < 6) {
        setState(() => _newPasswordError = '비밀번호는 6동자 이상이어야 합니다');
        hasError = true;
      }
    }

    if (hasError) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.updateProfile(
        nickname: nickname,
        currentPassword: newPassword.isNotEmpty ? currentPassword : null,
        newPassword: newPassword.isNotEmpty ? newPassword : null,
      );

      if (mounted) {
        await context.read<UserProvider>().updateNickname(nickname);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('프로필이 수정되었습니다')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        if (errorMsg.contains('Current password')) {
          setState(() => _currentPasswordError = '현재 비밀번호가 일치하지 않습니다');
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('프로필 수정 실패: $e')));
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImageAndUpload() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() {
      _isLoadingImage = true;
    });

    try {
      final mimeType = lookupMimeType(pickedFile.path) ?? 'image/jpeg';
      final fileName = pickedFile.path.split('/').last;

      // 1. Get Presigned URL
      final presignedInfo = await _apiService.getUploadPresignedUrl(
        fileName,
        mimeType,
      );
      final presignedUrl = presignedInfo['presignedUrl']!;
      final objectKey = presignedInfo['objectKey']!;

      // 2. Upload to S3
      await _apiService.uploadFileToS3(presignedUrl, pickedFile, mimeType);

      // 3. Update Backend via UserProvider
      if (!mounted) return;
      await context.read<UserProvider>().updateProfileImage(objectKey);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('프로필 사진이 변경되었습니다')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사진 업데이트 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    // Sync nickname if not currently editing and provider has data
    if (!_isNicknameEditable &&
        userProvider.nickname != null &&
        _nicknameController.text != userProvider.nickname) {
      _nicknameController.text = userProvider.nickname!;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('프로필 편집'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Profile Image Section
            Center(
              child: GestureDetector(
                onTap: _isLoadingImage ? null : _pickImageAndUpload,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        // Use the provided userProvider (Consumer is redundant here since we have it)
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[800],
                          backgroundImage:
                              userProvider.profileImageUrl != null
                                  ? NetworkImage(
                                    'https://feelscore-s3.s3.ap-northeast-2.amazonaws.com/${userProvider.profileImageUrl}',
                                  )
                                  : null,
                          child:
                              userProvider.profileImageUrl == null
                                  ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white,
                                  )
                                  : null,
                        ),
                        if (_isLoadingImage)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '사진 수정',
                      style: TextStyle(
                        color: Color(0xFF9C27B0), // Purple color
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Email Row (Read-only)
            _buildInfoRow(
              label: '이메일',
              value: userProvider.email ?? '',
              readOnly: true,
            ),

            // Nickname Row
            _buildInputRow(
              label: '사용자 닉네임',
              controller: _nicknameController,
              icon: Icons.edit,
              errorText: _nicknameError,
              readOnly: !_isNicknameEditable,
              focusNode: _nicknameFocusNode,
              onIconPressed: () {
                setState(() {
                  _isNicknameEditable = !_isNicknameEditable;
                });
                if (_isNicknameEditable) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FocusScope.of(context).requestFocus(_nicknameFocusNode);
                  });
                }
              },
            ),

            // Current Password
            _buildInputRow(
              label: '현재 비밀번호',
              controller: _currentPasswordController,
              isPassword: true,
              isVisible: _currentPasswordVisible,
              onVisibilityToggle: () {
                setState(() {
                  _currentPasswordVisible = !_currentPasswordVisible;
                });
              },
              errorText: _currentPasswordError,
              hint: '현재 비밀번호 입력',
            ),

            // New Password
            _buildInputRow(
              label: '새 비밀번호',
              controller: _newPasswordController,
              isPassword: true,
              isVisible: _newPasswordVisible,
              onVisibilityToggle: () {
                setState(() {
                  _newPasswordVisible = !_newPasswordVisible;
                });
              },
              errorText: _newPasswordError,
              hint: '새 비밀번호 입력',
            ),

            // Confirm Password
            _buildInputRow(
              label: '새 비밀번호 확인',
              controller: _confirmPasswordController,
              isPassword: true,
              isVisible: _confirmPasswordVisible,
              onVisibilityToggle: () {
                setState(() {
                  _confirmPasswordVisible = !_confirmPasswordVisible;
                });
              },
              errorText: _confirmPasswordError,
              hint: '새 비밀번호 확인',
            ),

            const SizedBox(height: 48),

            // Save Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[900],
                    foregroundColor: const Color(0xFF9C27B0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            '저장하기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 회원 탈퇴 텍스트
            GestureDetector(
              onTap: () async {
                // 확인 다이얼로그 표시
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('회원 탈퇴'),
                        content: const Text(
                          '정말 탈퇴하시겠습니까?\n\n탈퇴 시 모든 게시글, 댓글, 반응, 팔로우 정보가 영구적으로 삭제되며 복구할 수 없습니다.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              '탈퇴하기',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                );

                if (confirmed == true && mounted) {
                  try {
                    await _apiService.withdrawUser();
                    if (mounted) {
                      await context.read<UserProvider>().logout();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
                      );
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('회원 탈퇴 실패: $e')));
                    }
                  }
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '회원 탈퇴',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.red,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    bool readOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Unified Row Background
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow({
    required String label,
    required TextEditingController controller,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityToggle,
    IconData? icon,
    VoidCallback? onIconPressed,
    bool readOnly = false,
    FocusNode? focusNode,
    String? errorText,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Unified Row Background
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: readOnly,
                  obscureText: isPassword && !isVisible,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (isPassword && !isVisible) ? 20 : 16,
                    letterSpacing: (isPassword && !isVisible) ? 1.2 : 0,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: InputBorder.none,
                    filled: false, // Ensure transparent background
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ), // Adjust padding
                    suffixIcon:
                        isPassword
                            ? IconButton(
                              icon: Icon(
                                isVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: onVisibilityToggle,
                            )
                            : icon != null
                            ? IconButton(
                              icon: Icon(
                                icon,
                                color:
                                    !readOnly && !isPassword
                                        ? const Color(0xFF9C27B0)
                                        : Colors.white,
                                size: 20,
                              ),
                              onPressed: onIconPressed,
                            )
                            : null,
                  ),
                ),
              ),
            ],
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(left: 120, bottom: 8),
              child: Text(
                errorText,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
