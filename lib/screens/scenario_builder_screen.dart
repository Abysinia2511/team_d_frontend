import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../state/scenario_provider.dart';
import '../shared/models/node_block.dart';
import 'package:http/http.dart' as http;

class ScenarioBuilderScreen extends ConsumerStatefulWidget {
  final String initialDomain;

  const ScenarioBuilderScreen({super.key, required this.initialDomain});

  @override
  ConsumerState<ScenarioBuilderScreen> createState() =>
      _ScenarioBuilderScreenState();
}

class _ScenarioBuilderScreenState extends ConsumerState<ScenarioBuilderScreen> {
  late String selectedDomain;
  List<NodeBlock> _generatedBlocks = []; // Store parsed AI blocks

  final List<String> nodeTypes = [
    'Start',
    'Lesson',
    'Quiz',
    'Decision',
    'Checkpoint',
    'End',
    'Interactive',
    'Event',
  ];

  final List<String> domains = [
    'Oil & Gas',
    'IT Project Management',
    'Healthcare',
    'Military',
    'Government',
    'Finance',
  ];

  /**
 * Domain-specific event templates
 * These can be used to generate random events based on the selected domain.
 */
  ///
  final Map<String, List<Map<String, String>>> domainEventTemplates = {
    'Healthcare': [
      {'type': 'Pop Quiz', 'content': 'What is the normal blood pressure?'},
      {'type': 'Surprise Task', 'content': 'Sterilize a new tool set.'},
    ],
    'Military': [
      {'type': 'Pop Quiz', 'content': 'How do you identify friendly fire?'},
      {
        'type': 'Surprise Task',
        'content': 'Clean your weapon in under 2 minutes.',
      },
    ],
    'IT Project Management': [
      {
        'type': 'Surprise Task',
        'content': 'Your stakeholder changed a requirement. What do you do?',
      },
      {'type': 'Pop Quiz', 'content': 'What does MVP stand for?'},
    ],
    // Add more domain events...
  };

  Map<String, String> getRandomEventForDomain(String domain) {
    final events = domainEventTemplates[domain];
    if (events == null || events.isEmpty) {
      return {
        'type': 'Generic Event',
        'content': 'A random event has occurred.',
      };
    }
    return events[Random().nextInt(events.length)];
  }

  @override
  void initState() {
    super.initState();
    selectedDomain = widget.initialDomain;
  }

  void _addNode(String type, Offset offset) {
    if (type == 'Event') {
      final randomEvent = getRandomEventForDomain(selectedDomain);
      ref
          .read(scenarioProvider.notifier)
          .addNode(
            NodeBlock(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              offset: offset,
              type: type,
              title: randomEvent['type']!,
              eventType: randomEvent['type'],
              eventContent: randomEvent['content'],
            ),
          );
    } else {
      ref
          .read(scenarioProvider.notifier)
          .addNode(
            NodeBlock(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              offset: offset,
              type: type,
              title: type,
            ),
          );
    }
  }

  void _editNode(NodeBlock block) {
    showDialog(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final currentBlock = ref
              .watch(scenarioProvider)
              .firstWhere((b) => b.id == block.id);

          return AlertDialog(
            title: Text('Edit ${currentBlock.type}'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width >= 800 ? 768 : null,
              height: MediaQuery.of(context).size.width >= 800 ? 512 : null,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: currentBlock.title,
                      onChanged: (val) => ref
                          .read(scenarioProvider.notifier)
                          .updateNode(currentBlock.copyWith(title: val)),
                      decoration: const InputDecoration(
                        labelText: 'Node Title',
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (currentBlock.type == 'Start') ...[
                      TextFormField(
                        initialValue: currentBlock.welcomeMessage ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(welcomeMessage: val),
                            ),
                        decoration: const InputDecoration(
                          labelText: 'Welcome Message',
                        ),
                      ),
                    ],
                    if (currentBlock.type == 'Lesson') ...[
                      DropdownButtonFormField<String>(
                        value: currentBlock.lessonType ?? 'Text',
                        items: ['Text', 'Image', 'Video']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(currentBlock.copyWith(lessonType: val)),
                        decoration: const InputDecoration(
                          labelText: 'Lesson Type',
                        ),
                      ),

                      if (currentBlock.lessonType == 'Image' ||
                          currentBlock.lessonType == 'Video') ...[
                        ElevatedButton(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: currentBlock.lessonType == 'Image'
                                  ? FileType.image
                                  : FileType.video,
                            );
                            if (result != null &&
                                result.files.single.path != null) {
                              ref
                                  .read(scenarioProvider.notifier)
                                  .updateNode(
                                    currentBlock.copyWith(
                                      lessonContent: result.files.single.path!,
                                    ),
                                  );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Selected: ${result.files.single.name}",
                                  ),
                                ),
                              );
                            }
                          },
                          child: Text(
                            currentBlock.lessonType == 'Image'
                                ? 'Pick Image'
                                : 'Pick Video',
                          ),
                        ),
                        if (currentBlock.lessonContent != null &&
                            currentBlock.lessonContent!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              "Selected: ${currentBlock.lessonContent}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                      TextFormField(
                        initialValue: currentBlock.lessonContent ?? '',
                        maxLines: 8,
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(lessonContent: val),
                            ),
                        decoration: const InputDecoration(
                          labelText: 'Lesson Content',
                        ),
                      ),

