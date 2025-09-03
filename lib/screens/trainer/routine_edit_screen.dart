import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/routine_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

class RoutineEditScreen extends StatefulWidget {
  final String trainerId;
  final String? routineId;
  final String? clientId;

  const RoutineEditScreen({
    super.key,
    required this.trainerId,
    this.routineId,
    this.clientId,
  });

  @override
  State<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends State<RoutineEditScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final RoutineService _routineService = RoutineService();
  final AuthService _authService = AuthService();

  List<RoutineDay> _days = [];
  WorkoutRoutine? _existingRoutine;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _publicToken;
  String? _clientName;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

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

    _slideController.forward();
    _loadRoutine();
    _loadClientName();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutine() async {
    if (widget.routineId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      WorkoutRoutine? routine = await _routineService.getRoutineById(widget.routineId!);
      if (routine != null) {
        setState(() {
          _existingRoutine = routine;
          _titleController.text = routine.title;
          _notesController.text = routine.notes ?? '';
          _days = List.from(routine.days);
          _publicToken = routine.publicToken;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load routine';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadClientName() async {
    if (widget.clientId == null) return;
    
    try {
      String? clientName = await _authService.getClientNameById(widget.clientId!);
      setState(() {
        _clientName = clientName;
      });
    } catch (e) {
      // If we can't get the client name, continue without it
      print('Error loading client name: $e');
    }
  }

  bool _validateForm() {
    // Clear any existing error messages
    setState(() {
      _errorMessage = null;
    });

    // First validate the main form fields
    if (!_formKey.currentState!.validate()) {
      // Focus the title field if it's empty (main form validation failed)
      if (_titleController.text.trim().isEmpty) {
        FocusScope.of(context).requestFocus(FocusNode());
        // Since CustomTextField handles its own focus, we'll trigger the form validation to show errors
      }
      return false;
    }

    // Validate that we have at least one day
    if (_days.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one workout day';
      });
      return false;
    }

    // Validate each day
    for (int dayIndex = 0; dayIndex < _days.length; dayIndex++) {
      final day = _days[dayIndex];
      
      // Validate day name
      if (day.day.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Day ${dayIndex + 1}: Please enter a day name';
        });
        return false;
      }

      // Validate each exercise in the day
      int exerciseCount = 0; // Count only actual exercises for error messages
      for (int itemIndex = 0; itemIndex < day.items.length; itemIndex++) {
        final item = day.items[itemIndex];
        
        if (item is Exercise) {
          exerciseCount++; // Increment only for exercises, not dividers
          
          // Validate exercise name
          if (item.name.trim().isEmpty) {
            setState(() {
              _errorMessage = 'Day ${dayIndex + 1}: Exercise $exerciseCount - Please enter exercise name';
            });
            return false;
          }
          
          // Validate repetitions
          if (item.reps.trim().isEmpty) {
            setState(() {
              _errorMessage = 'Day ${dayIndex + 1}: Exercise $exerciseCount - Please enter repetitions';
            });
            return false;
          }
          
          // Validate sets
          if (item.sets.trim().isEmpty) {
            setState(() {
              _errorMessage = 'Day ${dayIndex + 1}: Exercise $exerciseCount - Please enter sets';
            });
            return false;
          }
        }
        // Note: Dividers don't require validation as their labels are optional
      }
    }

    return true;
  }

  Future<void> _saveRoutine() async {
    setState(() {
      _errorMessage = null;
    });

    // Custom validation to focus first invalid field
    if (!_validateForm()) {
      return;
    }

    if (_days.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one workout day';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      WorkoutRoutine routine = WorkoutRoutine(
        id: widget.routineId ?? '',
        clientId: widget.clientId ?? _existingRoutine?.clientId ?? '',
        trainerId: widget.trainerId,
        title: _titleController.text.trim(),
        days: _days,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        isPublic: _existingRoutine?.isPublic ?? false,
        publicToken: _publicToken,
        publicExpiresAt: _existingRoutine?.publicExpiresAt,
        createdAt: _existingRoutine?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool success;
      if (widget.routineId == null) {
        String? newId = await _routineService.createRoutine(routine);
        success = newId != null;
      } else {
        success = await _routineService.updateRoutine(widget.routineId!, routine);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Routine saved successfully!')),
        );
        // Pop back to trainer dashboard with a result to trigger refresh
        context.pop(true);
      } else {
        setState(() {
          _errorMessage = 'Failed to save routine';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred while saving';
      });
    }

    setState(() {
      _isSaving = false;
    });
  }

  Future<void> _generatePublicLink() async {
    if (widget.routineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the routine first')),
      );
      return;
    }

