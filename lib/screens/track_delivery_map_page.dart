import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/rider_order_model.dart';
import '../l10n/app_localizations.dart';

class TrackDeliveryMapPage extends StatefulWidget {
  final RiderOrderModel order;

  const TrackDeliveryMapPage({super.key, required this.order});

  @override
  State<TrackDeliveryMapPage> createState() => _TrackDeliveryMapPageState();
}

class _TrackDeliveryMapPageState extends State<TrackDeliveryMapPage> {
  late final MapController _mapController;
  LatLng? _riderLocation;
  LatLng? _customerLocation;
  bool _isLoadingLocation = true;
  String? _errorMessage;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.order.customerLat != null && widget.order.customerLng != null) {
      _customerLocation = LatLng(widget.order.customerLat!, widget.order.customerLng!);
    }

    _initGpsLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initGpsLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _errorMessage = 'Location services are disabled.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _errorMessage = 'Location permissions are denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _errorMessage = 'Location permissions are permanently denied.';
        });
        return;
      }

      // Initial Position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final current = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _riderLocation = current;
          _isLoadingLocation = false;
        });

        _fitBounds();
      }

      // Continuous live updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _riderLocation = LatLng(pos.latitude, pos.longitude);
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _errorMessage = 'Could not acquire GPS: $e';
        });
      }
    }
  }

  void _fitBounds() {
    if (_riderLocation != null && _customerLocation != null) {
      final bounds = LatLngBounds.fromPoints([_riderLocation!, _customerLocation!]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 80),
        ),
      );
    } else if (_riderLocation != null) {
      _mapController.move(_riderLocation!, 15);
    } else if (_customerLocation != null) {
      _mapController.move(_customerLocation!, 15);
    }
  }

  double _calculateDistanceKm() {
    if (_riderLocation == null || _customerLocation == null) return 0.0;
    final meters = Geolocator.distanceBetween(
      _riderLocation!.latitude,
      _riderLocation!.longitude,
      _customerLocation!.latitude,
      _customerLocation!.longitude,
    );
    return meters / 1000.0;
  }

  Future<void> _openExternalMap() async {
    if (_customerLocation == null) return;
    final lat = _customerLocation!.latitude;
    final lng = _customerLocation!.longitude;

    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    final geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(widget.order.customerName)})');

    if (await canLaunchUrl(geoUrl)) {
      await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callCustomer() async {
    final phone = widget.order.customerPhone.trim();
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final initialCenter = _riderLocation ?? _customerLocation ?? const LatLng(24.7136, 46.6753);
    final distanceKm = _calculateDistanceKm();
    final etaMinutes = (distanceKm * 2.5).round().clamp(1, 180);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tr('track_map'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              ),
            ),
            Text(
              widget.order.orderNumber,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF0284C7),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: Color(0xFF0284C7)),
            tooltip: 'Center Location',
            onPressed: _fitBounds,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
      ),
      body: Stack(
        children: [
          // OpenStreetMap Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.finalfx.merchant.rider',
              ),

              // Polyline connecting rider to customer
              if (_riderLocation != null && _customerLocation != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_riderLocation!, _customerLocation!],
                      strokeWidth: 4.5,
                      color: const Color(0xFF0284C7),
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // Rider GPS Pin
                  if (_riderLocation != null)
                    Marker(
                      point: _riderLocation!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
                      ),
                    ),

                  // Customer Destination Pin
                  if (_customerLocation != null)
                    Marker(
                      point: _customerLocation!,
                      width: 46,
                      height: 46,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEA580C).withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Loading or Error overlay
          if (_isLoadingLocation || _errorMessage != null)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _errorMessage != null ? const Color(0xFFEF4444) : Colors.transparent,
                  ),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    if (_isLoadingLocation)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage ?? 'Acquiring live GPS location...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _errorMessage != null
                              ? const Color(0xFFEF4444)
                              : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Info Floating Card
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Distance & ETA header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.route_rounded, size: 14, color: Color(0xFF0284C7)),
                                const SizedBox(width: 5),
                                Text(
                                  '${distanceKm.toStringAsFixed(1)} km',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF059669)),
                                const SizedBox(width: 5),
                                Text(
                                  '~$etaMinutes mins',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (widget.order.customerPhone.isNotEmpty)
                        InkWell(
                          onTap: _callCustomer,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF10B981)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone, size: 13, color: Color(0xFF059669)),
                                const SizedBox(width: 5),
                                Text(
                                  l10n.tr('call'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Customer name & address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_on_outlined, color: Color(0xFFEA580C), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.order.customerName,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.order.customerAddress.isNotEmpty
                                  ? widget.order.customerAddress
                                  : 'No street address provided',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Navigation launch button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _openExternalMap,
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: Text(
                        l10n.tr('open_google_maps'),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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

