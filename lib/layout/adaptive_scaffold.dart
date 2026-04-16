import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/chat/data/api_service.dart';
import '../features/chat/data/chat_storage_service.dart';
import '../features/chat/data/message_model.dart';
import '../features/chat/ui/widgets/chat_input_field.dart';
import '../features/chat/ui/widgets/chat_message_list.dart';
import '../screens/branch/branch_screen.dart';

class AdaptiveScaffold extends StatefulWidget {
  const AdaptiveScaffold({super.key});

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  int _selectedIndex = 0;

  bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _isInitializing = true;

  String _studentName = 'Guest';
  final String _appVersion = 'v1.1.0';

  final ApiService _apiService = ApiService();
  final ChatStorageService _chatStorageService = ChatStorageService();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatSession> _chatSessions = [];
  String? _activeChatId;

  static const List<_NavItem> _navItems = [
    _NavItem(
      label: 'Chat',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
    ),
    _NavItem(
      label: 'Books',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
    ),
    _NavItem(
      label: 'PYQs',
      icon: Icons.quiz_outlined,
      selectedIcon: Icons.quiz,
    ),
    _NavItem(
      label: 'Notes',
      icon: Icons.sticky_note_2_outlined,
      selectedIcon: Icons.sticky_note_2,
    ),
    _NavItem(
      label: 'History',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<ChatMessage> _buildStarterMessages() {
    return [
      ChatMessage(
        text:
            "Hello, I'm UniGuide.\nAsk me anything from your syllabus and I will help you revise faster.",
        isUser: false,
        source: 'UniGuide',
      ),
    ];
  }

  ChatSession _createFreshSession() {
    return ChatSession.create(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      messages: _buildStarterMessages(),
    );
  }

  ChatSession get _activeSession {
    if (_chatSessions.isEmpty) {
      final fallbackSession = _createFreshSession();
      _chatSessions = [fallbackSession];
      _activeChatId = fallbackSession.id;
      return fallbackSession;
    }

    return _chatSessions.firstWhere(
      (session) => session.id == _activeChatId,
      orElse: () {
        final fallbackSession = _chatSessions.first;
        _activeChatId = fallbackSession.id;
        return fallbackSession;
      },
    );
  }

  List<ChatMessage> get _messages => _activeSession.messages;

  ChatSession? _sessionForId(String id) {
    for (final session in _chatSessions) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  Future<void> _loadChats() async {
    final sessions = await _chatStorageService.loadSessions();
    final activeChatId = await _chatStorageService.loadActiveChatId();

    if (!mounted) return;

    setState(() {
      if (sessions.isEmpty) {
        final initialSession = _createFreshSession();
        _chatSessions = [initialSession];
        _activeChatId = initialSession.id;
      } else {
        _chatSessions = List<ChatSession>.from(sessions)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _activeChatId = _chatSessions.any((session) => session.id == activeChatId)
            ? activeChatId
            : _chatSessions.first.id;
      }
      _isInitializing = false;
    });

    await _persistChats();
  }

  Future<void> _persistChats() {
    return _chatStorageService.saveSessions(
      sessions: _chatSessions,
      activeChatId: _activeChatId,
    );
  }

  void _replaceSession(ChatSession updatedSession) {
    _chatSessions = _chatSessions
        .map((session) => session.id == updatedSession.id ? updatedSession : session)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  String _deriveTitle(List<ChatMessage> messages) {
    ChatMessage? firstUserMessage;
    for (final message in messages) {
      if (message.isUser) {
        firstUserMessage = message;
        break;
      }
    }

    final title = firstUserMessage?.text.trim() ?? '';
    if (title.isEmpty) {
      return 'New chat';
    }
    if (title.length <= 42) {
      return title;
    }
    return '${title.substring(0, 42).trimRight()}...';
  }

  Future<void> _saveMessagesForSession(
    String sessionId,
    List<ChatMessage> messages,
  ) async {
    final session = _sessionForId(sessionId);
    if (session == null) return;

    final updatedSession = session.copyWith(
      messages: messages,
      title: _deriveTitle(messages),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _replaceSession(updatedSession);
    });

    await _persistChats();
  }

  Future<void> _handleSend() async {
    if (_isInitializing || _isLoading) return;

    final userQuery = _chatController.text.trim();
    if (userQuery.isEmpty) return;
    final sessionId = _activeSession.id;

    final pendingMessages = [
      ..._messages,
      ChatMessage(text: userQuery, isUser: true),
    ];

    setState(() {
      _replaceSession(
        _activeSession.copyWith(
          messages: pendingMessages,
          title: _deriveTitle(pendingMessages),
          updatedAt: DateTime.now(),
        ),
      );
      _chatController.clear();
      _isLoading = true;
    });

    await _persistChats();
    _scrollToBottom();

    try {
      final response = await _apiService.getRAGResponse(userQuery);
      await _saveMessagesForSession(sessionId, [
        ...pendingMessages,
        ChatMessage(
          text: response,
          isUser: false,
          source: 'UniGuide',
        ),
      ]);
    } catch (_) {
      await _saveMessagesForSession(sessionId, [
        ...pendingMessages,
        ChatMessage(
          text:
              "I couldn't reach the backend. Please make sure the Flask server is running on port 5000.",
          isUser: false,
          source: 'System',
        ),
      ]);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _newChat() {
    final newSession = _createFreshSession();
    setState(() {
      _chatSessions = [newSession, ..._chatSessions];
      _activeChatId = newSession.id;
      _selectedIndex = 0;
      _chatController.clear();
    });
    _persistChats();
  }

  Future<void> _openChat(String chatId) async {
    setState(() {
      _activeChatId = chatId;
      _selectedIndex = 0;
    });
    await _persistChats();
    _scrollToBottom();
  }

  Future<void> _deleteChat(String chatId) async {
    if (_chatSessions.length == 1) {
      final replacement = _createFreshSession();
      setState(() {
        _chatSessions = [replacement];
        _activeChatId = replacement.id;
        _selectedIndex = 0;
      });
      await _persistChats();
      return;
    }

    setState(() {
      _chatSessions = _chatSessions.where((session) => session.id != chatId).toList();
      if (_activeChatId == chatId) {
        _activeChatId = _chatSessions.first.id;
      }
    });
    await _persistChats();
  }

  Future<void> _showRenameDialog(ChatSession session) async {
    final controller = TextEditingController(text: session.title);
    final updatedTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename chat'),
          content: TextField(
            controller: controller,
            autofocus: true,
            inputFormatters: [
              LengthLimitingTextInputFormatter(42),
            ],
            decoration: const InputDecoration(
              hintText: 'Enter chat title',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (updatedTitle == null || updatedTitle.isEmpty) return;

    setState(() {
      _replaceSession(
        session.copyWith(
          title: updatedTitle,
          updatedAt: DateTime.now(),
        ),
      );
    });
    await _persistChats();
  }

  String _formatSessionTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Updated just now';
    }
    if (difference.inHours < 1) {
      return 'Updated ${difference.inMinutes} min ago';
    }
    if (difference.inDays < 1) {
      return 'Updated ${difference.inHours} hr ago';
    }
    if (difference.inDays == 1) {
      return 'Updated yesterday';
    }
    return 'Updated ${time.day}/${time.month}/${time.year}';
  }

  void _toggleLogin() {
    setState(() {
      _isLoggedIn = !_isLoggedIn;
      _studentName = _isLoggedIn ? 'Arindam' : 'Guest';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 760;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isLoggedIn ? _studentName : 'UniGuide'),
            Text(
              _selectedIndex == 0
                  ? 'Study assistant for books, notes, and PYQs'
                  : 'Browse academic resources quickly',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _toggleLogin,
            child: Text(
              _isLoggedIn ? 'Logout' : 'Login',
              style: const TextStyle(color: Color(0xFF1B4D8C)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
            onPressed: _newChat,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF1B4D8C),
              child: Text(
                _studentName[0],
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      drawer: isLargeScreen ? null : _buildDrawer(),
      body: Row(
        children: [
          if (isLargeScreen) _buildSidebar(theme),
          Expanded(
            child: _isInitializing
                ? const Center(child: CircularProgressIndicator())
                : _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ThemeData theme) {
    return Container(
      width: 250,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFEAF0F7),
        border: Border(
          right: BorderSide(color: Color(0xFFD4DEE9)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workspace',
            style: theme.textTheme.labelLarge?.copyWith(
              color: const Color(0xFF526173),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'UniGuide',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF142033),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search your syllabus, open resources, and continue studying from one place.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5D6B7D),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: _navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final selected = index == _selectedIndex;

                return ListTile(
                  selected: selected,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  selectedTileColor: Colors.white,
                  leading: Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: const Color(0xFF1B4D8C),
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  onTap: () => setState(() => _selectedIndex = index),
                );
              },
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Version $_appVersion',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF526173),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Frontend refreshed with a cleaner chat workflow and copy-ready answers.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5D6B7D),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildChatUI();
      case 1:
        return const BranchScreen(category: 'books');
      case 2:
        return const BranchScreen(category: 'pyqs');
      case 3:
        return const BranchScreen(category: 'notes');
      case 4:
        return _buildHistoryView();
      default:
        return _buildChatUI();
    }
  }

  Widget _buildChatUI() {
    final theme = Theme.of(context);
    final showSuggestions = !_messages.any((message) => message.isUser);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF6F9FC),
            Color(0xFFEAF1F8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B4D8C),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activeSession.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF162132),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Continue this chat, start a new one, or reopen an older conversation from History.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF5D6B7D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ChatMessageList(
              messages: _messages,
              isLoading: _isLoading,
              scrollController: _scrollController,
            ),
          ),
          ChatInputField(
            controller: _chatController,
            onSend: _handleSend,
            isLoading: _isLoading,
            showSuggestions: showSuggestions,
            onSuggestionTap: (suggestion) {
              _chatController.value = TextEditingValue(
                text: suggestion,
                selection: TextSelection.collapsed(offset: suggestion.length),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    final theme = Theme.of(context);

    if (_chatSessions.isEmpty) {
      return const Center(
        child: Text('Your previous chats will appear here.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _chatSessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = _chatSessions[index];
        final isActive = session.id == _activeChatId;

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
            title: Text(
              session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF162132),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.previewText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D6B7D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatSessionTime(session.updatedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            leading: CircleAvatar(
              backgroundColor:
                  isActive ? const Color(0xFF1B4D8C) : const Color(0xFFE7F0FB),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: isActive ? Colors.white : const Color(0xFF1B4D8C),
              ),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'open') {
                  _openChat(session.id);
                } else if (value == 'rename') {
                  _showRenameDialog(session);
                } else if (value == 'delete') {
                  _deleteChat(session.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'open', child: Text('Open')),
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            onTap: () => _openChat(session.id),
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(child: Text(_studentName)),
          _drawerItem('Chat', 0),
          _drawerItem('Books', 1),
          _drawerItem('PYQs', 2),
          _drawerItem('Notes', 3),
          _drawerItem('History', 4),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text('App Version: $_appVersion'),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(String title, int index) {
    return ListTile(
      title: Text(title),
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context);
      },
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
