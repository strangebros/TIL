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