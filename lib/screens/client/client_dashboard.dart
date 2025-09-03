import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/routine_service.dart';

class ClientDashboard extends StatefulWidget {
final String clientId;

const ClientDashboard({super.key, required this.clientId});

@override
State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard>
with TickerProviderStateMixin {
final AuthService _authService = AuthService();
final RoutineService _routineService = RoutineService();

List<WorkoutRoutine> _routines = [];
UserData? _userData;
UserData? _trainerData;
ClientMetrics? _clientMetrics;
bool _isLoading = true;
int _currentPage = 0;
static const int _pageSize = 25;
int _selectedTabIndex = 0; // 0 = Your Routines, 1 = Your Stats

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
super.dispose();
}

Future<void> _loadData() async {
setState(() {
_isLoading = true;
});

try {
// Load user data
_userData = await _authService.getCurrentUserData();

// Load client metrics
_clientMetrics = await _authService.getClientMetrics(widget.clientId);

// Load trainer data if client has a trainer
if (_userData?.trainerId != null) {
_trainerData = await _authService.getTrainerById(_userData!.trainerId!);
}

// Load routines
List<WorkoutRoutine> routines = await _routineService.getClientRoutines(
widget.clientId,
page: _currentPage,
limit: _pageSize,
);

setState(() {
_routines = routines;
_isLoading = false;
});
} catch (e) {
print('Error loading data: $e');
setState(() {
_isLoading = false;
});
}
}

Future<void> _copyPublicLink(String token) async {
String publicUrl = 'https://fitfusion.app/r/$token';
await Clipboard.setData(ClipboardData(text: publicUrl));

if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Public link copied to clipboard!')),
);
}
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
color:
Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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

Future<void> _editStats() async {
final result = await context.push('/client/${widget.clientId}/edit-stats');
if (result == true) {
// Refresh data after successful update
_loadData();
}
}

String _formatHeight(double heightInCm) {
// Convert cm to total inches
double totalInches = heightInCm / 2.54;

// Calculate feet and remaining inches
int feet = (totalInches / 12).floor();
int inches = (totalInches % 12).round();

return '$feet\' $inches"';
}

double _calculateBMI() {
if (_clientMetrics == null) return 0;
double weightKg = _clientMetrics!.weight;
double heightM = _clientMetrics!.height / 100;
return weightKg / (heightM * heightM);
}

