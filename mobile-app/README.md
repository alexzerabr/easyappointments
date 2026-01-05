# Easy!Appointments Mobile App

Aplicativo móvel nativo em Flutter para o sistema Easy!Appointments.

## Visão Geral

Este projeto implementa um aplicativo móvel que se integra com o backend Easy!Appointments, oferecendo:

- Visualização e gestão de agendamentos
- Calendário interativo
- Notificações push em tempo real
- Sincronização offline
- Suporte multilíngue (PT, EN, ES)

## Arquitetura

O projeto utiliza **Clean Architecture** com as seguintes camadas:

```
lib/
├── core/           # Configurações, constantes, utilities
├── data/           # Models, Repositories, Data Sources
├── domain/         # Entities, Use Cases, Interfaces
├── presentation/   # BLoC, Pages, Widgets
└── l10n/           # Internacionalização
```

## Stack Tecnológico

| Categoria | Tecnologia |
|-----------|------------|
| Framework | Flutter 3.x |
| State Management | flutter_bloc |
| Network | Dio + Retrofit |
| Local Storage | Hive + Secure Storage |
| Real-time | WebSocket Channel |
| Push | Firebase Messaging |
| Calendar | Table Calendar / Syncfusion |

## Requisitos

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android SDK (para Android)
- Xcode (para iOS)
- Backend Easy!Appointments com API JWT habilitada

## Instalação

```bash
# Clonar repositório
git clone <repo-url>
cd mobile-app

# Instalar dependências
flutter pub get

# Gerar código (models, injeção de dependências)
flutter pub run build_runner build --delete-conflicting-outputs

# Executar em modo desenvolvimento
flutter run
```

## Configuração

### Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto:

```env
API_BASE_URL=https://sua-api.com/api/v1
WEBSOCKET_URL=wss://sua-api.com/ws
```

### Firebase (Push Notifications)

1. Crie um projeto no Firebase Console
2. Baixe `google-services.json` (Android) e `GoogleService-Info.plist` (iOS)
3. Coloque os arquivos nas respectivas pastas:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`

## Build

### Android

```bash
# APK Debug
flutter build apk --debug

# APK Release
flutter build apk --release

# App Bundle (Play Store)
flutter build appbundle --release
```

### iOS

```bash
# Simulador
flutter build ios --simulator

# Release (requer certificados Apple)
flutter build ios --release
```

## Estrutura de Telas

| Tela | Descrição |
|------|-----------|
| Login | Autenticação com JWT |
| Home | Dashboard com resumo |
| Calendar | Calendário de agendamentos |
| Appointments | Lista de agendamentos |
| Appointment Detail | Detalhes do agendamento |
| Appointment Form | Criar/editar agendamento |
| Services | Lista de serviços |
| Profile | Perfil do usuário |

## API Endpoints Utilizados

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/auth/login` | POST | Login e obtenção de tokens |
| `/auth/refresh` | POST | Renovação de access token |
| `/appointments` | GET | Listar agendamentos |
| `/appointments` | POST | Criar agendamento |
| `/appointments/:id` | GET | Detalhes do agendamento |
| `/appointments/:id` | PUT | Atualizar agendamento |
| `/appointments/:id` | DELETE | Excluir agendamento |
| `/services` | GET | Listar serviços |
| `/providers` | GET | Listar profissionais |
| `/availabilities` | GET | Verificar disponibilidade |

## Testes

```bash
# Executar todos os testes
flutter test

# Testes com coverage
flutter test --coverage

# Testes de integração
flutter test integration_test/
```

## Contribuindo

1. Crie uma branch: `git checkout -b feature/nome-da-feature`
2. Commit suas mudanças: `git commit -m 'feat: descrição'`
3. Push para a branch: `git push origin feature/nome-da-feature`
4. Abra um Pull Request

## Versionamento

Seguimos [SemVer](https://semver.org/). Para versões disponíveis, veja as [tags do repositório](tags).

## Licença

GPL-3.0 - Veja [LICENSE](../LICENSE) para mais detalhes.

## Changelog

Veja [CHANGELOG.md](CHANGELOG.md) para histórico de mudanças.
