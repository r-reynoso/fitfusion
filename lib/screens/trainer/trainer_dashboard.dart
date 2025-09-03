import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/routine_service.dart';
import '../../widgets/custom_button.dart';

class TrainerDashboard extends StatefulWidget {
  final String trainerId;

  const TrainerDashboard({super.key, required this.trainerId});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final RoutineService _routineService = RoutineService();

  List<Map<String, dynamic>> _clients = [];
  List<WorkoutRoutine> _recentRoutines = [];
  List<Map<String, dynamic>> _filteredClients = [];
  List<WorkoutRoutine> _filteredRoutines = [];
  UserData? _trainerData;
  bool _isLoading = true;
  int _currentPage = 0;
  static const int _pageSize = 25;
  int _selectedTabIndex = 0; // 0 = Your Clients, 1 = Recent Routines
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

    _loadData();
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load trainer data
      _trainerData = await _authService.getCurrentUserData();

      // Load clients using the auth service (which handles demo mode)
      List<Map<String, dynamic>> clients =
          await _authService.getTrainerClients(widget.trainerId);

      // Load recent routines using the routine service
      List<WorkoutRoutine> routines = await _routineService.getTrainerRoutines(
        widget.trainerId,
        page: _currentPage,
        limit: _pageSize,
      );

      setState(() {
        _clients = clients;
        _recentRoutines = routines;
        _isLoading = false;
      });
      
      _filterData();
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterData() {
    setState(() {
      if (_searchQuery.isEmpty) {
        // If no search query, show all clients and routines
        _filteredClients = List.from(_clients);
        _filteredRoutines = List.from(_recentRoutines);
      } else {
        // Filter clients by name (partial match, case-insensitive)
        _filteredClients = _clients.where((client) {
          final name = client['name']?.toString().toLowerCase() ?? '';
          return name.contains(_searchQuery.toLowerCase());
        }).toList();

        // Filter routines to show only those for filtered clients
        final filteredClientIds = _filteredClients.map((client) => client['userId']).toSet();
        _filteredRoutines = _recentRoutines.where((routine) {
          return filteredClientIds.contains(routine.clientId);
        }).toList();
      }
    });
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _filterData();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchQuery = '';
    _filterData();
  }

