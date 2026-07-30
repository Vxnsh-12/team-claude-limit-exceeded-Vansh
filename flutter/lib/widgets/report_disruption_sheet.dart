import 'package:flutter/material.dart';
import '../i18n/app_translations.dart';

/// Report Disruption bottom sheet.  Provides:
///   • A "Take Photo" tile that simulates capturing an image (a real camera
///     call can be wired later with `image_picker`).
///   • A "Submit" button that stays disabled until a photo has been captured.
///
/// Returns `true` from `showModalBottomSheet` when the user submits so the
/// caller can persist the report + refetch the route.
class ReportDisruptionSheet extends StatefulWidget {
  const ReportDisruptionSheet({super.key, required this.language});

  final String language;

  @override
  State<ReportDisruptionSheet> createState() => _ReportDisruptionSheetState();
}

class _ReportDisruptionSheetState extends State<ReportDisruptionSheet> {
  bool _photoTaken = false;

  void _simulateTakePhoto() {
    setState(() => _photoTaken = true);
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.t(widget.language, key);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFDC2626).withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('report_disruption'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1F2A44),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              t('report_hint'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF4A5468),
              ),
            ),
            const SizedBox(height: 20),

            // Take photo tile
            InkWell(
              onTap: _simulateTakePhoto,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _photoTaken
                      ? const Color(0xFF16A34A).withOpacity(0.08)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _photoTaken
                        ? const Color(0xFF16A34A).withOpacity(0.5)
                        : Colors.black.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _photoTaken
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF1F2A44),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _photoTaken
                            ? Icons.check_circle_rounded
                            : Icons.photo_camera_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('take_photo'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2A44),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _photoTaken
                                ? t('photo_captured')
                                : 'JPG · PNG · Max 20 MB',
                            style: TextStyle(
                              fontSize: 11,
                              color: _photoTaken
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF6B7280),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _photoTaken
                          ? Icons.refresh_rounded
                          : Icons.arrow_forward_rounded,
                      color: const Color(0xFF6B7280),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Submit / cancel row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side:
                            const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                        foregroundColor: const Color(0xFF1F2A44),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(t('cancel'),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFFDC2626).withOpacity(0.35),
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                      onPressed: _photoTaken
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(t('submit'),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