double _calculateBMR() {
if (_clientMetrics == null) return 0;
double weightKg = _clientMetrics!.weight;
double heightCm = _clientMetrics!.height;
int age = _clientMetrics!.age;
String? gender = _clientMetrics!.gender;

// Convert weight to pounds and height to inches for the Harris-Benedict formula
double weightLbs = weightKg * 2.20462;
double heightInches = heightCm / 2.54;

// Using Harris-Benedict Equation with gender-specific formulas
if (gender?.toLowerCase() == 'male') {
// Male: BMR = 66 + (6.23 × Weight in lbs) + (12.7 × Height in inches) − (6.8 × Age)
return 66 + (6.23 * weightLbs) + (12.7 * heightInches) - (6.8 * age);
} else if (gender?.toLowerCase() == 'female') {
// Female: BMR = 655 + (4.35 × Weight in lbs) + (4.7 × Height in inches) − (4.7 × Age)
return 655 + (4.35 * weightLbs) + (4.7 * heightInches) - (4.7 * age);
} else {
// Fallback to average formula if gender is not specified
return (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 78;
}
}

double _calculateTDEE() {
// Using moderate activity level (1.55 multiplier)
// Light/sedentary: 1.2, Light exercise: 1.375, Moderate: 1.55, Heavy: 1.725, Very heavy: 1.9
return _calculateBMR() * 1.55;
}

String _getHealthyWeightRange() {
if (_clientMetrics == null) return '';
double heightM = _clientMetrics!.height / 100;

// Healthy BMI range: 18.5 - 24.9
double minHealthyWeight = 18.5 * heightM * heightM;
double maxHealthyWeight = 24.9 * heightM * heightM;

// Convert to pounds
double minWeightLbs = minHealthyWeight * 2.205;
double maxWeightLbs = maxHealthyWeight * 2.205;

return '${minWeightLbs.toStringAsFixed(0)}-${maxWeightLbs.toStringAsFixed(0)} lbs';
}

String _getBMICategory() {
double bmi = _calculateBMI();
if (bmi < 18.5) return 'Underweight';
if (bmi < 25) return 'Normal';
if (bmi < 30) return 'Overweight';
return 'Obese';
}

void _showBMIInfo(BuildContext context) {
showDialog(
context: context,
builder: (BuildContext context) {
return AlertDialog(
backgroundColor: Theme.of(context).colorScheme.surface,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
title: Row(
children: [
Icon(
Icons.info_outline,
color: Theme.of(context).colorScheme.primary,
size: 24,
),
const SizedBox(width: 8),
Text(
'BMI Information',
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
],
),
content: Text(
'Body Mass Index - Quick measure of whether someone is underweight, normal, overweight, or obese (though it doesn\'t account for muscle mass).',
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
fontSize: 16,
height: 1.4,
),
),
actions: [
TextButton(
onPressed: () => Navigator.of(context).pop(),
child: Text(
'Got it',
style: TextStyle(
color: Theme.of(context).colorScheme.primary,
fontWeight: FontWeight.w600,
),
),
),
],
);
},
);
}

void _showBMRInfo(BuildContext context) {
showDialog(
context: context,
builder: (BuildContext context) {
return AlertDialog(
backgroundColor: Theme.of(context).colorScheme.surface,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),
title: Row(
children: [
Icon(
Icons.info_outline,
color: Theme.of(context).colorScheme.primary,
size: 24,
),
const SizedBox(width: 8),
Text(
'BMR Information',
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
],
),
content: Text(
'Basal Metabolic Rate - Estimates calories burned at rest (good for nutrition/routine planning).',
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
fontSize: 16,
height: 1.4,
),
),
actions: [
TextButton(
onPressed: () => Navigator.of(context).pop(),
child: Text(
'Got it',
style: TextStyle(
color: Theme.of(context).colorScheme.primary,
fontWeight: FontWeight.w600,
),
),
),
],
);
},
);
}

void _showTDEEInfo() {
showDialog(
context: context,
builder: (BuildContext context) {
return AlertDialog(
backgroundColor: Theme.of(context).colorScheme.surface,
title: Row(
children: [
Icon(
Icons.fitness_center_outlined,
color: Theme.of(context).colorScheme.primary,
size: 24,
),
const SizedBox(width: 8),
Text(
'TDEE',
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
],
),
content: Text(
'Daily Caloric Needs - Helps trainers set calorie goals for weight loss, maintenance, or muscle gain.',
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
fontSize: 16,
height: 1.4,
),
),
actions: [
TextButton(
onPressed: () => Navigator.of(context).pop(),
child: Text(
'Got it',
style: TextStyle(
color: Theme.of(context).colorScheme.primary,
fontWeight: FontWeight.w600,
),
),
),
],
);
},
);
}

Widget _buildYourStatsContent() {
if (_clientMetrics == null) return const SizedBox.shrink();

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Header Section
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
'Your Stats',
style: Theme.of(context)
.textTheme
.titleLarge
?.copyWith(
color:
Theme.of(context).colorScheme.onSurface,
fontWeight: FontWeight.bold,
),
),
ElevatedButton.icon(
onPressed: _editStats,
icon: Icon(
Icons.edit,
size: 18,
color: Theme.of(context).colorScheme.onPrimary,
),
label: Text(
'Edit Stats',
style: TextStyle(
color: Theme.of(context).colorScheme.onPrimary,
fontWeight: FontWeight.w600,
),
),
style: ElevatedButton.styleFrom(
backgroundColor: Theme.of(context).colorScheme.primary,
foregroundColor: Theme.of(context).colorScheme.onPrimary,
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(8),
),
),
),
],
),
const SizedBox(height: 16),

