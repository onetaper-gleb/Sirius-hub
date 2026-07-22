import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/bloc/news/news_bloc.dart';
import '../../domain/bloc/news/news_event.dart';
import '../../domain/bloc/news/news_state.dart';
import '../../domain/model/model.dart';

class CreateNewsScreen extends StatefulWidget {
  const CreateNewsScreen({super.key});

  @override
  State<CreateNewsScreen> createState() => _CreateNewsScreenState();
}

class _CreateNewsScreenState extends State<CreateNewsScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  bool _hasEvent = false;
  bool _hasTopic = false;
  bool _anon = false;
  bool _isRegOpen = false;
  int? maxPartic;
  EventStatus? _eventStatus;

  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _locationController;
  late TextEditingController _maxParticController;
  late TextEditingController _eventStartController;
  late TextEditingController _eventEndController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _locationController = TextEditingController();
    _maxParticController = TextEditingController();
    _eventStartController = TextEditingController();
    _eventEndController = TextEditingController();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveNews() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните заголовок и текст')),
      );
      return;
    }

    if (_hasEvent) {
      if (_eventStartController.text.trim().isEmpty ||
          _eventEndController.text.trim().isEmpty ||
          _eventStatus == null ||
          _locationController.text.trim().isEmpty ||
          _maxParticController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заполните все поля события')),
        );
        return;
      }

      final maxPartic = int.tryParse(_maxParticController.text.trim());
      if (maxPartic == null || maxPartic < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Макс. кол-во участников должно быть больше 0'),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    context.read<NewsBloc>().add(
      CreateNews(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        imageFile: _selectedImage,
        hasEvent: _hasEvent,
        hasTopic: _hasTopic,
        anon: _anon,
        eventStatus: _hasEvent ? _eventStatus : null,
        eventStart: _hasEvent ? _eventStartController.text.trim() : null,
        eventEnd: _hasEvent ? _eventEndController.text.trim() : null,
        location: _hasEvent ? _locationController.text.trim() : null,
        maxParticipants: _hasEvent ? maxPartic : null,
        isRegOpen: _hasEvent ? _isRegOpen : false,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    _maxParticController.dispose();
    _eventStartController.dispose();
    _eventEndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание новости'),
        leading: BackButton(),
      ),
      body: BlocListener<NewsBloc, NewsState>(
        listener: (context, state) {
          if (state is NewsCreateSuccess) {
            Navigator.pop(context, true);
          } else if (state is NewsError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
            setState(() => _isLoading = false);
          }
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 48,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Загрузить фото',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _titleController,
                    maxLines: 1,
                    maxLength: 100,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    decoration: const InputDecoration(
                      labelText: 'Заголовок',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    maxLines: 10,
                    maxLength: 859,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    decoration: const InputDecoration(
                      labelText: 'Текст новости',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text("Добавить событие"),
                    subtitle: const Text("Дата, место, регистрация"),
                    value: _hasEvent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() {
                        _hasEvent = value ?? false;
                      });
                    },
                  ),
                  if (_hasEvent) _buildEventMenu(),

                  CheckboxListTile(
                    title: const Text("Добавить обсуждение"),
                    subtitle: const Text("Комментарии к новости"),
                    value: _hasTopic,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() {
                        _hasTopic = value ?? false;
                      });
                    },
                  ),
                  if (_hasTopic) _buildTopicMenu(),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveNews,
                      child: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicMenu() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Анонимное обсуждение"),
          subtitle: const Text("Имена пользователей скрыты"),
          value: _anon,
          onChanged: (value) {
            setState(() {
              _anon = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildEventMenu() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _eventStartController,
              decoration: const InputDecoration(
                labelText: "Дата начала",
                hintText: "дд.мм.гггг",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _eventEndController,
              decoration: const InputDecoration(
                labelText: "Дата окончания",
                hintText: "дд.мм.гггг",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _locationController,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: "Место проведения",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _maxParticController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: "Макс. кол-во участников",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<EventStatus>(
              decoration: const InputDecoration(
                labelText: "Статус события",
                border: OutlineInputBorder(),
              ),
              value: _eventStatus,
              items: [EventStatus.draft, EventStatus.published]
                  .map(
                    (status) => DropdownMenuItem<EventStatus>(
                        value: status, child: Text(status.label)),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _eventStatus = value;
                });
              },
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Открыть регистрацию на событие"),
              value: _isRegOpen,
              onChanged: (value) {
                setState(() {
                  _isRegOpen = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
