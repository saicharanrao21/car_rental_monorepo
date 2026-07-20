# Razorpay Integration Guide

This NestJS backend includes a full integration for **Razorpay Payments** using Razorpay's official Node SDK. It handles order creation for pending bookings, webhook signature verification, booking confirmation on capture, retry on failures, and automated refunds upon cancellation.

---

## 1. Retrieving Razorpay Test Keys

1. Sign up for a free developer account at [razorpay.com](https://razorpay.com/).
2. Once logged in, toggle the environment to **Test Mode** (usually found in the header or sidebar).
3. Navigate to **Settings** -> **API Keys**.
4. Click **Generate Key** to receive your `Key ID` and `Key Secret`.
5. Copy these values into your local `.env` file:
   ```env
   RAZORPAY_KEY_ID="rzp_test_YOUR_KEY_ID"
   RAZORPAY_KEY_SECRET="YOUR_KEY_SECRET"
   ```

---

## 2. Setting Up Webhook for Local Testing

Razorpay communicates payment statuses (such as success and failure) back to the backend asynchronously via webhook events. Since Razorpay cannot make calls to a `localhost` URL directly, you need a public URL proxy for local development.

### Option A: Using `ngrok` (Recommended)

1. Install ngrok via npm or scoop/choco:
   ```bash
   npm install -g ngrok
   ```
2. Start the ngrok tunnel on the backend port (default: `3000`):
   ```bash
   ngrok http 3000
   ```
3. Copy the secure public forwarding URL (e.g., `https://a1b2-34-56-78.ngrok-free.app`).
4. Go to the Razorpay Dashboard -> **Settings** -> **Webhooks**.
5. Click **Add New Webhook**.
6. Set the **Webhook URL** to:
   ```
   https://YOUR_NGROK_FORWARDING_URL/payments/webhook
   ```
7. Set a **Secret** value and paste it into your `.env` file as `RAZORPAY_WEBHOOK_SECRET`.
8. Under **Active Events**, select:
   - `payment.captured`
   - `payment.failed`
9. Click **Create Webhook**.

### Option B: Local Simulation (Mock Mode)

For quick offline verification, configure:
```env
RAZORPAY_USE_MOCK="true"
```
In this mode, the backend simulates API calls to Razorpay and bypasses signature checks for requests that include the signature header `x-razorpay-signature: mock_signature`.

---

## 3. Razorpay Test Credentials (for Sandbox Testing)

When testing the checkout flow using the frontend or simulated checkout, use the following sandbox credentials:

### Success Card
- **Card Number**: `4111 1111 1111 1111` (Standard VISA Test Card)
- **Expiry Date**: Any future date (e.g., `12/30`)
- **CVV**: `123`
- **OTP**: Any 6-digit number (e.g., `123456`)

### Failure Cards
- **Insufficient Funds (Declined)**: `4000 0000 0000 1001`
- **Incorrect CVV**: `4000 0000 0000 1002`
- **Expired Card**: `4000 0000 0000 1003`

---

## 4. API Endpoints

- **Create Order**: `POST /payments/create-order`
  - Body: `{ "bookingId": "cuid_here" }`
  - Auth: `Bearer <CUSTOMER_JWT_TOKEN>`
- **Webhook Listener**: `POST /payments/webhook`
  - Body: Raw Webhook Event JSON
  - Auth: Verified using `x-razorpay-signature` header
- **Get Payment Status**: `GET /payments/:bookingId`
  - Auth: `Bearer <CUSTOMER_JWT_TOKEN>` or `Bearer <ADMIN_JWT_TOKEN>`
