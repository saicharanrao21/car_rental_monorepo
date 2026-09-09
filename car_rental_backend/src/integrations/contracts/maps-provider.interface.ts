import { BaseProvider } from './provider.interface';

export enum MapsCapability {
  GEOCODING = 'GEOCODING',
  REVERSE_GEOCODING = 'REVERSE_GEOCODING',
  DISTANCE_MATRIX = 'DISTANCE_MATRIX',
  DIRECTIONS = 'DIRECTIONS',
  PLACE_AUTOCOMPLETE = 'PLACE_AUTOCOMPLETE',
}

export interface LatLngPoint {
  latitude: number;
  longitude: number;
}

export interface GeocodeResult {
  formattedAddress: string;
  location: LatLngPoint;
  placeId?: string;
  city?: string;
  state?: string;
  postalCode?: string;
  country?: string;
}

export interface DistanceMatrixElement {
  originIndex: number;
  destinationIndex: number;
  distanceKm: number;
  durationMinutes: number;
  distanceMeters?: number;
  durationSeconds?: number;
  status: 'OK' | 'NOT_FOUND' | 'ZERO_RESULTS';
}

export interface DistanceMatrixResult {
  elements: DistanceMatrixElement[];
  matrix?: DistanceMatrixElement[][];
  provider?: string;
}

export interface DirectionsResult {
  distanceKm: number;
  durationMinutes: number;
  polyline?: string;
  waypoints?: LatLngPoint[];
}

export interface MapsProvider extends BaseProvider {
  geocode(address: string): Promise<GeocodeResult[]>;
  reverseGeocode(point: LatLngPoint): Promise<GeocodeResult | null>;
  calculateDistanceMatrix(
    origins: LatLngPoint[],
    destinations: LatLngPoint[],
  ): Promise<DistanceMatrixResult>;
  getDirections(origin: LatLngPoint, destination: LatLngPoint): Promise<DirectionsResult>;
}
