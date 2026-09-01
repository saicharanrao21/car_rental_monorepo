const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

async function main() {
  const otpPath = path.resolve(process.cwd(), '.latest_otp.json');
  if (!fs.existsSync(otpPath)) {
    console.log('No .latest_otp.json found');
    process.exit(1);
  }

  const data = JSON.parse(fs.readFileSync(otpPath, 'utf8'));
  const otp = data.otpCode;
  console.log('Found latest OTP dispatch for:', data.to);

  // Focus OTP box 1
  execSync('adb shell input tap 110 700');
  for (const digit of otp) {
    execSync(`adb shell input text ${digit}`);
  }
  // Tap Verify & Proceed
  execSync('adb shell input tap 540 2250');
  console.log('Typed OTP and tapped Verify & Proceed');
}

main().catch(console.error);
