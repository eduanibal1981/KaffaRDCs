import 'primitives.dart';

class RenalCenter {
  const RenalCenter({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    this.shortNameEn,
    this.shortNameAr,
    this.wilayatEn,
    this.wilayatAr,
    this.governorateEn,
    this.governorateAr,
    this.contactEmail,
    this.contactPhone,
    this.registeredPatients,
    this.dialysisBeds,
    this.logoPath,
    this.accentColor,
    required this.isActive,
  });

  final String id;
  final String code;
  final String nameEn;
  final String nameAr;
  final String? shortNameEn;
  final String? shortNameAr;
  final String? wilayatEn;
  final String? wilayatAr;
  final String? governorateEn;
  final String? governorateAr;
  final String? contactEmail;
  final String? contactPhone;
  final int? registeredPatients;
  final int? dialysisBeds;
  final String? logoPath;
  final String? accentColor;
  final bool isActive;

  factory RenalCenter.fromMap(Map<String, dynamic> m) => RenalCenter(
        id: asString(m['id']),
        code: asString(m['code']),
        nameEn: asString(m['name_en']),
        nameAr: asString(m['name_ar']),
        shortNameEn: asStringOrNull(m['short_name_en']),
        shortNameAr: asStringOrNull(m['short_name_ar']),
        wilayatEn: asStringOrNull(m['wilayat_en']),
        wilayatAr: asStringOrNull(m['wilayat_ar']),
        governorateEn: asStringOrNull(m['governorate_en']),
        governorateAr: asStringOrNull(m['governorate_ar']),
        contactEmail: asStringOrNull(m['contact_email']),
        contactPhone: asStringOrNull(m['contact_phone']),
        registeredPatients: asInt(m['registered_patients']),
        dialysisBeds: asInt(m['dialysis_beds']),
        logoPath: asStringOrNull(m['logo_path']),
        accentColor: asStringOrNull(m['accent_color']),
        isActive: asBool(m['is_active'], fallback: true),
      );

  Map<String, dynamic> toUpdateMap() => {
        'name_en': nameEn,
        'name_ar': nameAr,
        'short_name_en': shortNameEn,
        'short_name_ar': shortNameAr,
        'wilayat_en': wilayatEn,
        'wilayat_ar': wilayatAr,
        'contact_email': contactEmail,
        'contact_phone': contactPhone,
        'registered_patients': registeredPatients,
        'dialysis_beds': dialysisBeds,
      };
}

class UserProfile {
  const UserProfile({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.jobTitleEn,
    this.jobTitleAr,
    this.avatarPath,
    required this.preferredLocale,
    required this.isActive,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? jobTitleEn;
  final String? jobTitleAr;
  final String? avatarPath;
  final String preferredLocale;
  final bool isActive;

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty)
          ? fullName!
          : (email ?? '').split('@').first;

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id: asString(m['id']),
        fullName: asStringOrNull(m['full_name']),
        email: asStringOrNull(m['email']),
        phone: asStringOrNull(m['phone']),
        jobTitleEn: asStringOrNull(m['job_title_en']),
        jobTitleAr: asStringOrNull(m['job_title_ar']),
        avatarPath: asStringOrNull(m['avatar_path']),
        preferredLocale: asString(m['preferred_locale'], fallback: 'en'),
        isActive: asBool(m['is_active'], fallback: true),
      );
}

class RoleGrant {
  const RoleGrant({required this.role, this.centerId});

  final AppRole role;

  /// null means the grant applies to every centre.
  final String? centerId;

  factory RoleGrant.fromMap(Map<String, dynamic> m) => RoleGrant(
        role: AppRole.tryParse(asString(m['role'])) ?? AppRole.viewer,
        centerId: asStringOrNull(m['center_id']),
      );
}
