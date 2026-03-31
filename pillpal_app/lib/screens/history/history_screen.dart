import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/firestore_service.dart';
import '../../models/log_entry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _exportPdf(
      BuildContext context, List<LogEntry> logs) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text('PillPal — Medicine History Report',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Medicine', 'Dosage', 'Time', 'Status'],
            data: logs
                .map((l) => [
                      l.date,
                      l.medicineName,
                      l.dosage,
                      l.scheduledTime,
                      l.status.toUpperCase(),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(6),
          ),
        ],
      ),
    );
    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'pillpal_history.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          StreamBuilder<List<LogEntry>>(
            stream: FirestoreService().getHistoryLogsStream(_uid),
            builder: (ctx, snap) {
              final logs = snap.data ?? [];
              return IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export PDF',
                onPressed: logs.isEmpty
                    ? null
                    : () => _exportPdf(context, logs),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<LogEntry>>(
        stream: FirestoreService().getHistoryLogsStream(_uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary));
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text('No history yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('Your medicine logs will appear here',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          // Group logs by date
          final Map<String, List<LogEntry>> grouped = {};
          for (final log in logs) {
            grouped.putIfAbsent(log.date, () => []).add(log);
          }
          final sortedDates = grouped.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDates.length,
            itemBuilder: (context, i) {
              final date = sortedDates[i];
              final dayLogs = grouped[date]!;
              final formattedDate = DateFormat('EEEE, dd MMM yyyy')
                  .format(DateTime.parse(date));

              final taken = dayLogs.where((l) => l.isTaken).length;
              final total = dayLogs.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text(formattedDate,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                                fontSize: 13)),
                        const Spacer(),
                        Text('$taken/$total taken',
                            style: TextStyle(
                                fontSize: 12,
                                color: taken == total
                                    ? AppTheme.taken
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  ...dayLogs.map((log) => _HistoryTile(log: log)),
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final LogEntry log;
  const _HistoryTile({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.medication_rounded, color: _color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.medicineName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                Text('${log.dosage}  ·  ${log.scheduledTime}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          StatusBadge(status: log.status),
        ],
      ),
    );
  }

  Color get _color {
    if (log.isTaken) return AppTheme.taken;
    if (log.isMissed) return AppTheme.missed;
    return AppTheme.pending;
  }
}
