import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  // Common fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Trainer fields
  final _specializationController = TextEditingController();
  final _experienceController = TextEditingController();

  // Client fields
  final _weightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _ageController = TextEditingController();
  final _goalsController = TextEditingController();

  UserRole _selectedRole = UserRole.client;
  String? _selectedTrainerId;
  String? _selectedGender;
  List<UserData> _trainers = [];
  bool _isLoading = false;
  bool _showOptionalFields = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Phone number formatter
  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(###) ###-####',
    filter: {'#': RegExp(r'[0-9]')},
  );

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    
    // Listen to password changes for real-time validation
    _passwordController.addListener(() {
      setState(() {});
    });
    
    _slideController.forward();
    _loadTrainers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _experienceController.dispose();
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _ageController.dispose();
    _goalsController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadTrainers() async {
    final trainers = await _authService.getTrainers();
    setState(() {
      _trainers = trainers;
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == UserRole.client && _selectedTrainerId == null) {
      setState(() {
        _errorMessage = 'Please select a trainer';
      });
      return;
    }

    if (_selectedRole == UserRole.client && _selectedGender == null) {
      setState(() {
        _errorMessage = 'Please select your gender';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? error;

      if (_selectedRole == UserRole.trainer) {
        error = await _authService.registerTrainer(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.replaceAll(RegExp(r'[^\d]'), ''),
          specialization: _specializationController.text.trim().isEmpty 
              ? null : _specializationController.text.trim(),
          experienceYears: _experienceController.text.trim().isEmpty 
              ? null : int.tryParse(_experienceController.text.trim()),
        );
      } else {
        // Validate client-specific numeric fields
        double? weightLbs = double.tryParse(_weightController.text.trim());
        int? heightFeet = int.tryParse(_heightFeetController.text.trim());
        int? heightInches = int.tryParse(_heightInchesController.text.trim());
        int? age = int.tryParse(_ageController.text.trim());

        if (weightLbs == null || heightFeet == null || heightInches == null || age == null) {
          setState(() {
            _errorMessage = 'Please enter valid numeric values for weight, height, and age';
            _isLoading = false;
          });
          return;
        }

        // Validate height values
        if (heightInches < 0 || heightInches > 11) {
          setState(() {
            _errorMessage = 'Inches must be between 0 and 11';
            _isLoading = false;
          });
          return;
        }

        if (heightFeet < 3 || heightFeet > 8) {
          setState(() {
            _errorMessage = 'Feet must be between 3 and 8';
            _isLoading = false;
          });
          return;
        }

        // Convert pounds to kg (1 lb = 0.453592 kg)
        double weightKg = weightLbs * 0.453592;

        // Convert feet and inches to cm (1 foot = 30.48 cm, 1 inch = 2.54 cm)
        double heightCm = (heightFeet * 30.48) + (heightInches * 2.54);

        error = await _authService.registerClient(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          trainerId: _selectedTrainerId!,
          weight: weightKg,
          height: heightCm,
          age: age,
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.replaceAll(RegExp(r'[^\d]'), ''),
          goals: _goalsController.text.trim().isEmpty ? null : _goalsController.text.trim(),
          gender: _selectedGender,
        );
      }

      if (error != null) {
        String displayError = error;
        
        // Handle specific Firebase errors with user-friendly messages
        if (error.contains('demo-api-key') || error.contains('fitfusion-demo')) {
          displayError = 'This is a demo app. Firebase authentication is not fully configured for production use.';
        } else if (error.contains('email-already-in-use')) {
          displayError = 'An account with this email already exists. Please use a different email or sign in.';
        } else if (error.contains('weak-password')) {
          displayError = 'Password is too weak. Please meet all password requirements shown above.';
        } else if (error.contains('invalid-email')) {
          displayError = 'Please enter a valid email address.';
        } else if (error.contains('network')) {
          displayError = 'Network error. Please check your internet connection and try again.';
        }
        
        setState(() {
          _errorMessage = displayError;
          _isLoading = false;
        });
      } else {
        // Show success message and navigate
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account created successfully! Please sign in.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
          context.go('/login');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Registration failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _toggleOptionalFields() {
    setState(() {
      _showOptionalFields = !_showOptionalFields;
    });
    
    if (_showOptionalFields) {
      _fadeController.forward();
    } else {
      _fadeController.reverse();
    }
  }

  Widget _buildPasswordRequirement(String requirement, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet 
                ? Colors.green 
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requirement,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isMet 
                    ? Colors.green 
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Create Account',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value * 30),
            child: Opacity(
              opacity: 1 - _slideAnimation.value,
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Role Selection
                Text(
                  'I am a...',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(
                        title: 'Personal Trainer',
                        subtitle: 'Create and manage client workouts',
                        icon: Icons.fitness_center,
                        isSelected: _selectedRole == UserRole.trainer,
                        onTap: () {
                          setState(() {
                            _selectedRole = UserRole.trainer;
                            _selectedTrainerId = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoleCard(
                        title: 'Client',
                        subtitle: 'Follow personalized workout plans',
                        icon: Icons.person,
                        isSelected: _selectedRole == UserRole.client,
                        onTap: () {
                          setState(() {
                            _selectedRole = UserRole.client;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Account Info Section
                Text(
                  'Account Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _emailController,
                  label: 'Email *',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _passwordController,
                  label: 'Password *',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]').hasMatch(value)) {
                      return 'Password must contain uppercase, lowercase,\nnumber, and special character (@\$!%*?&)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Password Requirements
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password Requirements:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildPasswordRequirement(
                        'At least 8 characters', 
                        _passwordController.text.length >= 8,
                      ),
                      _buildPasswordRequirement(
                        'One uppercase letter (A-Z)', 
                        RegExp(r'[A-Z]').hasMatch(_passwordController.text),
                      ),
                      _buildPasswordRequirement(
                        'One lowercase letter (a-z)', 
                        RegExp(r'[a-z]').hasMatch(_passwordController.text),
                      ),
                      _buildPasswordRequirement(
                        'One number (0-9)', 
                        RegExp(r'\d').hasMatch(_passwordController.text),
                      ),
                      _buildPasswordRequirement(
                        'One special character (@\$!%*?&)', 
                        RegExp(r'[@$!%*?&]').hasMatch(_passwordController.text),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Personal Info Section
                Text(
                  'Personal Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _nameController,
                  label: 'Full Name *',
                  prefixIcon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Client-specific required fields
                if (_selectedRole == UserRole.client) ...[
                  CustomTextField(
                    controller: _weightController,
                    label: 'Weight (lbs) *',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.monitor_weight_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your weight';
                      }
                      double? weight = double.tryParse(value);
                      if (weight == null) {
                        return 'Please enter a valid weight';
                      }
                      if (weight < 50 || weight > 500) {
                        return 'Please enter a weight between 50-500 lbs';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Height in feet and inches
                  Text(
                    'Height *',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
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
                          prefixIcon: Icons.height,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            int? feet = int.tryParse(value);
                            if (feet == null) {
                              return 'Invalid';
                            }
                            if (feet < 3 || feet > 8) {
                              return '3-8 ft';
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
                          prefixIcon: Icons.straighten,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            int? inches = int.tryParse(value);
                            if (inches == null) {
                              return 'Invalid';
                            }
                            if (inches < 0 || inches > 11) {
                              return '0-11 in';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _ageController,
                    label: 'Age *',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.cake_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your age';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid age';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Gender Selection
                  Text(
                    'Biological Gender *',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
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
                          'Choose your gender',
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
                  const SizedBox(height: 16),

                  // Trainer Selection
                  Text(
                    'Select Trainer *',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
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
                        value: _selectedTrainerId,
                        hint: Text(
                          'Choose a trainer',
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
                        items: _trainers.map((trainer) {
                          return DropdownMenuItem<String>(
                            value: trainer.id,
                            child: Text(
                              '${trainer.name}${trainer.specialization != null ? ' - ${trainer.specialization}' : ''}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTrainerId = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Optional Fields Toggle
                TextButton.icon(
                  onPressed: _toggleOptionalFields,
                  icon: Icon(
                    _showOptionalFields 
                        ? Icons.keyboard_arrow_up 
                        : Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(
                    _showOptionalFields 
                        ? 'Hide Optional Information'
                        : 'More Info (Optional)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                // Optional Fields
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: _showOptionalFields ? null : 0,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        inputFormatters: [_phoneMaskFormatter],
                      ),
                      const SizedBox(height: 16),

                      if (_selectedRole == UserRole.trainer) ...[
                        CustomTextField(
                          controller: _specializationController,
                          label: 'Specialization',
                          prefixIcon: Icons.sports_gymnastics_outlined,
                          hintText: 'e.g., Strength Training, Yoga, Cardio',
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _experienceController,
                          label: 'Years of Experience',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.timeline_outlined,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final years = int.tryParse(value);
                              if (years == null || years < 0 || years > 50) {
                                return 'Please enter a valid number of years (0-50)';
                              }
                            }
                            return null;
                          },
                        ),
                      ] else ...[
                        CustomTextField(
                          controller: _goalsController,
                          label: 'Fitness Goals',
                          maxLines: 3,
                          prefixIcon: Icons.flag_outlined,
                          hintText: 'e.g., Lose weight, Build muscle, Improve endurance',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Register Button
                CustomButton(
                  onPressed: _isLoading ? null : _register,
                  isLoading: _isLoading,
                  child: const Text('Create Account'),
                ),
                const SizedBox(height: 16),

                // Cancel Button
                CustomButton(
                  onPressed: () => context.pop(),
                  type: ButtonType.secondary,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.tertiary,
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}