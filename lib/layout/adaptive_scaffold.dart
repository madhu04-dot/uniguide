import 'package:flutter/material.dart';

import '../features/chat/data/api_service.dart';
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
  String _studentName = 'Guest';
  final String _appVersion = 'v1.1.0';

  final ApiService _apiService = ApiService();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          "Hello, I'm UniGuide.\nAsk me anything from your syllabus and I will help you revise faster.",
      isUser: false,
      source: 'UniGuide',
    ),
  ];

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
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final userQuery = _chatController.text.trim();
    if (userQuery.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: userQuery, isUser: true));
      _chatController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final response = await _apiService.getRAGResponse(userQuery);

      setState(() {
        _messages.add(
          ChatMessage(
            text: response,
            isUser: false,
            source: 'UniGuide',
          ),
        );
      });
    } catch (_) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                "I couldn't reach the backend. Please make sure the Flask server is running on port 5000.",
            isUser: false,
            source: 'System',
          ),
        );
      });
    }

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
    setState(() {
      _messages
        ..clear()
        ..add(
          ChatMessage(
            text:
                'New chat ready.\nShare a topic, paste a question, or ask for a concise summary.',
            isUser: false,
            source: 'UniGuide',
          ),
        );
    });
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
          Expanded(child: _buildMainContent()),
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
        return const Center(child: Text('History will appear here.'));
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
                            'Ask better questions, get cleaner answers',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF162132),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Paste text, ask for summaries, and copy responses instantly.',
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