// Stats Row (Weight, Height, Age)
Row(
children: [
Expanded(
child: _StatCard(
icon: Icons.scale_outlined,
label: 'Weight',
value:
'${(_clientMetrics!.weight * 2.20462).toStringAsFixed(0)} lbs',
color: Theme.of(context).colorScheme.primary,
),
),
const SizedBox(width: 12),
Expanded(
child: _StatCard(
icon: Icons.height_outlined,
label: 'Height',
value: _formatHeight(_clientMetrics!.height),
color: Theme.of(context).colorScheme.primary,
),
),
const SizedBox(width: 12),
Expanded(
child: _StatCard(
icon: Icons.cake_outlined,
label: 'Age',
value: '${_clientMetrics!.age} yrs',
color: Theme.of(context).colorScheme.primary,
),
),
],
),
const SizedBox(height: 24),

// Health Metrics Section
Container(
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
Text(
'Health Metrics',
style: Theme.of(context).textTheme.titleMedium?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 20),

// BMI Section
Row(
children: [
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
borderRadius: BorderRadius.circular(12),
),
child: Icon(
Icons.analytics_outlined,
color: Theme.of(context).colorScheme.primary,
size: 24,
),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Text(
'BMI',
style: Theme.of(context).textTheme.bodyLarge?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.w600,
),
),
const SizedBox(width: 8),
GestureDetector(
onTap: () => _showBMIInfo(context),
child: Icon(
Icons.info_outline,
size: 18,
color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.6),
),
),
],
),
const SizedBox(height: 4),
Text(
_getBMICategory(),
style: Theme.of(context).textTheme.bodySmall?.copyWith(
color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.7),
),
),
],
),
),
Text(
_calculateBMI().toStringAsFixed(1),
style: Theme.of(context).textTheme.titleLarge?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.bold,
),
),
],
),

const SizedBox(height: 20),
Divider(
color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.1),
height: 1,
),
const SizedBox(height: 20),

// BMR Section
Row(
children: [
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
borderRadius: BorderRadius.circular(12),
),
child: Icon(
Icons.local_fire_department_outlined,
color: Theme.of(context).colorScheme.primary,
size: 24,
),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Flexible(
child: Text(
'BMR',
style: Theme.of(context).textTheme.bodyLarge?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.w600,
),
overflow: TextOverflow.ellipsis,
),
),
const SizedBox(width: 8),
GestureDetector(
onTap: () => _showBMRInfo(context),
child: Icon(
Icons.info_outline,
size: 18,
color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.6),
),
),
],
),
const SizedBox(height: 4),
Text(
'Calories burned at rest',
style: Theme.of(context).textTheme.bodySmall?.copyWith(
color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.7),
),
),
],
),
),
Column(
crossAxisAlignment: CrossAxisAlignment.end,
children: [
Text(
'${_calculateBMR().toStringAsFixed(0)}',
style: Theme.of(context).textTheme.titleLarge?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.bold,
),
),
Text(
'cal/day',
style: Theme.of(context).textTheme.bodySmall?.copyWith(
color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.7),
),
),
],
),
],
),

const SizedBox(height: 20),
Divider(
color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.1),
height: 1,
),
const SizedBox(height: 20),

// TDEE Section
Row(
children: [
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
borderRadius: BorderRadius.circular(12),
),
child: Icon(
Icons.fitness_center_outlined,
color: Theme.of(context).colorScheme.primary,
size: 24,
),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Flexible(
child: Text(
'TDEE',
style: Theme.of(context).textTheme.bodyLarge?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.w600,
),
overflow: TextOverflow.ellipsis,
),
),
const SizedBox(width: 8),
GestureDetector(
onTap: _showTDEEInfo,
child: Icon(
Icons.info_outline,
size: 18,
color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.6),
),
),
],
),
const SizedBox(height: 4),
Text(
'Daily caloric needs',
style: Theme.of(context).textTheme.bodySmall?.copyWith(
color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.7),
),
),
],
),
),
Column(
crossAxisAlignment: CrossAxisAlignment.end,
children: [
Text(
'${_calculateTDEE().toStringAsFixed(0)}',
style: Theme.of(context).textTheme.titleLarge?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.bold,
),
),
Text(
'cal/day',
style: Theme.of(context).textTheme.bodySmall?.copyWith(
color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.7),
),
),
],
),
],
),

