# DriveGo Self-Drive Mobility Marketplace — City, Location & Pickup Point Model

**Document Reference:** `MODEL-LOC-04`  
**Version:** 2.0.0-PROD  
**Author:** DriveGo Principal Software Architect & Geospatial Systems Lead  
**Scope:** Supported Cities, Vendor Operating Locations, Vehicle Allocation, and Customer Delivery  
**Status:** Approved for Implementation

---

## 1. Domain Separation of 5 Core Geographic Concepts

To prevent marketplace confusion between administrative boundaries and partner operating yards, DriveGo strictly distinguishes 5 concepts:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 1. SUPPORTED CITY (Platform Level - Managed by Super Admin)                            │
│    e.g., Hyderabad, Bengaluru, Mumbai, Delhi-NCR, Pune                                 │
└──────────────────────────────────────────┬─────────────────────────────────────────────┘
                                           │ contains
                                           ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 2. SERVICE AREA (Platform Level - Managed by Super Admin)                              │
│    e.g., Cyberabad IT Corridor (Latitude, Longitude, Radius / GeoJSON Polygon)          │
└──────────────────────────────────────────┬─────────────────────────────────────────────┘
                                           │ authorized vendors operate within
                                           ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 3. VENDOR OPERATING LOCATION / YARD (Vendor Level - Managed by Vendor)                 │
│    e.g., Apex Fleet Yard 1 (Plot 42, Financial District, Gachibowli, Hyderabad)        │
│    (name, exact address, locality, city, state, lat/lng, operating hours, phone)       │
└──────────────────────────────────────────┬─────────────────────────────────────────────┘
                                           │ stations
                                           ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 4. VEHICLE HOME LOCATION (Vehicle Level - Assigned by Vendor)                          │
│    e.g., Hyundai Creta TS09FA1234 assigned to "Apex Fleet Yard 1" (pickupHubId)        │
└──────────────────────────────────────────┬─────────────────────────────────────────────┘
                                           │ fulfilled via
                                           ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 5. PICKUP & DELIVERY OPTIONS (Booking Level - Configured by Vendor & Platform Rules)   │
│    - Self Pickup at Yard (Free)                                                        │
│    - Doorstep Delivery to Customer Location (Calculated per-km from Yard)               │
│    - Airport Terminal Meet & Greet (Subject to Airport Commercial Permit Rules)        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Vendor Operating Location Lifecycle & Management

### 2.1 Workflow: Vendor Registers a Genuine Operating Yard
1. **Select Enabled City:** The vendor app queries `GET /locations/cities` to list only active platform cities (e.g. Hyderabad).
2. **Specify Yard Details:** Vendor inputs:
   - Location Name (e.g. *"Gachibowli Operations Yard"*).
   - Street Address (e.g. *"Plot 18, Telecom Nagar, Gachibowli"*).
   - Locality & Pincode (e.g. *"Gachibowli, 500032"*).
   - Coordinates: Selected on map or reverse-geocoded via `GET /locations/reverse-geocode`.
   - Operating Hours (e.g. *"06:00 - 23:00"*).
   - Gate / Attendant Contact Number.
3. **Backend Validation:**
   - Confirms the city is currently enabled (`SupportedCity.status == 'ACTIVE'`).
   - Ensures coordinates fall within India and within permissible state bounds.
   - Saves record into `PickupHub` with `vendorId` set to the authenticated partner.
4. **Multiple Yards per Vendor:** A single vendor can operate multiple distinct locations (e.g., Kondapur, Gachibowli, Shamshabad Airport Service Point).
5. **Cross-Vendor Isolation:**
   - A vendor can only view and update locations where `PickupHub.vendorId == req.user.vendorId`.
   - Attempting to inspect or assign another vendor's hub triggers `HTTP 403 Forbidden`.

---

## 3. Vehicle-to-Location Binding & Integrity Rules

1. **Mandatory Association:** Every vehicle in the fleet must reference an active `pickupHubId`.
2. **Ownership Validation:** During `POST /vendor/fleet` and `PATCH /vendor/fleet/:id`, the backend verifies that `pickupHub.vendorId == vendor.id`. Vehicles cannot be tethered to orphaned or rival partner hubs.
3. **Deactivation Safety:** If an operating yard is deactivated or closed by the vendor, existing active and confirmed bookings retain historical snapshots of the yard name, address, and coordinates in `Booking.pickupHubSnapshot`. New bookings for that yard are blocked.
4. **Search and Discovery Integrity:** Customer searches by city or GPS proximity only return vehicles stationed at operating yards within permissible distance or with delivery coverage matching the customer's coordinates.

