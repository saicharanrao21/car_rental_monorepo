import { GeospatialService } from './geospatial.service';

describe('Phase 27.1 — Geospatial & PostGIS Infrastructure Tests', () => {
  let geoService: GeospatialService;

  beforeEach(() => {
    geoService = new GeospatialService();
  });

  describe('Haversine Distance Calculation', () => {
    it('accurately calculates distance between Mumbai and Pune (~120 km)', () => {
      const mumbaiLat = 19.076;
      const mumbaiLng = 72.8777;
      const puneLat = 18.5204;
      const puneLng = 73.8567;

      const dist = geoService.calculateDistanceKm(
        mumbaiLat,
        mumbaiLng,
        puneLat,
        puneLng,
      );

      expect(dist).toBeGreaterThan(115);
      expect(dist).toBeLessThan(125);
    });

    it('returns 0 for identical coordinate pairs', () => {
      const dist = geoService.calculateDistanceKm(19.076, 72.8777, 19.076, 72.8777);
      expect(dist).toBe(0);
    });
  });

  describe('Bounding Box Generation for Fast DB Queries', () => {
    it('computes accurate bounding box for 10km radius around Mumbai center', () => {
      const centerLat = 19.076;
      const centerLng = 72.8777;
      const radiusKm = 10;

      const bbox = geoService.getBoundingBox(centerLat, centerLng, radiusKm);

      expect(bbox.minLat).toBeLessThan(centerLat);
      expect(bbox.maxLat).toBeGreaterThan(centerLat);
      expect(bbox.minLng).toBeLessThan(centerLng);
      expect(bbox.maxLng).toBeGreaterThan(centerLng);

      // Verify latitude delta is approx 0.0898 degrees (10 / 111.32)
      expect(bbox.maxLat - centerLat).toBeCloseTo(0.0898, 3);
    });
  });

  describe('Distance Filtering & Sorting', () => {
    it('filters and sorts items by proximity', () => {
      const userLat = 19.076;
      const userLng = 72.8777;

      const locations = [
        { name: 'Pune Branch', latitude: 18.5204, longitude: 73.8567 }, // ~120km
        { name: 'Bandra Hub', latitude: 19.0596, longitude: 72.8295 }, // ~5km
        { name: 'Thane Hub', latitude: 19.2183, longitude: 72.9781 }, // ~19km
      ];

      const results = geoService.filterAndSortByDistance(
        locations,
        userLat,
        userLng,
        50, // max 50km
      );

      expect(results.length).toBe(2);
      expect(results[0].name).toBe('Bandra Hub');
      expect(results[1].name).toBe('Thane Hub');
      expect(results[0].distanceKm).toBeLessThan(results[1].distanceKm);
    });
  });

  describe('PostGIS SQL Generator', () => {
    it('builds valid ST_DWithin SQL clause for native PostGIS execution', () => {
      const sql = geoService.buildPostGisFilterSql(
        'v.latitude',
        'v.longitude',
        19.076,
        72.8777,
        50000,
      );

      expect(sql).toContain('ST_DWithin');
      expect(sql).toContain('ST_MakePoint');
      expect(sql).toContain('50000');
    });
  });
});
