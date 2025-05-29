import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart';
import 'sensor_data.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart' as gauges;
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Sensor Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: const SensorPage(),
    );
  }
}

class SensorPage extends StatefulWidget {
  const SensorPage({super.key});

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  List<SensorData> _data = [];
  bool _isLoading = true;
  double tempThreshold = 0;
  double humThreshold = 0;
  final TooltipBehavior _tooltipBehavior1 = TooltipBehavior(enable: true);
  final TooltipBehavior _tooltipBehavior2 = TooltipBehavior(enable: true);

  double latestTemp = 0;
  double latestHum = 0;
  String relayStatus = '-';
  String? lastRelayTime = '-';
  final TextEditingController tempController = TextEditingController();
  final TextEditingController humController = TextEditingController();
  bool relayToggle = false;
  DateTime? lastUpdated;
  Timer? _refreshTimer;
  List<SensorData> _chartData = [];
  int _rowsPerPage = 25;
  int _currentPage = 0;

  List<SensorData> get _paginatedData {
    final start = _currentPage * _rowsPerPage;
    return _data.reversed.skip(start).take(_rowsPerPage).toList();
  }

  int get _totalPages => (_data.length / _rowsPerPage).ceil();

  Future<void> fetchSensorData() async {
    // If it's the first fetch (app loading), show the spinner
    if (_data.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    final url =
        Uri.parse("http://iottraining.threelittlecar.com/load_data.php");
    try {
      final response = await http.get(url);
      // print("API response: ${response.body}");
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final List<SensorData> fetchedData =
            jsonData.map((item) => SensorData.fromJson(item)).toList();

        setState(() {
          _data = fetchedData;
          _chartData =
              _data.length > 100 ? _data.sublist(_data.length - 100) : _data;
          _isLoading = false;

          // Set latest values from the last data
          if (_data.isNotEmpty) {
            latestTemp = _data.last.temperature;
            latestHum = _data.last.humidity;
            relayStatus = _data.last.relayStatus;
            // lastRelayTime = _data.last.timestamp;
            // print('lastRelayTime: $lastRelayTime');
          }

          relayToggle = (relayStatus == "ON");
          lastUpdated = DateTime.now();
        });
      } else {
        throw Exception("Failed to load data");
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> fetchThresholds() async {
    final url = Uri.parse(
        "http://iottraining.threelittlecar.com/get_threshold.php?id=101");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        setState(() {
          tempThreshold = double.parse(jsonData['temp_threshold'].toString());
          humThreshold = double.parse(jsonData['hum_threshold'].toString());

          // Update controllers here AFTER fetching values
          tempController.text = tempThreshold.toStringAsFixed(1);
          humController.text = humThreshold.toStringAsFixed(1);
        });
      }
    } catch (e) {
      print("Threshold fetch error: $e");
    }
  }

  Future<void> _updateThresholds() async {
    final String temp = tempController.text;
    final String hum = humController.text;

    final url =
        Uri.parse("http://iottraining.threelittlecar.com/update_threshold.php");

    try {
      final response = await http.post(
        url,
        body: {
          'id': '101', // Replace with dynamic ID if needed
          'temp_threshold': temp,
          'hum_threshold': hum,
        },
      );

      if (response.statusCode == 200) {
        print("Threshold update successful: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Threshold updated")),
        );
        fetchThresholds(); // Refresh UI
        fetchSensorData();
      } else {
        throw Exception("Failed to update");
      }
    } catch (e) {
      print("Error updating thresholds: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to update threshold")),
      );
    }
  }

  Future<void> fetchLastRelayOnTime() async {
    final url = Uri.parse(
        "http://iottraining.threelittlecar.com/get_last_relay_on_time.php");

    try {
      // Make the HTTP GET request to fetch the last "ON" relay timestamp
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Parse the JSON response
        final Map<String, dynamic> jsonData = json.decode(response.body);

        setState(() {
          // Update the lastRelayTime with the fetched timestamp
          lastRelayTime = jsonData['last_relay_on_time'] ?? 'No data';
        });
      } else {
        // Handle if the server returns an error
        throw Exception("Failed to load last relay ON time");
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        // Handle any errors, like network issues, etc.
        lastRelayTime = "Error fetching data";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchSensorData();
    fetchThresholds();
    fetchLastRelayOnTime();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      fetchSensorData();
      // fetchThresholds();
      fetchLastRelayOnTime();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    tempController.dispose();
    humController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color.fromARGB(255, 235, 235, 235), // Light pastel background
      appBar: AppBar(
        backgroundColor:
            const Color.fromARGB(255, 226, 167, 234).withOpacity(0.3),
        title: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            child: Text(
                "Temperature and Humidity Monitoring with Relay Trigger",
                style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800])),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showThresholdSettingsDialog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(flex: 1, child: _buildStatusMessage()),
                        const SizedBox(
                            width: 10), // Add some space between cards
                        Expanded(flex: 1, child: buildLastUpdatedCard()),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 4 summary cards in one row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                "", // title replaced with widget, so pass empty string here
                                "$latestTemp °C",
                                const Color.fromARGB(255, 170, 77, 228),
                                gauge: buildGauge(latestTemp, 100,
                                    const Color.fromARGB(255, 170, 77, 228)),
                                titleWidget: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.thermostat,
                                        color:
                                            Color.fromARGB(255, 170, 77, 228)),
                                    SizedBox(width: 6),
                                    Text(
                                      "Temperature",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color:
                                            Color.fromARGB(255, 170, 77, 228),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInfoCard(
                                "",
                                "$latestHum %",
                                Colors.blue,
                                gauge: buildGauge(latestHum, 100, Colors.blue),
                                titleWidget: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.opacity, color: Colors.blue),
                                    SizedBox(width: 6),
                                    Text(
                                      "Humidity",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInfoCard(
                                "",
                                relayStatus,
                                relayStatus == "ON" ? Colors.green : Colors.red,
                                extraWidget: SizedBox(
                                  width: 100,
                                  height: 122,
                                  child: Transform.scale(
                                    scale: 1.5,
                                    child: Switch(
                                      value: relayToggle,
                                      activeColor: const Color.fromARGB(
                                          255, 73, 253, 79),
                                      inactiveThumbColor: Colors.red,
                                      onChanged: (bool newValue) {
                                        setState(() {
                                          relayToggle = newValue;
                                          relayStatus =
                                              relayToggle ? "ON" : "OFF";
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                titleWidget: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.power,
                                        color: relayStatus == "ON"
                                            ? Colors.green
                                            : Colors.red),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Relay Status",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: relayStatus == "ON"
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Card(
                                color: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                margin: const EdgeInsets.all(4),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.timer,
                                              color: Color.fromARGB(
                                                  255, 127, 127, 127)),
                                          SizedBox(width: 6),
                                          Text(
                                            "Last Relay Trigger",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color.fromARGB(
                                                  255, 127, 127, 127),
                                              fontSize: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      buildLastRelayTriggerCard(
                                          lastRelayTime ?? "-"),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 40, vertical: 5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Sensor Data Chart View - Latest 100 records",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                    child: Card(
                      color: Colors.white,
                      elevation: 5,
                      margin: const EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 40),
                            const Center(
                              child: Text(
                                "🌡️ Temperature Chart (°C)",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 23,
                                    color: Colors.deepPurple),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 350,
                              child: SfCartesianChart(
                                primaryXAxis: CategoryAxis(
                                    labelRotation: 45, interval: 10),
                                primaryYAxis: NumericAxis(
                                  title: AxisTitle(text: '°C'),
                                  plotBands: [
                                    PlotBand(
                                      isVisible: true,
                                      start: tempThreshold,
                                      end: tempThreshold,
                                      text: 'Temp Threshold',
                                      textStyle:  const TextStyle(
                                          color: Colors.deepPurple),
                                      borderColor: Colors.deepPurple,
                                      borderWidth: 2,
                                      dashArray: [6, 3],
                                    ),
                                  ],
                                ),
                                tooltipBehavior: _tooltipBehavior1,
                                legend: const Legend(
                                    isVisible: true,
                                    position: LegendPosition.bottom),
                                trackballBehavior:
                                    TrackballBehavior(enable: true),
                                series: [
                                  SplineAreaSeries<SensorData, String>(
                                    dataSource: _chartData,
                                    xValueMapper: (SensorData data, _) =>
                                        data.formattedTimestamp,
                                    yValueMapper: (SensorData data, _) =>
                                        data.temperature,
                                    name: 'Temperature',
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color.fromARGB(255, 206, 48, 234)
                                            .withOpacity(0.6),
                                        Colors.transparent
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    markerSettings:
                                        const MarkerSettings(isVisible: true),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                    child: Card(
                      color: Colors.white,
                      elevation: 5,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 40),
                            const Center(
                              child: Text(
                                "💧 Humidity Chart (%)",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 23,
                                    color: Color.fromARGB(255, 3, 114, 205)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 350,
                              child: SfCartesianChart(
                                primaryXAxis: CategoryAxis(
                                  labelRotation: 45,
                                  interval: 10,
                                ),
                                primaryYAxis: NumericAxis(
                                  title: AxisTitle(text: '%'),
                                  plotBands: [
                                    PlotBand(
                                      isVisible: true,
                                      start: humThreshold,
                                      end: humThreshold,
                                      text: 'Hum Threshold',
                                      textStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 3, 114, 205)),
                                      borderColor: const Color.fromARGB(
                                          255, 3, 114, 205),
                                      borderWidth: 2,
                                      dashArray: [6, 3],
                                    ),
                                  ],
                                ),
                                tooltipBehavior: _tooltipBehavior2,
                                legend: const Legend(
                                    isVisible: true,
                                    position: LegendPosition.bottom),
                                trackballBehavior:
                                    TrackballBehavior(enable: true),
                                series: [
                                  SplineAreaSeries<SensorData, String>(
                                    dataSource: _chartData,
                                    xValueMapper: (SensorData data, _) =>
                                        data.formattedTimestamp,
                                    yValueMapper: (SensorData data, _) =>
                                        data.humidity,
                                    name: 'Humidity',
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.withOpacity(0.6),
                                        Colors.transparent
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    markerSettings:
                                        const MarkerSettings(isVisible: true),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Sensor Data Table - All Records",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 22),
                        ),
                        const SizedBox(height: 10),

                        // Table Container
                        SizedBox(
                          width: MediaQuery.of(context).size.width - 75,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                )
                              ],
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                dividerThickness: 0,
                                showBottomBorder: false, // remove table borders
                                headingRowColor:
                                    WidgetStateProperty.all(Colors.deepPurple),
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                                dataRowColor:
                                    WidgetStateProperty.resolveWith<Color?>(
                                  (Set<WidgetState> states) {
                                    if (_paginatedData.isEmpty)
                                      return Colors.white;
                                    final rowIndex = _paginatedData.indexWhere(
                                        (sensor) =>
                                            sensor.id.toString() ==
                                            (states.contains(
                                                    WidgetState.selected)
                                                ? ""
                                                : sensor.id.toString()));
                                    return rowIndex % 2 == 0
                                        ? Colors.white
                                        : const Color.fromARGB(255, 245, 245,
                                            245); // alternating gray
                                  },
                                ),
                                columnSpacing:
                                    (MediaQuery.of(context).size.width -
                                            60 -
                                            (5 * 100)) /
                                        4,
                                columns: const [
                                  DataColumn(label: Text('ID')),
                                  DataColumn(label: Text('Temp (°C)')),
                                  DataColumn(label: Text('Humidity (%)')),
                                  DataColumn(label: Text('Timestamp')),
                                  DataColumn(label: Text('Relay Status')),
                                ],
                                rows: List.generate(_paginatedData.length,
                                    (index) {
                                  final sensor = _paginatedData[index];
                                  return DataRow(
                                    color: WidgetStateProperty.all(
                                      index % 2 == 0
                                          ? Colors.white
                                          : const Color.fromARGB(
                                              255, 245, 245, 245),
                                    ),
                                    cells: [
                                      DataCell(Text(sensor.id.toString())),
                                      DataCell(Text(sensor.temperature
                                          .toStringAsFixed(1))),
                                      DataCell(Text(
                                          sensor.humidity.toStringAsFixed(1))),
                                      DataCell(Text(sensor.formattedTimestamp)),
                                      DataCell(Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: sensor.relayStatus == 'ON'
                                              ? Colors.green[100]
                                              : Colors.red[100],
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          sensor.relayStatus,
                                          style: TextStyle(
                                            color: sensor.relayStatus == 'ON'
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Centered pagination
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios),
                                onPressed: _currentPage > 0
                                    ? () => setState(() => _currentPage--)
                                    : null,
                              ),
                              Text("Page ${_currentPage + 1} of $_totalPages"),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios),
                                onPressed: (_currentPage + 1) < _totalPages
                                    ? () => setState(() => _currentPage++)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(String title, String value, Color color,
      {Widget? gauge, Widget? extraWidget, Widget? titleWidget}) {
    return Card(
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            titleWidget ??
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 20,
                  ),
                ),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: color,
              ),
            ),
            if (gauge != null) ...[
              const SizedBox(height: 16),
              SizedBox(height: 120, width: 120, child: gauge),
            ],
            if (extraWidget != null) ...[
              const SizedBox(height: 16),
              extraWidget,
            ],
          ],
        ),
      ),
    );
  }

  Widget buildLastRelayTriggerCard(String datetimeString) {
    DateTime? dt;
    try {
      dt = DateTime.parse(datetimeString);
    } catch (_) {
      dt = null;
    }

    if (dt == null) {
      return const Text(
        'Invalid Date',
        style: TextStyle(fontSize: 16, color: Colors.grey),
        textAlign: TextAlign.center,
      );
    }

    String dateStr =
        "${dt.day}/${dt.month}/${dt.year}"; // or use intl DateFormat for nicer formatting
    String timeStr =
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dateStr,
          style: const TextStyle(fontSize: 20, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Text(
          timeStr,
          style: const TextStyle(fontSize: 70, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget buildLastUpdatedCard() {
    if (lastUpdated == null) {
      return const Card(
        color: Colors.white,
        elevation: 5,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.update, color: Colors.blue, size: 30),
              SizedBox(width: 8),
              Text(
                "Last Updated: -",
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    // Format date and time
    final formattedDate =
        "${lastUpdated!.day}/${lastUpdated!.month}/${lastUpdated!.year}";
    final formattedTime = TimeOfDay.fromDateTime(lastUpdated!).format(context);

    return Card(
      color: Colors.white,
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.update,
              color: Colors.blue,
              size: 30,
            ),
            const SizedBox(width: 8),
            Text(
              "Last Updated: $formattedDate, $formattedTime",
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    IconData iconData;
    String statusText;

    if (latestTemp >= tempThreshold) {
      iconData = Icons.warning_amber_rounded; // Warning icon
      statusText = "Alert: High Temperature!";
    } else if (latestHum >= humThreshold) {
      iconData = Icons.warning_amber_rounded; // Warning icon
      statusText = "Alert: High Humidity!";
    } else {
      iconData = Icons.check_circle_outline; // Checkmark icon
      statusText = "Temperature and Humidity reading normal";
    }

    Color textColor =
        statusText.contains("Alert") ? Colors.red[900]! : Colors.green[500]!;

    return Card(
      color: Colors.white,
      elevation: 5,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(iconData, color: textColor, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(fontSize: 18, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build gauge for temperature or humidity
  Widget buildGauge(double value, double maxValue, Color color) {
    return gauges.SfRadialGauge(
      axes: <gauges.RadialAxis>[
        gauges.RadialAxis(
          minimum: 0,
          maximum: maxValue,
          showLabels: false,
          showTicks: false,
          axisLineStyle: gauges.AxisLineStyle(
            thickness: 0.5,
            thicknessUnit: gauges.GaugeSizeUnit.factor,
            color: color.withOpacity(0.3),
            cornerStyle: gauges.CornerStyle.bothCurve,
          ),
          pointers: <gauges.GaugePointer>[
            gauges.RangePointer(
              value: value.clamp(0, maxValue),
              width: 0.5,
              sizeUnit: gauges.GaugeSizeUnit.factor,
              color: color,
              cornerStyle: gauges.CornerStyle.bothCurve,
            ),
          ],
        )
      ],
    );
  }

  void _showThresholdSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(
              24, 16, 8, 0), // adjust padding for better layout
          title: Row(
            children: [
              const Expanded(
                child: Center(
                  child: Text(
                    "Set Thresholds",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog on cancel
                },
              ),
            ],
          ),
          content: SizedBox(
            width: 500, // Fixed width
            height: 450, // Fixed height
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Set Temperature and Humidity Thresholds",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  Image.asset(
                    'assets/images/robot.png',
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: tempController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Temp Threshold (°C)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: humController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Hum Threshold (%)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _updateThresholds();
                        Navigator.of(context).pop();
                      },
                      label: const Text(
                        "Update Threshold",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 170, 77, 228),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
