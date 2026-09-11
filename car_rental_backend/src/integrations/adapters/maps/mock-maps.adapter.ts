import { Injectable } from '@nestjs/common';
import {
  MapsProvider,
  MapsCapability,
  LatLngPoint,
  GeocodeResult,
  DistanceMatrixResult,
  DirectionsResult,
} from '../../contracts/maps-provider.interface';
import {
  IntegrationCategory,
  ProviderHealthCheckResult,
  ProviderHealthStatus,
  TestConnectionResult,
} from '../../registry/provider.types';

@Injectable()
export class MockMapsAdapter implements MapsProvider {
  getProviderId(): string {
    return 'mock_maps';
  }

  getCategory(): IntegrationCategory {
    return IntegrationCategory.MAPS;
  }

  getDisplayName(): string {
    return 'Mock Maps & Geospatial Provider';
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
    return 3000;
  }

  async geocode(address: string): Promise<GeocodeResult[]> {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('CRITICAL SECURITY ERROR: MockMapsAdapter cannot be used in production.');
    }
    return [
      {
        formattedAddress: address,
        location: { latitude: 12.9716, longitude: 77.5946 },
        placeId: `mock_place_${Date.now()}`,
        city: 'Bangalore',
      },
    ];
  }

  async reverseGeocode(point: LatLngPoint): Promise<GeocodeResult | null> {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('CRITICAL SECURITY ERROR: MockMapsAdapter cannot be used in production.');
    }
    return {
      formattedAddress: `Lat: ${point.latitude}, Lng: ${point.longitude}`,
      location: point,
      city: 'Bangalore',
    };
  }

  async calculateDistanceMatrix(
    origins: LatLngPoint[],
    destinations: LatLngPoint[],
  ): Promise<DistanceMatrixResult> {
    return {
      elements: origins.map((_, o) =>
        destinations.map((__, d) => ({
          originIndex: o,
          destinationIndex: d,
          distanceKm: 12.5,
          durationMinutes: 30,
          status: 'OK' as const,
        })),
      ).flat(),
    };
  }

  async getDirections(origin: LatLngPoint, destination: LatLngPoint): Promise<DirectionsResult> {
    return {
      distanceKm: 15.0,
      durationMinutes: 35,
      waypoints: [origin, destination],
    };
  }

  async checkHealth(): Promise<ProviderHealthCheckResult> {
    return {
      status: ProviderHealthStatus.HEALTHY,
      latencyMs: 1,
      message: 'Mock Maps Provider is healthy',
      lastChecked: new Date(),
    };
  }

  async testConnection(): Promise<TestConnectionResult> {
    return {
      success: true,
      latencyMs: 1,
      message: 'Mock Maps connection test successful',
    };
  }
}
