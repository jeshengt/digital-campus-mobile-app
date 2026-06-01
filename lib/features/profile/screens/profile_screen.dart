import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_glass_panel.dart';
import '../../../shared/widgets/utm_primary_button.dart';
import '../../../shared/widgets/utm_text_field.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../../auth/services/auth_service.dart';
import '../models/app_user.dart';
import '../services/user_profile_service.dart';
import '../utils/profile_form_helpers.dart';
import '../widgets/profile_action_tile.dart';
import '../widgets/password_change_sheet.dart';
import '../widgets/profile_header_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _authService = AuthService();
  final _profileService = UserProfileService();

  bool _isLoggingOut = false;
  String? _loadedProfileUid;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _showEditProfileSheet(AppUser profile) async {
    _syncControllers(profile, force: true);

    bool isSaving = false;
    String? sheetErrorMessage;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> saveProfile() async {
              if (!_formKey.currentState!.validate()) {
                return;
              }

              setSheetState(() {
                isSaving = true;
                sheetErrorMessage = null;
              });

              try {
                final identifier = _identifierController.text.trim();
                await _profileService.updateAllowedProfileFields(
                  uid: profile.uid,
                  name: _nameController.text.trim(),
                  matricNumber: profileUsesMatricNumber(profile.role)
                      ? identifier
                      : null,
                  staffId: profileUsesMatricNumber(profile.role)
                      ? null
                      : identifier,
                );

                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, true);
                }
              } catch (error) {
                setSheetState(() {
                  isSaving = false;
                  sheetErrorMessage = _friendlyError(error);
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppDimensions.spacingLarge,
                  right: AppDimensions.spacingLarge,
                  top: AppDimensions.spacingMedium,
                  bottom:
                      MediaQuery.viewInsetsOf(sheetContext).bottom +
                      AppDimensions.spacingLarge,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Edit Profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppDimensions.spacingSmall),
                      Text(
                        'Update the safe profile details for your role.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppDimensions.spacingLarge),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                        validator: validateProfileName,
                      ),
                      const SizedBox(height: AppDimensions.spacingMedium),
                      UtmTextField(
                        controller: _identifierController,
                        label: profileIdentifierLabel(profile.role),
                        isRequired: false,
                        textInputAction: TextInputAction.done,
                      ),
                      if (sheetErrorMessage != null) ...[
                        const SizedBox(height: AppDimensions.spacingMedium),
                        Text(
                          sheetErrorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppDimensions.spacingLarge),
                      UtmPrimaryButton(
                        label: 'Save profile',
                        icon: Icons.save_outlined,
                        isLoading: isSaving,
                        onPressed: saveProfile,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      setState(() {
        _statusMessage = 'Profile updated.';
        _errorMessage = null;
      });
    }
  }

  Future<void> _showPasswordChangeSheet() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PasswordChangeSheet(authService: _authService),
    );

    if (changed == true && mounted) {
      setState(() {
        _statusMessage = 'Password updated.';
        _errorMessage = null;
      });
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    try {
      await _authService.logout();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.signIn,
          (_) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    if (user == null) {
      return UtmBackgroundScaffold(
        appBar: _buildProfileAppBar(),
        body: const Center(child: Text('Please sign in to view your profile.')),
      );
    }

    return UtmBackgroundScaffold(
      appBar: _buildProfileAppBar(),
      body: StreamBuilder<AppUser?>(
        stream: _profileService.watchProfile(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(_friendlyError(snapshot.error)));
          }

          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('Profile details are not ready.'));
          }

          _syncControllers(profile);

          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDimensions.maxContentWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.spacingLarge,
                    AppDimensions.spacingMedium,
                    AppDimensions.spacingLarge,
                    AppDimensions.spacingLarge,
                  ),
                  children: [
                    ProfileHeaderCard(profile: profile),
                    const SizedBox(height: AppDimensions.spacingMedium),
                    _buildMessageArea(context),
                    _buildActionsCard(profile),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildProfileAppBar() {
    return const UtmTopAppBar(title: 'Profile');
  }

  void _syncControllers(AppUser profile, {bool force = false}) {
    if (!force && _loadedProfileUid == profile.uid) {
      return;
    }

    _loadedProfileUid = profile.uid;
    _nameController.text = profile.name;
    _identifierController.text = profileIdentifierValue(
      role: profile.role,
      matricNumber: profile.matricNumber,
      staffId: profile.staffId,
    );
  }

  Widget _buildMessageArea(BuildContext context) {
    if (_statusMessage == null && _errorMessage == null) {
      return const SizedBox.shrink();
    }

    final isError = _errorMessage != null;
    final message = _errorMessage ?? _statusMessage!;
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
      child: UtmGlassPanel(
        backgroundColor: color.withValues(alpha: isError ? 0.08 : 0.1),
        borderRadius: AppDimensions.radiusLarge,
        showShadow: false,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMedium),
          child: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: color,
              ),
              const SizedBox(width: AppDimensions.spacingSmall),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsCard(AppUser profile) {
    final colors = UtmThemeColors.of(context);

    return UtmGlassPanel(
      backgroundColor: colors.glassStrong.withValues(alpha: 0.82),
      borderRadius: AppDimensions.radiusExtraLarge,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingSmall),
        child: Column(
          children: [
            ProfileActionTile(
              icon: Icons.person_outline_rounded,
              label: 'Edit Profile',
              subtitle: 'Update your name and campus ID.',
              onTap: () => _showEditProfileSheet(profile),
            ),
            const SizedBox(height: AppDimensions.spacingTiny),
            ProfileActionTile(
              icon: Icons.lock_outline_rounded,
              label: 'Change Password',
              subtitle: 'Keep your account secure.',
              onTap: _showPasswordChangeSheet,
            ),
            const SizedBox(height: AppDimensions.spacingTiny),
            ProfileActionTile(
              icon: Icons.logout_rounded,
              label: 'Logout',
              subtitle: 'Sign out from this device.',
              isDestructive: true,
              isLoading: _isLoggingOut,
              onTap: _isLoggingOut ? null : _logout,
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyError(Object? error) {
    final text = error.toString();

    if (text.contains('permission-denied')) {
      return 'You do not have permission to update that profile detail.';
    }

    if (text.contains('network')) {
      return 'Network error. Please check your connection and try again.';
    }

    return text;
  }
}
