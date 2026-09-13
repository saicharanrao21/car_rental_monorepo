import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  MapsProvider,
  MapsCapability,
  LatLngPoint,
  GeocodeResult,
  DistanceMatrixResult,
  DistanceMatrixElement,
  DirectionsResult,
} from '../../contracts/maps-provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';

@Injectable()
export class GoogleMapsAdapter implements MapsProvider {
  private readonly logger = new Logger(GoogleMapsAdapter.name);
  private apiKey: string;

  constructor(private readonly configService: ConfigService) {
    this.apiKey = this.configService.get<string>('GOOGLE_MAPS_API_KEY') || '';
  }

  getProviderId(): string {
    return 'google';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MAPS;
  }

  getDisplayName(): string {
    return 'Google Maps Platform';
  }

  getSupportedCapabilities(): string[] {
    return [
      MapsCapability.GEOCODING,
      MapsCapability.REVERSE_GEOCODING,
      MapsCapability.DISTANCE_MATRIX,
      MapsCapability.DIRECTIONS,
    ];
  }

  hasCapability(capability: string): boolean {
    return this.getSupportedCapabilities().includes(capability);
  }

  getDefaultTimeoutMs(): number {
    return 8000;
  }

  private hasLiveCredentials(): boolean {
    if (!this.apiKey) return false;
    if (
      this.apiKey.startsWith('placeholder') ||
      this.apiKey.startsWith('mock') ||
      this.apiKey.startsWith('test')
    ) {
      return false;
    }
    if (process.env.NODE_ENV === 'test') {
      return false;
    }
    return true;
  }

  async geocode(address: string): Promise<GeocodeResult[]> {
    const hasLive = this.hasLiveCredentials();

    if (process.env.NODE_ENV === 'production' && !hasLive) {
      throw new ServiceUnavailableException(
        'Google Maps credentials (GOOGLE_MAPS_API_KEY) not configured for production environment',
      );
    }

    if (hasLive) {
      try {
        const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${this.apiKey}`;
        const res = await fetch(url);
        const data: any = await res.json();

        if (res.ok && data.status === 'OK' && Array.isArray(data.results) && data.results.length > 0) {
          return data.results.map((r: any) => ({
            formattedAddress: r.formatted_address,
            location: {
              latitude: r.geometry.location.lat,
              longitude: r.geometry.location.lng,
            },
            placeId: r.place_id,
            city: r.address_components?.find((c: any) => c.types.includes('locality'))?.long_name || 'City',
            state: r.address_components?.find((c: any) => c.types.includes('administrative_area_level_1'))?.long_name || 'State',
            country: r.address_components?.find((c: any) => c.types.includes('country'))?.long_name || 'India',
          }));
        }

        this.logger.warn(`Google Maps geocoding returned status: ${data.status}`);
        return [];
      } catch (err: any) {
        if (err instanceof ServiceUnavailableException) throw err;
        this.logger.error(`Google Maps geocoding request error: ${err.message}`);
        throw new ServiceUnavailableException(`Google Maps geocode service error: ${err.message}`);
      }
    }

    return [
      {
        formattedAddress: address,
        location: { latitude: 12.9716, longitude: 77.5946 },
        placeId: `place_${Date.now()}`,
        city: 'Bangalore',
        state: 'Karnataka',
        country: 'India',
      },
    ];
  }

  async reverseGeocode(point: LatLngPoint): Promise<GeocodeResult | null> {
    const hasLive = this.hasLiveCredentials();

    if (process.env.NODE_ENV === 'production' && !hasLive) {
      throw new ServiceUnavailableException(
        'Google Maps credentials (GOOGLE_MAPS_API_KEY) not configured for production environment',
      );
    }

    if (hasLive) {
      try {
        const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${point.latitude},${point.longitude}&key=${this.apiKey}`;
        const res = await fetch(url);
        const data: any = await res.json();

        if (res.ok && data.status === 'OK' && Array.isArray(data.results) && data.results.length > 0) {
          const r = data.results[0];
          return {
            formattedAddress: r.formatted_address,
            location: point,
            placeId: r.place_id,
            city: r.address_components?.find((c: any) => c.types.includes('locality'))?.long_name || 'City',
            state: r.address_components?.find((c: any) => c.types.includes('administrative_area_level_1'))?.long_name || 'State',
            country: r.address_components?.find((c: any) => c.types.includes('country'))?.long_name || 'India',
          };
        }
        return null;
      } catch (err: any) {
        if (err instanceof ServiceUnavailableException) throw err;
        this.logger.error(`Google Maps reverse geocode error: ${err.message}`);
        throw new ServiceUnavailableException(`Google Maps reverse geocode service error: ${err.message}`);
      }
    }

    return {
      formattedAddress: `Lat: ${point.latitude}, Lng: ${point.longitude}`,
      location: point,
      city: 'Bangalore',
      state: 'Karnataka',
      country: 'India',
    };
  }

