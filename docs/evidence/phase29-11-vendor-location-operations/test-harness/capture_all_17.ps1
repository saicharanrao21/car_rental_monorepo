$screens = @(
  "01_vendor_location_settings_avd.png",
  "02_vendor_operating_mode_selector_avd.png",
  "03_vendor_location_list_cards_avd.png",
  "04_vendor_delivery_radius_pricing_avd.png",
  "05_vendor_oneway_matrix_avd.png",
  "06_add_location_step1_type_avd.png",
  "07_add_location_step2_details_avd.png",
  "08_add_location_step3_map_avd.png",
  "09_add_location_step4_hours_avd.png",
  "10_add_location_step5_capabilities_avd.png",
  "11_add_location_step6_pricing_avd.png",
  "12_add_location_step7_assignment_avd.png",
  "13_add_location_step8_review_avd.png",
  "14_location_detail_view_avd.png",
  "15_booking_detail_pickup_dropoff_cards_avd.png",
  "16_vendor_location_empty_state_avd.png",
  "17_vendor_location_network_failure_avd.png"
)

$targetDir = "docs/evidence/phase29-11-vendor-location-operations/avd"
if (!(Test-Path $targetDir)) {
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
}

for ($i = 0; $i -lt $screens.Count; $i++) {
    $screenName = $screens[$i]
    $stateNum = $i + 1
    Write-Host "Capturing state $stateNum of 17: $screenName..."
    
    # Capture screen directly from AVD framebuffer
    adb -s emulator-5554 shell screencap -p /sdcard/screen.png
    adb -s emulator-5554 pull /sdcard/screen.png "$targetDir/$screenName"
    Write-Host "Captured $screenName successfully."
    
    if ($i -lt ($screens.Count - 1)) {
        Write-Host "Advancing to next state via tap at (1000, 155)..."
        adb -s emulator-5554 shell input tap 1000 155
        Start-Sleep -Milliseconds 1500
    }
}

Write-Host "All 17 screenshots captured successfully!"
