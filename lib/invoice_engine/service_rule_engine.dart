import '../core/models/erp_models.dart';

class ServiceRuleEngine {
  const ServiceRuleEngine();

  /// Electric Fence has unique running-feet logic.
  double electricFenceRatePerFeet(double runningFeet) {
    if (runningFeet <= 100) return 450;
    return 350;
  }

  /// CCTV uses camera-count package mapping.
  List<ServiceProduct> cctvMappedProducts(double cameraCount) {
    if (cameraCount <= 4) {
      return const [
        ServiceProduct(name: '4MP IP Camera', quantity: 4, unitPrice: 12500),
        ServiceProduct(name: '4 Channel NVR', quantity: 1, unitPrice: 22000),
        ServiceProduct(name: '2TB Hard Drive', quantity: 1, unitPrice: 16500),
        ServiceProduct(name: 'POE Switch', quantity: 1, unitPrice: 8500),
        ServiceProduct(name: 'CAT6 Cable', quantity: 1, unitPrice: 12000, unit: 'roll'),
        ServiceProduct(name: 'Installation', quantity: 1, unitPrice: 18000, unit: 'job'),
      ];
    }

    return [
      ServiceProduct(name: '4MP IP Camera', quantity: cameraCount, unitPrice: 12500),
      const ServiceProduct(name: '8 Channel NVR', quantity: 1, unitPrice: 28500),
      const ServiceProduct(name: '4TB Hard Drive', quantity: 1, unitPrice: 24000),
      const ServiceProduct(name: 'POE Switch', quantity: 1, unitPrice: 9500),
      const ServiceProduct(name: 'CAT6 Cable', quantity: 1, unitPrice: 15000, unit: 'roll'),
      const ServiceProduct(name: 'Installation', quantity: 1, unitPrice: 22000, unit: 'job'),
    ];
  }

  /// Solar uses KW package mapping (not running-feet).
  List<ServiceProduct> solarMappedProducts(double kw) {
    if (kw >= 8) {
      return const [
        ServiceProduct(name: 'Solar Panel 585W', quantity: 14, unitPrice: 18000),
        ServiceProduct(name: '8KW Hybrid Inverter', quantity: 1, unitPrice: 350000),
        ServiceProduct(name: 'Lithium Battery', quantity: 2, unitPrice: 135000),
        ServiceProduct(name: 'Structure', quantity: 1, unitPrice: 85000),
        ServiceProduct(name: 'DP Box', quantity: 1, unitPrice: 18000),
        ServiceProduct(name: 'AC DB', quantity: 1, unitPrice: 12000),
        ServiceProduct(name: 'Wiring', quantity: 1, unitPrice: 65000),
        ServiceProduct(name: 'Installation', quantity: 1, unitPrice: 120000, unit: 'job'),
      ];
    }

    return const [
      ServiceProduct(name: 'Solar Panel 585W', quantity: 9, unitPrice: 18000),
      ServiceProduct(name: '5KW Hybrid Inverter', quantity: 1, unitPrice: 245000),
      ServiceProduct(name: 'Lithium Battery', quantity: 1, unitPrice: 135000),
      ServiceProduct(name: 'Structure', quantity: 1, unitPrice: 65000),
      ServiceProduct(name: 'DP Box', quantity: 1, unitPrice: 15000),
      ServiceProduct(name: 'AC DB', quantity: 1, unitPrice: 10000),
      ServiceProduct(name: 'Wiring', quantity: 1, unitPrice: 42000),
      ServiceProduct(name: 'Installation', quantity: 1, unitPrice: 90000, unit: 'job'),
    ];
  }

  List<ServiceProduct> gateMappedProducts({required bool sliding}) {
    return [
      ServiceProduct(
        name: sliding ? 'Sliding Motor' : 'Swing Motor',
        quantity: 1,
        unitPrice: sliding ? 98000 : 110000,
      ),
      const ServiceProduct(name: 'Rack', quantity: 1, unitPrice: 14000),
      const ServiceProduct(name: 'Sensors', quantity: 1, unitPrice: 8500),
      const ServiceProduct(name: 'WiFi Controller', quantity: 1, unitPrice: 18500),
      const ServiceProduct(name: 'Installation', quantity: 1, unitPrice: 25000, unit: 'job'),
    ];
  }
}
