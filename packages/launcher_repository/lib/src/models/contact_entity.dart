// packages/launcher_repository/lib/src/models/contact_entity.dart
import 'package:equatable/equatable.dart';

class ContactEntity extends Equatable {
  const ContactEntity({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.relationship,
    this.isEmergency = false,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final String? relationship;
  final bool isEmergency;

  @override
  List<Object?> get props => [id, name, phoneNumber, relationship, isEmergency];
}