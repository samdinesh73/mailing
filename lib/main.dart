import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

const Color primaryColor = Color(0xFF0088CC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();  // 🔥 Required
  await dotenv.load(fileName: ".env");        // 🔥 Load .env first
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MailScreen(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ),
      ),
    );
  }
}

class MailHistory {
  final String timestamp;
  final String recipient;
  final String subject;

  MailHistory({
    required this.timestamp,
    required this.recipient,
    required this.subject,
  });
}

class MailScreen extends StatefulWidget {
  const MailScreen({super.key});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen>
    with SingleTickerProviderStateMixin {
  List<MailHistory> mailHistory = [];
  bool isLoading = false;
  TextEditingController? _recipientController;
  TextEditingController? _subjectController;
  TextEditingController? _manualTemplateController;
  String _selectedTemplate = 'bulk';
  late TabController _tabController;
  List<PlatformFile> attachedFiles = [];

  @override
  void initState() {
    super.initState();
    _recipientController = TextEditingController();
    _subjectController = TextEditingController();
    _manualTemplateController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _recipientController?.dispose();
    _subjectController?.dispose();
    _manualTemplateController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> sendMail() async {
    
    final apiKey = dotenv.env['MAIL_GUN_API_KEY'];
    const domain = "claripik.com";

    setState(() {
      isLoading = true;
    });

    if (_recipientController == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Controller not initialized")),
        );
      }
      setState(() => isLoading = false);
      return;
    }

    final String basicAuth =
        'Basic ' + base64Encode(utf8.encode('api:$apiKey'));

    try {
      final recipientEmail = (_recipientController?.text.trim().isNotEmpty ??
              false)
          ? _recipientController!.text.trim()
          : 'bulk@claripik.com';

      final subject = (_subjectController?.text.trim().isNotEmpty ?? false)
          ? _subjectController!.text.trim()
          : 'default subject';

      final template = _selectedTemplate == 'manual'
          ? (_manualTemplateController?.text.trim().isNotEmpty ?? false
              ? _manualTemplateController!.text.trim()
              : 'bulk')
          : _selectedTemplate;

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.mailgun.net/v3/$domain/messages'),
      );

      request.headers['Authorization'] = basicAuth;

      // Add form fields
      request.fields['from'] = 'Oliver <hello@$domain>';
      request.fields['to'] = recipientEmail;
      request.fields['subject'] = subject;
      request.fields['template'] = template;
      request.fields['h:X-Mailgun-Variables'] = jsonEncode({
        'subject': subject,
        'test': "test",
      });

      // Add attachments
      for (final file in attachedFiles) {
        if (file.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'attachment',
              file.bytes!,
              filename: file.name,
            ),
          );
        }
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final now = DateTime.now();
        final formattedTime =
            "${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.day}/${now.month}/${now.year}";

        setState(() {
          mailHistory.add(
            MailHistory(
              timestamp: formattedTime,
              recipient: recipientEmail,
              subject: subject,
            ),
          );
          isLoading = false;
          attachedFiles.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✓ Mail Sent Successfully"),
              backgroundColor: Color(0xFF0088CC),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          isLoading = false;
        });

        final responseBody = await response.stream.bytesToString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed: $responseBody"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          attachedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error picking files: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      attachedFiles.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.mail,
                color: primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Seller Rocket",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              text: "Send Mail",
              icon: Icon(Icons.mail_outline),
            ),
            Tab(
              text: "History",
              icon: Icon(Icons.history),
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.white,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildSendTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSendTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Send Email",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Send professional emails via Mailgun",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 32),
            _buildInputLabel('Recipient Email'),
            const SizedBox(height: 10),
            _buildPremiumTextField(
              controller: _recipientController,
              placeholder: 'name@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            _buildInputLabel('Subject'),
            const SizedBox(height: 10),
            _buildPremiumTextField(
              controller: _subjectController,
              placeholder: 'Enter subject line',
              icon: Icons.subject,
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 24),
            _buildInputLabel('Template'),
            const SizedBox(height: 12),
            _buildTemplateSelector(),
            if (_selectedTemplate == 'manual') ...[
              const SizedBox(height: 24),
              _buildInputLabel('Custom Template Name'),
              const SizedBox(height: 10),
              _buildPremiumTextField(
                controller: _manualTemplateController,
                placeholder: 'Enter template name',
                icon: Icons.description_outlined,
                keyboardType: TextInputType.text,
              ),
            ],
            const SizedBox(height: 24),
            _buildInputLabel('Attachments'),
            const SizedBox(height: 12),
            _buildAttachmentSection(),
            const SizedBox(height: 40),
            _buildSendButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF333333),
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController? controller,
    required String placeholder,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller ?? TextEditingController(),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(
            color: Color(0xFFB0B0B0),
            fontSize: 14,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          prefixIcon: Icon(
            icon,
            color: primaryColor,
            size: 20,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTemplateSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTemplateButton('TEST', 'TEST'),
          _buildTemplateButton('bulk', 'Bulk'),
          _buildTemplateButton('manual', 'Manual'),
        ],
      ),
    );
  }

  Widget _buildTemplateButton(String value, String label) {
    final isSelected = _selectedTemplate == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTemplate = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF666666),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add attachment button
        GestureDetector(
          onTap: _pickFiles,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.attach_file,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Attachments',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (attachedFiles.isNotEmpty)
                  Text(
                    ' (${attachedFiles.length})',
                    style: TextStyle(
                      color: primaryColor.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
        // List of attached files
        if (attachedFiles.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...List.generate(
            attachedFiles.length,
            (index) {
              final file = attachedFiles[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.file_present,
                      color: primaryColor,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(file.size / 1024).toStringAsFixed(2)} KB',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeAttachment(index),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFFCC0000),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : sendMail,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          disabledBackgroundColor: primaryColor.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isLoading ? 2 : 4,
        ),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
                ),
              )
            : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
        label: Text(
          isLoading ? 'Sending...' : 'Send Mail',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return mailHistory.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.mail_outline,
                    color: primaryColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "No emails sent yet",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Your email history will appear here",
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mailHistory.length,
            itemBuilder: (context, index) {
              final mail = mailHistory[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.mail,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mail.subject,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF333333),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mail.recipient,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF666666),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        mail.timestamp,
                        style: const TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
