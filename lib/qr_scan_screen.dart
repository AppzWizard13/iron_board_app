import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';



class QRScanScreen extends StatefulWidget {
  const QRScanScreen({Key? key}) : super(key: key);

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QRView(
        key: qrKey,
        overlay: QrScannerOverlayShape(borderColor: Colors.blue, borderRadius: 10, borderLength: 30, borderWidth: 10),
        onQRViewCreated: (ctrl) {
          controller = ctrl;
          ctrl.scannedDataStream.listen((scanData) {
            if (!scanned) {
              scanned = true;
              controller?.pauseCamera();
              Navigator.of(context).pop(scanData.code); // Return scanned QR data
            }
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