    try {
      DateTime expiresAt = DateTime.now().add(const Duration(days: 30));
      String token = await _routineService.generatePublicToken(widget.routineId!, expiresAt);
      setState(() {
        _publicToken = token;
      });

      String publicUrl = 'https://fitfusion.app/r/$token';
      await Clipboard.setData(ClipboardData(text: publicUrl));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Public link copied to clipboard!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate public link')),
      );
    }
  }

  String _buildTitle() {
    String baseTitle = widget.routineId == null ? 'Create Routine' : 'Edit Routine';
    if (_clientName != null) {
      return '$baseTitle – $_clientName';
    }
    return baseTitle;
  }

  void _addDay() {
    setState(() {
      _days.add(RoutineDay(day: 'Day ${_days.length + 1}', items: []));
    });
  }

  Future<void> _removeDay(int index) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Delete Day',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this day?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      setState(() {
        _days.removeAt(index);
      });
    }
  }

  void _addExercise(int dayIndex) {
    setState(() {
      _days[dayIndex] = RoutineDay(
        day: _days[dayIndex].day,
        items: [
          ..._days[dayIndex].items,
          Exercise(name: '', reps: '', sets: ''),
        ],
      );
    });
  }

  void _addDivider(int dayIndex) {
    setState(() {
      _days[dayIndex] = RoutineDay(
        day: _days[dayIndex].day,
        items: [
          ..._days[dayIndex].items,
          RoutineDivider(label: ''),
        ],
      );
    });
  }

  Future<void> _removeItem(int dayIndex, int itemIndex) async {
    final RoutineItem item = _days[dayIndex].items[itemIndex];
    String itemType = item is Exercise ? 'exercise' : 'divider';
    String title = item is Exercise ? 'Delete Exercise' : 'Delete Divider';
    String message = item is Exercise 
        ? 'Are you sure you want to delete this exercise?' 
        : 'Are you sure you want to delete this divider?';

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      setState(() {
        List<RoutineItem> items = List.from(_days[dayIndex].items);
        items.removeAt(itemIndex);
        _days[dayIndex] = RoutineDay(
          day: _days[dayIndex].day,
          items: items,
        );
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
          _buildTitle(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (widget.routineId != null)
            IconButton(
              onPressed: _generatePublicLink,
              icon: Icon(
                Icons.share,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SlideTransition(
              position: _slideAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: 24.0,
                          right: 24.0,
                          top: 24.0,
                          bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Basic Info
                            CustomTextField(
                              controller: _titleController,
                              label: 'Routine Title *',
                              prefixIcon: Icons.title,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a routine title';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            CustomTextField(
                              controller: _notesController,
                              label: 'Notes (Optional)',
                              prefixIcon: Icons.notes,
                              maxLines: 3,
                              hintText: 'Add any general notes or instructions...',
                            ),
                            const SizedBox(height: 24),

                            // Workout Days
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Workout Days',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _addDay,
                                  icon: Icon(
                                    Icons.add,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  label: Text(
                                    'Add Day',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (_days.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.tertiary,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.fitness_center_outlined,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No workout days yet',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onTertiary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Add workout days to build your routine',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _days.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  return _DayCard(
                                    day: _days[index],
                                    dayIndex: index,
                                    onDayChanged: (newDay) {
                                      setState(() {
                                        _days[index] = newDay;
                                      });
                                    },
                                    onRemoveDay: () => _removeDay(index),
                                    onAddExercise: () => _addExercise(index),
                                    onAddDivider: () => _addDivider(index),
                                    onRemoveItem: (itemIndex) => _removeItem(index, itemIndex),
                                  );
                                },
                              ),

                            // Error Message
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],

                            // Public Link Info
                            if (_publicToken != null) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.link,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Public Link Active',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'https://fitfusion.app/r/$_publicToken',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 80), // Space for bottom buttons
                          ],
                        ),
                      ),
                    ),

                    // Bottom Actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              onPressed: () => context.pop(),
                              type: ButtonType.secondary,
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomButton(
                              onPressed: _isSaving ? null : _saveRoutine,
                              isLoading: _isSaving,
                              child: Text(
                                widget.routineId == null ? 'Create' : 'Save',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DayCard extends StatefulWidget {
  final RoutineDay day;
  final int dayIndex;
  final Function(RoutineDay) onDayChanged;
  final VoidCallback onRemoveDay;
  final VoidCallback onAddExercise;
  final VoidCallback onAddDivider;
  final Function(int) onRemoveItem;

  const _DayCard({
    required this.day,
    required this.dayIndex,
    required this.onDayChanged,
    required this.onRemoveDay,
    required this.onAddExercise,
    required this.onAddDivider,
    required this.onRemoveItem,
  });

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  late TextEditingController _dayController;
  List<dynamic> _itemControllers = []; // Can hold exercise controllers or divider controllers

  @override
  void initState() {
    super.initState();
    _dayController = TextEditingController(text: widget.day.day);
    _initializeControllers();
  }

  @override
  void dispose() {
    _dayController.dispose();
    for (var controllerGroup in _itemControllers) {
      if (controllerGroup is List<TextEditingController>) {
        for (var controller in controllerGroup) {
          controller.dispose();
        }
      } else if (controllerGroup is TextEditingController) {
        controllerGroup.dispose();
      }
    }
    super.dispose();
  }

  void _initializeControllers() {
    _itemControllers = widget.day.items.map((item) {
      if (item is Exercise) {
        return [
          TextEditingController(text: item.name),
          TextEditingController(text: item.reps),
          TextEditingController(text: item.sets),
          TextEditingController(text: item.notes ?? ''),
        ];
      } else if (item is RoutineDivider) {
        return TextEditingController(text: item.label ?? '');
      }
      return null;
    }).where((controller) => controller != null).toList();
  }

  void _updateDay() {
    List<RoutineItem> items = [];
    
    for (int i = 0; i < _itemControllers.length; i++) {
      final controller = _itemControllers[i];
      final originalItem = i < widget.day.items.length ? widget.day.items[i] : null;
      
      if (controller is List<TextEditingController> && originalItem is Exercise) {
        final exercise = Exercise(
          name: controller[0].text.trim(),
          reps: controller[1].text.trim(),
          sets: controller[2].text.trim(),
          notes: controller[3].text.trim().isEmpty ? null : controller[3].text.trim(),
        );
        if (exercise.name.isNotEmpty) {
          items.add(exercise);
        }
      } else if (controller is TextEditingController && originalItem is RoutineDivider) {
        items.add(RoutineDivider(label: controller.text.trim().isEmpty ? null : controller.text.trim()));
      }
    }

    RoutineDay updatedDay = RoutineDay(
      day: _dayController.text.trim(),
      items: items,
    );

    widget.onDayChanged(updatedDay);
  }

  void _addExercise() {
    setState(() {
      _itemControllers.add([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]);
    });
    widget.onAddExercise();
  }

  void _addDivider() {
    setState(() {
      _itemControllers.add(TextEditingController());
    });
    widget.onAddDivider();
  }

  void _removeItem(int index) {
    setState(() {
      final controller = _itemControllers[index];
      if (controller is List<TextEditingController>) {
        for (var ctrl in controller) {
          ctrl.dispose();
        }
      } else if (controller is TextEditingController) {
        controller.dispose();
      }
      _itemControllers.removeAt(index);
    });
    widget.onRemoveItem(index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dayController,
                  onChanged: (_) => _updateDay(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiary,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Day Name',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onRemoveDay,
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Items (Exercises and Dividers)
          if (_itemControllers.isEmpty)
            Center(
              child: Text(
                'No exercises yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.7),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _itemControllers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final controller = _itemControllers[index];
                
                // Determine item type based on controller type, not original item
                if (controller is List<TextEditingController>) {
                  return _ExerciseRow(
                    controllers: controller,
                    onChanged: _updateDay,
                    onRemove: () => _removeItem(index),
                  );
                } else if (controller is TextEditingController) {
                  return _DividerRow(
                    controller: controller,
                    onChanged: _updateDay,
                    onRemove: () => _removeItem(index),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

          const SizedBox(height: 16),

          // Add buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: _addExercise,
                  type: ButtonType.secondary,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.onSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Add Exercise',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  onPressed: _addDivider,
                  type: ButtonType.secondary,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.horizontal_rule,
                        color: Theme.of(context).colorScheme.onSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Add Divider',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ExerciseRow({
    required this.controllers,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Main exercise info row
          Row(
            children: [
              // Exercise name field - takes more space
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: controllers[0],
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: 'Exercise',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Repetitions and Sets row - responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              // On smaller screens, stack vertically; on larger screens, use row
              if (constraints.maxWidth < 300) {
                return Column(
                  children: [
                    _buildRepetitionsField(),
                    const SizedBox(height: 8),
                    _buildSetsField(),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(child: _buildRepetitionsField()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSetsField()),
                  ],
                );
              }
            },
          ),
          
          const SizedBox(height: 12),
          
          // Notes field
          TextFormField(
            controller: controllers[3],
            onChanged: (_) => onChanged(),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepetitionsField() {
    return TextFormField(
      controller: controllers[1],
      onChanged: (_) => onChanged(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Repetitions',
        hintText: '8-12',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildSetsField() {
    return TextFormField(
      controller: controllers[2],
      onChanged: (_) => onChanged(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Sets',
        hintText: '3-4',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

class _DividerRow extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _DividerRow({
    required this.controller,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          style: BorderStyle.solid,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Divider Header
          Row(
            children: [
              Icon(
                Icons.horizontal_rule,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: 'Divider Label (Optional)',
                    hintText: 'e.g., Upper Body, Cardio',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Visual Divider Preview
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}