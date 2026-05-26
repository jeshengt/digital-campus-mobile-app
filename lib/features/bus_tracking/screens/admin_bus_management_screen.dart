import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/errors/app_exception.dart';
import '../../profile/models/app_user.dart';
import '../models/bus_route_point.dart';
import '../models/campus_bus.dart';
import '../services/bus_admin_service.dart';
import '../services/bus_tracking_service.dart';
import '../utils/bus_admin_validation.dart';
import '../utils/bus_tracking_helpers.dart';

class AdminBusManagementScreen extends StatefulWidget {
  const AdminBusManagementScreen({super.key, BusAdminService? busAdminService})
    : _busAdminService = busAdminService;

  final BusAdminService? _busAdminService;

  @override
  State<AdminBusManagementScreen> createState() =>
      _AdminBusManagementScreenState();
}

class _AdminBusManagementScreenState extends State<AdminBusManagementScreen> {
  late final BusAdminService _busAdminService;

  @override
  void initState() {
    super.initState();
    _busAdminService = widget._busAdminService ?? FirebaseBusAdminService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bus management')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('addBusButton'),
        onPressed: () => _showBusSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add bus'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<AppUser>>(
              stream: _busAdminService.watchDrivers(),
              builder: (context, driverSnapshot) {
                if (driverSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (driverSnapshot.hasError) {
                  return _AdminBusMessageState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load drivers',
                    message: driverSnapshot.error.toString(),
                  );
                }

                final drivers = driverSnapshot.data ?? const <AppUser>[];
                return StreamBuilder<List<CampusBus>>(
                  stream: _busAdminService.watchBuses(),
                  builder: (context, busSnapshot) {
                    if (busSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !busSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (busSnapshot.hasError) {
                      return _AdminBusMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load buses',
                        message: busSnapshot.error.toString(),
                      );
                    }

                    final buses = busSnapshot.data ?? const <CampusBus>[];

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.spacingLarge,
                        AppDimensions.spacingLarge,
                        AppDimensions.spacingLarge,
                        96,
                      ),
                      children: [
                        _AdminBusHeader(busCount: buses.length),
                        const SizedBox(height: AppDimensions.spacingLarge),
                        if (buses.isEmpty)
                          const _AdminBusMessageCard(
                            icon: Icons.directions_bus_filled_outlined,
                            title: 'No buses configured',
                            message:
                                'Add a route and map its points. You can assign a driver later.',
                          )
                        else
                          for (final bus in buses)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppDimensions.spacingMedium,
                              ),
                              child: _AdminBusTile(
                                bus: bus,
                                driverName: _driverLabel(
                                  drivers,
                                  bus.driverIds,
                                ),
                                onEdit: () => _showBusSheet(bus: bus),
                                onAssignDriver: () => _showAssignDriverSheet(
                                  bus: bus,
                                  drivers: drivers,
                                ),
                                onDelete: () => _confirmDelete(bus),
                              ),
                            ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBusSheet({CampusBus? bus}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _BusFormSheet(bus: bus, busAdminService: _busAdminService),
    );

    if (saved == true) {
      _showSnack(bus == null ? 'Bus route added.' : 'Bus route updated.');
    }
  }

  Future<void> _showAssignDriverSheet({
    required CampusBus bus,
    required List<AppUser> drivers,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DriverAssignmentSheet(
        bus: bus,
        drivers: drivers,
        currentDriverName: _driverLabel(drivers, bus.driverIds),
        busAdminService: _busAdminService,
      ),
    );

    if (saved == true) {
      _showSnack('Driver assignments updated.');
    }
  }

  Future<void> _confirmDelete(CampusBus bus) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete bus route?'),
          content: Text(
            '${bus.routeName} will be removed and any live location for this bus will be cleared.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('confirmDeleteBusButton'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _busAdminService.deleteBus(bus);
      _showSnack('Bus route deleted.');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _driverLabel(List<AppUser> drivers, List<String> driverIds) {
    if (driverIds.isEmpty) {
      return 'Unassigned drivers';
    }

    final names = <String>[];
    for (final driverId in driverIds) {
      AppUser? matchedDriver;
      for (final driver in drivers) {
        if (driver.uid == driverId) {
          matchedDriver = driver;
          break;
        }
      }

      names.add(
        matchedDriver == null
            ? 'Unknown driver'
            : matchedDriver.name.isEmpty
            ? matchedDriver.email
            : matchedDriver.name,
      );
    }

    return names.join(', ');
  }
}

class _BusFormSheet extends StatefulWidget {
  const _BusFormSheet({required this.busAdminService, this.bus});

  final BusAdminService busAdminService;
  final CampusBus? bus;

  @override
  State<_BusFormSheet> createState() => _BusFormSheetState();
}

class _BusFormSheetState extends State<_BusFormSheet> {
  final _routeNameController = TextEditingController();
  final _startNameController = TextEditingController();
  final _endNameController = TextEditingController();
  String _selectedStatus = busStatusActive;
  List<BusRoutePoint> _routePoints = const <BusRoutePoint>[];
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final bus = widget.bus;
    _routeNameController.text = bus?.routeName ?? '';
    _startNameController.text = bus?.startName ?? '';
    _endNameController.text = bus?.endName ?? '';
    _selectedStatus = allowedBusStatuses.contains(bus?.status)
        ? bus!.status
        : busStatusActive;
    _routePoints = List<BusRoutePoint>.from(
      bus?.routePoints ?? const <BusRoutePoint>[],
    );
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    _startNameController.dispose();
    _endNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.spacingLarge,
          right: AppDimensions.spacingLarge,
          top: AppDimensions.spacingMedium,
          bottom:
              MediaQuery.viewInsetsOf(context).bottom +
              AppDimensions.spacingLarge,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.bus == null ? 'Add bus route' : 'Edit bus route',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              Text(
                'Tap the map to build the route in travel order.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              TextField(
                key: const Key('busRouteNameField'),
                controller: _routeNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Route name'),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              DropdownButtonFormField<String>(
                key: const Key('busStatusDropdown'),
                initialValue: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                    value: busStatusActive,
                    child: Text('Active'),
                  ),
                  DropdownMenuItem(
                    value: busStatusInactive,
                    child: Text('Inactive'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedStatus = value;
                  });
                },
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              TextField(
                controller: _startNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Start name'),
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              TextField(
                controller: _endNameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'End name'),
              ),
              const SizedBox(height: AppDimensions.spacingLarge),
              _RoutePointPicker(
                routePoints: _routePoints,
                onPointAdded: (point) {
                  setState(() {
                    _routePoints = [..._routePoints, point];
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('undoRoutePointButton'),
                      onPressed: _routePoints.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _routePoints = _routePoints
                                    .take(_routePoints.length - 1)
                                    .toList();
                              });
                            },
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Undo point'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMedium),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('clearRoutePointsButton'),
                      onPressed: _routePoints.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _routePoints = const <BusRoutePoint>[];
                              });
                            },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Clear'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              Text(
                '${_routePoints.length} route point${_routePoints.length == 1 ? '' : 's'} added',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppDimensions.spacingMedium),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: AppDimensions.spacingLarge),
              ElevatedButton.icon(
                key: const Key('saveBusButton'),
                onPressed: _isSaving ? null : _saveBus,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Save bus route'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveBus() async {
    final validationError = validateCampusBusDraft(
      routeName: _routeNameController.text,
      routePoints: _routePoints,
    );

    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final bus = CampusBus(
      busId: widget.bus?.busId ?? '',
      routeName: _routeNameController.text.trim(),
      driverIds: widget.bus?.driverIds ?? const <String>[],
      status: _selectedStatus,
      startName: _emptyToNull(_startNameController.text),
      endName: _emptyToNull(_endNameController.text),
      routePoints: _routePoints,
    );

    try {
      if (widget.bus == null) {
        await widget.busAdminService.createBus(bus);
      } else {
        await widget.busAdminService.updateBus(
          currentBus: widget.bus!,
          updatedBus: bus,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _DriverAssignmentSheet extends StatefulWidget {
  const _DriverAssignmentSheet({
    required this.bus,
    required this.drivers,
    required this.currentDriverName,
    required this.busAdminService,
  });

  final CampusBus bus;
  final List<AppUser> drivers;
  final String currentDriverName;
  final BusAdminService busAdminService;

  @override
  State<_DriverAssignmentSheet> createState() => _DriverAssignmentSheetState();
}

class _DriverAssignmentSheetState extends State<_DriverAssignmentSheet> {
  late Set<String> _selectedDriverIds;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final validDriverIds = widget.drivers.map((driver) => driver.uid).toSet();
    _selectedDriverIds = widget.bus.driverIds
        .where(validDriverIds.contains)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.spacingLarge,
          right: AppDimensions.spacingLarge,
          top: AppDimensions.spacingMedium,
          bottom:
              MediaQuery.viewInsetsOf(context).bottom +
              AppDimensions.spacingLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Assign drivers',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            Text(
              widget.bus.routeName,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            _AssignmentSummary(driverName: widget.currentDriverName),
            const SizedBox(height: AppDimensions.spacingMedium),
            if (widget.drivers.isEmpty)
              const _AdminBusMessageCard(
                icon: Icons.person_off_outlined,
                title: 'No drivers available',
                message:
                    'This route can stay unassigned until driver accounts exist.',
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      key: const Key('clearDriverAssignmentsOption'),
                      value: _selectedDriverIds.isEmpty,
                      onChanged: (_) {
                        setState(() {
                          _selectedDriverIds = <String>{};
                          _errorMessage = null;
                        });
                      },
                      title: const Text('Unassigned drivers'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const Divider(height: 1),
                    for (final driver in widget.drivers)
                      CheckboxListTile(
                        key: Key('assignDriverOption_${driver.uid}'),
                        value: _selectedDriverIds.contains(driver.uid),
                        onChanged: (isSelected) {
                          setState(() {
                            final next = Set<String>.from(_selectedDriverIds);
                            if (isSelected == true) {
                              next.add(driver.uid);
                            } else {
                              next.remove(driver.uid);
                            }
                            _selectedDriverIds = next;
                            _errorMessage = null;
                          });
                        },
                        title: Text(
                          driver.name.isEmpty ? driver.email : driver.name,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppDimensions.spacingMedium),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingLarge),
            ElevatedButton.icon(
              key: const Key('saveDriverAssignmentButton'),
              onPressed: _isSaving ? null : _saveAssignment,
              icon: const Icon(Icons.assignment_ind_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save assignment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAssignment() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.busAdminService.assignDrivers(
        bus: widget.bus,
        driverIds: _selectedDriverIds.toList(),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = error.toString();
        });
      }
    }
  }
}

class _AssignmentSummary extends StatelessWidget {
  const _AssignmentSummary({required this.driverName});

  final String driverName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Row(
          children: [
            const Icon(
              Icons.assignment_ind_outlined,
              color: AppColors.utmMaroon,
            ),
            const SizedBox(width: AppDimensions.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current assignment',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingTiny),
                  Text(
                    driverName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePointPicker extends StatefulWidget {
  const _RoutePointPicker({
    required this.routePoints,
    required this.onPointAdded,
  });

  final List<BusRoutePoint> routePoints;
  final ValueChanged<BusRoutePoint> onPointAdded;

  @override
  State<_RoutePointPicker> createState() => _RoutePointPickerState();
}

class _RoutePointPickerState extends State<_RoutePointPicker> {
  final _mapController = MapController();
  final _locationProvider = const GeolocatorBusLocationProvider();
  BusPosition? _currentPosition;
  Offset? _pointerDownPosition;
  bool _isLocating = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.routePoints.isEmpty
        ? const LatLng(campusDefaultLatitude, campusDefaultLongitude)
        : LatLng(
            widget.routePoints.last.latitude,
            widget.routePoints.last.longitude,
          );
    final polylinePoints = [
      for (final point in widget.routePoints)
        LatLng(point.latitude, point.longitude),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                _pointerDownPosition = event.localPosition;
              },
              onPointerUp: (event) {
                final downPosition = _pointerDownPosition;
                _pointerDownPosition = null;
                if (downPosition != null &&
                    (event.localPosition - downPosition).distance > 8) {
                  return;
                }

                final point = _pointForTap(event.localPosition, center);
                widget.onPointAdded(
                  BusRoutePoint(
                    latitude: point.latitude,
                    longitude: point.longitude,
                  ),
                );
              },
              child: FlutterMap(
                key: const Key('adminBusRouteMap'),
                mapController: _mapController,
                options: MapOptions(initialCenter: center, initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.utmgo',
                  ),
                  if (polylinePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: polylinePoints,
                          color: AppColors.utmMaroon,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_currentPosition != null)
                        Marker(
                          point: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          width: 38,
                          height: 38,
                          child: const _RouteCurrentLocationMarker(),
                        ),
                      for (
                        var index = 0;
                        index < widget.routePoints.length;
                        index++
                      )
                        Marker(
                          point: LatLng(
                            widget.routePoints[index].latitude,
                            widget.routePoints[index].longitude,
                          ),
                          width: 34,
                          height: 34,
                          child: _RoutePointMarker(number: index + 1),
                        ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: AppDimensions.spacingSmall,
              bottom: AppDimensions.spacingSmall,
              child: FloatingActionButton.small(
                key: const Key('adminRouteLocateButton'),
                heroTag: null,
                tooltip: 'Locate current location',
                onPressed: _isLocating ? null : _locateCurrentPosition,
                child: _isLocating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _locateCurrentPosition() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final position = await _locationProvider.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      _mapController.move(point, 16);
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLocating = false;
        });
      }
    } on AppException catch (error) {
      _showLocationError(error.message);
    } catch (error) {
      _showLocationError(error.toString());
    }
  }

  void _showLocationError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLocating = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  LatLng _pointForTap(Offset localPosition, LatLng fallback) {
    try {
      return _mapController.camera.offsetToCrs(localPosition);
    } catch (_) {
      return fallback;
    }
  }
}

class _RouteCurrentLocationMarker extends StatelessWidget {
  const _RouteCurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Current location',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.utmGoldTint,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.my_location_rounded,
          color: AppColors.warning,
          size: 20,
        ),
      ),
    );
  }
}

class _RoutePointMarker extends StatelessWidget {
  const _RoutePointMarker({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.utmMaroon,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          number.toString(),
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

class _AdminBusHeader extends StatelessWidget {
  const _AdminBusHeader({required this.busCount});

  final int busCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.utmMaroon,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: const Icon(
                Icons.route_rounded,
                color: AppColors.utmGoldTint,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campus bus routes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingTiny),
                  Text(
                    '$busCount route${busCount == 1 ? '' : 's'} configured',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.utmGoldTint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminBusTile extends StatelessWidget {
  const _AdminBusTile({
    required this.bus,
    required this.driverName,
    required this.onEdit,
    required this.onAssignDriver,
    required this.onDelete,
  });

  final CampusBus bus;
  final String driverName;
  final VoidCallback onEdit;
  final VoidCallback onAssignDriver;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.utmMaroonTint,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: const Icon(
                Icons.directions_bus_filled_rounded,
                color: AppColors.utmMaroon,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bus.routeName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingTiny),
                  Text(
                    driverName,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingSmall),
                  Wrap(
                    spacing: AppDimensions.spacingSmall,
                    runSpacing: AppDimensions.spacingSmall,
                    children: [
                      _BusAdminChip(label: bus.status),
                      _BusAdminChip(
                        label:
                            '${bus.routePoints.length} route point${bus.routePoints.length == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit bus route',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Assign drivers',
              onPressed: onAssignDriver,
              icon: const Icon(Icons.assignment_ind_outlined),
            ),
            IconButton(
              tooltip: 'Delete bus route',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusAdminChip extends StatelessWidget {
  const _BusAdminChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSmall,
        vertical: AppDimensions.spacingTiny,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _AdminBusMessageState extends StatelessWidget {
  const _AdminBusMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: _AdminBusMessageContent(
          icon: icon,
          title: title,
          message: message,
        ),
      ),
    );
  }
}

class _AdminBusMessageCard extends StatelessWidget {
  const _AdminBusMessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLarge),
        child: _AdminBusMessageContent(
          icon: icon,
          title: title,
          message: message,
        ),
      ),
    );
  }
}

class _AdminBusMessageContent extends StatelessWidget {
  const _AdminBusMessageContent({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: AppColors.utmMaroon),
        const SizedBox(height: AppDimensions.spacingMedium),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppDimensions.spacingSmall),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
