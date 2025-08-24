## 개요
사이드 프로젝트의 기획 디자인 프론트 백엔드를 모두 혼자 만들어보고 싶은 욕심이 있어서,,
기존에 flutter 를 써서 프로젝트를 진행했었다.

당시 상태관리를 위해 provider 를 사용했는데, context 의존성 때문에 골치아픈적이 되게 많았다.

## provider 불편한 점
### case 1
```dart
// ❌ Provider - API 서비스 클래스에서 토큰 접근하려면...
class ApiService {
  Future<User> getUser() async {
    // 어? 여기서 AuthProvider의 토큰이 필요한데...
    // context가 없어서 접근 불가!
    
    // 결국 매번 파라미터로 받아야 함
  }
}

// 매번 이렇게 context를 끌고 다녀야 함
class UserScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return ElevatedButton(
      onPressed: () async {
        // context를 계속 전달전달전달...
        await ApiService().getUserWithToken(auth.token);
      },
    );
  }
}
```

### case 2
```dart
// ❌ Provider - 악명높은 "Don't use context after async gap" 에러 -> 진짜 많이 만났음
class MyScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final data = await fetchData();
        
        // 🚨 에러 발생 가능! 
        // async 작업 중에 화면이 dispose되면 context가 invalid
        Provider.of<DataProvider>(context, listen: false).setData(data);
        
        // 이것도 위험!
        Navigator.push(context, ...);
      },
    );
  }
}

// 매번 이렇게 체크해야 함
if (mounted) {  // StatefulWidget에서만 가능
  Provider.of<DataProvider>(context, listen: false).setData(data);
}
```

## RiverPod
riverPod 은 provider 제작자가 만들었으며, 기존의 단점들을 개선했다고 한다. 다만 provider 보다는 러닝 커브가 있다고 하여, 우선 간단한 사용법을 확인해보자.

### 기본 설정
main.dart 에서 루트 위젯을 아래와 같이 감싸주어야 한다.
```dart
// main.dart - ProviderScope로 감싸기
void main() {
  runApp(
    ProviderScope(  // 요걸 추가
      child: MyApp(),
    ),
  );
}
```

### cluade 가 정리해준 riverpod vs spring 개념 비교
| Riverpod | 백엔드 비유 | 설명 |
|----------|------------|------|
| **Provider** | Bean/Service | 의존성 주입될 객체 정의 |
| **ref** | DI Container | 의존성을 가져오는 참조 |
| **ProviderScope** | Application Context | 전체 DI 컨테이너 |
| **ConsumerWidget** | Controller | Provider를 사용하는 위젯 |

### provider 종류
```dart
// 1. Provider - 단순 값/서비스 (백엔드의 @Service)
final apiServiceProvider = Provider((ref) => ApiService());

// 2. StateProvider - 단순 상태 (백엔드의 전역 변수)
final counterProvider = StateProvider((ref) => 0);

// 3. StateNotifierProvider - 복잡한 상태 (백엔드의 @Service + @State)
final userProvider = StateNotifierProvider<UserNotifier, User>((ref) {
  return UserNotifier();
});

// 4. FutureProvider - 비동기 데이터 (백엔드의 @Async)
final fetchUserProvider = FutureProvider((ref) async {
  return await api.getUser();
});
```

### 예제코드

#### Step 1: Todo 모델 정의

```dart
// lib/models/todo.dart
class Todo {
  final String id;
  final String title;
  final bool completed;

  Todo({
    required this.id,
    required this.title,
    this.completed = false,
  });

  Todo copyWith({
    String? id,
    String? title,
    bool? completed,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }
}
```

#### Step 2: StateNotifier로 비즈니스 로직 구현

```dart
// lib/providers/todo_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo.dart';

// StateNotifier = 백엔드의 Service 클래스와 유사
class TodoNotifier extends StateNotifier<List<Todo>> {
  TodoNotifier() : super([]);  // 초기값은 빈 리스트

  // Todo 추가
  void addTodo(String title) {
    final newTodo = Todo(
      id: DateTime.now().toString(),
      title: title,
    );
    state = [...state, newTodo];  // 새 리스트로 교체 (불변성)
  }

  // Todo 토글
  void toggleTodo(String id) {
    state = state.map((todo) {
      if (todo.id == id) {
        return todo.copyWith(completed: !todo.completed);
      }
      return todo;
    }).toList();
  }

  // Todo 삭제
  void removeTodo(String id) {
    state = state.where((todo) => todo.id != id).toList();
  }
}

// Provider 정의 (백엔드의 @Bean 등록과 유사)
final todoProvider = StateNotifierProvider<TodoNotifier, List<Todo>>((ref) {
  return TodoNotifier();
});

// 완료된 Todo만 필터링하는 Provider
final completedTodosProvider = Provider((ref) {
  final todos = ref.watch(todoProvider);
  return todos.where((todo) => todo.completed).toList();
});

// 통계 Provider
final todoStatsProvider = Provider((ref) {
  final todos = ref.watch(todoProvider);
  return {
    'total': todos.length,
    'completed': todos.where((t) => t.completed).length,
    'remaining': todos.where((t) => !t.completed).length,
  };
});
```