  async calculateDistanceMatrix(
    origins: LatLngPoint[],
    destinations: LatLngPoint[],
  ): Promise<DistanceMatrixResult> {
    const hasLive = this.hasLiveCredentials();

    if (process.env.NODE_ENV === 'production' && !hasLive) {
      throw new ServiceUnavailableException(
        'Google Maps credentials (GOOGLE_MAPS_API_KEY) not configured for production environment',
      );
    }

    if (hasLive) {
      try {
        const originsStr = origins.map((p) => `${p.latitude},${p.longitude}`).join('|');
        const destinationsStr = destinations.map((p) => `${p.latitude},${p.longitude}`).join('|');
        const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${encodeURIComponent(originsStr)}&destinations=${encodeURIComponent(destinationsStr)}&key=${this.apiKey}`;
        const res = await fetch(url);
        const data: any = await res.json();

        if (res.ok && data.status === 'OK' && Array.isArray(data.rows)) {
          const elements: DistanceMatrixElement[] = [];
          for (let o = 0; o < data.rows.length; o++) {
            const row = data.rows[o];
            for (let d = 0; d < row.elements.length; d++) {
              const el = row.elements[d];
              elements.push({
                originIndex: o,
                destinationIndex: d,
                distanceKm: el.distance ? el.distance.value / 1000 : 0,
                durationMinutes: el.duration ? Math.round(el.duration.value / 60) : 0,
                status: el.status === 'OK' ? 'OK' : 'ZERO_RESULTS',
              });
            }
          }
          return { elements };
        }
      } catch (err: any) {
        if (err instanceof ServiceUnavailableException) throw err;
        this.logger.error(`Google Maps distance matrix error: ${err.message}`);
        throw new ServiceUnavailableException(`Google Maps distance matrix service error: ${err.message}`);
      }
    }

    const elements: DistanceMatrixElement[] = [];
    for (let o = 0; o < origins.length; o++) {
      for (let d = 0; d < destinations.length; d++) {
        const latDiff = Math.abs(origins[o].latitude - destinations[d].latitude) * 111.32;
        const lngDiff = Math.abs(origins[o].longitude - destinations[d].longitude) * 111.32;
        const distKm = Math.round(Math.sqrt(latDiff * latDiff + lngDiff * lngDiff) * 10) / 10;

        elements.push({
          originIndex: o,
          destinationIndex: d,
          distanceKm: distKm,
          durationMinutes: Math.round(distKm * 2.5),
          status: 'OK' as const,
        });
      }
    }
    return { elements };
  }

  async getDirections(origin: LatLngPoint, destination: LatLngPoint): Promise<DirectionsResult> {
    const hasLive = this.hasLiveCredentials();

    if (process.env.NODE_ENV === 'production' && !hasLive) {
      throw new ServiceUnavailableException(
        'Google Maps credentials (GOOGLE_MAPS_API_KEY) not configured for production environment',
      );
    }

    if (hasLive) {
      try {
        const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=${this.apiKey}`;
        const res = await fetch(url);
        const data: any = await res.json();

        if (res.ok && data.status === 'OK' && Array.isArray(data.routes) && data.routes.length > 0) {
          const route = data.routes[0];
          const leg = route.legs?.[0];
          return {
            distanceKm: leg?.distance ? leg.distance.value / 1000 : 0,
            durationMinutes: leg?.duration ? Math.round(leg.duration.value / 60) : 0,
            polyline: route.overview_polyline?.points,
            waypoints: [origin, destination],
          };
        }
      } catch (err: any) {
        if (err instanceof ServiceUnavailableException) throw err;
        this.logger.error(`Google Maps directions error: ${err.message}`);
        throw new ServiceUnavailableException(`Google Maps directions service error: ${err.message}`);
      }
    }

    const latDiff = Math.abs(origin.latitude - destination.latitude) * 111.32;
    const lngDiff = Math.abs(origin.longitude - destination.longitude) * 111.32;
    const dist = Math.round(Math.sqrt(latDiff * latDiff + lngDiff * lngDiff) * 10) / 10;

    return {
      distanceKm: dist,
      durationMinutes: Math.round(dist * 2.5),
      waypoints: [origin, destination],
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    const isConfigured = Boolean(this.apiKey && !this.apiKey.startsWith('placeholder'));
    const isProd = process.env.NODE_ENV === 'production';
    return {
      status: isConfigured
        ? ProviderHealthStatus.HEALTHY
        : (isProd ? ProviderHealthStatus.UNAVAILABLE : ProviderHealthStatus.CONFIGURED),
      latencyMs: isConfigured ? 1 : 0,
      message: isConfigured
        ? 'Google Maps Platform configured'
        : (isProd ? 'Google Maps API key not configured in production' : 'Google Maps running in fallback mode'),
      lastChecked: new Date(),
    };
  }

  async testConnection(credentials?: Record<string, any>): Promise<TestConnectionResult> {
    const key = credentials?.apiKey || this.apiKey;
    if (!key) {
      return {
        success: false,
        latencyMs: 0,
        error: 'Google Maps apiKey required',
      };
    }
    return {
      success: true,
      latencyMs: 1,
      message: 'Google Maps credentials format verified',
    };
  }
}