                      TextFormField(
                        initialValue: currentBlock.estimatedTime ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(estimatedTime: val),
                            ),
                        decoration: const InputDecoration(
                          labelText: 'Estimated Time (minutes)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    if (currentBlock.type == 'Quiz') ...[
                      TextFormField(
                        initialValue: currentBlock.quizTitle ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(currentBlock.copyWith(quizTitle: val)),
                        decoration: const InputDecoration(
                          labelText: 'Quiz Title',
                        ),
                      ),
                      TextFormField(
                        initialValue: currentBlock.passingScore ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(passingScore: val),
                            ),
                        decoration: const InputDecoration(
                          labelText: 'Passing Score (%)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        initialValue: currentBlock.timeLimit ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(currentBlock.copyWith(timeLimit: val)),
                        decoration: const InputDecoration(
                          labelText: 'Time Limit (minutes)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          String questionText = "";
                          String correctAnswer = "";
                          final result = await showDialog<Map<String, String>>(
                            context: context,
                            builder: (ctx) {
                              return AlertDialog(
                                title: const Text("Add Question"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextFormField(
                                      autofocus: true,
                                      decoration: const InputDecoration(
                                        labelText: "Question",
                                      ),
                                      onChanged: (val) => questionText = val,
                                    ),
                                    TextFormField(
                                      decoration: const InputDecoration(
                                        labelText: "Correct Answer",
                                      ),
                                      onChanged: (val) => correctAnswer = val,
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx, {
                                        "question": questionText,
                                        "answer": correctAnswer,
                                      });
                                    },
                                    child: const Text("Save"),
                                  ),
                                ],
                              );
                            },
                          );

                          if (result != null &&
                              result["question"]!.trim().isNotEmpty) {
                            final updatedQuestions = [
                              ...?currentBlock.questions,
                              result,
                            ];
                            ref
                                .read(scenarioProvider.notifier)
                                .updateNode(
                                  currentBlock.copyWith(
                                    questions: updatedQuestions,
                                  ),
                                );
                          }
                        },
                        child: const Text('Add Question'),
                      ),
                      if (currentBlock.questions != null &&
                          currentBlock.questions!.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            const Text(
                              "Questions:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            ...currentBlock.questions!.asMap().entries.map(
                              (entry) => ListTile(
                                dense: true,
                                title: Text(
                                  "${entry.key + 1}. ${entry.value['question']} (Answer: ${entry.value['answer']})",
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],

                    if (currentBlock.type == 'Decision') ...[
                      TextFormField(
                        initialValue: currentBlock.conditionExpression ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(conditionExpression: val),
                            ),
                        decoration: const InputDecoration(
                          labelText: 'Condition Expression',
                        ),
                      ),
                      TextFormField(
                        initialValue: currentBlock.truePathLabel ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(truePathLabel: val),
                            ),
                        decoration: const InputDecoration(
                          labelText: 'True Path Label',
                        ),
                      ),
                      TextFormField(
                        initialValue: currentBlock.falsePathLabel ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(falsePathLabel: val),
                            ),
                        decoration: const InputDecoration(
                          labelText: 'False Path Label',
                        ),
                      ),
                    ],

                    if (currentBlock.type == 'Checkpoint') ...[
                      TextFormField(
                        initialValue: currentBlock.checkpointTitle ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(checkpointTitle: val),
                            ),
                        decoration: const InputDecoration(
                          labelText: 'Checkpoint Title',
                        ),
                      ),
                      TextFormField(
                        initialValue: currentBlock.checkpointNote ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(checkpointNote: val),
                            ),
                        decoration: const InputDecoration(
                          labelText: 'Checkpoint Note',
                        ),
                      ),
                      TextFormField(
                        initialValue: currentBlock.estimatedTime ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(estimatedTime: val),
                            ),
                        decoration: const InputDecoration(
                          labelText: 'Estimated Time (minutes)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],

                    /**
                     * Event nodes allow for dynamic interactions
                     * like pop quizzes or surprise tasks.
                     */
                    if (currentBlock.type == 'Event') ...[
                      TextFormField(
                        initialValue: currentBlock.eventType ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(currentBlock.copyWith(eventType: val)),
                        decoration: const InputDecoration(
                          labelText:
                              'Event Type (e.g., Pop Quiz, Surprise Task)',
                        ),
                      ),
                      TextFormField(
                        initialValue: currentBlock.triggerCondition ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(triggerCondition: val),
                            ),
                        decoration: const InputDecoration(
                          labelText:
                              'Trigger Condition (e.g., Random, After Lesson)',
                        ),
                      ),
                      TextFormField(
                        initialValue: currentBlock.eventContent ?? '',
                        maxLines: 6,
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(eventContent: val),
                            ),
                        decoration: const InputDecoration(
                          labelText:
                              'Event Content (e.g., quiz question or info)',
                        ),
                      ),
                      TextFormField(
                        initialValue: currentBlock.eventAnswer ?? '',
                        onChanged: (val) => ref
                            .read(scenarioProvider.notifier)
                            .updateNode(
                              currentBlock.copyWith(eventAnswer: val),
                            ),
                        decoration: const InputDecoration(
                          labelText: 'Correct Answer (if applicable)',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, bool isMobile) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.indigo),
            child: Text(
              'Scenario Designer',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButton<String>(
              value: selectedDomain,
              isExpanded: true,
              items: domains
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => selectedDomain = value);
              },
            ),
          ),
          ExpansionTile(
            title: const Text('Node Palette'),
            children: nodeTypes.map((type) {
              return isMobile
                  ? ListTile(
                      leading: const Icon(Icons.touch_app),
                      title: Text(type),
                      onTap: () {
                        _addNode(type, const Offset(100, 100));
                        Navigator.pop(context);
                      },
                    )
                  : Draggable<String>(
                      data: type,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Chip(label: Text(type)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.drag_indicator),
                        title: Text(type),
                      ),
                    );
            }).toList(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Properties Inspector'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Properties Inspector feature')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenario = ref.read(scenarioProvider.notifier);
    final blocks = ref.watch(scenarioProvider);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: isMobile,
        leading: isMobile
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/dashboard'),
              ),
        title: Text('Scenario Designer - $selectedDomain'),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: scenario.undo),
          IconButton(icon: const Icon(Icons.redo), onPressed: scenario.redo),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Scenario',
            onPressed: () {
              ref.read(scenarioProvider.notifier).clear();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Canvas cleared')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: () async {
              final blocks = ref.read(
                scenarioProvider,
              ); // 👈 Get current scenario blocks
              final dio = Dio();

              try {
                final response = await dio.post(
                  'http://localhost:8080/api/v1/scenario/save', // ✅ Change to your actual endpoint
                  data: blocks.map((block) => block.toJson()).toList(),
                  options: Options(
                    headers: {'Content-Type': 'application/json'},
                  ),
                );

                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Scenario saved successfully'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save: ${response.statusCode}'),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Save error: $e')));
              }
            },
          ),

          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Generate Scenario',
            onPressed: () async {
              final prompt = await showDialog<String>(
                context: context,
                builder: (context) {
                  String userInput = '';
                  return AlertDialog(
                    title: const Text('AI Generate Prompt'),
                    content: TextFormField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Enter prompt',
                        hintText: 'e.g., Wound cleaning scenario',
                      ),
                      onChanged: (value) => userInput = value,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, userInput),
                        child: const Text('Generate'),
                      ),
                    ],
                  );
                },
              );

              if (prompt != null && prompt.trim().isNotEmpty) {
                try {
                  final dio = Dio();
                  final response = await dio.post(
                    'http://localhost:8080/api/v1/scenario/generate',
                    data: {'prompt': prompt},
                    options: Options(
                      headers: {'Content-Type': 'application/json'},
                    ),
                  );

                  if (response.statusCode == 200) {
                    print('🔵 Raw DeepSeek response: ${response.data}');
                    final List<dynamic> data = response.data;
                    setState(() {
                      _generatedBlocks = data
                          .map((json) => NodeBlock.fromJson(json))
                          .toList();
                    });
                    final blocks = data
                        .map((json) => NodeBlock.fromJson(json))
                        .toList();

                    print('🟢 Parsed NodeBlocks: $blocks');

                    ref.read(scenarioProvider.notifier).replace(blocks);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Scenario generated from prompt!'),
                      ),
                    );
                  } else {
                    print('🔴 Server error: ${response.statusCode}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${response.statusCode}')),
                    );
                  }
                } catch (e) {
                  print('❌ Exception: $e');
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Request failed: $e')));
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Load Scenario',
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['json'],
              );
              if (result != null && result.files.single.bytes != null) {
                try {
                  final jsonString = String.fromCharCodes(
                    result.files.single.bytes!,
                  );
                  final parsedJson = jsonDecode(jsonString);

                  if (parsedJson is! List) {
                    throw Exception("Expected JSON array at the top level");
                  }

                  final loadedBlocks = parsedJson
                      .map(
                        (e) => NodeBlock(
                          id: e['id'],
                          offset: Offset(
                            (e['offset']['dx'] as num).toDouble(),
                            (e['offset']['dy'] as num).toDouble(),
                          ),
                          title: e['title'],
                          type: e['type'],
                          description: e['description'],
                          welcomeMessage: e['welcomeMessage'],
                          lessonType: e['lessonType'],
                          lessonContent: e['lessonContent'],
                          estimatedTime: e['estimatedTime'],
                          quizTitle: e['quizTitle'],
                          passingScore: e['passingScore'],
                          timeLimit: e['timeLimit'],
                          conditionExpression: e['conditionExpression'],
                          truePathLabel: e['truePathLabel'],
                          falsePathLabel: e['falsePathLabel'],
                          checkpointTitle: e['checkpointTitle'],
                          checkpointNote: e['checkpointNote'],
                          questions: (e['questions'] as List?)
                              ?.map((q) => (q as Map).cast<String, String>())
                              .toList(),
                        ),
                      )
                      .toList();

                  ref.read(scenarioProvider.notifier).replace(loadedBlocks);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Scenario loaded successfully!'),
                    ),
                  );
                } catch (err) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error loading: $err")),
                  );
                }
              }
            },
          ),
        ],
      ),
      drawer: isMobile ? _buildSidebar(context, isMobile) : null,
      body: Row(
        children: [
          if (!isMobile)
            SizedBox(width: 260, child: _buildSidebar(context, isMobile)),
          Expanded(
            flex: 2,
            child: DragTarget<String>(
              onAcceptWithDetails: (details) {
                final renderBox = context.findRenderObject() as RenderBox;
                final offset = renderBox.globalToLocal(details.offset);
                _addNode(details.data, offset);
              },
              builder: (context, candidate, rejected) {
                return Stack(
                  children: [
                    CustomPaint(
                      painter: _ConnectionPainter(blocks),
                      child: Container(),
                    ),
                    ...blocks.map(
                      (block) => Positioned(
                        left: block.offset.dx,
                        top: block.offset.dy,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            scenario.moveNode(
                              block,
                              block.offset + details.delta,
                            );
                          },
                          onTap: () => _editNode(block),
                          child: Card(
                            color: Colors.indigo,
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    block.type,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    block.title,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // 🟩 ListView of AI-generated NodeBlocks
          Expanded(
            flex: 1,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _generatedBlocks.length,
              itemBuilder: (context, index) {
                final block = _generatedBlocks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ID: ${block.id}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: block.title,
                          onChanged: (val) {
                            setState(() {
                              _generatedBlocks[index] = block.copyWith(
                                title: val,
                              );
                            });
                          },
                          decoration: const InputDecoration(labelText: 'Title'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Type: ${block.type}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionPainter extends CustomPainter {
  final List<NodeBlock> blocks;
  _ConnectionPainter(this.blocks);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black38
      ..strokeWidth = 2;
    for (int i = 0; i < blocks.length - 1; i++) {
      final from = blocks[i].offset + const Offset(50, 20);
      final to = blocks[i + 1].offset + const Offset(50, 20);
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) => true;
}
