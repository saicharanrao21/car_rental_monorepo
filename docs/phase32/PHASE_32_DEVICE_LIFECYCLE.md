# DRIVEGO — PHASE 32 DEVICE & TOKEN LIFECYCLE ARCHITECTURE
## Multi-Device Registry, Hardware Uniqueness, Token Invalidation & Stale Pruning

**Author**: Principal Software Architect, CTO, Senior Backend & Flutter Engineer  
**Date**: September 2026  
**Subsystem**: Notifications & Device Management  
**Repository**: `car_rental_monorepo`

---

### 1. The Multi-Device Reality

Real-world users often operate across multiple platforms:
- An iPhone during transit and an Android work tablet in the host yard.
- Frequent app reinstalls or system upgrades causing FCM token rotation.
- Users logging out on personal devices or logging into shared vendor terminal tablets.

Prior to Phase 32, push notifications only queried a single `User.fcmToken` column. Phase 32 establishes `UserDevice` as the server-authoritative multi-device registry.

---

### 2. Schema Specification (`UserDevice`)

```prisma
model UserDevice {
  id          String    @id @default(uuid())
  userId      String
  user        User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  deviceId    String?   // Hardware identifier (e.g. Android ID, iOS identifierForVendor)
  fcmToken    String    @unique
  platform    String    // ANDROID | IOS | WEB
  appVersion  String?
  isActive    Boolean   @default(true)
  lastSeenAt  DateTime  @default(now())
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt

  @@index([userId])
  @@index([userId, isActive])
  @@index([userId, deviceId])
}
```

---

### 3. Lifecycle State Machine

```
                   +----------------------------------+
                   |  App Launch / FCM Token Issued   |
                   +----------------+-----------------+
                                    |
                                    v
                   +----------------------------------+
                   |  POST /notifications/devices/reg |
                   |  - Deactivate previous tokens on |
                   |    same physical deviceId        |
                   |  - Set isActive = true           |
                   |  - Update lastSeenAt & appVersion|
                   +----------------+-----------------+
                                    |
            +-----------------------+-----------------------+
            |                                               |
            v                                               v
    [User Signs Out]                               [Push Provider Error]
            |                                               |
            v                                               v
  DELETE /devices/unregister               FCM Error: token-not-registered
            |                                               |
            v                                               v
+-----------------------+                       +-----------------------+
|  isActive = false     |                       |  isActive = false     |
|  fcmToken deactivated |                       |  Purged from pool     |
+-----------------------+                       +-----------------------+
```

---

### 4. Hardware Uniqueness & Token Rotation

When Firebase refreshes an FCM token on a physical phone:
1. The app receives `onNewToken` or retrieves the fresh token on launch.
2. The app calls `POST /notifications/devices/register` with:
   ```json
   {
     "token": "eXamPle_fcm_token_new_9921",
     "deviceId": "dev_hardware_id_pixel_8",
     "platform": "ANDROID",
     "appVersion": "2.1.0"
   }
   ```
3. The server executes an atomic multi-step reconciliation:
   - Queries existing active devices with `deviceId == 'dev_hardware_id_pixel_8'`.
   - Flags all obsolete tokens on that hardware ID as `isActive = false`.
   - Upserts the current token with `isActive = true`, associating it with the authenticated `userId`.
   - Updates legacy `User.fcmToken` to ensure backward compatibility.

---

### 5. Multi-User Shared Device Invariant

If User A logs into a tablet (`deviceId: 'tablet_yard_01'`), and subsequently User B logs into the same tablet:
- During User B's registration, the backend locates all active `UserDevice` rows matching `deviceId: 'tablet_yard_01'`.
- It deactivates User A's token on that tablet immediately.
- Result: User A will **never** receive notifications intended for User B, preventing tenant and privacy leaks.

---

### 6. Stale Device Pruning Policy

Inactive device records accumulate over time due to uninstalls without explicit logout. 

**Admin Governance Routine**:
- **Endpoint**: `POST /admin/notifications/devices/cleanup?daysInactive=30`
- **RBAC**: Admin only (`@Roles(UserRole.ADMIN)`).
- **Execution**: Deactivates or removes all `UserDevice` rows where `lastSeenAt < now() - 30 days`.
- **Telemetry**: Returns the count of pruned devices for audit logging.
