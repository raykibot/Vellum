import { findNearestCity } from './chinaCities';

export interface GeolocationResult {
  city: string | null;
  failed: boolean;
}

export function detectCurrentCity(): Promise<GeolocationResult> {
  if (typeof navigator === 'undefined' || !('geolocation' in navigator)) {
    return Promise.resolve({ city: null, failed: true });
  }

  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const city = findNearestCity(position.coords.latitude, position.coords.longitude);
        if (city) {
          resolve({ city, failed: false });
        } else {
          resolve({ city: null, failed: true });
        }
      },
      () => {
        resolve({ city: null, failed: true });
      },
      {
        enableHighAccuracy: false,
        timeout: 6000,
        maximumAge: 300000,
      },
    );
  });
}
