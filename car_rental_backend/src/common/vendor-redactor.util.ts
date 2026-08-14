export interface VendorRedactionOptions {
  isAdmin?: boolean;
  isOwner?: boolean;
  isPaid?: boolean;
}

export function maskBankDetails(value: string | null | undefined): string | null {
  if (!value || value.trim() === '') {
    return null;
  }
  // If ciphertext enc:v1:..., we handle inside service or fallback
  return value.replace(/\b(\d{4,})\b/g, (match) => {
    if (match.length <= 4) return match;
    const visible = match.slice(-4);
    return '••••••••' + visible;
  });
}

export function redactVendor(
  vendor: any,
  options: VendorRedactionOptions = {},
) {
  if (!vendor) return vendor;

  const copy = { ...vendor };

  // Compute displayName
  const localityStr = copy.locality || copy.city || '';
  copy.displayName = localityStr
    ? `Partner in ${localityStr}`
    : 'Verified Partner';

  // Admin or Vendor Owner sees vendor identity & details (bankDetails masked for display)
  if (options.isAdmin || options.isOwner) {
    if (copy.bankDetails && !copy.bankDetails.startsWith('enc:v1:')) {
      copy.bankDetails = maskBankDetails(copy.bankDetails);
    }
    return copy;
  }

  // Always strip sensitive financial details for customers/public
  delete copy.gstNumber;
  delete copy.panNumber;
  delete copy.bankDetails;

  // Always strip vendor user raw phone number to prevent direct off-platform calling
  if (copy.user) {
    const userCopy = { ...copy.user };
    delete userCopy.phone;
    delete userCopy.passwordHash;
    copy.user = userCopy;
  }
  delete copy.phone;

  if (options.isPaid) {
    // Post-payment reveal: reveal real businessName and ownerName, exact coordinates
    return copy;
  } else {
    // Pre-payment redaction: hide real businessName and ownerName, round coordinates to ~1km precision (2 decimals)
    delete copy.businessName;
    delete copy.ownerName;

    if (copy.latitude !== undefined && copy.latitude !== null) {
      copy.latitude = Math.round(Number(copy.latitude) * 100) / 100;
    }
    if (copy.longitude !== undefined && copy.longitude !== null) {
      copy.longitude = Math.round(Number(copy.longitude) * 100) / 100;
    }

    return copy;
  }
}
