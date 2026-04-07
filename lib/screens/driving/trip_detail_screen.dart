import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/trip.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({
    super.key,
    required this.trip,
  });

  final Trip trip;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _setupMapData();
  }

  void _setupMapData() {
    if (widget.trip.routePath.isEmpty) return;

    // Create polyline from route path
    final polyline = Polyline(
      polylineId: const PolylineId('trip_route'),
      points: widget.trip.routePath.map((geoPoint) {
        return LatLng(geoPoint.latitude, geoPoint.longitude);
      }).toList(),
      color: Theme.of(context).primaryColor,
      width: 4,
      patterns: [],
    );

    // Create start and end markers
    final startMarker = Marker(
      markerId: const MarkerId('start'),
      position: LatLng(
        widget.trip.routePath.first.latitude,
        widget.trip.routePath.first.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: 'Start',
        snippet: widget.trip.startAddress,
      ),
    );

    final endMarker = Marker(
      markerId: const MarkerId('end'),
      position: LatLng(
        widget.trip.routePath.last.latitude,
        widget.trip.routePath.last.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: 'End',
        snippet: widget.trip.endAddress,
      ),
    );

    setState(() {
      _polylines = {polyline};
      _markers = {startMarker, endMarker};
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitMapToRoute();
  }

  void _fitMapToRoute() {
    if (_mapController == null || widget.trip.routePath.isEmpty) return;

    final bounds = _calculateBounds(widget.trip.routePath.map((geoPoint) {
      return LatLng(geoPoint.latitude, geoPoint.longitude);
    }).toList());

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Details'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Trip stats header
          Container(
            width: double.infinity,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.schedule,
                      label: 'Duration',
                      value: widget.trip.formattedDuration,
                    ),
                    _buildStatItem(
                      icon: Icons.straighten,
                      label: 'Distance',
                      value: widget.trip.formattedDistance,
                    ),
                    _buildStatItem(
                      icon: Icons.speed,
                      label: 'Avg Speed',
                      value: _calculateAverageSpeed(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTimeInfo(),
              ],
            ),
          ),

          // Map section
          Expanded(
            flex: 3,
            child: widget.trip.routePath.isNotEmpty
                ? GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        widget.trip.routePath.first.latitude,
                        widget.trip.routePath.first.longitude,
                      ),
                      zoom: 14.0,
                    ),
                    polylines: _polylines,
                    markers: _markers,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No route data available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Address details section
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trip Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAddressRow(
                    icon: Icons.radio_button_checked,
                    iconColor: Colors.green,
                    title: 'Start Location',
                    address: widget.trip.startAddress,
                    time: _formatTime(widget.trip.startTime),
                  ),
                  const SizedBox(height: 12),
                  _buildAddressRow(
                    icon: Icons.location_on,
                    iconColor: Colors.red,
                    title: 'End Location',
                    address: widget.trip.endAddress,
                    time: _formatTime(widget.trip.endTime),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Trip Date', _formatDate(widget.trip.startTime)),
                  _buildInfoRow('Route Points', '${widget.trip.routePath.length} locations'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Started: ${_formatDateTime(widget.trip.startTime)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              'Ended: ${_formatDateTime(widget.trip.endTime)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
    required String time,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              Text(
                address.isNotEmpty ? address : 'Unknown location',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateAverageSpeed() {
    if (widget.trip.durationMinutes == 0) return '0 km/h';
    
    final speedKmh = (widget.trip.distanceKm / (widget.trip.durationMinutes / 60));
    return '${speedKmh.toStringAsFixed(0)} km/h';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} at ${_formatTime(dateTime)}';
  }
}