#### Step 3: UI에서 사용하기

```dart
// lib/screens/todo_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/todo_provider.dart';

// ConsumerWidget = Provider를 사용할 수 있는 Widget
class TodoScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Provider 구독 (변경 시 자동 리빌드)
    final todos = ref.watch(todoProvider);
    final stats = ref.watch(todoStatsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Todo (${stats['remaining']} remaining)'),
      ),
      body: ListView.builder(
        itemCount: todos.length,
        itemBuilder: (context, index) {
          final todo = todos[index];
          return ListTile(
            leading: Checkbox(
              value: todo.completed,
              onChanged: (_) {
                // Provider의 메서드 호출
                ref.read(todoProvider.notifier).toggleTodo(todo.id);
              },
            ),
            title: Text(
              todo.title,
              style: todo.completed
                  ? TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                ref.read(todoProvider.notifier).removeTodo(todo.id);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Todo'),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(todoProvider.notifier).addTodo(controller.text);
              Navigator.pop(context);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }
}
```

#### Step 4: 비동기 데이터 처리 (API 연동)

```dart
// lib/providers/user_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// API 서비스 Provider
final apiServiceProvider = Provider((ref) => ApiService());

// 비동기 데이터 Provider
final userListProvider = FutureProvider<List<User>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.fetchUsers();
});

// UI에서 사용
class UserListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(userListProvider);
    
    return usersAsync.when(
      data: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (_, i) => ListTile(title: Text(users[i].name)),
      ),
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
```

#### Step 5: Provider 간 의존성 관리

```dart
// 백엔드의 DI처럼 Provider끼리 의존성 주입
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final userRepositoryProvider = Provider((ref) {
  // 다른 Provider 주입받기
  final auth = ref.watch(authProvider);
  return UserRepository(token: auth.token);
});

final currentUserProvider = FutureProvider((ref) async {
  // Repository Provider 사용
  final repository = ref.watch(userRepositoryProvider);
  return await repository.getCurrentUser();
});
```

### 핵심 패턴 정리

#### 1. **읽기 vs 구독**
```dart
// watch: 변경 감지 + 리빌드 (UI에서 주로 사용)
final todos = ref.watch(todoProvider);

// read: 일회성 읽기 (이벤트 핸들러에서 사용)
ref.read(todoProvider.notifier).addTodo('New');
```

#### 2. **Provider 조합**
```dart
// 여러 Provider를 조합해서 새로운 Provider 생성
final filteredTodosProvider = Provider((ref) {
  final todos = ref.watch(todoProvider);
  final filter = ref.watch(filterProvider);
  
  switch (filter) {
    case Filter.completed:
      return todos.where((t) => t.completed).toList();
    case Filter.active:
      return todos.where((t) => !t.completed).toList();
    default:
      return todos;
  }
});
```

#### 3. **상태 초기화**
```dart
// Provider 새로고침
ref.refresh(userListProvider);

// 상태 초기화
ref.invalidate(todoProvider);
```

### RiverPod의 장점 요약

#### ✅ Provider 대비 개선된 점

1. **Context 없이 어디서나 접근**
   ```dart
   // Provider - context 필요
   Provider.of<AuthProvider>(context).token
   
   // RiverPod - context 불필요
   ref.read(authProvider).token
   ```

2. **타입 안전성 강화**
   ```dart
   // Provider - 런타임 에러 가능
   Provider.of<String>(context)  // 잘못된 타입이면 에러
   
   // RiverPod - 컴파일 시점에 체크
   final value = ref.watch(stringProvider);  // 타입 자동 추론
   ```

3. **비동기 처리 간소화**
   ```dart
   // Provider - 복잡한 FutureBuilder 패턴
   FutureBuilder<User>(
     future: api.getUser(),
     builder: (context, snapshot) {
       if (snapshot.hasData) return Text(snapshot.data!.name);
       if (snapshot.hasError) return Text('Error');
       return CircularProgressIndicator();
     },
   )
   
   // RiverPod - when으로 간단하게
   userProvider.when(
     data: (user) => Text(user.name),
     error: (err, _) => Text('Error'),
     loading: () => CircularProgressIndicator(),
   )
   ```

4. **Provider 간 의존성 관리**
   ```dart
   // 백엔드 DI 컨테이너처럼 자동으로 의존성 해결
   final userProvider = FutureProvider((ref) async {
     final auth = ref.watch(authProvider);     // 자동 주입
     final api = ref.watch(apiProvider);       // 자동 주입
     return api.getUser(auth.token);
   });
   ```