  Future<void> _confirmSignOut() async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Confirm Sign Out',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out?',
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
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'Sign Out',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      await _authService.signOut();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _confirmDeleteRoutine(WorkoutRoutine routine) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Delete Routine',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${routine.title}"? This action cannot be undone.',
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
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'Delete',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        bool success = await _routineService.deleteRoutine(routine.id);
        if (success) {
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Routine "${routine.title}" has been deleted'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }
          // Refresh the data to remove the deleted routine
          _loadData();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete routine. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('Error deleting routine: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete routine. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteClient(Map<String, dynamic> client) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Delete Client',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${client['name']}"? This will permanently remove the client and all their routines. The client will need to register again to use the app.',
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
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(
                'Delete Client',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            content: Row(
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 20),
                Text(
                  'Deleting client...',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );

        // First delete all routines for this client
        bool routinesDeleted = await _routineService.deleteAllClientRoutines(client['userId']);
        
        if (routinesDeleted) {
          // Then delete the client
          String? error = await _authService.deleteClient(client['userId']);
          
          // Dismiss loading dialog
          if (mounted) Navigator.of(context).pop();
          
          if (error == null) {
            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Client "${client['name']}" has been deleted'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
            }
            // Refresh the data to remove the deleted client
            _loadData();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          // Dismiss loading dialog
          if (mounted) Navigator.of(context).pop();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete client routines. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        // Dismiss loading dialog if still showing
        if (mounted) Navigator.of(context).pop();
        
        print('Error deleting client: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete client. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
        title: Text(
          _selectedTabIndex == 0 ? 'My Clients' : 'My Routines',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _confirmSignOut,
            icon: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
            label: Text(
              'Sign Out',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SlideTransition(
              position: _slideAnimation,
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 16.0,
                    bottom: 16.0 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedTabIndex == 0) _buildYourClientsContent(),
                      if (_selectedTabIndex == 1) _buildRecentRoutinesContent(),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Your Clients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: 'Recent Routines',
          ),
        ],
      ),
    );
  }

  Widget _buildYourClientsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome, ${_trainerData?.name ?? 'Trainer'}!",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onTertiary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have ${_clients.length} active clients',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
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
        const SizedBox(height: 24),

        // Clients Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Clients',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '${_filteredClients.length}/${_clients.length}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Search Filter
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onTertiary,
            ),
            decoration: InputDecoration(
              hintText: 'Search clients by name...',
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.6),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.6),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: _clearSearch,
                      icon: Icon(
                        Icons.clear,
                        color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.6),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_filteredClients.isEmpty && _searchQuery.isEmpty)
          _EmptyStateCard(
            icon: Icons.people_outline,
            title: 'No Clients Yet',
            subtitle:
                'Clients will appear here once they register and select you as their trainer.',
          )
        else if (_filteredClients.isEmpty && _searchQuery.isNotEmpty)
          _EmptyStateCard(
            icon: Icons.search_off,
            title: 'No Clients Found',
            subtitle:
                'No clients match your search criteria. Try a different search term.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredClients.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final client = _filteredClients[index];
              return _ClientCard(
                client: client,
                onCreateRoutine: () async {
                  final result = await context.push(
                    '/trainer/${widget.trainerId}/routines/new/edit?clientId=${client['userId']}',
                  );
                  // If routine was saved, refresh the data
                  if (result == true) {
                    _loadData();
                  }
                },
                onDelete: () async {
                  await _confirmDeleteClient(client);
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildRecentRoutinesContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome back, ${_trainerData?.name ?? 'Trainer'}!",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onTertiary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'You have ${_recentRoutines.length} total routines',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
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
        const SizedBox(height: 24),

        // Recent Routines Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Routines',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '${_filteredRoutines.length} total',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_filteredRoutines.isEmpty && _searchQuery.isEmpty)
          _EmptyStateCard(
            icon: Icons.fitness_center_outlined,
            title: 'No Routines Created',
            subtitle:
                'Create workout routines for your clients to get started.',
          )
        else if (_filteredRoutines.isEmpty && _searchQuery.isNotEmpty)
          _EmptyStateCard(
            icon: Icons.search_off,
            title: 'No Routines Found',
            subtitle:
                'No routines found for the filtered clients.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredRoutines.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final routine = _filteredRoutines[index];
              return _RoutineCard(
                routine: routine,
                onEdit: () async {
                  final result = await context.push(
                    '/trainer/${widget.trainerId}/routines/${routine.id}/edit?clientId=${routine.clientId}',
                  );
                  // If routine was saved, refresh the data
                  if (result == true) {
                    _loadData();
                  }
                },
                onDelete: () async {
                  await _confirmDeleteRoutine(routine);
                },
              );
            },
          ),
      ],
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final VoidCallback onCreateRoutine;
  final VoidCallback onDelete;

  const _ClientCard({
    required this.client,
    required this.onCreateRoutine,
    required this.onDelete,
  });

  String _formatWeight(dynamic weight) {
    if (weight == null) return 'N/A';
    try {
      double weightKg = double.parse(weight.toString());
      double weightLbs = weightKg * 2.20462;
      return '${weightLbs.round()} lbs';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatHeight(dynamic height) {
    if (height == null) return 'N/A';
    try {
      double heightCm = double.parse(height.toString());
      double heightInches = heightCm / 2.54;
      int feet = (heightInches / 12).floor();
      int inches = (heightInches % 12).round();
      return '${feet}\'${inches}"';
    } catch (e) {
      return 'N/A';
    }
  }

  double _calculateBMI(dynamic weight, dynamic height) {
    if (weight == null || height == null) return 0.0;
    try {
      double weightKg = double.parse(weight.toString());
      double heightCm = double.parse(height.toString());
      double heightM = heightCm / 100;
      return weightKg / (heightM * heightM);
    } catch (e) {
      return 0.0;
    }
  }

  double _calculateBMR(dynamic weight, dynamic height, dynamic age, String? gender) {
    if (weight == null || height == null || age == null) return 0.0;
    try {
      double weightKg = double.parse(weight.toString());
      double heightCm = double.parse(height.toString());
      double heightInches = heightCm / 2.54;
      double weightLbs = weightKg * 2.20462;
      int ageYears = int.parse(age.toString());

      // Use gender-specific BMR formulas
      if (gender == 'Male') {
        return 66 + (6.23 * weightLbs) + (12.7 * heightInches) - (6.8 * ageYears);
      } else if (gender == 'Female') {
        return 655 + (4.35 * weightLbs) + (4.7 * heightInches) - (4.7 * ageYears);
      }
      
      // Default to men's formula if gender is unknown
      return 66 + (6.23 * weightLbs) + (12.7 * heightInches) - (6.8 * ageYears);
    } catch (e) {
      return 0.0;
    }
  }

  double _calculateTDEE(double bmr) {
    // Using moderately active multiplier (1.55) as default
    return bmr * 1.55;
  }

  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // If not 10 digits, return as is
    if (digits.length != 10) {
      return phone;
    }
    
    // Format as (XXX) XXX-XXXX
    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final metrics = client['metrics'] as Map<String, dynamic>? ?? {};

    // Calculate health metrics
    final bmi = _calculateBMI(metrics['weight'], metrics['height']);
    final bmr = _calculateBMR(metrics['weight'], metrics['height'], metrics['age'], metrics['gender']);
    final tdee = _calculateTDEE(bmr);

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
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  client['name']?.toString().substring(0, 1).toUpperCase() ??
                      'C',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client['name'] ?? 'Unknown Client',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      client['email'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiary
                                .withOpacity(0.7),
                          ),
                    ),
                    if (client['phone'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatPhoneNumber(client['phone'] ?? ''),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onTertiary
                                  .withOpacity(0.7),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                tooltip: 'Delete Client',
              ),
            ],
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  icon: Icons.monitor_weight_outlined,
                  label: _formatWeight(metrics['weight']),
                ),
                _MetricChip(
                  icon: Icons.height,
                  label: _formatHeight(metrics['height']),
                ),
                _MetricChip(
                  icon: Icons.cake_outlined,
                  label: '${metrics['age']?.toString() ?? 'N/A'} yrs',
                ),
                if (metrics['gender'] != null)
                  _MetricChip(
                    icon: metrics['gender'] == 'Male' 
                        ? Icons.male 
                        : metrics['gender'] == 'Female' 
                            ? Icons.female 
                            : Icons.person,
                    label: metrics['gender'].toString(),
                  ),
                // Health metrics
                if (bmi > 0)
                  _MetricChip(
                    icon: Icons.accessibility_new,
                    label: 'BMI ${bmi.toStringAsFixed(1)}',
                  ),
                if (bmr > 0)
                  _MetricChip(
                    icon: Icons.local_fire_department,
                    label: 'BMR ${bmr.round()}',
                  ),
                if (tdee > 0)
                  _MetricChip(
                    icon: Icons.fitness_center,
                    label: 'TDEE ${tdee.round()}',
                  ),
              ],
            ),
            if (metrics['goals'] != null && metrics['goals'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Goals:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metrics['goals'].toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiary
                                .withOpacity(0.8),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              onPressed: onCreateRoutine,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Create Routine',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 16,
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
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final WorkoutRoutine routine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoutineCard({
    required this.routine,
    required this.onEdit,
    required this.onDelete,
  });

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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${routine.days.length} days • Updated ${_formatDate(routine.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiary
                                .withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outlined,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (routine.isPublic) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.link,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Public Link Active',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'today';
    } else if (difference == 1) {
      return 'yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onTertiary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onTertiary.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
