import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Button,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  Camera,
  useCameraDevice,
  useFrameProcessor,
} from 'react-native-vision-camera';
import { useRunOnJS } from 'react-native-worklets-core';
import {
  detectBrand,
  getLast4,
  isSupported,
  isValidLuhn,
  normalizePan,
  parseExpiry,
  scanCardImage,
  scanPaymentCard,
  type CardImageScanOptions,
  type CardScanResult,
  type ScanCardOptions,
} from 'react-native-vision-camera-payment-card-scanner';

const samplePan = normalizePan('4111 1111 1111 1111');
const sampleLast4 = getLast4(samplePan);
const sampleBrand = detectBrand(samplePan);
const sampleExpiry = parseExpiry('04/29');
const sampleIsValid = isValidLuhn(samplePan);

const liveScanOptions: ScanCardOptions = {
  scanExpiry: true,
};

const imageScanOptions = (imageUri: string): CardImageScanOptions => ({
  imageUri,
  scanExpiry: true,
});

function formatResult(result: CardScanResult | null): string {
  if (!result) {
    return 'No scan result yet.';
  }

  return JSON.stringify(result, null, 2);
}

function serializeResult(result: CardScanResult | null): string {
  return result ? JSON.stringify(result) : 'null';
}

export default function App() {
  const cameraRef = useRef<Camera | null>(null);
  const device = useCameraDevice('back');
  const lastLiveResultRef = useRef<string>('null');

  const [loading, setLoading] = useState(false);
  const [supportValue, setSupportValue] = useState<string>('unchecked');
  const [result, setResult] = useState<CardScanResult | null>(null);
  const [liveResult, setLiveResult] = useState<CardScanResult | null>(null);
  const [cameraPermission, setCameraPermission] = useState<
    'unknown' | 'granted' | 'denied'
  >('unknown');
  const [lastCapturedPath, setLastCapturedPath] = useState<string | null>(null);

  const helperText = useMemo(() => {
    if (cameraPermission === 'granted') {
      return Platform.OS === 'ios'
        ? 'Live frame scanning is active while the preview is visible. You can also capture a still image to compare results.'
        : 'Camera preview is available. Capture a still image to run Android ML Kit OCR image scanning. Android live frame scanning is not enabled in this demo.';
    }

    if (cameraPermission === 'denied') {
      return Platform.OS === 'ios'
        ? 'Camera permission is denied. Grant access in iOS Settings, then reopen the app.'
        : 'Camera permission is denied. Grant access in Android Settings, then reopen the app.';
    }

    return 'Grant camera permission to test payment card scanning.';
  }, [cameraPermission]);

  useEffect(() => {
    let active = true;

    const loadPermission = async () => {
      try {
        const current = await Camera.getCameraPermissionStatus();
        if (!active) {
          return;
        }
        setCameraPermission(current === 'granted' ? 'granted' : 'denied');
      } catch {
        if (!active) {
          return;
        }
        setCameraPermission('denied');
      }
    };

    loadPermission();

    return () => {
      active = false;
    };
  }, []);

  const updateLiveResult = useCallback((nextResult: CardScanResult | null) => {
    const nextSerialized = serializeResult(nextResult);
    if (nextSerialized === lastLiveResultRef.current) {
      return;
    }

    lastLiveResultRef.current = nextSerialized;
    setLiveResult(nextResult);
  }, []);

  const runUpdateLiveResult = useRunOnJS(updateLiveResult, [updateLiveResult]);

  const frameProcessor = useFrameProcessor(
    (frame) => {
      'worklet';

      const nextResult = scanPaymentCard(frame, liveScanOptions);
      if (nextResult == null) {
        return;
      }

      if (
        nextResult.complete ||
        nextResult.pan ||
        nextResult.last4 ||
        nextResult.expiryMonth
      ) {
        runUpdateLiveResult(nextResult);
      }
    },
    [runUpdateLiveResult]
  );

  const handleRequestCameraPermission = async () => {
    try {
      const permission = await Camera.requestCameraPermission();
      setCameraPermission(permission === 'granted' ? 'granted' : 'denied');
    } catch (error) {
      setCameraPermission('denied');
      Alert.alert('Permission failed', String(error));
    }
  };

  const handleCheckSupport = async () => {
    try {
      const supported = await isSupported();
      setSupportValue(supported ? 'true' : 'false');
    } catch (error) {
      setSupportValue('error');
      Alert.alert('Support check failed', String(error));
    }
  };

  const handleCaptureAndScan = async () => {
    if (cameraPermission !== 'granted') {
      Alert.alert(
        'Camera permission required',
        'Grant camera access before scanning a payment card.'
      );
      return;
    }

    if (!device) {
      Alert.alert(
        'Camera unavailable',
        'No back camera device is currently available.'
      );
      return;
    }

    if (!cameraRef.current) {
      Alert.alert('Camera unavailable', 'The camera preview is not ready yet.');
      return;
    }

    setLoading(true);
    try {
      const photo = await cameraRef.current.takePhoto({
        enableAutoRedEyeReduction: false,
        flash: 'off',
      });
      const imageUri = photo.path.startsWith('file://')
        ? photo.path
        : `file://${photo.path}`;
      setLastCapturedPath(imageUri);

      const scanResult = await scanCardImage(imageScanOptions(imageUri));
      setResult(scanResult);
    } catch (error) {
      Alert.alert('Capture or scan failed', String(error));
    } finally {
      setLoading(false);
    }
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>vision-camera-payment-card-scanner</Text>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Parser smoke test</Text>
        <Text>PAN: {samplePan}</Text>
        <Text>Last4: {sampleLast4 ?? 'unavailable'}</Text>
        <Text>Brand: {sampleBrand}</Text>
        <Text>Luhn valid: {sampleIsValid ? 'yes' : 'no'}</Text>
        <Text>
          Expiry:{' '}
          {sampleExpiry
            ? `${sampleExpiry.expiryMonth}/${sampleExpiry.expiryYear}`
            : 'unavailable'}
        </Text>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Camera scanning demo</Text>
        <Text style={styles.helper}>{helperText}</Text>
        <Text style={styles.label}>Native support</Text>
        <Text style={styles.value}>{supportValue}</Text>
        <Text style={styles.label}>Camera permission</Text>
        <Text style={styles.value}>{cameraPermission}</Text>
        <View style={styles.buttonRow}>
          <Button title="Check support" onPress={handleCheckSupport} />
        </View>
        {cameraPermission !== 'granted' ? (
          <View style={styles.buttonRow}>
            <Button
              title="Grant camera access"
              onPress={handleRequestCameraPermission}
            />
          </View>
        ) : null}
        {device && cameraPermission === 'granted' ? (
          <View style={styles.cameraFrame}>
            <Camera
              ref={cameraRef}
              device={device}
              isActive={cameraPermission === 'granted'}
              photo={true}
              frameProcessor={frameProcessor}
              style={StyleSheet.absoluteFill}
            />
          </View>
        ) : (
          <View style={styles.cameraFallback}>
            <Text style={styles.helper}>
              {device
                ? 'Grant permission to show the camera preview.'
                : 'No compatible back camera was detected.'}
            </Text>
          </View>
        )}
        <Text style={styles.label}>Live frame result</Text>
        <Text style={styles.result}>{formatResult(liveResult)}</Text>
        <View style={styles.buttonRow}>
          <Button
            title={loading ? 'Scanning…' : 'Capture card image for OCR'}
            onPress={handleCaptureAndScan}
            disabled={loading || cameraPermission !== 'granted' || !device}
          />
        </View>
        {loading ? <ActivityIndicator style={styles.loader} /> : null}
        <Text style={styles.label}>Last captured image</Text>
        <Text style={styles.result}>
          {lastCapturedPath ?? 'No image captured yet.'}
        </Text>
        <Text style={styles.label}>Still-image scan result</Text>
        <Text style={styles.result}>{formatResult(result)}</Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 20,
    paddingVertical: 32,
    gap: 16,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    textAlign: 'center',
  },
  section: {
    gap: 8,
    borderWidth: 1,
    borderColor: '#d0d7de',
    borderRadius: 12,
    padding: 16,
    backgroundColor: '#ffffff',
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
  },
  helper: {
    color: '#57606a',
  },
  label: {
    fontSize: 13,
    fontWeight: '600',
    marginTop: 4,
  },
  value: {
    fontFamily: Platform.select({ ios: 'Menlo', default: 'monospace' }),
  },
  buttonRow: {
    alignItems: 'flex-start',
  },
  cameraFrame: {
    overflow: 'hidden',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#d0d7de',
    height: 280,
    backgroundColor: '#000000',
  },
  cameraFallback: {
    minHeight: 120,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#d0d7de',
    padding: 12,
    justifyContent: 'center',
    backgroundColor: '#f6f8fa',
  },
  loader: {
    marginTop: 8,
  },
  result: {
    fontFamily: Platform.select({ ios: 'Menlo', default: 'monospace' }),
  },
});
