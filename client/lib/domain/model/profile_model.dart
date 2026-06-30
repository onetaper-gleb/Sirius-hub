import 'package:client/domain/model/model.dart';

class ProfileModel {
  final RegistrationProfileData registrationProfileData;
  final UserModel userModel;
  const ProfileModel({
    required this.registrationProfileData,
    required this.userModel,
  });
}
