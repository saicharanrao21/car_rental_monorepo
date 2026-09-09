export enum MapsCapability {
  GEOCODE = 'GEOCODE',
  REVERSE_GEOCODE = 'REVERSE_GEOCODE',
  ROUTE = 'ROUTE',
  DISTANCE_MATRIX = 'DISTANCE_MATRIX',
  PLACE_SEARCH = 'PLACE_SEARCH',
  PLACE_DETAILS = 'PLACE_DETAILS',
  AUTOCOMPLETE = 'AUTOCOMPLETE',
  MAP_TILES = 'MAP_TILES',
  NAVIGATION = 'NAVIGATION',
  ETA = 'ETA',
  TRAFFIC = 'TRAFFIC',
}

export interface Coordinates {
  latitude: number;
  longitude: number;
}

export interface GeocodeRequest {
  address: string;
  countryCode?: string;
  language?: string;
}

export interface GeocodeResult {
  latitude: number;
  longitude: number;
  location?: Coordinates;
  formattedAddress: string;
  placeId?: string;
  confidence?: number;
  provider: string;
  raw?: any;
}

export interface ReverseGeocodeRequest {
  coordinates: Coordinates;
  language?: string;
}

export interface RouteWaypoint {
  latitude: number;
  longitude: number;
  label?: string;
}

export interface RouteRequest {
  origin: Coordinates;
  destination: Coordinates;
  waypoints?: RouteWaypoint[];
  mode?: 'driving' | 'walking' | 'bicycling' | 'driving-traffic';
  avoidTolls?: boolean;
  avoidHighways?: boolean;
}

export interface RouteStep {
  instruction: string;
  distanceMeters: number;
  durationSeconds: number;
  startLocation: Coordinates;
  endLocation: Coordinates;
}

export interface RouteResult {
  distanceMeters: number;
  durationSeconds: number;
  durationInTrafficSeconds?: number;
  overviewPolyline?: string;
  steps?: RouteStep[];
  waypoints?: RouteWaypoint[];
  bounds?: {
    northeast: Coordinates;
    southwest: Coordinates;
  };
  provider: string;
}

export interface DistanceMatrixRequest {
  origins: Coordinates[];
  destinations: Coordinates[];
  mode?: 'driving' | 'walking' | 'bicycling';
}

export interface DistanceMatrixElement {
  originIndex: number;
  destinationIndex: number;
  distanceMeters?: number;
  durationSeconds?: number;
  distanceKm?: number;
  durationMinutes?: number;
  status: 'OK' | 'ZERO_RESULTS' | 'NOT_FOUND';
}

export interface DistanceMatrixResult {
  elements: DistanceMatrixElement[];
  matrix?: DistanceMatrixElement[][];
  provider?: string;
}

export interface PlaceSearchRequest {
  query: string;
  location?: Coordinates;
  radiusMeters?: number;
}

export interface PlaceSearchResult {
  places: Array<{
    placeId: string;
    name: string;
    address: string;
    location: Coordinates;
    types?: string[];
  }>;
  provider: string;
}
