# Fluxo de Validação de Login e Habilitação de Usuários

## Resumo
O sistema agora valida o atributo `ind_habilitado` em **dois momentos críticos**:
1. **Durante o login** - Consulta Firestore para verificar credenciais e habilitação
2. **Na inicialização do app** - Valida se usuário em cache ainda está habilitado

---

## 1. Fluxo de Login (Method: `AuthService.login()`)

### Passo a Passo:
1. **Usuário insere credenciais** na tela de login
2. **Busca no Firestore** pela collection `users` com `login` igual ao inserido
3. **Se não encontrado** → Exceção: `'Usuário não encontrado'`
4. **Se encontrado**, extrai dados do documento:
   - Campo `login` (nome de usuário)
   - Campo `role` (admin ou user)
   - Campo `ind_habilitado` (S ou N)
5. **Valida habilitação** - Se `ind_habilitado != 'S'` → Exceção: `'Usuário inválido'`
6. **Valida senha** - Se não coincide → Exceção: `'Senha incorreta'`
7. **Se tudo OK** - Cria sessão no AuthService e salva em SharedPreferences

### Código Relevante:
```dart
final ind_habilitado = userData['ind_habilitado'] ?? 'S';
if (ind_habilitado != 'S') {
  throw Exception('Usuário inválido');
}
```

---

## 2. Validação na Inicialização (Method: `AuthService.loadUserFromPreferences()`)

### Passo a Passo:
1. **Ao iniciar o app**, verifica cache local (SharedPreferences)
2. **Se houver usuário em cache**, consulta Firestore para validar
3. **Se Firestore confirmar `ind_habilitado = 'S'`** → Carrega sessão
4. **Se Firestore mostrar `ind_habilitado = 'N'`** → Limpa cache e força novo login
5. **Se erro ao consultar Firestore** (sem internet) → Carrega do cache como fallback

### Código Relevante:
```dart
// Validar novamente no Firestore para garantir que o usuário ainda está habilitado
final firestoreIndHabilitado = userData['ind_habilitado'] ?? 'S';

// Se o usuário foi desabilitado no Firestore, não carregá-lo
if (firestoreIndHabilitado != 'S') {
  _currentUser = null;
  await prefs.clear();
  notifyListeners();
  return;
}
```

---

## 3. Verificação de Credenciais (Method: `AuthService.verifyCredentials()`)

Usada em operações como agendamentos. Segue o mesmo padrão de validação do login.

---

## 4. Cenários de Teste

### ✅ Cenário 1: Usuário Habilitado
- **Firebase**: `ind_habilitado = 'S'`
- **Ação**: Tenta fazer login
- **Resultado**: ✅ Login permitido

### ❌ Cenário 2: Usuário Desabilitado
- **Firebase**: `ind_habilitado = 'N'`
- **Ação**: Tenta fazer login
- **Resultado**: ❌ Mensagem: `'Usuário inválido'`

### ❌ Cenário 3: Usuário Desabilitado Enquanto Conectado
- **Situação Inicial**: Usuário logado com `ind_habilitado = 'S'`
- **Firebase Atualizado**: Admin muda para `ind_habilitado = 'N'`
- **Ação**: App reinicia
- **Resultado**: ❌ Sessão limpa, força novo login

### ⚠️ Cenário 4: Sem Conexão Internet
- **Situação**: Usuário logado, tenta usar app offline
- **Firestore**: Inacessível
- **Resultado**: ⚠️ Carrega do cache local (continuará usando app offline)

---

## 5. Estrutura do Documento Firestore

```json
{
  "login": "usuario1",
  "role": "user",
  "senha": "abc123",
  "ind_habilitado": "S"  // ou "N"
}
```

---

## 6. Fluxo Visual

```
┌──────────────────────────────────────────────────────────────┐
│                     TELA DE LOGIN                             │
└──────────────────────────────────────────────────────────────┘
                            │
                            ▼
                  Usuário insere credenciais
                            │
                            ▼
        ┌────────────────────────────────────────┐
        │  Busca no Firestore collection 'users' │
        └────────────────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
     ❌ Não encontrado          ✅ Encontrado
     "Usuário não encontrado"            │
                                         ▼
                          ┌──────────────────────────┐
                          │ ind_habilitado == 'S' ?  │
                          └──────────────────────────┘
                              │            │
                          ✅ SIM           ❌ NÃO
                              │            │
                              ▼            ▼
                      Verifica Senha  "Usuário inválido"
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
                ✅ Correto          ❌ Incorreto
                    │                "Senha incorreta"
                    ▼
            ✅ LOGIN PERMITIDO
                    │
                    ▼
        ┌─────────────────────────────────┐
        │ Salva em SharedPreferences      │
        │ Cria sessão no AuthService      │
        │ Notifica listeners               │
        └─────────────────────────────────┘
                    │
                    ▼
         ✅ Acessa HOME PAGE
```

---

## 7. Mensagens de Erro na Tela de Login

| Erro | Causa | Solução |
|------|-------|---------|
| `Usuário não encontrado` | Usuário não existe no Firestore | Verificar nome de usuário ou criar novo usuário |
| `Usuário inválido` | `ind_habilitado = 'N'` no Firestore | Contatar administrador para habilitar |
| `Senha incorreta` | Senha não coincide | Verificar Caps Lock e tentar novamente |

---

## 8. Administração de Usuários

### Para Desabilitar um Usuário:
1. Admin acessa "Gerenciar Usuários"
2. Seleciona usuário
3. Clica em "Editar"
4. Muda Status de "Habilitado" para "Desabilitado"
5. Clica em "Salvar"
6. Campo `ind_habilitado` no Firestore é atualizado para `'N'`

### Efeito Imediato:
- ❌ Usuário desabilitado **não consegue fazer login**
- ❌ Se já estava logado, será desconectado na próxima inicialização do app

---

## 9. Fluxo de Logout Automático

Quando um usuário é desabilitado enquanto o app está aberto:
1. Usuário continua usando o app (cache local)
2. Ao fechar e reabrir o app:
   - `loadUserFromPreferences()` é chamado
   - Consulta Firestore para validar
   - Detecção: `ind_habilitado = 'N'`
   - Ação: Limpa cache e força novo login
   - Resultado: Usuário redirecionado para LoginPage

---

## 10. Checklist de Implementação

- ✅ Modelo `User` com atributo `ind_habilitado`
- ✅ Campo `ind_habilitado` criado no Firestore ao criar usuários
- ✅ Validação no método `login()`
- ✅ Validação no método `verifyCredentials()`
- ✅ Validação ao carregar do cache (`loadUserFromPreferences()`)
- ✅ UI para gerenciar `ind_habilitado` no "Gerenciar Usuários"
- ✅ Mensagem de erro clara na tela de login ("Usuário inválido")
- ✅ Sincronização com Firestore em create/update/delete
