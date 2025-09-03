import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

class EditStatsScreen extends StatefulWidget {
  final String clientId;

  const EditStatsScreen({super.key, required this.clientId});

  @override
  State<EditStatsScreen> createState() => _EditStatsScreenState();
}

class _EditStatsScreenState extends State<EditStatsScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _ageController = TextEditingController();
  final _goalsController = TextEditingController();

  ClientMetrics? _currentMetrics;
  String? _selectedGender;
  UserData? _userData;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(###) ###-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _loadCurrentMetrics();
    _slideController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _ageController.dispose();
    _goalsController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentMetrics() async {
    try {
      final metrics = await _authService.getClientMetrics(widget.clientId);
      final userData = await _authService.getCurrentUserData();

      if (metrics != null && userData != null) {
        setState(() {
          _currentMetrics = metrics;
          _userData = userData;

          // Load contact info
          _nameController.text = userData.name;
          _emailController.text = userData.email;
          String rawPhone = userData.phone ?? '';
          if (rawPhone.isNotEmpty) {
            // Use the mask formatter to format the phone number
            final formattedResult = _phoneMaskFormatter.formatEditUpdate(
              const TextEditingValue(),
              TextEditingValue(text: rawPhone),
            );
            _phoneController.text = formattedResult.text;
          }

          // Convert kg to lbs for display
          _weightController.text =
              (metrics.weight * 2.20462).round().toString();

          // Convert cm to feet and inches
          double totalInches = metrics.height / 2.54;
          int feet = (totalInches / 12).floor();
          int inches = (totalInches % 12).round();
          _heightFeetController.text = feet.toString();
          _heightInchesController.text = inches.toString();

          _ageController.text = metrics.age.toString();
          _goalsController.text = metrics.goals ?? '';
          _selectedGender = metrics.gender;

          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load current stats';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveStats() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Convert pounds to kg
      double weightLbs = double.parse(_weightController.text);
      double weightKg = weightLbs / 2.20462;

      // Convert feet and inches to cm
      int feet = int.parse(_heightFeetController.text);
      int inches = int.parse(_heightInchesController.text);
      double heightCm = ((feet * 12) + inches) * 2.54;

      int age = int.parse(_ageController.text);
      String goals = _goalsController.text.trim();
      String phone = _phoneMaskFormatter.getUnmaskedText().trim();
      String name = _nameController.text.trim();

      final error = await _authService.updateClientInfo(
        widget.clientId,
        name: name,
        phone: phone.isEmpty ? null : phone,
        weight: weightKg,
        height: heightCm,
        age: age,
        goals: goals.isEmpty ? null : goals,
        gender: _selectedGender,
      );

      if (error != null) {
        setState(() {
          _errorMessage = error;
          _isSaving = false;
        });
        return;
      }

      // Success
      setState(() {
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Stats updated successfully.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Wait a moment for the snackbar to show, then navigate back
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.pop(true); // Return true to indicate success
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update stats. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Your Stats',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SlideTransition(
              position: _slideAnimation,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    top: 24.0,
                    bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Update Your Information',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onTertiary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Keep your personal information up to date to help your trainer create better workout plans for you.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onTertiary
                                        .withOpacity(0.8),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Full Name',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _nameController,
                        label: 'Enter your full name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Email Address',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _emailController.text,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.7),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Email address cannot be changed',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                      const SizedBox(height: 24),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _phoneController,
                        label: 'Phone Number (optional)',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [_phoneMaskFormatter],
                        validator: null,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Current Weight',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _weightController,
                        label: 'Weight (lbs)',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your weight';
                          }
                          final weight = double.tryParse(value);
                          if (weight == null || weight < 50 || weight > 500) {
                            return 'Please enter a valid weight (50-500 lbs)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Current Height',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _heightFeetController,
                              label: 'Feet',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final feet = int.tryParse(value);
                                if (feet == null || feet < 3 || feet > 8) {
                                  return '3-8 feet';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomTextField(
                              controller: _heightInchesController,
                              label: 'Inches',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                final inches = int.tryParse(value);
                                if (inches == null ||
                                    inches < 0 ||
                                    inches > 11) {
                                  return '0-11 inches';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Current Age',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _ageController,
                        label: 'Age (years)',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your age';
                          }
                          final age = int.tryParse(value);
                          if (age == null || age < 13 || age > 100) {
                            return 'Please enter a valid age (13-100)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Biological Gender',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGender,
                            hint: Text(
                              'Select your gender',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                            isExpanded: true,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            dropdownColor: Theme.of(context).colorScheme.tertiary,
                            items: [
                              DropdownMenuItem<String>(
                                value: 'Male',
                                child: Text(
                                  'Male',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'Female',
                                child: Text(
                                  'Female',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedGender = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Fitness Goals',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _goalsController,
                        label: 'Describe your fitness goals (optional)',
                        maxLines: 3,
                        validator: null,
                      ),
                      const SizedBox(height: 32),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.error),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Theme.of(context).colorScheme.error),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      CustomButton(
                        onPressed: _isSaving ? null : _saveStats,
                        isLoading: _isSaving,
                        child: Text(
                          _isSaving ? 'Updating...' : 'Update Stats',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
