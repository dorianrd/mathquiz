// lib/screens/components/components.dart
import 'package:flutter/material.dart';

/// Ein benutzerdefinierter Button für die E-Mail-Anmeldung und Registrierung.
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontSize: 16),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
          color: textColor ?? Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}

/// Ein einfaches Ladeindikator-Widget, das überall in der App verwendet werden kann.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator();
  }
}

/// Eine benutzerdefinierte Fehlerbox, die von unten eingeblendet wird.
class ErrorBox extends StatefulWidget {
  final String message;
  final Duration duration;

  const ErrorBox({
    super.key,
    required this.message,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<ErrorBox> createState() => _ErrorBoxState();
}

class _ErrorBoxState extends State<ErrorBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    // Initialisieren des AnimationControllers
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Definieren der Animation, die die Box von unten nach oben bewegt
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Starten der Animation
    _controller.forward();

    // Automatisches Ausblenden der Box nach der angegebenen Dauer
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: Colors.grey[300], // Leichtes Grau
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: const [
            BoxShadow(
              blurRadius: 6.0,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.black54),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14, // Kleinere Schriftgröße
                  decoration: TextDecoration.none, // Keine Unterstreichung
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                _controller.reverse();
              },
              child: const Icon(Icons.close, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Utility-Klasse zur Anzeige der Fehlerbox
class ErrorNotifier {
  static void show(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 20, // Leichte Abhebung vom unteren Rand
        left: 20,
        right: 20,
        child: ErrorBox(
          message: message,
          duration: const Duration(seconds: 3),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Entfernen des Overlay nach der Dauer der ErrorBox
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }
}