const SizedBox(height: 20),
Divider(
color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.1),
height: 1,
),
const SizedBox(height: 20),

// Healthy Weight Range Section
Row(
children: [
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
borderRadius: BorderRadius.circular(12),
),
child: Icon(
Icons.balance_outlined,
color: Theme.of(context).colorScheme.primary,
size: 24,
),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Healthy Weight',
style: Theme.of(context).textTheme.bodyLarge?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.w600,
),
overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 4),
Text(
'Based on BMI 18.5-24.9',
style: Theme.of(context).textTheme.bodySmall?.copyWith(
color: Theme.of(context).colorScheme.onTertiary.withOpacity(0.7),
),
),
],
),
),
Text(
_getHealthyWeightRange(),
style: Theme.of(context).textTheme.titleLarge?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.bold,
),
),
],
),
],
),
),
],
);
}

Widget _buildYourRoutinesContent() {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
'Your Routines',
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
'${_routines.length} total',
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

if (_routines.isEmpty)
_EmptyStateCard(
icon: Icons.fitness_center_outlined,
title: 'No Routines Yet',
subtitle: _trainerData != null
? 'No routines have been created yet by ${_trainerData!.name}.'
: 'Your trainer will create personalized workout routines for you.',
)
else
ListView.separated(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
itemCount: _routines.length,
separatorBuilder: (context, index) =>
const SizedBox(height: 12),
itemBuilder: (context, index) {
final routine = _routines[index];
return _RoutineCard(
routine: routine,
onShare: routine.publicToken != null
? () => _copyPublicLink(routine.publicToken!)
: null,
);
},
),
],
);
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
'My Workouts',
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
'Welcome back, ${_userData?.name ?? 'Client'}! ',
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
'You have ${_routines.length} workout routines',
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

// Content based on selected tab
if (_selectedTabIndex == 0) _buildYourRoutinesContent(),
if (_selectedTabIndex == 1) _buildYourStatsContent(),
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
icon: Icon(Icons.fitness_center_outlined),
activeIcon: Icon(Icons.fitness_center),
label: 'Your Routines',
),
BottomNavigationBarItem(
icon: Icon(Icons.assessment_outlined),
activeIcon: Icon(Icons.assessment),
label: 'Your Stats',
),
],
),
);
}
}

class _StatCard extends StatelessWidget {
final IconData icon;
final String label;
final String value;
final Color color;

const _StatCard({
required this.icon,
required this.label,
required this.value,
required this.color,
});

@override
Widget build(BuildContext context) {
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.tertiary,
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
),
),
child: Column(
children: [
Icon(
icon,
size: 32,
color: color,
),
const SizedBox(height: 8),
Text(
value,
style: Theme.of(context).textTheme.titleMedium?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.bold,
),
textAlign: TextAlign.center,
),
const SizedBox(height: 4),
Text(
label,
style: Theme.of(context).textTheme.bodySmall?.copyWith(
color:
Theme.of(context).colorScheme.onTertiary.withOpacity(0.7),
),
),
],
),
);
}
}

class _MetricCard extends StatelessWidget {
final IconData icon;
final String label;
final String value;
final Color color;

const _MetricCard({
required this.icon,
required this.label,
required this.value,
required this.color,
});

@override
Widget build(BuildContext context) {
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.tertiary,
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
),
),
child: Column(
children: [
Icon(
icon,
size: 32,
color: color,
),
const SizedBox(height: 8),
Text(
value,
style: Theme.of(context).textTheme.titleMedium?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 4),
Text(
label,
style: Theme.of(context).textTheme.bodySmall?.copyWith(
color:
Theme.of(context).colorScheme.onTertiary.withOpacity(0.7),
),
),
],
),
);
}
}

