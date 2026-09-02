$screenshots = @(
    "01_vendor_operations_bookings_avd.png",
    "02_vendor_handover_entry_avd.png",
    "03_vendor_handover_step0_identity_avd.png",
    "04_vendor_handover_step1_odometer_fuel_avd.png",
    "05_vendor_handover_step2_photo_burst_avd.png",
    "06_vendor_handover_step3_damage_clean_avd.png",
    "07_vendor_handover_step3_damage_added_avd.png",
    "08_vendor_handover_step4_review_avd.png",
    "09_vendor_handover_completed_success_avd.png",
    "10_vendor_return_entry_avd.png",
    "11_vendor_return_step0_odometer_fuel_delta_avd.png",
    "12_vendor_return_step0_validation_error_avd.png",
    "13_vendor_return_step1_photo_burst_avd.png",
    "14_vendor_return_step2_before_after_damage_avd.png",
    "15_vendor_return_step2_new_damage_spot_avd.png",
    "16_vendor_return_step3_review_settlement_avd.png",
    "17_vendor_return_completed_success_avd.png",
    "18_vendor_network_failure_avd.png"
)

$outDir = "docs/evidence/phase29-10-vendor-inspection/avd"

for ($i = 0; $i -lt $screenshots.Length; $i++) {
    $filename = $screenshots[$i]
    $dest = "$outDir/$filename"
    
    Write-Host "Capturing state $($i+1): $filename..."
    Start-Sleep -Milliseconds 1500
    
    adb -s emulator-5554 shell screencap -p /sdcard/screen.png
    adb -s emulator-5554 pull /sdcard/screen.png $dest
    
    Write-Host "Captured $filename successfully."
    
    # Tap FAB in top right to advance to next state (if not last)
    if ($i -lt ($screenshots.Length - 1)) {
        Write-Host "Advancing to next state..."
        adb -s emulator-5554 shell input tap 990 200
        Start-Sleep -Milliseconds 1500
    }
}

Write-Host "All 18 screenshots captured successfully!"
