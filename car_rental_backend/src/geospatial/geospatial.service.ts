import { Injectable, Logger } from '@nestjs/common';

export interface BoundingBox {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
}

export interface SpatialPoint {
  latitude: number;
  longitude: number;
}

@Injectable()
export class GeospatialService {
  private readonly logger = new Logger(GeospatialService.name);
  private static readonly EARTH_RADIUS_KM = 6371.0;

  /**
   * Computes the great-circle distance between two points in kilometers using the Haversine formula.
   */
  calculateDistanceKm(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const dLat = this.toRadians(lat2 - lat1);
    const dLon = this.toRadians(lon2 - lon1);

    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRadians(lat1)) *
        Math.cos(this.toRadians(lat2)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Number((GeospatialService.EARTH_RADIUS_KM * c).toFixed(2));
  }

  /**
   * Computes an axis-aligned bounding box (minLat, maxLat, minLng, maxLng)
   * for sub-millisecond database index range queries.
   */
  getBoundingBox(centerLat: number, centerLng: number, radiusKm: number): BoundingBox {
    // 1 degree of latitude is approx 111.32 km
    const latDelta = radiusKm / 111.32;
    // 1 degree of longitude depends on latitude
    const latRad = this.toRadians(centerLat);
    const lngDelta = radiusKm / (111.32 * Math.cos(latRad));

    return {
      minLat: Number((centerLat - latDelta).toFixed(6)),
      maxLat: Number((centerLat + latDelta).toFixed(6)),
      minLng: Number((centerLng - lngDelta).toFixed(6)),
      maxLng: Number((centerLng + lngDelta).toFixed(6)),
    };
  }

  /**
   * Checks if a point is within radiusKm of center coordinates.
   */
  isWithinRadius(
    centerLat: number,
    centerLng: number,
    pointLat: number,
    pointLng: number,
    radiusKm: number,
  ): boolean {
    const distance = this.calculateDistanceKm(
      centerLat,
      centerLng,
      pointLat,
      pointLng,
    );
    return distance <= radiusKm;
  }

  /**
   * Filters and sorts an array of objects having latitude and longitude properties by distance.
   */
  filterAndSortByDistance<T extends { latitude?: number | null; longitude?: number | null }>(
    items: T[],
    userLat: number,
    userLng: number,
    maxRadiusKm: number = 100,
  ): Array<T & { distanceKm: number }> {
    const scored = items
      .filter((item) => item.latitude != null && item.longitude != null)
      .map((item) => {
        const distanceKm = this.calculateDistanceKm(
          userLat,
          userLng,
          item.latitude!,
          item.longitude!,
        );
        return { ...item, distanceKm };
      })
      .filter((item) => item.distanceKm <= maxRadiusKm);

    scored.sort((a, b) => a.distanceKm - b.distanceKm);
    return scored;
  }

  /**
   * PostGIS SQL Helper: Generates an optimized spatial query fragment
   * when native PostGIS ST_DWithin and GIST indexes are available.
   */
  buildPostGisFilterSql(
    latColumn: string,
    lngColumn: string,
    targetLat: number,
    targetLng: number,
    radiusMeters: number,
  ): string {
    return `ST_DWithin(
      ST_SetSRID(ST_MakePoint(${lngColumn}, ${latColumn}), 4326)::geography,
      ST_SetSRID(ST_MakePoint(${targetLng}, ${targetLat}), 4326)::geography,
      ${radiusMeters}
    )`;
  }

  private toRadians(degrees: number): number {
    return degrees * (Math.PI / 180);
  }
}