class _BMICard extends StatelessWidget {
final String value;
final String subtitle;
final Color color;
final VoidCallback onInfoPressed;

const _BMICard({
required this.value,
required this.subtitle,
required this.color,
required this.onInfoPressed,
});

@override
Widget build(BuildContext context) {
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.tertiary,
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
),
),
child: Column(
children: [
Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
Icons.analytics_outlined,
size: 24,
color: color,
),
const SizedBox(width: 8),
Text(
'BMI',
style: Theme.of(context).textTheme.bodyMedium?.copyWith(
color: Theme.of(context)
.colorScheme
.onTertiary
.withOpacity(0.7),
fontWeight: FontWeight.w600,
),
),
const SizedBox(width: 4),
GestureDetector(
onTap: onInfoPressed,
child: Icon(
Icons.info_outline,
size: 16,
color:
Theme.of(context).colorScheme.onTertiary.withOpacity(0.6),
),
),
],
crossAxisAlignment: CrossAxisAlignment.center,
),
const SizedBox(height: 12),
Text(
value,
style: Theme.of(context).textTheme.titleLarge?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.bold,
),
textAlign: TextAlign.center,
),
const SizedBox(height: 4),
Text(
subtitle,
style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _HealthMetricCard extends StatelessWidget {
final IconData icon;
final String label;
final String value;
final String subtitle;
final Color color;
final VoidCallback? onInfoPressed;

const _HealthMetricCard({
required this.icon,
required this.label,
required this.value,
required this.subtitle,
required this.color,
this.onInfoPressed,
});

@override
Widget build(BuildContext context) {
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.tertiary,
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
),
),
child: Column(
children: [
Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
icon,
size: 24,
color: color,
),
const SizedBox(width: 8),
Text(
label,
style: Theme.of(context).textTheme.bodyMedium?.copyWith(
color: Theme.of(context)
.colorScheme
.onTertiary
.withOpacity(0.7),
fontWeight: FontWeight.w600,
),
),
if (onInfoPressed != null) ...[
const SizedBox(width: 4),
GestureDetector(
onTap: onInfoPressed,
child: Icon(
Icons.info_outline,
size: 16,
color: Theme.of(context)
.colorScheme
.onTertiary
.withOpacity(0.6),
),
),
],
],
),
const SizedBox(height: 12),
Text(
value,
style: Theme.of(context).textTheme.titleLarge?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.bold,
),
textAlign: TextAlign.center,
),
const SizedBox(height: 4),
Text(
subtitle,
style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _RoutineCard extends StatefulWidget {
final WorkoutRoutine routine;
final VoidCallback? onShare;

const _RoutineCard({
required this.routine,
this.onShare,
});

@override
State<_RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends State<_RoutineCard> {
String? _selectedDay;
Map<String, bool> _completedExercises = {};

@override
void initState() {
super.initState();
_loadCompletedExercises();
}

void _selectDay(String dayName) {
setState(() {
if (_selectedDay == dayName) {
_selectedDay = null; // Deselect if already selected
} else {
_selectedDay = dayName;
}
});
}

Future<void> _loadCompletedExercises() async {
final prefs = await SharedPreferences.getInstance();
final completedKey = 'completed_exercises_${widget.routine.id}';
final completedList = prefs.getStringList(completedKey) ?? [];

setState(() {
_completedExercises = {};
for (String exerciseId in completedList) {
_completedExercises[exerciseId] = true;
}
});
}

Future<void> _toggleExerciseCompletion(
String exerciseId, bool completed) async {
final prefs = await SharedPreferences.getInstance();
final completedKey = 'completed_exercises_${widget.routine.id}';
final completedList = prefs.getStringList(completedKey) ?? [];

setState(() {
_completedExercises[exerciseId] = completed;
});

if (completed) {
if (!completedList.contains(exerciseId)) {
completedList.add(exerciseId);
}
} else {
completedList.remove(exerciseId);
}

await prefs.setStringList(completedKey, completedList);
}

Future<void> _resetAllCheckmarks() async {
final bool? confirmReset = await showDialog<bool>(
context: context,
builder: (BuildContext context) {
return AlertDialog(
backgroundColor: Theme.of(context).colorScheme.surface,
title: Text(
'Reset All Checkmarks',
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
fontWeight: FontWeight.bold,
),
),
content: Text(
'Are you sure you want to uncheck all completed exercises?',
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
color:
Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
),
),
),
TextButton(
onPressed: () => Navigator.of(context).pop(true),
style: TextButton.styleFrom(
backgroundColor: Theme.of(context).colorScheme.primary,
),
child: Text(
'Reset All',
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

if (confirmReset == true) {
final prefs = await SharedPreferences.getInstance();
final completedKey = 'completed_exercises_${widget.routine.id}';

setState(() {
_completedExercises.clear();
});

await prefs.remove(completedKey);

if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
'All checkmarks have been reset',
style: TextStyle(
color: Theme.of(context).colorScheme.onSurface,
),
),
backgroundColor: Theme.of(context).colorScheme.tertiary,
duration: const Duration(seconds: 2),
),
);
}
}
}

String _getExerciseId(String dayName, int exerciseIndex) {
return '${dayName}_$exerciseIndex';
}

RoutineDay? get _selectedDayData {
if (_selectedDay == null) return null;
return widget.routine.days.firstWhere(
(day) => day.day == _selectedDay,
orElse: () => widget.routine.days.first,
);
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
Row(
children: [
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
shape: BoxShape.circle,
),
child: Icon(
Icons.fitness_center,
color: Theme.of(context).colorScheme.primary,
),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
widget.routine.title,
style: Theme.of(context).textTheme.titleMedium?.copyWith(
color: Theme.of(context).colorScheme.onTertiary,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 4),
Text(
'${widget.routine.days.length} workout days',
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
if (widget.onShare != null)
IconButton(
onPressed: widget.onShare,
icon: Icon(
Icons.share,
color: Theme.of(context).colorScheme.primary,
),
),
],
),

if (widget.routine.notes != null &&
widget.routine.notes!.isNotEmpty) ...[
const SizedBox(height: 16),
Container(
width: double.infinity,
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.surface,
borderRadius: BorderRadius.circular(8),
),
child: Text(
widget.routine.notes!,
style: Theme.of(context).textTheme.bodyMedium?.copyWith(
color: Theme.of(context)
.colorScheme
.onSurface
.withOpacity(0.8),
),
),
),
],

const SizedBox(height: 16),

// Workout Days Preview (Now Clickable)
Wrap(
spacing: 8,
runSpacing: 8,
children: widget.routine.days.map((day) {
final isSelected = _selectedDay == day.day;
return GestureDetector(
onTap: () => _selectDay(day.day),
child: Container(
padding:
const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
decoration: BoxDecoration(
color: isSelected
? Theme.of(context).colorScheme.primary
: Theme.of(context)
.colorScheme
.primary
.withOpacity(0.1),
borderRadius: BorderRadius.circular(20),
border: isSelected
? null
: Border.all(
color: Theme.of(context)
.colorScheme
.primary
.withOpacity(0.3),
),
),
child: Text(
'${day.day} (${day.exercises.length})',
style: Theme.of(context).textTheme.bodySmall?.copyWith(
color: isSelected
? Theme.of(context).colorScheme.onPrimary
: Theme.of(context).colorScheme.primary,
fontWeight: FontWeight.w500,
),
),
),
);
}).toList(),
),

// Selected Day Exercises
if (_selectedDayData != null) ...[
const SizedBox(height: 16),
Container(
width: double.infinity,
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Theme.of(context).colorScheme.surface,
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Row(
children: [
Icon(
Icons.calendar_today,
size: 18,
color: Theme.of(context).colorScheme.primary,
),
const SizedBox(width: 8),
Text(
_selectedDayData!.day,
style: Theme.of(context)
.textTheme
.titleSmall
?.copyWith(
color: Theme.of(context).colorScheme.primary,
fontWeight: FontWeight.bold,
),
),
],
),
if (_completedExercises.values
.any((completed) => completed))
TextButton.icon(
onPressed: _resetAllCheckmarks,
style: TextButton.styleFrom(
padding: const EdgeInsets.symmetric(
horizontal: 12, vertical: 6),
),
icon: Icon(
Icons.refresh,
size: 16,
color: Theme.of(context).colorScheme.primary,
),
label: Text(
'Reset All',
style: TextStyle(
color: Theme.of(context).colorScheme.primary,
fontWeight: FontWeight.w500,
fontSize: 12,
),
),
),
],
),
const SizedBox(height: 12),
if (_selectedDayData!.items.isEmpty)
Text(
'No exercises for this day',
style: Theme.of(context).textTheme.bodyMedium?.copyWith(
color: Theme.of(context)
.colorScheme
.onSurface
.withOpacity(0.7),
fontStyle: FontStyle.italic,
),
)
else
ListView.separated(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
itemCount: _selectedDayData!.items.length,
separatorBuilder: (context, index) =>
const SizedBox(height: 8),
itemBuilder: (context, index) {
final item = _selectedDayData!.items[index];

if (item is RoutineDivider) {
return Container(
margin: const EdgeInsets.symmetric(vertical: 8),
child: Column(
children: [
if (item.label != null &&
item.label!.isNotEmpty) ...[
Text(
item.label!,
style: Theme.of(context)
.textTheme
.bodyMedium
?.copyWith(
color: Theme.of(context)
.colorScheme
.primary,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 8),
],
Container(
height: 2,
margin: const EdgeInsets.symmetric(
horizontal: 16),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [
Theme.of(context)
.colorScheme
.primary
.withOpacity(0.1),
Theme.of(context).colorScheme.primary,
Theme.of(context)
.colorScheme
.primary
.withOpacity(0.1),
],
),
),
),
],
),
);
}

// Handle Exercise items
final exercise = item as Exercise;
final exerciseId =
_getExerciseId(_selectedDayData!.day, index);
final isCompleted =
_completedExercises[exerciseId] ?? false;

return Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: isCompleted
? Theme.of(context)
.colorScheme
.primary
.withOpacity(0.1)
: Theme.of(context)
.colorScheme
.primary
.withOpacity(0.05),
borderRadius: BorderRadius.circular(8),
border: Border.all(
color: isCompleted
? Theme.of(context)
.colorScheme
.primary
.withOpacity(0.3)
: Theme.of(context)
.colorScheme
.primary
.withOpacity(0.1),
),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Checkbox(
value: isCompleted,
onChanged: (bool? value) {
_toggleExerciseCompletion(
exerciseId, value ?? false);
},
activeColor:
Theme.of(context).colorScheme.primary,
checkColor:
Theme.of(context).colorScheme.onPrimary,
),
const SizedBox(width: 8),
Expanded(
child: Text(
exercise.name,
style: Theme.of(context)
.textTheme
.bodyLarge
?.copyWith(
color: Theme.of(context)
.colorScheme
.onSurface,
fontWeight: FontWeight.w500,
decoration: isCompleted
? TextDecoration.lineThrough
: null,
),
),
),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 8, vertical: 4),
decoration: BoxDecoration(
color: Theme.of(context)
.colorScheme
.primary
.withOpacity(0.15),
borderRadius: BorderRadius.circular(12),
),
child: Text(
'${exercise.sets} × ${exercise.reps}',
style: Theme.of(context)
.textTheme
.bodySmall
?.copyWith(
color: Theme.of(context)
.colorScheme
.primary,
fontWeight: FontWeight.bold,
),
),
),
],
),
if (exercise.notes != null &&
exercise.notes!.isNotEmpty) ...[
const SizedBox(height: 8),
Container(
width: double.infinity,
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: Theme.of(context)
.colorScheme
.surface
.withOpacity(0.5),
borderRadius: BorderRadius.circular(6),
),
child: Text(
exercise.notes!,
style: Theme.of(context)
.textTheme
.bodySmall
?.copyWith(
color: Theme.of(context)
.colorScheme
.onSurface
.withOpacity(0.7),
decoration: isCompleted
? TextDecoration.lineThrough
: null,
),
),
),
],
],
),
);
},
),
],
),
),
],
],
),
);
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
